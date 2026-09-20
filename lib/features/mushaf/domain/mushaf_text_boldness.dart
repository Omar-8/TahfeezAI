/// A user-facing, semantic preference for how bold Mushaf-mode Quran glyph
/// text looks — never exposed to callers as a raw stroke-width `double`
/// (see [strokeWidthForMushafBoldness]), and never a `FontWeight` value:
/// the vendored QCF page fonts are single-weight and are always painted at
/// `FontWeight.w400` regardless of this preference (see
/// `mushaf_page_render_model.dart`'s stroke-behind-fill mechanism, and the
/// real Flutter/Skia comparison that ruled out synthetic/faux bold — it
/// thickened small Quranic marks and ayah-marker ornaments unevenly
/// relative to base letterforms).
enum MushafTextBoldness { light, medium, bold }

extension MushafTextBoldnessX on MushafTextBoldness {
  String get label => switch (this) {
    MushafTextBoldness.light => 'Light',
    MushafTextBoldness.medium => 'Medium',
    MushafTextBoldness.bold => 'Bold',
  };
}

/// The single source of truth mapping a [MushafTextBoldness] preference to
/// the stroke width (logical px) the Mushaf Quran-glyph renderer's
/// stroke-behind-fill pass paints with — never scattered as a magic number
/// across widgets/providers. Chosen from a real visual comparison across
/// representative dense-diacritic Mushaf pages (Ayat al-Kursi, a Surah
/// transition, the Mushaf's final page): every value here stayed clean at
/// that comparison (no muddying/merging of small marks, ayah-marker
/// ornaments, waqf signs, hamza/madda, or superscript alif) — `light` is
/// the least perceptible increase over the font's own default rendering
/// that still reads as intentional, `bold` is the most emboldened value
/// that comparison judged still fully clean.
double strokeWidthForMushafBoldness(MushafTextBoldness value) =>
    switch (value) {
      MushafTextBoldness.light => 0.25,
      MushafTextBoldness.medium => 0.30,
      MushafTextBoldness.bold => 0.40,
    };
