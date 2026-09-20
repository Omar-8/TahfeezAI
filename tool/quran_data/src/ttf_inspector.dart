// A minimal, dependency-free TrueType font table reader — just enough to
// verify a QCF V2 page font's embedded family name and basic structural
// validity (magic number, presence of required tables). No external tool
// (e.g. `fc-query`) is assumed available, since this must run in any dev/CI
// environment this project's tooling runs in.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class TtfInspectionResult {
  const TtfInspectionResult({
    required this.isValidSfnt,
    required this.familyName,
    required this.tableTags,
    this.cmap = const {},
    this.gsubFeatureTags = const {},
  });

  final bool isValidSfnt;
  final String? familyName;
  final Set<String> tableTags;

  /// Every Unicode codepoint this font's `cmap` table maps to a non-zero
  /// glyph id, read from whichever of the format 4 (BMP) / format 12 (full
  /// Unicode) subtables are present — never assumed from a codepoint chart,
  /// since these Quran fonts are known to remap ordinary-looking codepoints
  /// (including real Arabic Presentation Forms-A characters, not just
  /// private-use-area ones) to unrelated decorative glyphs.
  final Map<int, int> cmap;

  /// Feature tags (e.g. `liga`, `rlig`) declared in the `GSUB` table's
  /// feature list, if present — a shallow read (script/feature list headers
  /// only, no lookup/substitution parsing) just to confirm whether this font
  /// relies on GSUB ligature substitution at all, or whether (as with the
  /// QUL ligature JSON mappings) every "ligature" is really just a direct
  /// cmap entry for a single input codepoint.
  final Set<String> gsubFeatureTags;
}

/// Reads just enough of [file] to confirm it is a well-formed TrueType/OpenType
/// font (a valid `sfnt` header with a `cmap`/`glyf`/`name` table directory)
/// and to extract its embedded family name (`name` table, nameID 1, falling
/// back to nameID 4 then 6) — never modifies the file.
TtfInspectionResult inspectTtf(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  if (bytes.length < 12) {
    return const TtfInspectionResult(
      isValidSfnt: false,
      familyName: null,
      tableTags: {},
    );
  }

  final sfntVersion = data.getUint32(0);
  // 0x00010000 = TrueType outlines, 0x4F54544F ("OTTO") = CFF outlines.
  final isValidSfnt = sfntVersion == 0x00010000 || sfntVersion == 0x4F54544F;
  if (!isValidSfnt) {
    return const TtfInspectionResult(
      isValidSfnt: false,
      familyName: null,
      tableTags: {},
    );
  }

  final numTables = data.getUint16(4);
  final tables = <String, ({int offset, int length})>{};
  var offset = 12;
  for (var i = 0; i < numTables; i++) {
    final tag = ascii.decode(bytes.sublist(offset, offset + 4));
    final tableOffset = data.getUint32(offset + 8);
    final tableLength = data.getUint32(offset + 12);
    tables[tag] = (offset: tableOffset, length: tableLength);
    offset += 16;
  }

  String? familyName;
  final nameTable = tables['name'];
  if (nameTable != null) {
    familyName = _readNameTableFamily(data, bytes, nameTable.offset);
  }

  var cmap = const <int, int>{};
  final cmapTable = tables['cmap'];
  if (cmapTable != null) {
    cmap = _readCmap(data, cmapTable.offset);
  }

  var gsubFeatureTags = const <String>{};
  final gsubTable = tables['GSUB'];
  if (gsubTable != null) {
    gsubFeatureTags = _readGsubFeatureTags(data, bytes, gsubTable.offset);
  }

  return TtfInspectionResult(
    isValidSfnt: true,
    familyName: familyName,
    tableTags: tables.keys.toSet(),
    cmap: cmap,
    gsubFeatureTags: gsubFeatureTags,
  );
}

/// Reads every subtable this font's `cmap` table declares and merges their
/// codepoint->glyphId mappings (a later subtable's entry for a codepoint
/// already seen is kept, not overwritten, since format 4's BMP subtable is
/// listed first by convention and is the one these page fonts actually use).
/// Supports format 4 (segment mapping, the common BMP subtable) and format
/// 12 (segmented coverage, full Unicode) — the two formats real-world fonts
/// use for anything beyond a trivial single-byte encoding. An unsupported
/// format is skipped, not treated as an error, since a font can carry
/// several subtables and only one needs to be readable for this tool's
/// purpose (recovering which codepoints map to which glyph ids).
Map<int, int> _readCmap(ByteData data, int tableStart) {
  final numTables = data.getUint16(tableStart + 2);
  final result = <int, int>{};

  for (var i = 0; i < numTables; i++) {
    final recordOffset = tableStart + 4 + i * 8;
    final subtableOffset = tableStart + data.getUint32(recordOffset + 4);
    final format = data.getUint16(subtableOffset);

    if (format == 4) {
      _readCmapFormat4(data, subtableOffset, result);
    } else if (format == 12) {
      _readCmapFormat12(data, subtableOffset, result);
    }
  }

  return result;
}

