# Google Play — Data safety answers for TahfeezAI

Prepared 2026-10-10 from the code (see "Basis" below). Re-check before every release that adds a network call, an SDK or a permission.

## Data collection and security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not applicable (no data collected). All network requests use HTTPS. |
| Do you provide a way for users to request that their data is deleted? | Not applicable (nothing leaves the device). In the app: Settings → Your data → Reset all data; uninstalling removes everything. |

Play counts data as **collected** only when it is transmitted off the device. TahfeezAI transmits none of the user data types:

| Data type | Why it is not collected |
|---|---|
| Audio (voice or sound recordings) | Recitation audio is processed on the device by the bundled model and discarded; nothing is uploaded. Release builds store no recordings (`TAHFEEZ_KEEP_RECORDINGS` is off). |
| App activity, app info and performance | Memorization progress, bookmarks and settings stay in local storage; no analytics or crash-reporting SDK. |
| Personal info, contacts, identifiers | Not accessed. No accounts, no advertising ID. |
| Location (approximate) | **Accessed, not collected** (since 2026-11-20, the Qibla finder; prayer times since 2026-11-21): a city-level position in automatic mode, used on the phone to compute the qibla direction and prayer times; kept on the phone only rounded to about a kilometre (two decimals, named after the nearest built-in city) so Home shows today's prayer times; never transmitted — Play's "processed only on the device" exception, so the form's answer stays "no data collected". A city chosen by hand is stored on the phone only. Permission: `ACCESS_COARSE_LOCATION` (no fine, no background; geolocator's location service removed from the manifest). Prayer reminders are local notifications. |
| Files and docs | The export file is written only where the user picks; it is never uploaded by the app. |

Audio requests to `cdn.islamic.network` and `audio.qurancdn.com` contain only the name of a public audio file. The IP address these services see is inherent to the internet request; no user data is attached.

## App content declarations (related)

- **Ads:** No ads.
- **Target audience:** All ages. (If the Families programme is chosen, re-check the third-party audio services' terms.)
- **Privacy policy URL:** host `docs/PRIVACY_POLICY.md` publicly (fill in the contact email first) and enter its URL.
- **Permissions:** `RECORD_AUDIO` (on-device recitation checking), `INTERNET` (recitation audio), `POST_NOTIFICATIONS` (daily reminder), `VIBRATE` (mistake alert), `RECEIVE_BOOT_COMPLETED` (reschedules the reminder), `WAKE_LOCK` / `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (recitation audio playing in the background).
- **Foreground service declaration (Play Console → App content):** type *media playback* — the user plays Quran recitation and it continues with the screen off; the notification shows what plays, with controls.

## Basis (checked in the code, 2026-10-10)

- Network: `lib/features/listen/domain/quran_audio_sources.dart` (audio URLs only). The web build also fetches Mushaf pages from its own site. The remote acoustic server and the speech recognizer run only with developer `--dart-define`s (`lib/features/recitation/application/recitation_ai_config.dart`); on Android the default is the on-device model.
- Recordings: `recitationKeepRecordingsProvider` (`lib/features/recitation/application/recitation_providers.dart`) is false unless the build passes `--dart-define=TAHFEEZ_KEEP_RECORDINGS=true`. **Never pass it to a release build.**
- No analytics, crash-reporting, advertising or account SDK in `pubspec.yaml`.
- Google Play's in-app update and in-app review (`in_app_update`, `in_app_review`) run through the Play Store app on the device; TahfeezAI passes them no user data. `share_plus` and `url_launcher` hand text/links to apps the user picks.

## Release build command

```
flutter build appbundle --release
```

No `--dart-define`s: in particular not `TAHFEEZ_KEEP_RECORDINGS`, `TAHFEEZ_ACOUSTIC_BACKEND=remote` or `TAHFEEZ_SPEECH_COMPARATOR`.
