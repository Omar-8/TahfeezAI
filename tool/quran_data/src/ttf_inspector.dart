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
  });

  final bool isValidSfnt;
  final String? familyName;
  final Set<String> tableTags;
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

  return TtfInspectionResult(
    isValidSfnt: true,
    familyName: familyName,
    tableTags: tables.keys.toSet(),
  );
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