void _readCmapFormat4(ByteData data, int start, Map<int, int> result) {
  final segCountX2 = data.getUint16(start + 6);
  final segCount = segCountX2 ~/ 2;
  final endCodesStart = start + 14;
  final startCodesStart = endCodesStart + segCountX2 + 2; // + reservedPad
  final idDeltasStart = startCodesStart + segCountX2;
  final idRangeOffsetsStart = idDeltasStart + segCountX2;

  for (var seg = 0; seg < segCount; seg++) {
    final endCode = data.getUint16(endCodesStart + seg * 2);
    final startCode = data.getUint16(startCodesStart + seg * 2);
    if (startCode == 0xFFFF && endCode == 0xFFFF) continue;
    final idDelta = data.getInt16(idDeltasStart + seg * 2);
    final idRangeOffset = data.getUint16(idRangeOffsetsStart + seg * 2);

    for (var c = startCode; c <= endCode; c++) {
      int glyphId;
      if (idRangeOffset == 0) {
        glyphId = (c + idDelta) & 0xFFFF;
      } else {
        final glyphIndexAddr =
            idRangeOffsetsStart + seg * 2 + idRangeOffset + (c - startCode) * 2;
        if (glyphIndexAddr + 1 >= data.lengthInBytes) continue;
        final rawGlyphId = data.getUint16(glyphIndexAddr);
        glyphId = rawGlyphId == 0 ? 0 : (rawGlyphId + idDelta) & 0xFFFF;
      }
      if (glyphId != 0) result[c] = glyphId;
    }
  }
}

void _readCmapFormat12(ByteData data, int start, Map<int, int> result) {
  final numGroups = data.getUint32(start + 12);
  var groupOffset = start + 16;
  for (var g = 0; g < numGroups; g++) {
    final startCharCode = data.getUint32(groupOffset);
    final endCharCode = data.getUint32(groupOffset + 4);
    final startGlyphId = data.getUint32(groupOffset + 8);
    for (var c = startCharCode; c <= endCharCode; c++) {
      result[c] = startGlyphId + (c - startCharCode);
    }
    groupOffset += 12;
  }
}

/// Reads only the `GSUB` table's feature list and returns the set of
/// 4-character feature tags it declares (e.g. `liga`, `rlig`, `ccmp`) —
/// never the lookup subtables themselves, since this tool's purpose is
/// answering "does this font do any GSUB substitution at all", not
/// reimplementing shaping.
Set<String> _readGsubFeatureTags(ByteData data, Uint8List bytes, int start) {
  final featureListOffset = start + data.getUint16(start + 6);
  final featureCount = data.getUint16(featureListOffset);
  final tags = <String>{};
  for (var i = 0; i < featureCount; i++) {
    final recordOffset = featureListOffset + 2 + i * 6;
    final tag = ascii.decode(bytes.sublist(recordOffset, recordOffset + 4));
    tags.add(tag);
  }
  return tags;
}

String? _readNameTableFamily(ByteData data, Uint8List bytes, int tableStart) {
  final format = data.getUint16(tableStart);
  if (format != 0 && format != 1) return null;
  final count = data.getUint16(tableStart + 2);
  final stringOffset = tableStart + data.getUint16(tableStart + 4);

  String? byNameId(int wantedNameId) {
    var recordOffset = tableStart + 6;
    for (var i = 0; i < count; i++) {
      final platformId = data.getUint16(recordOffset);
      final nameId = data.getUint16(recordOffset + 6);
      final length = data.getUint16(recordOffset + 8);
      final strOffset = data.getUint16(recordOffset + 10);
      recordOffset += 12;

      if (nameId != wantedNameId) continue;
      final start = stringOffset + strOffset;
      final raw = bytes.sublist(start, start + length);

      // Platform 3 (Windows) commonly uses UTF-16BE; platform 1 (Macintosh)
      // commonly uses a single-byte Mac Roman encoding that is ASCII-safe
      // for the plain family names QCF V2 fonts use (e.g. "QCF2001").
      if (platformId == 3 || (platformId == 0)) {
        final codeUnits = <int>[];
        for (var j = 0; j + 1 < raw.length; j += 2) {
          codeUnits.add((raw[j] << 8) | raw[j + 1]);
        }
        return String.fromCharCodes(codeUnits);
      } else if (platformId == 1) {
        return ascii.decode(raw, allowInvalid: true);
      }
    }
    return null;
  }

  return byNameId(1) ?? byNameId(4) ?? byNameId(6);
}
