# Translation and tafsir milestone (18) — plan

Status: planned 2026-10-09; T1, T2, T4 and T5 done the same day; T3 (word meanings) deferred. Decisions by the product owner are marked **(decided)**; open
ones **(open)**.

## Goal

Meaning alongside the Mushaf, fully offline: tap a word for its meaning, long-press for its
ayah's translation and tafsir. What is shown is chosen once in Settings, not from a button on
every Mushaf page. Quran text is never changed; translations and tafsir are separate,
source-verified resources with their provenance recorded
(`docs/THIRD_PARTY_RESOURCES.md`).

## Decisions

- **(decided)** The Mushaf's top-bar "Translation & tafsir" button is removed; the choices
  live in **Settings → Translation & tafsir**.
- **(decided)** Word sheet: the word's translation (and transliteration if turned on).
- **(decided)** Ayah sheet (long-press): translation, tafsir, or both — the user's choice.
- **(decided)** Word-by-word source: **QUL / Quran.com word translations, licence checked
  first** — their terms are looked up and reported before anything ships (see "Data").
- **(decided)** Launch languages: **English, Arabic, Urdu, Indonesian, Turkish, French** —
  an ayah translation in each (none needed for Arabic) and a short tafsir where a
  license-clean one exists (Al-Muyassar for Arabic; Al-Mukhtasar candidates for the others).
- **(decided)** **Everything bundled**: fully offline from install, no downloads. The app
  grows about 1–2 MB (compressed) per language; T4 becomes adding the remaining launch
  languages to the bundle rather than a download system.

## Data, and whether it can all be offline

Yes: every resource here is plain text stored in local SQLite (Drift) databases, already the
case for the two translations and the tafsir bundled today. Nothing needs a server once it is
on the device. Sizes are small next to the app (≈ 290 MB, mostly the recitation model):

| Resource | Have now | Size each (raw → in the APK, compressed) | Source / license |
|---|---|---|---|
| Ayah translations | English, German (Rowwad) | ~1.5–2 MB → ~0.6 MB | QuranEnc: offline redistribution allowed, no modification, attribution + version (decided earlier, `docs/QURAN_DATA_PROVENANCE.md`). ~70 languages available |
| Tafsir | Al-Muyassar (Arabic) | 3 MB → ~1 MB | QuranEnc, same terms |
| Short tafsir in other languages | — | ~3–5 MB each | **Candidate:** QuranEnc's *Al-Mukhtasar fī Tafsīr* translations (English and others), same terms — to verify per language |
| Long classical tafsir (e.g. Ibn Kathīr, al-Saʿdī, Arabic) | — | 8–40 MB each | Texts are classical, but each **digital edition** has its own rights — verify per source before shipping |
| Word meanings (word by word) | **none** | ~2–3 MB per language (77,429 words) | **Open.** Candidates: (1) QUL / Quran.com word translations — many languages, license "per resource", unverified; (2) Quranic Arabic Corpus English — GPL **and non-commercial only**, so usable only if Tahfeez stays non-commercial, ideally with the maintainers' consent; (3) none for now (word sheet keeps "no data"). Word meanings are never generated with AI |

Integrity checks for every import: one entry per ayah (6,236) or per canonical word, keyed to
the canonical ayah / word ids (never to Mushaf glyph data), with SHA-256 recorded per file,
as the existing translation import already does.

### Word meanings: licence check (2026-10-09)

QUL lists word-by-word sets for every launch language (English #92, Urdu #93, French #95,
Indonesian #96, Turkish #99 — also Persian, Bengali, Hindi, Tamil, Ingush; German #472 and
Russian #97 are marked "© copyrighted"), as JSON or SQLite. Findings:
- every set's copyright page says *"We don't have copyright information for this
  resource"*;
- QUL's FAQ: resources "vary in their copyright status"; commercial use of QUL data is
  allowed in general, but "review the licensing information provided by each resource's
  author before use";
- these are Quran.com's word-by-word data (third parties cite its API v4 as the source); no
  licence from Quran.com for it was found.

So the status is **unverified**, like the Mushaf page corpus. Shipping needs either written
permission from Quran.com / Tarteel (the QUL maintainers) or an explicit owner decision to
ship while unverified, recorded in `docs/THIRD_PARTY_RESOURCES.md`.

## The user's surfaces

- **Settings → Translation & tafsir:**
  - *Ayah translations:* which (one or more) of the installed ones;
  - *Tafsir:* which one;
  - *When I long-press an ayah, show:* translation · tafsir · both;
  - *Word meaning:* language, and transliteration on / off;
  - (with packs) installed / available, size, download, delete.
- **Word sheet** (tap): the word, its meaning (and transliteration), recitation feedback as
  today.
- **Ayah sheet** (long-press, highlighted ayah): the ayah, then translation(s) and/or the
  tafsir as chosen. Tafsir shows its opening, with "Read more" opening the full tafsir
  reader at that ayah.
- The Mushaf page itself stays clean: no translation button, nothing printed over the page.

## Phases and Definition of Done

1. **T1 — Settings and cleanup.** *(done 2026-10-09)* Remove the Mushaf (and reader) top-bar button; the
   Settings section with the choices above for what exists today (EN/DE translations,
   Al-Muyassar); persisted. *Done when* the button is gone and every choice persists and is
   reflected in the sheets.
2. **T2 — The ayah sheet.** *(done 2026-10-09; until T5's defaults, nothing chosen shows where to choose it)* Translation and/or tafsir per the setting, tafsir opening with
   "Read more"; Arabic tafsir right-to-left in the Arabic UI font, translations in their own
   direction. *Done when* long-press shows exactly what Settings says, in both languages and
   themes.
3. **T3 — Word meanings.** *(deferred 2026-10-09 by the owner: no license-clean source; revisit later)* Once the source is decided: an import tool
   (`tool/quran_data/`) building a word-meaning pack aligned to canonical word ids, with the
   integrity checks above; bundled for the launch language(s); the word sheet shows it.
   *Done when* tapping any word shows its meaning offline and the checks pass for every word.
4. **T4 — The launch languages, bundled.** *(done 2026-10-09: Urdu (Junagarhi), Indonesian (Ministry of Religious Affairs), Turkish (Rowwad), French (Noor International) translations; Al-Mukhtasar tafsir in English, Indonesian, Turkish and French — none exists in Urdu; no word meanings, T3 being deferred)* Urdu, Indonesian, Turkish and French
   translations, and the short tafsir per language where license-clean, imported with
   checksums and integrity checks and bundled (word meanings for them too, if the source
   has them). *Done when* every launch language works in airplane mode on a fresh install.
5. **T5 — Defaults and attribution.** *(done 2026-10-09: until the user chooses, the translation and tafsir follow the app's language, else the phone's — Arabic: Al-Muyassar, no translation; English, Indonesian, Turkish, French: their translation + Al-Mukhtasar; Urdu, German: their translation, no tafsir; any other: English. Every source is credited on the About screen)* Sensible defaults by app language (Arabic: tafsir, no
   translation; English: Rowwad + Mukhtasar, etc.); every source credited on the About
   screen with its version; provenance rows complete. *Done when* a fresh install in each
   language shows useful meaning without any setup.

Each phase: `flutter analyze` clean, tests added and passing, English + Arabic strings, light
and dark themes, phone and tablet layouts, offline.

## Later (not in this milestone)

- Search inside translations and tafsir; word morphology (root, form), if a license-clean
  source exists; translation audio.
