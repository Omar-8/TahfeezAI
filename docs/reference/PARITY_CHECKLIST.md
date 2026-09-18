# Parity Checklist

> Master checkbox matrix derived from `01_FEATURE_MATRIX.md` through `18_VISUAL_REFERENCE_NOTES.md`.
> This checklist tracks **functional/behavioral parity capability**, not visual copying — checking
> a box means "Tahfeez supports an equivalent capability, independently implemented and
> independently designed," per `docs/CLEAN_ROOM_RULES.md` and `docs/DESIGN_DIRECTION.md`. Update
> this file as later milestones ship; do not check a box before its milestone's Definition of Done
> is satisfied.

## Read
- [ ] Verse-by-verse reading mode
- [ ] Mushaf mode with variable line count
- [ ] Translation-first reading mode
- [ ] Chapter reading
- [ ] Juz reading
- [ ] Hizb reading
- [ ] Page-based navigation
- [ ] Jump to verse / chapter / juz / hizb / page
- [ ] At least one independently-licensed Quran script/font installed
- [ ] Multiple Quran scripts selectable
- [ ] Arabic text size control
- [ ] Translation text size control
- [ ] Arabic text on/off toggle
- [ ] At least one independently-licensed translation installed
- [ ] Multiple translations selectable and installable
- [ ] Read multiple translations simultaneously
- [ ] Footnote preview
- [ ] Verse-reference quick preview
- [ ] At least one independently-licensed tafsir installed
- [ ] Dedicated tafsir reading screen
- [ ] Word-by-word translation + transliteration
- [ ] Word-by-word audio
- [ ] Chapter info screen
- [ ] Similar-verses cross-reference (or explicitly deferred)
- [ ] Sajdah verse marking

## Listen
- [ ] At least one Quran reciter with downloadable audio
- [ ] Multiple reciters selectable
- [ ] Translation audio (at least one reciter)
- [ ] Play Quran-only / translation-only / both
- [ ] Custom repeat (verse-group + count)
- [ ] Playback speed control
- [ ] Audio-end behavior options
- [ ] Verse synchronization / auto-scroll to playing verse
- [ ] Spotlight / distraction-minimal playback view
- [ ] Background playback (lock screen / notification controls)
- [ ] Explicit per-chapter and bulk audio downloads
- [ ] Streaming without explicit download
- [ ] Download vs. cached-stream distinction visible to user
- [ ] Home-screen player widget (platform-permitting)
- [ ] Android Auto / media-browse integration (optional, later)

## Organize
- [ ] Single-verse bookmark
- [ ] Range bookmark
- [ ] Bookmark notes
- [ ] Bookmark bulk delete / selection mode
- [ ] Reading history auto-tracked
- [ ] Resume exact reading position (including Mushaf page)
- [ ] Export (settings)
- [ ] Export (bookmarks)
- [ ] Import (settings)
- [ ] Import (bookmarks)
- [ ] Explicit, documented decision on whether read history is exportable
- [ ] Verse sharing

## Explore
- [ ] Verse of the Day (in-app)
- [ ] Verse of the Day widget (platform-permitting)
- [ ] Daily reminder notification
- [ ] Recommended/curated content surface
- [ ] Featured reading shortcuts
- [ ] At least one reference-content collection with verified provenance (duas, solutions,
      etiquette, major sins, prophets, science, topics — Tahfeez decides its own roster)
- [ ] Arabic Quran text search
- [ ] Translation text search
- [ ] Chapter name/alias search
- [ ] Quick-link pattern recognition (verse/chapter/juz jump from search box)
- [ ] Voice search (platform-permitting)
- [ ] Search history
- [ ] Search filtering by translation

## Settings / Platform / Product
- [ ] No ads, no purchases
- [ ] No mandatory account
- [ ] No mandatory backend for core reading
- [ ] No third-party analytics/tracking
- [ ] Minimal runtime permissions
- [ ] Light theme (Tahfeez-original palette)
- [ ] Dark theme (independently designed, not inverted light)
- [ ] Multiple accent theme presets (optional)
- [ ] Dynamic/system color support (platform-permitting)
- [ ] Multi-language UI (roster and count are Tahfeez's own decision)
- [ ] RTL layout support
- [ ] Arabic numeral-system choice (Western vs. Arabic-Indic digits)
- [ ] Resource download-source preference (if multiple sources are ever offered)
- [ ] Storage cleanup per resource category
- [ ] Self-hosted diagnostics/crash log viewer (or equivalent privacy-respecting approach)
- [ ] Deep links for chapter / verse / verse-range / juz
- [ ] Brief, account-free onboarding
- [ ] Offline-first: reading, navigation, Mushaf, verse-by-verse, search, bookmarks, history,
      settings, and all installed resources work with no network

## Data & Quran-correctness gates (non-negotiable)
- [ ] Canonical Quran text stored separately from mutable user data
- [ ] Canonical Quran text never AI-generated
- [ ] Canonical Quran text never silently edited
- [ ] Search-index text kept separate from and derived from canonical text
- [ ] Integrity check (checksum/hash) on the canonical Quran dataset
- [ ] Every shipped external resource recorded in `docs/THIRD_PARTY_RESOURCES.md` with verified
      license and redistribution rights, before shipping

## Memorize (Tahfeez-original — no reference equivalent)
- [ ] Memorization plans
- [ ] Listen/repeat drilling
- [ ] Hide/reveal text
- [ ] Review scheduling
- [ ] Memorization strength tracking
- [ ] Testing/quizzing

## AI (Tahfeez-original — no reference equivalent, future milestones)
- [ ] Live Quran location detection during recitation
- [ ] Live word-following
- [ ] Constrained sequence alignment
- [ ] Skipped/incorrect/added word detection
- [ ] Hesitation/self-correction event detection
- [ ] Adaptive review coach
- [ ] On-device recognition (stretch goal)

---

**Note on scope**: this checklist intentionally does not require Tahfeez to ship every box before
any release — `docs/DESIGN_DIRECTION.md` and the milestone kit sequence features across many
milestones. Its purpose is to make omissions visible and deliberate rather than accidental, and to
give every later milestone a single place to mark what it actually completed.
