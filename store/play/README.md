# Google Play listing — Tahfeez AI

Everything to enter in Play Console for the first release (prepared 2026-10-24, features updated 2026-10-25).
Text in `listings/<language>/` (title ≤ 30, short description ≤ 80, full
description ≤ 4,000 characters — all within). Graphics in `graphics/`, made
by `python3 tool/make_play_listing.py` from the landing page's media
(`site/images/screens`, `site/images/icon-512.png`).

## The build

| | |
|---|---|
| File | `build/app/outputs/bundle/release/app-release.aab` (`flutter build appbundle --release`, no `--dart-define`s — see `docs/PLAY_DATA_SAFETY.md`) |
| Package | `ai.tahfeez.tahfeez_ai` |
| Version | 1.0.5 (versionCode 7 — code 6 was taken by an earlier upload to the Play Console) — `version:` in `pubspec.yaml`; 1.0.5: Mohamed Al-Tablawi as a reciter (everyayah.com), back twice to leave again on Android 16 (predictive back off), bigger reveal buttons in hide mode in the same order in right-to-left languages, the daily ayah's number kept on its last line, sheets' Cancel narrower than their main button. 1.0.4 (5): no black screen between the splash and Home (Android 11, checked on emulators), Ayah mode no longer stalls as a recitation starts or ends. 1.0.3 (4): smoother recitation animations (the old ones could crash a phone's graphics driver on a long recitation), an Animations switch, no end-of-page glow. 1.0.0 (1) and 1.0.1 (2) on internal testing: their release builds crash on the first recitation check (R8 renamed ONNX Runtime's classes; fixed in 1.0.2 — checked on the owner's POCO, release build, a real recitation, 2026-10-29) |
| Signed with | the upload key (`android/key.properties`; CN=Omar Attia, OU=TahfeezAI); SHA-256 `D4:2A:7E:18:46:FC:47:4F:5F:2C:92:F3:C6:1F:6F:ED:66:0F:3D:82:0B:48:EF:DC:38:43:A2:83:6E:A8:A8:4C` |
| SDK | min 24 (Android 7.0), target 36 |
| Acoustic model | v3.7 (release `model-v3.7`, SHA-256 `7cbe486f…`), bundled |
| Download size (bundletool, `get-size total --dimensions=ABI`) | arm64-v8a 169.5 MB, armeabi-v7a 174.2 MB, x86_64 177.9 MB — under Play's 200 MB (measured 2026-10-29: the Quran as ready-made xz databases and per-language packs instead of JSON; ONNX Runtime reduced on arm64, Microsoft's build for 32-bit ARM and x86_64 too; the model stored uncompressed, read in place) |

## Main store listing

| Field | Value |
|---|---|
| App name | `listings/en-US/title.txt` — Tahfeez AI: Quran Memorization |
| Short description | `listings/en-US/short_description.txt` |
| Full description | `listings/en-US/full_description.txt` |
| App icon (512 × 512, 32-bit PNG) | `graphics/icon.png` |
| Feature graphic (1,024 × 500) | `graphics/featureGraphic.png` |
| Phone screenshots (8, 1,242 × 2,208) | `graphics/phoneScreenshots/` in their numbered order |
| Translated screenshots (same 8, captions in the language) | `graphics/<Play language code>/phoneScreenshots/` — made by `python3 tool/make_play_localized.py`; Arabic's Home and Ayah mode show the app in Arabic |
| Translations of the listing | `listings/<Play language code>/` — ar, de-DE, fr-FR, es-ES, ru-RU, tr-TR, id, ms, ur, fa, bn-BD, sw, kk; all in one file: `listings/all_languages.csv` (for Play's "Import translations"). Hausa, Kurdish, Pashto, Somali and Uzbek: no Play store-listing language — their users see English |

## Store settings

| Field | Value |
|---|---|
| App or game | App |
| Category | Education (alternative: Books & Reference) |
| Tags | Quran, Education, Religion — whichever Play offers |
| Contact email | tahfeez.ai.app@gmail.com |
| Website | https://github.com/Omar-8/TahfeezAI (or the landing page's URL once it has one) |
| Free or paid | Free (cannot be changed to paid later) |

## App content

| Declaration | Answer |
|---|---|
| Privacy policy | https://github.com/Omar-8/TahfeezAI/blob/main/docs/PRIVACY_POLICY.md |
| Ads | No ads |
| App access | All functionality available without special access (no login) |
| Content rating | IARC questionnaire: reference / education; no violence, sexual content, gambling, drugs, user-generated content or user interaction; no location sharing — expected rating Everyone / PEGI 3 |
| Target audience | All ages (13+ is the simpler choice: under-13 groups bring the Families policy — see `docs/PLAY_DATA_SAFETY.md`) |
| Data safety | `docs/PLAY_DATA_SAFETY.md` — no data collected or shared |
| Foreground service | Media playback: Quran recitation keeps playing with the screen off; the notification shows what plays, with controls |
| Government app / financial features / health | No |
| News app | No |

## Before pressing release

- Your noisy-room test on the phone (the microphone has been raw since 2026-10-20).
- First release on a closed or internal testing track: a new personal developer account must run a closed test (12 testers for 14 days) before production.
