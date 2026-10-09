# Listening milestone (19) — plan

Status: planned 2026-10-09; L1–L3 done the same day. Decisions by the product owner are marked **(decided)**.

## Goal

Hear the Quran: an ayah, a whole surah from any ayah, or a single word — streamed, nothing
downloaded (**decided: online only**). Recitation tests keep the microphone to themselves:
starting one stops playback.

## Sources and licences (checked 2026-10-09)

| Audio | Source | Terms | Use |
|---|---|---|---|
| Ayahs (and so whole surahs, ayah by ayah) | Islamic Network CDN, `cdn.islamic.network/quran/audio/{kbps}/{edition}/{ayah 1–6236}.mp3` — ~190 editions | alquran.cloud terms: reciters license their recitations "for free, non-commercial redistribution"; streaming, embedding and downloading allowed; commercial bundling allowed, but "copyrights lie with the reciters and they may ask you to remove" a recitation; caching encouraged | **(decided)** Used, with credit to Islamic Network and each reciter; a reciter is removed on request |
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
   the menu at that ayah.

Each phase: `flutter analyze` clean, tests, English + Arabic strings, credits and
`docs/THIRD_PARTY_RESOURCES.md` rows.

## Later

Translation audio; downloading recitations for offline listening (not wanted for now).
