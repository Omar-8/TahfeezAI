# 08 — Audio / Recitation Specification (Reference Behavior)

> Source: `com.quranapp.android.utils.mediaplayer.*`, `com.quranapp.android.compose.components.player.*`,
> `com.quranapp.android.api.models.{mediaplayer,recitation,recitation2}.*`, `AndroidManifest.xml`
> service declaration.

## 1. Platform foundation

`RecitationService` is a foreground `Service` (`foregroundServiceType="mediaPlayback"`) exposing
`androidx.media3.session.MediaLibraryService` / `MediaSessionService` / the legacy
`android.media.browse.MediaBrowserService` actions — i.e., built on **AndroidX Media3**, giving it
lock-screen controls, Bluetooth/headset controls, Android Auto/media-browser exposure, and
survival across the launching Activity's lifecycle for free. `RecitationHeadsetReceiver` handles
headset-unplug-style hardware events. Tahfeez's Flutter equivalent should target an analogous
platform capability (e.g., `audio_service`/`just_audio` background session on mobile, Media
Session Web API on web) to preserve background playback and lock-screen controls — a capability
explicitly required by `docs/PROJECT_BRIEF.md`'s "Listen" product area.

## 2. Command surface (`PlayerCommand.kt`)

The service is driven by a fixed, serializable command vocabulary (`BasePlayerCommand` sealed
hierarchy, each with a string `ACTION` and a `Bundle` (de)serialization), decoupling
UI-thread/Activity code from the service's internal player state:

| Command | Effect |
|---|---|
| `StartCommand(verse?)` | Start playback, optionally at a specific chapter:verse |
| `SetAudioOptionCommand(option)` | Switch between Quran-only / translation-only / both audio |
| `SetVerseGroupSizeCommand(n)` | Set how many verses constitute one "repeat unit" |
| `SetPlaybackSpeedCommand(speed)` | Change playback rate |
| `SetRepeatCommand(count)` | Set how many times the current verse-group repeats before advancing |
| `SetReciterCommand(reciterId, kind)` | Change the active reciter for Quran or Translation audio independently (`kind: QURAN \| TRANSLATION`) |
| `SeekToPositionCommand(ms)` | Seek within the current track |
| `SetAudioEndBehaviourCommand(behaviour)` | What happens when playback reaches the end of the current scope |
| `StopCommand` / `PreviousVerseCommand` / `NextVerseCommand` | Transport controls |

This confirms `FEATURES.md`'s claims precisely: **"Play only Quran / Play only translation / Play
both Quran and translation"** = `AudioOption {ONLY_QURAN, ONLY_TRANSLATION, BOTH}` (default
`ONLY_QURAN`); **"Custom repeat"** = verse-group-size + repeat-count, i.e. repeat is defined over
an arbitrary verse range, not just a single verse; **"Playback speed control"** = a plain float
multiplier command.

## 3. Audio-end behavior

`AudioEndBehaviour { STOP_PLAYBACK, NEXT_CHAPTER, REPEAT_CHAPTER }` (default `STOP_PLAYBACK`) —
what the player does once it has finished the current playback scope (after any configured
repeats): stop, automatically continue into the next chapter, or repeat the whole current chapter
from the start. This is a distinct, independently-configurable setting from the per-verse-group
repeat count (§2), i.e. there are two nested loop concepts: repeat a small verse group N times,
then decide macro-behavior once past that.

## 4. Reciters and translation audio

- `RecitationModelManager` / `RecitationModelBase` / `RecitationQuranModel` /
  `RecitationTranslationModel` model two independent reciter rosters: Quran-recitation reciters
  and translation-audio reciters (`RecitationAudioKind.{QURAN, TRANSLATION}`), matching
  `FEATURES.md`'s "18+ recitations" and "10+ translation audios." The reference repository's local
  inventory manifest snapshot recorded **19 Quran reciters** and **11 translation-audio reciters**
  at time of inspection (`inventory/recitations/available_recitations_info_v2.json` /
  `available_recitation_translations_info_v2.json`) — treat exact live counts as
  `NEEDS_VERIFICATION` since these numbers grow over time via remote manifest updates.
