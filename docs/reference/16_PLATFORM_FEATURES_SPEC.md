# 16 — Platform Features Specification (Reference Behavior)

> Source: `app/src/main/AndroidManifest.xml`, `com.quranapp.android.views.{reader,player}.*`,
> `com.quranapp.android.utils.receivers.CrashReceiver`, `com.quranapp.android.utils.workers.*`.
> This document is Android-specific by nature (the reference app is Android-only); Tahfeez must
> translate each capability to its own per-platform adapter rather than treat this as Flutter
> guidance directly, per `docs/PROJECT_BRIEF.md`'s "platform adapters" principle.

## 1. Deep links / App Links

Two `https://quran.com/...` HTTPS App Link families are registered with `autoVerify="true"`
(Android App Links, meaning Android will attempt to verify domain ownership and open the app
directly rather than a disambiguation chooser, when possible):

| URL pattern | Opens |
|---|---|
| `/chapter_info/*` | `ActivityChapInfo` (chapter-info screen) |
| `/juz/*` | `ActivityReader` (Juz reading) |
| `/{n}` | `ActivityReader` (chapter `n`) |
| `/{n}/{m}` | `ActivityReader` (chapter `n`, page or verse `m` — exact semantics `NEEDS_VERIFICATION`) |
| `/{n}/{m}-{k}` | `ActivityReader` (range variant) |
| `/{n}:{m}` | `ActivityReader` (chapter `n`, verse `m`) |
| `/{n}:{m}-{k}` | `ActivityReader` (chapter `n`, verse range `m`-`k`) |

Additionally, custom (non-browsable) intent actions provide in-app-only deep links used by
notifications, widgets, and internal navigation without needing a real URL: `com.quranapp.
android.action.{OPEN_READER, OPEN_TAFSIR, OPEN_CHAPTER_INFO, OPEN_REFERENCE, SHOW_POPUP}`.

Tahfeez, as a cross-platform Flutter app, should design an equivalent `go_router`-based deep-link
scheme (both a custom scheme/universal link and internal named routes) covering at minimum:
chapter, chapter+verse, chapter+verse-range, and Juz, since these are exactly the granularities
external links (sharing, notifications, widgets) need to address.

## 2. Home-screen widgets

Two Android App Widgets, each with its own `BroadcastReceiver` implementing
`APPWIDGET_UPDATE`:
- **Verse of the Day widget** (`VotdWidgetReceiver`) — refreshed proactively on every
  `MainActivity.onResume` (`updateAllVotdWidgets`), reusing the same VOTD content source as the
  in-app Home tab (`docs/reference/11_HOME_SPEC.md` §3).
- **Recitation player widget** (`RecitationPlayerWidgetReceiver`) — basic transport controls
  (play/pause, and presumably next/previous) from the home screen, mirroring the in-app mini
  player's control surface (`docs/reference/08_AUDIO_SPEC.md` §9).

Widgets are an Android-specific platform capability with no direct Flutter equivalent; on Android,
Flutter apps commonly implement home-screen widgets via a native platform channel/plugin (e.g.,
`home_widget`), which Tahfeez should treat as a platform-adapter concern for a later milestone
rather than core cross-platform code, consistent with `docs/PROJECT_BRIEF.md`'s "platform
adapters ... for widgets."

## 3. Android Auto / Automotive

`automotive_app_desc.xml` declares `<uses name="media"/>`, and `RecitationService` exposes the
`android.media.browse.MediaBrowserService` action alongside the Media3 session actions — together
these expose the app's recitation playback (browsable by reciter/chapter, presumably) to Android
Auto head units. This is a "nice to have" platform integration; Tahfeez's audio milestone should
note it as a possible future Android-specific enhancement once background audio playback itself
is solid, not a near-term requirement.

## 4. Sharing

