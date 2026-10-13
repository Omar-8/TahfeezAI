import 'package:flutter/material.dart';

/// The verse-by-verse reader's own Arabic Quran font size when rendering
/// through the QPC Hafs font (`VerseBlock`/`BismillahDivider`) — larger
/// than [quranTextStyle]'s own default (26), because that Uthmani
/// calligraphy reads best with more room; the "make the Arabic Quran text
/// visually dominant" design goal. Applies whether or not the QPC Hafs
/// font actually loaded, so a font-load fallback never also shrinks the
/// text relative to how it looked with the font.
const quranVerseFontSize = 30.0;

/// The fonts Quran text may be drawn in (Ayah mode's choice): each built
/// for Uthmani Quran text, its annotation marks included — never a UI
/// font (`docs/DESIGN_DIRECTION.md`).
enum QuranFont {
  /// SIL's Scheherazade New: the default (as the Daily Ayah).
  scheherazade('Scheherazade New', 'شهرزاد'),

  /// Amiri Quran: classic Naskh, set for the Quran.
  amiri('Amiri Quran', 'الأميري');

  const QuranFont(this.family, this.arabicName);

  /// The `pubspec.yaml` font family.
  final String family;

  /// Its name, in Arabic.
  final String arabicName;
}

/// Builds the text style used to render Quran Arabic text in the
/// verse-by-verse reader.
///
/// Deliberately **not** part of [buildTahfeezTextTheme]/`app_typography.dart`
/// — per `docs/DESIGN_DIRECTION.md`'s "UI typography and Quran typography
/// are separate systems" rule, Quran text must never render with Tahfeez's
/// own UI font (Noto Sans / Noto Kufi Arabic).
///
/// Takes [color]/[fontFamily] as plain parameters rather than reading them
/// from a `BuildContext`/`WidgetRef` itself: [color] comes from
/// `MushafAppearanceController`, a feature-layer concern `core/theme` must
/// not import directly (`docs/ARCHITECTURE.md` §1's dependency direction) —
/// callers (`VerseBlock`/`BismillahDivider`) resolve it and pass it in.
/// [fontFamily] exists for the same reason: those callers resolve
/// `uthmanicHafsFontManifestProvider`'s font and pass it through, but only
/// when paired with that font's own validated QPC Hafs display text (see
/// `docs/QURAN_DATA_PROVENANCE.md` §16/§17) — plain canonical `AyahWord`
/// text through this font was found to mis-render several genuine Uthmani
/// Quran-annotation marks. `fontFamily: null` is the honest, expected
/// fallback to the platform's own default Arabic-capable system font
/// whenever that pairing isn't available, not an error.
TextStyle quranTextStyle({
  required Color color,
  String? fontFamily,
  double fontSize = 26,
}) {
  return TextStyle(
    fontSize: fontSize,
    height: 1.9,
    color: color,
    fontFamily: fontFamily,
  );
}
