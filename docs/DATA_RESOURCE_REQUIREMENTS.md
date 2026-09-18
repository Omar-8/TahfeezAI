# Tahfeez AI — Data Resource Requirements

Per `prompts/milestones/MILESTONE_02_QURAN_DATA_ENGINE.md` and `docs/CLEAN_ROOM_RULES.md`, this
document is **planning and license research only**. No dataset listed here has been integrated
into Tahfeez. `QuranApp`'s bundled database has **not** been imported, and will not be. A dataset
may be integrated only after its specific source and terms are recorded in
`docs/THIRD_PARTY_RESOURCES.md` — this document exists to make that a well-informed decision when
it happens, not to authorize it now.

All license summaries below were read directly from each project's own current license/terms
page (URLs given per source) as of this milestone. They are summaries for planning purposes, not
legal advice — final integration must re-verify terms at that time, since they can change.

---

## 1. Canonical Arabic Quran text (per script)

- **Purpose**: the authoritative Arabic text every other dataset below (words, Mushaf lines,
  navigation ranges) is structured around. Maps to `QuranDatabase`'s `Surahs`/`Ayahs`/`AyahWords`
  tables (`lib/quran/data/tables/`).
- **Required fields**: for every verse — chapter number, verse number, full Arabic text (ideally
  already word-segmented, or segmentable deterministically); for every chapter — verse count,
  revelation order, revelation place (Meccan/Medinan).
- **Format**: candidate sources ship as XML, plain delimited text, or SQLite; any is workable
  since `QuranDatasetPayload` (`lib/quran/domain/quran_dataset_payload.dart`) decouples "source
  format" from "how it's imported" — a new source only needs a new parser feeding the same
  payload shape.
