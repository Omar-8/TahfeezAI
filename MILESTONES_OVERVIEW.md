# Tahfeez AI — Milestones Overview

| Milestone | Name | Result |
|---:|---|---|
| 0 | Clean-room reference specification | Behavioral blueprint + visual reference notes |
| 1 | Flutter foundation | Android/iOS/Web architecture |
| 2 | Offline Quran data engine | Local Quran domain/repository |
| 3 | Tahfeez design system | Distinct light/dark visual identity |
| 4 | Home + navigation | Main shell |
| 5 | Quran index/navigation | Surah/Juz/Hizb/Page |
| 6 | Verse-by-verse reader | Semantic reader |
| 7 | Mushaf renderer | Accurate page/line rendering |
| 7B | Optional glyph atlas | Advanced rendering |
| 8 | Scripts + WBW | Multiple scripts / word details |
| 9 | Translations + tafsir | Offline study resources |
| 10 | Search | Advanced local search |
| 11 | Bookmarks/history/share | User Quran data |
| 12 | Audio | Recitation player |
| 13 | Resource manager | Unified offline downloads |
| 14 | Settings/localization | Themes + EN/AR/DE |
| 15 | Daily Ayah/collections | Exploration/reminders |
| 16 | Responsive/PWA | Tablet/desktop/web |
| 17 | Memorization | Offline Hifz engine |
| 18 | AI tracking | Live recitation following |
| 19 | AI mistakes/coach | Alignment + adaptive review |
| 20 | Hardening/release | Parity/offline/licensing/release |

## Design rule

Every milestone reads `CLEAN_ROOM_RULES.md`, `DESIGN_DIRECTION.md`, and `PROJECT_BRIEF.md`. UI milestones must treat `DESIGN_DIRECTION.md` as authoritative for appearance.

The target is functional breadth comparable to the reference app, but only about **50–60% visual familiarity**, with a distinctly Tahfeez identity.

## Recommended commit discipline

Use one branch/commit series per milestone. Do not mix future milestone work into the current milestone unless it is a required interface/foundation explicitly requested by the prompt.
