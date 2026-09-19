# Tahfeez AI — Third-Party Resource Register

Per `docs/CLEAN_ROOM_RULES.md`, every external resource shipped or downloaded by Tahfeez must be
recorded here before use, with its permissions verified from the upstream license itself — never
assumed. This file is created for the first time in Milestone 3 (Design System), which is the
first milestone to actually bundle a third-party asset (a UI typeface).

Canonical Quran text, translations, and tafsir were integrated in the "Production Quran Data
Integration" milestone — see `docs/QURAN_DATA_PROVENANCE.md` for the full per-resource detail
(exact editions, versions, content hashes, and license terms) that this table summarizes. The
Mushaf page/line layout and its glyph font remain blocked (`SHIP_BLOCKED_PENDING_WORD_DATA` /
`SHIP_BLOCKED_LICENSE`) and are recorded as such below, not silently treated as permitted.
`docs/DATA_RESOURCE_REQUIREMENTS.md` has the original, now-superseded planning research.

| Resource | Type | Source | Version | License | Attribution | Redistribution | Offline redistribution | Modification | Checksum/version strategy | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| Noto Sans (variable font) | Font | https://github.com/google/fonts/tree/main/ofl/notosans | google/fonts commit `f2bd09b` (2026-09-18), copyright 2022 The Noto Project Authors | SIL Open Font License 1.1 (https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/OFL.txt) | Not required, but copyright/license notice must be retained if the font file itself is redistributed unmodified (standard OFL term) | Yes — OFL explicitly permits bundling, embedding, and redistributing within an application | Yes — OFL places no online/offline distinction; bundling in an offline-capable app is standard, widely-practiced OFL use | Yes, with conditions — OFL permits modification but a modified font may not be sold by itself and must not use the original reserved font name in a way that implies endorsement | SHA-256 `bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d` (`assets/fonts/NotoSans-Variable.ttf`) | Tahfeez's UI (chrome/Latin) typeface — never used to render canonical Quran Arabic text, per `docs/CLEAN_ROOM_RULES.md` Quran-correctness rules and `docs/DESIGN_DIRECTION.md`'s UI/Quran typography separation |
| Noto Sans Arabic (variable font) | Font | https://github.com/google/fonts/tree/main/ofl/notosansarabic | google/fonts commit `f2bd09b` (2026-09-18), copyright 2022 The Noto Project Authors | SIL Open Font License 1.1 (https://raw.githubusercontent.com/google/fonts/main/ofl/notosansarabic/OFL.txt) | Not required, same OFL notice-retention term as above | Yes | Yes | Yes, with conditions — same OFL terms as above | SHA-256 `63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e` (`assets/fonts/NotoSansArabic-Variable.ttf`) | Tahfeez's UI (chrome/Arabic — settings, buttons, labels) typeface, paired with Noto Sans via `fontFamilyFallback` for mixed Latin/Arabic UI strings. Also never used for canonical Quran text. |
| Tanzil canonical Quran text (Uthmani, v1.1) | Quran text | https://tanzil.net (pub/download) | Uthmani, Version 1.1 | Tanzil text license (CC-BY-3.0-style); verbatim only, "CHANGING IT IS NOT ALLOWED" (https://tanzil.net/docs/text_license) | Required — source (Tanzil Project) + link to tanzil.net | Yes — explicitly permitted for apps | Yes — verified via `DatasetIntegrityValidator` before every import | No modification permitted; Tahfeez performs zero content edits (see `docs/QURAN_DATA_PROVENANCE.md` §1's documented Bismillah-parsing rule, not a text edit) | SHA-256 `bf4f57b968d03f4131c070b1e285da9be0e0a108a21c910e872801ca273312c8` | Canonical `Surahs`/`Ayahs`/`AyahWords` (script `tanzil_uthmani`). Full detail: `docs/QURAN_DATA_PROVENANCE.md` §1. |
| Tanzil Quran metadata (quran-data.xml) | Quran structural metadata | https://tanzil.net/res/text/metadata/quran-data.xml | root `license="cc-by"`, copyright 2008-2009 Tanzil.info | CC-BY | Required | Yes | Yes | No modification | SHA-256 `8867c1d88191472adec9db694b3cd9f135b1a2ef580574d32cf888dcb22c5c7a` | Surah metadata, Juz/Hizb/Rub/Manzil/Ruku/Sajdah navigation. Full detail: `docs/QURAN_DATA_PROVENANCE.md` §2. |
| QuranEnc English translation (Rowwad) | Translation | https://quranenc.com (key `english_rwwad`) | 1.0.19 | QuranEnc Terms and Policies — no modification, attribution + version + update obligations (full text in `docs/QURAN_DATA_PROVENANCE.md` §6) | Required (publisher + source + version) | Yes | No (attribution/version/update conditions only) | SHA-256 `77e2ede3d8e6d6b5c6e16ff78eda2d2b6cc0a6b7489c94a5dde4f7481f5fdee8` | `TranslationDatabase` slug `en-rowwad`. Full detail: `docs/QURAN_DATA_PROVENANCE.md` §3. |
| QuranEnc German translation (Rowwad) | Translation | https://quranenc.com (key `german_rwwad`) | 1.0.15 | Same QuranEnc Terms and Policies as above | Required | Yes | No | SHA-256 `32c6a6e0e45b4ece65f3b85094fa6f4c0a9b9bdc5c94a7933e8fe711efb5125e` | `TranslationDatabase` slug `de-rowwad`. Full detail: `docs/QURAN_DATA_PROVENANCE.md` §4. |
| QuranEnc Tafsir Al-Muyassar (Arabic) | Tafsir | https://quranenc.com (key `arabic_moyassar`) | Unversioned upstream (QuranEnc publishes no version number for this resource; tracked by content hash) | Same QuranEnc Terms and Policies as above | Required | Yes | No | SHA-256 `eb384e586487b089b826375d3f705d07e775e0019325da405e0337a9f6b3da04` | `TafsirDatabase` id `ar-muyassar`. Full detail: `docs/QURAN_DATA_PROVENANCE.md` §5. |
| QUL KFGQPC V2 Mushaf layout (1421H print) | Mushaf page/line layout | https://qul.tarteel.ai (login-gated download) | KFGQPC V2, 604 pages, 15 lines/page | **Unverified** — QUL's per-resource license page requires the same login gate that blocks automated access; QUL's platform MIT license does **not** cover this data resource | Unverified | **`SHIP_BLOCKED_LICENSE`** | Unverified | SHA-256 `e4df98f35dd3b8927ff096337c8739e0f0b12c8ba622834c345eaa4c3e28dd8c` (vendored at `tool/quran_data/sources/qpc-v2-15-lines.db.zip`) | Layout validated structurally (604 pages, 15 lines/page, correct line-type counts) and cross-audited against the word dataset below; **not imported** into the shipped dataset yet. No synthetic data substituted. Full detail: `docs/QURAN_DATA_PROVENANCE.md` §7. |
| QUL QPC V2 Glyph - Word by Word (resource id 61) | Mushaf word/glyph data | https://qul.tarteel.ai/resources/quran-script/61 (login-gated download) | Table `words`, 83,668 rows | **Unverified** — same login gate; QUL's platform MIT license does **not** cover this data resource | Unverified | **`SHIP_BLOCKED_LICENSE`** | Unverified | SHA-256 `4bf9549dfcfd367d4d4b151bd58b51af63b677d1c980cf5e52541c2f981d7e6d` (vendored at `tool/quran_data/sources/qpc-v2-word-by-word.db.zip`) | Audited against the layout above (word-id resolution, monotonicity, per-ayah counts vs. canonical text) and against canonical Tanzil data via `MushafTokenClassifier`; **not imported** into the shipped dataset yet. Full detail: `docs/QURAN_DATA_PROVENANCE.md` §7a/§7b. |
| QCF V2 Mushaf glyph font | Font | https://qul.tarteel.ai/resources/font/249 (login-gated download; per-page files also reachable via a CDN of unverified redistribution status) | v2, 604 per-page TTFs (`QCF2001`..`QCF2604`) | **Unverified** | Unverified | **`SHIP_BLOCKED_LICENSE`** | Unverified | — | Obtained by the project owner; confirmed genuinely page-specific via direct `cmap` inspection (identical codepoints draw different glyphs per page). Not committed to git pending a packaging decision, not bundled, not used anywhere in Tahfeez yet. Full detail: `docs/QURAN_DATA_PROVENANCE.md` §8. |

## Provenance notes

- Both files were fetched directly from Google's own `google/fonts` GitHub repository (the
  canonical distribution point for Google Fonts' static/variable font files), not from a
  third-party mirror, and their `OFL.txt` license files were fetched from the same commit and are
  archived alongside the fonts in `assets/fonts/`.
- Both are single-file variable fonts (a `wght` weight axis, `NotoSans[wdth,wght].ttf` /
  `NotoSansArabic[wdth,wght].ttf` upstream), which is why only one file per family is bundled
  rather than one file per weight.
- Chosen specifically because the Noto family is explicitly designed by Google for exactly this
  pairing use case (visually harmonious multi-script UI text), and because OFL 1.1 is one of the
  most well-understood, permissively-documented font licenses for exactly this kind of bundling.

## Rules

- Do not mark a permission as "Yes" unless it has been verified from the upstream terms/license.
- Store links to the exact license/terms page where practical.
- Record resource-specific attribution text if required.
- Quran text, fonts, translations, tafsir, audio recordings, AI models, and artwork must be audited separately.
- A software repository license does not automatically define the rights of third-party content referenced by that repository.