- **Candidate independent sources**:
  - **Tanzil.net** — Uthmani and Simple/Clean encodings. License: a Tanzil-specific text license
    (CC-BY-3.0-style). Offline redistribution in apps is **explicitly permitted**: "This Quran
    text can be used in any website or application, provided that its source (Tanzil Project) is
    clearly indicated, and a link is made to tanzil.net." Attribution and a link to tanzil.net are
    required in every verbatim copy. **Modification is explicitly forbidden** ("CHANGING IT IS NOT
    ALLOWED") — verbatim use only, which aligns naturally with `CLAUDE.md`'s "never silently edit
    Quran text" rule. Source: <https://tanzil.net/docs/text_license>.
  - **Al Quran Cloud** (alquran.cloud) — both a live API and a bulk-embeddable text source per its
    own terms. Non-commercial reproduction/embedding/storage is unconditionally free; **commercial
    reproduction, including paid apps that bundle the corpus offline, "requires no permission...
    but a respectful acknowledgement of the source in the colophon is the minimum courtesy."**
    Reproductions must faithfully preserve Uthmani orthography/diacritics and must not be altered
    or commingled with non-Quranic material in a way that could be mistaken for the Quran. Source:
    <https://alquran.cloud/terms-and-conditions>.
  - **QUL — Quranic Universal Library** (qul.tarteel.ai, Tarteel AI / Digital Khadeeja Foundation)
    — offers Arabic scripts among many other resource types. **License is not uniform across QUL's
    datasets**: the QUL *platform/codebase* is MIT-licensed, but per QUL's own FAQ, "the resources
    available on QUL vary in their copyright status. Some are in the public domain, while others
    may be subject to specific licenses," and commercial use is generally allowed but reviewers
    must "review the licensing terms for each resource." **Each individual QUL dataset's license
    must be checked before use — there is no blanket grant.** Sources:
    <https://qul.tarteel.ai/faq>, <https://qul.tarteel.ai/resources>.
- **License status**: Tanzil and Al Quran Cloud both look workable for Tahfeez's offline,
  potentially-commercial use case, subject to their respective attribution/non-alteration
  conditions; QUL requires per-resource verification. **Not yet verified to the standard
  `docs/CLEAN_ROOM_RULES.md` requires for shipping** — no text has been integrated.
- **Redistribution requirements**: attribution/link-back (Tanzil), colophon acknowledgement
  (Al Quran Cloud), and in both cases no modification of the canonical text itself.
- **Integrity verification**: `DatasetIntegrityValidator` (`lib/quran/domain/dataset_integrity.dart`)
  already enforces exactly 114 surahs, contiguous ayah numbering per surah matching the declared
  `ayahCount`, unique/stable ayah ids, and non-blank word text for every ayah. Before any real
  import, the importer should additionally compare a hash of the raw source file(s) against a
  publicly documented checksum from the upstream project, recorded as this dataset's `contentHash`
  in `DatasetMetadata`.

## 2. Surah metadata and localized names

- **Purpose**: chapter-level structural facts (verse count, revelation order/place, Ruku count)
  plus per-language display names/meanings. Maps to `Surahs`/`SurahLocalizations`.
- **Required fields**: surah number, verse count, revelation order, revelation place, Ruku count;
  per language — chapter name and (where available) its meaning/translation.
- **Format**: typically bundled with the text source above (Tanzil and Al Quran Cloud both expose
  chapter metadata alongside verse text) or QUL's chapter-metadata exports.
- **Candidate independent sources**: the same sources as §1, since chapter metadata is normally
  distributed together with verse text; localized chapter names specifically may need a
  supplementary source per target language (Tahfeez currently ships English and Arabic UI locales
  per `docs/reference/15_LOCALIZATION_SPEC.md` — this dataset's language coverage does not need to
  match the UI locale list one-for-one).
- **License status**: inherits from whichever verse-text source is ultimately chosen for §1.
- **Redistribution requirements**: same as §1.
- **Integrity verification**: the validator's `surah_count`/`surah_missing`/`ayah_numbering`
  checks directly cover this table; a chapter with a `SurahLocalization` row missing for a
  supported language degrades gracefully (the reader falls back per
  `docs/reference/15_LOCALIZATION_SPEC.md` §3's fallback-chain approach) rather than failing
  import.

## 3. Ayah structural metadata (Juz/Hizb/Rub/Manzil/Ruku/Sajdah)

- **Purpose**: the traditional reading/navigation divisions, stored per-ayah (`Ayahs.juzNo` etc.)
  and per-range (`NavigationRanges`) so `QuranRepository` can answer "what Juz/Hizb is this verse
  in" without recomputation.
- **Required fields**: for every verse — its Juz, Hizb, Rub, Manzil, and Ruku number, and whether
  it carries a Sajdah (and of which kind); for every Juz/Hizb/Rub/Manzil — which chapter(s) and
  verse ranges it spans.
- **Format**: these divisions are traditional and effectively invariant across sources; most
  Quran datasets (including Tanzil's and QUL's) include them as auxiliary metadata rather than
  requiring a separate source.
- **Candidate independent sources**: same as §1; cross-checked against a second independent source
  before import, since these boundaries must be exactly correct (an off-by-one Juz boundary is a
  correctness bug, not a display bug).
- **License status**: inherits from the chosen source; these are traditional divisions rather than
  original creative content, but the specific dataset encoding them is still a licensed work.
- **Integrity verification**: the validator's `navigation_range_invalid_bounds` and
  `navigation_range_unknown_surah` checks cover `NavigationRanges`; a recommended addition before
  real import (not yet implemented, since it needs real reference numbers to check against) is a
  fixed-count assertion — exactly 30 Juz, 60 Hizb, 240 Rub, and 7 Manzil — mirroring the existing
  "exactly 114 Surahs" pattern.

## 4. Mushaf page/line maps (per script/edition)

- **Purpose**: the printed pagination — which words fall on which line of which page, for a given
  Mushaf edition. Maps to `Mushafs`/`MushafLines` (`lib/quran/domain/models/mushaf_models.dart`,
  `docs/reference/05_MUSHAF_SPEC.md` §2). This is the hardest dataset to source independently:
  page/line layout is specific to a particular typeset edition, not a generic property of the
  Quran text.
- **Required fields**: per (Mushaf, page, line) — line type (chapter header / Bismillah / Quran
  text), centering flag, and the start/end (ayah, word-index) the line spans.
- **Format**: QUL explicitly offers "Mushaf layouts/page-line maps" as one of its dataset
  categories (JSON/SQLite exports).
- **Candidate independent sources**: **QUL** is presently the most directly relevant known source
  for this specific dataset category. Per §1's QUL finding, **its license must be checked per
  resource before use** — this is not yet done, and a Mushaf-layout dataset is exactly the kind of
  resource QUL's FAQ says to individually review.
- **License status**: unverified. This is the dataset most likely to require direct correspondence
  with the source project (as QUL's own FAQ and a related GitHub issue about a separate
  commercial-licensing question suggest is sometimes necessary) rather than a self-service license
  page.
- **Redistribution requirements**: unknown until the specific resource's license is reviewed.
- **Integrity verification**: `DatasetIntegrityValidator`'s `mushaf_page_out_of_range`,
  `mushaf_lines_not_contiguous`, `line_missing_word_range`, `line_references_unknown_ayah`, and
  `line_range_reversed` checks all target this table specifically, since it is the one most prone
  to off-by-one or boundary errors when transcribed from a source format Tahfeez did not design.

## 5. Quran script/font rendering assets

- **Purpose**: the actual glyphs used to render Arabic text on screen (a later, Mushaf-renderer
  milestone's concern, `docs/reference/05_MUSHAF_SPEC.md` §5 and §7) — listed here only because
  script/font selection is entangled with which Mushaf pagination dataset (§4) is usable, since a
  Mushaf's line-fitting is typeset against one specific font.
- **Explicit exclusion already recorded**: `docs/reference/05_MUSHAF_SPEC.md` §7 already flags
  that the reference app's own KFQPC-style font/glyph files must **not** be copied into Tahfeez.
  This milestone does not select a replacement; that is later Mushaf/Design-System milestone work.
- **Candidate independent sources**: not researched in this milestone; candidates commonly used by
  other open Quran projects include King Fahd Quran Printing Complex fonts (license terms vary and
  have historically been restrictive) and community-maintained open fonts such as those in the
  Amiri/KFGQPC-alternative space — none verified here.
- **License status**: unresearched. Flagged for the milestone that actually selects a rendering
  font.

## 6. Word segmentation (`AyahWords.wordIndex`)

- **Purpose**: how each verse's Arabic text is split into individually addressable words — the
  shared index space Mushaf glyph placement, word-by-word translation, and per-word tap targets
  all key off (`docs/reference/04_READER_SPEC.md` §14, §8 of the Mushaf spec). This is a property
  of the text source chosen in §1: most Quran text sources already ship space-delimited words,
  making segmentation a matter of splitting on whitespace consistently rather than a separate
  dataset.
- **Note on scope**: word-by-word **translation/transliteration** (a separate downloadable
  resource per `docs/reference/14_WORD_BY_WORD_SPEC.md`, owned by `lib/core/audio`-adjacent
  download infrastructure per `docs/ARCHITECTURE.md`) is explicitly **not** part of the immutable
  `QuranDatabase` this milestone owns — only the canonical word *text* and its position within a
  verse are.
- **Integrity verification**: the validator's `word_indices_not_contiguous` check.

## 7. Explicitly out of scope for this milestone

Per `prompts/milestones/MILESTONE_02_QURAN_DATA_ENGINE.md`, translations, tafsir, word-by-word
translation content, recitation audio, and reference-content collections (duas, topics, etc.) are
separate downloadable resources owned by later milestones
(`docs/ARCHITECTURE.md` §9, `docs/reference/13_TRANSLATION_TAFSIR_SPEC.md`,
`docs/reference/14_WORD_BY_WORD_SPEC.md`) and are not evaluated here. The Quranic Arabic Corpus
(corpus.quran.com) was researched as a *candidate* word-by-word morphology source for that future
milestone and is recorded here for continuity: it is **GPL-licensed and explicitly restricted to
non-commercial/research use** ("an annotated Quran available freely for non-commercial use under
the GNU public license," per <https://corpus.quran.com/faq.jsp>) — **not usable as-is** in a
commercial app without separate permission from its maintainers, and its GPL copyleft would also
need review before any code (not just data) derived from it was used. This should be re-evaluated
by whichever milestone actually selects a word-by-word data source.

## 8. Summary table

| Dataset | Best current candidate | Offline redistribution | Commercial use | Modification | Verified? |
|---|---|---|---|---|---|
| Canonical Arabic text | Tanzil.net or Al Quran Cloud | Yes (with attribution) | Yes | No (verbatim only) | License read; not yet integrated |
| Surah metadata/localization | Same as above | Yes | Yes | No | Inherits from text source |
| Juz/Hizb/Rub/Manzil/Sajdah | Same as above | Yes | Yes | No | Inherits from text source |
| Mushaf page/line maps | QUL (per-resource check needed) | Unverified | Likely, per-resource | Unverified | **Not verified — needs per-resource review** |
| Script/font assets | Not researched | — | — | — | **Not researched** |
| Word-by-word morphology (future milestone) | Quranic Arabic Corpus | No (non-commercial only) | **No** | GPL copyleft | Verified unusable as-is |

## 9. Next steps before any real integration

1. Pick one canonical-text source (§1) and one Mushaf-layout source (§4), and obtain their exact
   current license text (not just this document's summary) in writing/archived form.
2. Compute and record a `contentHash` for the exact files used.
3. Record the resource in `docs/THIRD_PARTY_RESOURCES.md` per `docs/CLEAN_ROOM_RULES.md`'s
   resource-register template, before writing any importer that targets it.
4. Only then build a concrete `QuranDatasetPayload` source/parser for that dataset — the
   `QuranDatasetImporter`/`DatasetIntegrityValidator` pipeline built in this milestone does not
   change regardless of which source is eventually chosen.