- `ReciterSelectionSheet` — a bottom sheet for picking the active reciter per audio kind.
- Each reciter's manifest carries independently-versioned `audioVersion` and `timingVersion`
  fields (`ManifestVersionSnapshot`) — the audio files and the verse-timing metadata for a
  reciter can be updated independently of each other, and `RecitationVersionManager` reconciles
  locally-stored version numbers against the remote manifest to detect per-resource staleness
  (surfaced as the Home "resource update" banners, `docs/reference/11_HOME_SPEC.md` §2 and §"home
  resource updates").

## 5. Verse synchronization and timing

- `VerseClipPlan` — computes the exact playback clip/segment boundaries for a verse (or verse
  group) from a reciter's timing metadata, so a single continuous chapter audio file can be
  played "as if" scoped to just the selected verse range (seek-in, stop-at-boundary), rather than
  requiring per-verse audio files.
- `WbwAudioTimingEntity` (see `docs/reference/06_DATA_MODEL_SPEC.md` §4) provides word-level
  timing for WBW audio playback and Spotlight-mode word highlighting
  (`docs/reference/04_READER_SPEC.md` §12).
- "Automatic scroll to match current verse" (`FEATURES.md`) is implemented in the reader layer,
  not the player (`docs/reference/04_READER_SPEC.md` §11), driven by the player's currently-
  playing-verse state (`LocalRecitation.current.playingVerse`).

## 6. Mini player / expanded player / Spotlight

- `RecitationPlayerSheet` is a persistent, app-wide overlay (mounted once in `MainScreen`, above
  the bottom navigation bar) that manages the mini-player ↔ expanded-player transition, meaning
  playback state and its UI persist across navigating between Home, Search, and other top-level
  screens, not just within the reader.
- `MiniPlayer` — compact bar: play/pause, current verse/chapter label, presumably a progress
  indicator (`NEEDS_VERIFICATION` on exact mini-player content beyond play/pause + label).
- `ExpandedPlayer` — full player surface with reciter switch, audio-option switch, repeat/speed/
  audio-end-behavior configuration entry points (`AudioOptionsSheet`, `RepeatOptionsSheet`,
  `PlaybackSpeedSheet`, `AudioEndBehaviourSheet`), and (implied by `Thumbnail`/
  `RecitationChapterArtwork`) chapter artwork.
- `Spotlight` — a fullscreen, distraction-focused word/verse-following view during playback (see
  `docs/reference/04_READER_SPEC.md` §12); supports text selection.
- `PlayerConfigButton` / `PlayerMessages` — small supporting UI: a config-shortcut button and
  ephemeral player status/toast-style messages (e.g., "downloading audio…", errors).

## 7. Downloads vs. streaming cache

Two distinct storage tiers, matching Milestone-0's required "cache vs. explicitly downloaded
audio" distinction:
- **Explicit downloads**: `RecitationAudioDownloadWorker` / `RecitationBulkDownloadWorker`
  (WorkManager jobs) persist full reciter audio (per chapter or in bulk for a whole reciter) to
  app-private storage for guaranteed offline playback, tracked via
  `RecitationVersionStore`/`RecitationDownloadProgressBus` (a progress-event bus UI can subscribe
  to for live download-progress rendering, e.g. in Settings' "Download Recitations" and Storage
  Cleanup screens).
- **Streaming cache**: `RecitationStreamCache` caches recently-streamed (not explicitly
  downloaded) audio transparently, likely evicted by normal cache policy (size/age) rather than
  kept indefinitely, and explicitly cleared when a reciter's `timingVersion` changes (§4) since
  cached bytes could otherwise desync from updated timing metadata.
- `RecitationAudioFileDownloader` / `RecitationAudioRepository` provide the actual network-fetch
  + on-disk-file resolution logic used by both tiers.
- `WbwAudioDownloadWorker` / `WbwAudioBulkDownloadWorker` / `WbwAudioDownloadProgressBus` mirror
  the same explicit-download pattern for word-by-word audio specifically (a separate resource
  category from full verse/chapter recitation audio).

## 8. Offline behavior

Once a reciter's audio (and, for verse-accurate playback, its timing metadata) is downloaded,
playback, repeat, speed control, and verse synchronization all work with no network. Undownloaded
reciters can still stream (subject to `RecitationStreamCache`) when online, but are unavailable
when offline — Settings and the mini/expanded player should (and, per Milestone-0 verification
requirements, must be checked to) clearly distinguish "downloaded, always available offline" from
"stream only, requires network" reciters. Exact UI treatment of that distinction is
`NEEDS_VERIFICATION`.

## 9. Background playback and OS integration

Because the service is Media3-based and declared as a proper `mediaPlayback` foreground service,
background playback continues when the app is backgrounded, with system media-session controls
(notification, lock screen). A `RecitationPlayerWidgetReceiver` + associated home-screen widget
(`recitation_player_widget_info`) additionally exposes basic transport controls from the device
home screen, matching `FEATURES.md`'s "Background player."

## 10. NEEDS_VERIFICATION

- Exact mini-player visual content beyond play/pause and a label.
- Exact behavior when downloaded audio's `timingVersion` changes but `audioVersion` does not (is
  only the cached stream cleared, or is the downloaded file also considered stale?).
- Whether Spotlight mode is user-toggle-initiated or auto-entered on playback start.
- Exact bitrate/format choices and per-reciter file size, relevant to Tahfeez's own download-size
  UX (show estimated size before download).
