# Google Play listing — Tahfeez AI

Everything to enter in Play Console for the first release (prepared 2026-10-24).
Text in `listings/<language>/` (title ≤ 30, short description ≤ 80, full
description ≤ 4,000 characters — all within). Graphics in `graphics/`, made
by `python3 tool/make_play_listing.py` from the landing page's media
(`site/images/screens`, `site/images/icon-512.png`).

## The build

| | |
|---|---|
| File | `build/app/outputs/bundle/release/app-release.aab` (`flutter build appbundle --release`, no `--dart-define`s — see `docs/PLAY_DATA_SAFETY.md`) |
| Package | `ai.tahfeez.tahfeez_ai` |
| Version | 1.0.0 (versionCode 1) — `version:` in `pubspec.yaml` |
| Signed with | the upload key (`android/key.properties`; CN=Omar Attia, OU=TahfeezAI); SHA-256 `D4:2A:7E:18:46:FC:47:4F:5F:2C:92:F3:C6:1F:6F:ED:66:0F:3D:82:0B:48:EF:DC:38:43:A2:83:6E:A8:A8:4C` |
| SDK | min 24 (Android 7.0), target 36 |
| Acoustic model | v3.7 (release `model-v3.7`, SHA-256 `7cbe486f…`), bundled |
| Download size (bundletool 1.18.3, `get-size total --dimensions=ABI`) | arm64-v8a 167.5 MB, armeabi-v7a 161.0 MB, x86_64 161.5 MB — under Play's 200 MB |

## Main store listing

| Field | Value |
|---|---|
| App name | `listings/en-US/title.txt` — Tahfeez AI: Quran Memorization |
| Short description | `listings/en-US/short_description.txt` |
| Full description | `listings/en-US/full_description.txt` |
| App icon (512 × 512, 32-bit PNG) | `graphics/icon.png` |
| Feature graphic (1,024 × 500) | `graphics/featureGraphic.png` |
| Phone screenshots (8, 1,242 × 2,208) | `graphics/phoneScreenshots/` in their numbered order |
| Arabic translation of the listing | `listings/ar/` (add language: Arabic – ar) |

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
