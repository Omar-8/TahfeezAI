/// Which engine draws a Mushaf page's Quran ink, Surah headers, Bismillah,
/// ayah markers, and decorations.
///
/// This is the single selection point `MushafPageView` branches on — no
/// other file should ask "which backend" via its own check. Both backends
/// are driven by the same canonical `(mushafId, pageNumber)` and communicate
/// word/ayah hits back through the same `MushafTokenHitRect`
/// (`mushaf_page_render_model.dart`) and canonical `WordRef`/`VerseRef`
/// (`lib/quran/domain/models/quran_refs.dart`) types — see
/// `docs/QURAN_ENGINE_MIGRATION.md` for the full architecture.
enum MushafRenderBackend {
  /// The existing, production QPC V2 page-specific-font renderer
  /// (`docs/MUSHAF_RENDERING.md`) — line-level shaping, `MushafPagePainter`.
  qpcV2,

  /// Quran Engine (`quran-ws/quran-engine`), via its own official Android
  /// (`qvp_flutter`) and Web (`qvp.js`/WASM) wrappers — the engine renders
  /// the complete page itself; Tahfeez never reimplements its glyph
  /// rendering or hit-testing.
  quranEngine,
}
