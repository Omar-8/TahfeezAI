# Listening milestone (19) — plan

Status: planned 2026-10-09; L1–L3 done the same day. Decisions by the product owner are marked **(decided)**.

## Goal

Hear the Quran: an ayah, a whole surah from any ayah, or a single word — streamed, or
for ayahs from a reciter downloaded for offline use (**decided 2026-10-10**; online only
before). Recitation tests keep the microphone to themselves:
starting one stops playback.

## Sources and licences (checked 2026-10-09)

| Audio | Source | Terms | Use |
|---|---|---|---|
| Ayahs (and so whole surahs, ayah by ayah) | Islamic Network CDN, `cdn.islamic.network/quran/audio/{kbps}/{edition}/{ayah 1–6236}.mp3` — ~190 editions | alquran.cloud terms: reciters license their recitations "for free, non-commercial redistribution"; streaming, embedding and downloading allowed; commercial bundling allowed, but "copyrights lie with the reciters and they may ask you to remove" a recitation; caching encouraged | **(decided)** Used, with credit to Islamic Network and each reciter; a reciter is removed on request. Users may download a reciter for offline listening (2026-10-10): the terms allow downloading for personal use and encourage caching; a reciter removed on request also has existing downloads deleted |
| Words | Quran.com CDN, `audio.qurancdn.com/wbw/{sss}_{aaa}_{www}.mp3` | Quran Foundation Developer Terms (2026-10-04): showing QF content allowed (free or paid); no keeping it beyond a week outside Content Sync; no scraping; redistribution needs a commercial licence. Direct use of the public CDN by an app isn't addressed | **(decided)** Streamed only (nothing kept), credited to Quran Foundation; no email needed |
| EveryAyah, mp3quran.net | — | No licence published | Not used |

## Phases

1. **L1 — Ayah and surah listening.** *(done 2026-10-09)* Reciter choice in Settings (a curated list of
   Ḥafṣ murattal/mujawwad reciters); the ayah sheet's *Play ayah* and *Play from here* (to
   the surah's end); the mini player with the current ayah, play/pause and stop; the playing
   ayah highlighted on the Mushaf page; a clear message offline; recitation tests stop it.
2. **L2 — Word audio.** *(done 2026-10-09)* The word sheet's speaker plays the word (Quran.com word positions
   mapped from the canonical words — they differ only where Quran.com joins two words).

3. **L3 — Listening from the Mushaf bar.** *(done 2026-10-09, replacing L1's mini player at
   the owner's request)* A Listen button beside the mic opens a menu: the reciter, a range
   (from / to ayah), repeat each ayah and the range (1–10), turn the pages with the
   recitation, highlight the ayah being recited. While it plays the same bar holds stop,
   pause / resume and the speed (0.75–1.5×), the hide buttons in place; in hide mode each ayah
   is revealed as it is recited; the page's progress line follows the recited ayah. Leaving the
   Mushaf, or a recitation test starting, stops it. The ayah sheet's *Play from here* opens
   the menu at that ayah. Speeds run 0.5–2×; *Continue to the next surahs* plays on, surah
   by surah, once a range ends at a surah's end. While reciting or listening the bar shows only
   the eye (revealing follows the recitation); turning hide mode on mid-playback keeps the
   playing ayah and those before it on its page shown.

4. **L4 — Follow along.** *(done 2026-10-10)* A third bar button beside the mic and Listen
   opens a menu laid out like Listen's: the reciter, a range, each ayah or the whole range,
   how many times the reciter recites it and then how many times the user does (1–10), and
   the reciter's speed. The reciter plays the part; then a banner above the bar says it is
   the user's turn (with a vibration on Android) and the microphone tests the same part as a
   loop (`HifzController.setLoop`, whole-range mode); once every repetition is recited, on
   to the next part. Stopping either turn from the bar, leaving the Mushaf, the audio
   failing (offline) or the microphone being refused ends the run; the results sheet is
   not shown between turns. (`FollowAlongController`; needs live recognition.)
   The user's turn ends only once the pronunciation check of its last words is done
   (it follows the voice by about a second and the pause after it; at most 5 s) —
   stopping sooner missed those mistakes. *Strict*: a turn with a mistake (a word
   wrong or skipped, or a pronunciation mistake) is recited once more, until without.

Each phase: `flutter analyze` clean, tests, English + Arabic strings, credits and
`docs/THIRD_PARTY_RESOURCES.md` rows.

5. **L5 — Offline reciters.** *(done 2026-10-10; reverses the "online only" decision
   for ayah recitations)* In the reciter list (Settings, Listen and Follow along menus),
   each reciter shows its recitation's size and a download button: a ring with the
   progress while it downloads (tap to stop), then delete. All 6,236 ayah files come from
   the same Islamic Network CDN, 6 at a time, into the app's own storage (removed with
   the app); an interrupted or stopped download goes on from where it was. The player
   plays a downloaded ayah from the phone (offline too), else streams it. Not on the web.
   Word audio stays streamed only (Quran Foundation terms: nothing kept beyond a week).
   (`ReciterDownloads`.)

## Later

Translation audio.
