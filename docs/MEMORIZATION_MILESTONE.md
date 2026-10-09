# Memorization milestone (17) — plan

Status: planned 2026-10-09; M1 to M4 done the same day. Decisions by the product owner are marked **(decided)**.

## Goal

Turn recitation tests into memorization: what the user has memorized, how strong each part
is, and what to recite today. Everything stays on the device (no account, no backend);
`MemorizationRepository` (`lib/memorization/domain/`) gets its first implementation.

## Decisions

- **Scheduling (decided): the Hifz day, ordered by measured strength.** Each day has three
  parts, as in Hifz programmes:
  - **New lesson (sabaq):** the next portion of the active plan;
  - **Recent revision (sabqi):** what was learned in the last week (default 7 days), every day;
  - **Old revision (manzil):** a daily amount from everything memorized before that, by
    Mushaf page, **weakest first** by the strength model below (then least recently
    reviewed); unverified parts come first. A day holds about a two-week cycle of what is
    memorized (2–20 pages); pages reviewed today stay listed, marked done.
- **Unit (decided): chosen per plan** — ayahs, half-pages or pages. Strength is always tracked
  **per ayah**; pages and half-pages come from the Mushaf's page map.
- **Starting (decided): mark, then verify.** The user marks surahs / juz / pages they already
  know. They count as memorized but *unverified* (no strength yet) until first recited in the
  app, which scores them.

## Concepts and data

A new Drift database, `memorization.sqlite` — mutable user data, physically separate from the
Quran databases (as `docs/ARCHITECTURE.md` requires):

| Table | Holds |
|---|---|
| `memorized_ayahs` | per ayah: status (`learning` / `memorized`), `verified`, stability (days), last reviewed, learned on |
| `attempts` | per ayah per test: session id, time, grade, words, wrong, skipped, self-corrected, pronunciation mistakes, hidden (hide mode on), duration |
| `plans` | name, range (from / to ayah), unit, amount per day, days per week, direction (forward / backward, e.g. An-Nās → An-Nabaʾ), active |

**Recording results.** When a recitation test ends (completed, stopped or a loop pass done),
every ayah the reciter covered is graded from the test's own results (`HifzJudge` marks +
the acoustic verdicts):

| Grade | When |
|---|---|
| **fail** | a word wrong or skipped, or revealed by hand in hide mode |
| **hard** | correct words, but a self-correction or a pronunciation mistake |
| **good** | clean |

Pronunciation mistakes count as *hard*, not *fail*: memorization is about the words; tajweed
is shown but does not reset memorization strength. Ayahs only partly recited are not graded.

**Strength model (per ayah)** — `lib/memorization/domain/strength_model.dart`, in the spirit
of FSRS:
- *stability* S (days): how long after a review the ayah is still recalled with 90%
  likelihood. First test: good 1 day, hard 0.5, fail 0.25;
- *strength* after t days: R = (1 + t / 9S)⁻¹ — 100% right after a review, 90% when due
  (t = S), shown as 0–100%; a part is *weak* below 70%;
- a review grows S by how much it had faded: when due, good × 2.5, hard × 1.3; a repeat the
  same day (e.g. loop recitation) barely changes it, so repetition in one sitting is not
  mistaken for long-term memory; a fail cuts S to 0.3 × (at least 0.25 days);
- an ayah becomes *memorized* once recited from memory (hide mode) without a mistake in the
  words.

The constants are a starting point, to be tuned on real use (see "Later").

## The user's surfaces

- **Memorize tab** (the fourth primary navigation item, per `docs/DESIGN_DIRECTION.md`):
  - **Today:** three cards — New lesson, Recent revision, Old revision — each with its range,
    amount and a Start button. Start opens the Mushaf at the range with hide mode on and the
    Hifz test set to that range (loop recitation optional for the new lesson);
  - **Plans:** create / edit (range, unit, amount, days per week, direction);
  - **Progress:** a map of the Quran (by juz → surah → page) coloured by strength, with the
    weak parts listed and "mark as memorized" for the start.
- **Session summary** after each test: per-ayah grades, strength before → after, and "repeat
  the weak ayahs" (opens a loop over them).
- **Home:** "Today's Memorization" and "Today's Revision" replace the current teaser.
- Memorization states on the page reuse the existing overlay (hidden, revealed, current word,
  correct / skipped / wrong, self-correction); "weak range" and "scheduled revision" are new
  overlay marks. The Quran text itself is never changed.

## Phases and Definition of Done

1. **M1 — Data and recording.** *(done 2026-10-09)* Drift database + `MemorizationRepository` implementation;
   grading at the end of each test; the strength model; unit tests for grading, the model and
   the repository; the existing Hifz tests still pass. *Done when* a test's results are stored
   per ayah and strengths update, verified by tests (no UI yet).
2. **M2 — Today.** *(done 2026-10-09)* The scheduler (sabaq / sabqi / manzil from plans and strengths), the
   Memorize tab's Today screen, starting a session at a range, the session summary. *Done
   when* a user with memorized parts sees today's three tasks, recites one, and sees its
   summary and updated strength.
3. **M3 — Plans.** *(done 2026-10-09; one active plan, its new lesson on the Memorize tab; chosen study days; more can be learned once the lesson is; a plan is stopped rather than paused)* Create / edit / pause plans in ayahs, half-pages or pages; the new lesson
   advances when its test passes (no fail); missed days roll forward. *Done when* a plan
   produces the right new lesson day by day (tests over simulated days).
4. **M4 — Progress and starting point.** *(done 2026-10-09; a Progress screen from the Memorize tab: the share memorized, a page-by-page strength map by juz, the weakest pages with Start; "Mark what I know" by surah or juz, unmarking only what was never recited)* The strength map, the weak-parts list, marking
   already-memorized surahs / juz / pages (unverified until recited). *Done when* marking
   works and the map reflects tests.
5. **M5 — Home and reminders.** Home cards; an optional daily reminder (local notification,
   opt-in, Android first). *Done when* Home shows today's tasks and the reminder fires.

Each phase: `flutter analyze` clean, tests added and passing, English + Arabic strings, light
and dark themes, phone and tablet layouts, offline.

## Later (not in this milestone)

- **Adaptive review coach:** recurring confusions (e.g. a word said as another ayah's —
  mutashābihāt — from the verifier's word swaps), hesitation patterns, suggested drills.
- Tuning the strength constants on real use; export / import of memorization data (with the
  User Data milestone); iOS recitation.
- Listen-and-repeat drilling, once reciter audio exists (Listen milestone).