Verse sharing (`docs/reference/04_READER_SPEC.md` §9) uses Android's standard share-sheet
mechanism via a `FileProvider` (`androidx.core.content.FileProvider`, declared with
`android:exported="false"` and `grantUriPermissions="true"`), meaning shared content that includes
a generated file (e.g., a rendered verse image) is exposed to the receiving app via a
content-provider URI rather than a raw file path — the standard, required modern-Android pattern
for sharing files outside the app's own storage sandbox. Tahfeez's Flutter equivalent (e.g.,
`share_plus`) handles this transparently per-platform.

## 5. Notifications and scheduling

- Permissions: `POST_NOTIFICATIONS` (Android 13+ runtime notification permission),
  `SCHEDULE_EXACT_ALARM`, `WAKE_LOCK`, `VIBRATE` — together these support the Daily
  Reminder/Verse-of-the-Day notification (`docs/reference/10_SETTINGS_SPEC.md` §4) firing at an
  exact scheduled time even under Doze/battery-optimization restrictions.
- `RecommendedReminderWorker` and `VerseOfTheDayWorker` (WorkManager) are the periodic/scheduled
  jobs behind this notification and behind refreshing the Home "Recommended" content
  (`docs/reference/11_HOME_SPEC.md` §3).
- `CrashReceiver` + `checkForCrashLogs`/`AppLogsScreen` implement in-app crash-log capture and
  review (`docs/reference/10_SETTINGS_SPEC.md` §3's "App Logs" item) — a self-hosted diagnostics
  feature rather than a third-party crash-reporting SDK, consistent with `FEATURES.md`'s "No
  analytics or tracking / No data collection or sharing" privacy claim.

## 6. Foreground services

Two foreground-service-related manifest entries: the WorkManager system foreground service
(`SystemForegroundService`, `dataSync` type, used to keep long-running download workers alive)
and `RecitationService` itself (`mediaPlayback` type, for background audio — see
`docs/reference/08_AUDIO_SPEC.md` §1). `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
and `FOREGROUND_SERVICE_DATA_SYNC` permissions back these.

## 7. Network security

`android:usesCleartextTraffic="@string/cleartextTrafficPermitted"` (a resource-driven boolean,
allowing cleartext HTTP to be conditionally permitted — likely disabled in release builds and
possibly enabled for local/dev/testing builds) plus a `network_security_config.xml` resource.
Tahfeez should default to HTTPS-only for any of its own network calls (resource manifests,
optional AI services) and avoid needing a cleartext exception at all.

## 8. Privacy / permissions posture

Per `FEATURES.md`'s "No phone permission is required" and `README.md`'s "Permissions that affect
your privacy such as storage, gps, camera etc. are not required" — the manifest confirms this:
no storage, location, camera, microphone (voice search uses a `<queries>` package-visibility
declaration + a system speech-recognition intent, not a raw `RECORD_AUDIO` permission held by the
app itself), or contacts permissions are requested. Only network, notification, exact-alarm,
wake-lock, vibrate, and foreground-service permissions appear — all either invisible to the user
or Android-13+-runtime-gated notification permission. This directly aligns with
`docs/PROJECT_BRIEF.md`'s "no mandatory account; no mandatory backend; privacy-oriented" goals,
and Tahfeez should hold itself to the same minimal-permissions bar.

## 9. File provider paths and export/import

The `FileProvider`'s `provider_paths.xml` (not itself inspected in detail) governs which app-
private directories can be exposed via content URIs — used by both verse sharing (§4) and the
Export/Import feature's file-save/file-open flow (`docs/reference/12_BOOKMARK_HISTORY_SPEC.md`
§4). Tahfeez's Flutter equivalent is typically a file-picker/share plugin per platform rather than
a manifest-declared provider.

## 10. NEEDS_VERIFICATION

- Exact semantics of the ambiguous `/{n}/{m}` and `/{n}/{m}-{k}` deep-link patterns (page number
  vs. verse number disambiguation).
- Whether the Android Auto media-browse tree exposes full chapter/reciter browsing or only "resume
  last playback."
- Exact contents of `provider_paths.xml` and `network_security_config.xml`.
