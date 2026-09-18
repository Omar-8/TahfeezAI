# Tahfeez AI — Third-Party Resource Register

Per `docs/CLEAN_ROOM_RULES.md`, every external resource shipped or downloaded by Tahfeez must be
recorded here before use, with its permissions verified from the upstream license itself — never
assumed. This file is created for the first time in Milestone 3 (Design System), which is the
first milestone to actually bundle a third-party asset (a UI typeface). No Quran text, translation,
tafsir, or audio resource has been integrated yet — see `docs/DATA_RESOURCE_REQUIREMENTS.md` for
that separate, still-unresolved research.

| Resource | Type | Source | Version | License | Attribution | Redistribution | Offline redistribution | Modification | Checksum/version strategy | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| Noto Sans (variable font) | Font | https://github.com/google/fonts/tree/main/ofl/notosans | google/fonts commit `f2bd09b` (2026-09-18), copyright 2022 The Noto Project Authors | SIL Open Font License 1.1 (https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/OFL.txt) | Not required, but copyright/license notice must be retained if the font file itself is redistributed unmodified (standard OFL term) | Yes — OFL explicitly permits bundling, embedding, and redistributing within an application | Yes — OFL places no online/offline distinction; bundling in an offline-capable app is standard, widely-practiced OFL use | Yes, with conditions — OFL permits modification but a modified font may not be sold by itself and must not use the original reserved font name in a way that implies endorsement | SHA-256 `bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d` (`assets/fonts/NotoSans-Variable.ttf`) | Tahfeez's UI (chrome/Latin) typeface — never used to render canonical Quran Arabic text, per `docs/CLEAN_ROOM_RULES.md` Quran-correctness rules and `docs/DESIGN_DIRECTION.md`'s UI/Quran typography separation |
| Noto Sans Arabic (variable font) | Font | https://github.com/google/fonts/tree/main/ofl/notosansarabic | google/fonts commit `f2bd09b` (2026-09-18), copyright 2022 The Noto Project Authors | SIL Open Font License 1.1 (https://raw.githubusercontent.com/google/fonts/main/ofl/notosansarabic/OFL.txt) | Not required, same OFL notice-retention term as above | Yes | Yes | Yes, with conditions — same OFL terms as above | SHA-256 `63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e` (`assets/fonts/NotoSansArabic-Variable.ttf`) | Tahfeez's UI (chrome/Arabic — settings, buttons, labels) typeface, paired with Noto Sans via `fontFamilyFallback` for mixed Latin/Arabic UI strings. Also never used for canonical Quran text. |

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
