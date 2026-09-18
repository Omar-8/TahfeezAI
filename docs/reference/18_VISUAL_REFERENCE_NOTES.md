# 18 — Visual Reference Notes

> Broad design observations only, per Milestone 0's instruction not to produce a pixel-spec
> clone. No color hex values, exact typography scales, spacing constants, or artwork from the
> reference app are recorded here — per `docs/CLEAN_ROOM_RULES.md`, these must not be copied.
> Every observation is classified **KEEP AS UX PRINCIPLE**, **TAHFEEZ SHOULD EVOLVE**, or
> **DO NOT COPY EXACTLY**, supporting the 50–60% familiarity target in
> `docs/DESIGN_DIRECTION.md`.

## 1. Overall density

The reference app is a fairly dense, information-forward Material 3 app: Home stacks six-plus
sections with modest vertical rhythm, settings screens are long single-scroll lists, and card
padding throughout is tight-to-moderate (roughly 12–16dp) rather than generous.
- **TAHFEEZ SHOULD EVOLVE**: `docs/DESIGN_DIRECTION.md` explicitly calls for "slightly more
  spacious," "less visually dense" than this baseline — Tahfeez should widen padding, increase
  section spacing, and consider trimming simultaneous Home sections rather than matching this
  density 1:1.

## 2. Navigation prominence

The bottom bar gives its center item (Quran access) a visually distinct, larger, filled-pill
treatment versus the other two items' plain icon+label style — a clear "this is the primary
action" signal.
- **KEEP AS UX PRINCIPLE**: elevating the single most important action in a bottom nav is a
  sound, brand-neutral pattern.
- **DO NOT COPY EXACTLY**: the specific pill shape/size/color and icon glyph are reference
  artwork; Tahfeez should express "Quran access is primary" (and, per `docs/DESIGN_DIRECTION.md`,
  eventually "Memorize is co-primary") with its own shape language.

## 3. Card and list usage

Nearly every content grouping (home sections, settings items, bookmarks, search results,
navigator lists) is expressed as a card or list-row inside a `LazyColumn`/`LazyRow`, generally
with light borders/tonal surfaces rather than heavy elevation/shadow.
- **KEEP AS UX PRINCIPLE**: card/list-based organization with restrained elevation is exactly the
  "low-contrast boundaries, restrained elevation" character `docs/DESIGN_DIRECTION.md` already
  wants.
- **TAHFEEZ SHOULD EVOLVE**: corner radii observed skew moderate (~12–18dp); Tahfeez's target
  range (16–20dp, per `docs/DESIGN_DIRECTION.md`) is a deliberate, slightly softer evolution, not
  a copy of the reference's exact radius choice.

## 4. Bottom sheets for secondary actions

Verse options, share, similar verses, WBW word detail, filters, text-size adjustment, daily-
reminder configuration, download-source choice, and the reader navigator are all `ModalBottomSheet`s
rather than full-screen navigations or dialogs.
- **KEEP AS UX PRINCIPLE**: this is a strong, broadly-adopted Material pattern for secondary/
  contextual actions and is already named as a KEEP item in `docs/DESIGN_DIRECTION.md`.

## 5. Reader minimalism and chrome-recede behavior

The reader's app bar collapses on scroll, verse action rows are compact icon rows rather than a
persistent labeled toolbar, and a dedicated Spotlight mode strips chrome to near-zero during
playback.
- **KEEP AS UX PRINCIPLE**: directly matches `docs/DESIGN_DIRECTION.md`'s "Quran content is the
  visual focus; controls appear when needed; top/bottom chrome can collapse."
- **TAHFEEZ SHOULD EVOLVE**: the reference's specific two-row sticky-header chrome (mode tabs +
  a second contextual row) can be simplified or restyled by Tahfeez if a single-row equivalent
  achieves the same information without the extra row, consistent with "more spacious/less
  dense."

## 6. Audio integration

A persistent, app-wide mini player overlay with an expand-to-full-player gesture, plus a
distraction-minimal Spotlight mode for active listening.
- **KEEP AS UX PRINCIPLE**: compact, always-reachable audio control without leaving the current
  screen is exactly `docs/DESIGN_DIRECTION.md`'s "compact audio-player integration."
- **TAHFEEZ SHOULD EVOLVE**: the reference's player only truly persists within `MainActivity`
  (Home), not across its other Activities (`docs/reference/03_NAVIGATION_MAP.md` §7) — Tahfeez's
  single-shell Flutter navigation can and should make the player persist across every top-level
  screen, an improvement over the reference's Activity-boundary limitation.

## 7. Onboarding tone

A short, 4-page, capability-selection-first onboarding (language, theme, translations, tafsir) —
no login/account step, no lengthy feature-tour carousel.
- **KEEP AS UX PRINCIPLE**: brief, preference-first onboarding with zero account friction aligns
  perfectly with `docs/PROJECT_BRIEF.md`'s "no mandatory account" and general product tone.

## 8. Theming system

A fixed roster of roughly seven named preset color themes (each its own light/dark
`ColorScheme` pair) plus Android dynamic (Material You) color support, layered on Material 3
`ColorScheme` tokens throughout — matching `FEATURES.md`'s "5+ material colors with dynamic
support."
- **KEEP AS UX PRINCIPLE**: offering multiple curated accent themes plus a dynamic/system-derived
  option is a good, inclusive pattern.
- **DO NOT COPY EXACTLY**: the specific named palettes and their exact color values are reference
  artwork; `docs/DESIGN_DIRECTION.md` already specifies Tahfeez's own independently-chosen
  exploration palette (emerald/teal primary, warm gold accent, etc.) as the starting point, not
  any of this app's preset names or values.

## 9. Typography and Quran-text separation

UI chrome uses a standard system/Material sans-serif family; Quran Arabic text is rendered via a
dedicated script/font/atlas pipeline entirely separate from UI typography (per-language font
substitution is even modeled for translation attribution lines, e.g. a dedicated Urdu font).
- **KEEP AS UX PRINCIPLE**: strict separation between "UI font" and "Quran font" is exactly
  `docs/DESIGN_DIRECTION.md`'s "UI typography and Quran typography are separate systems" and
  `CLAUDE.md`'s Quran-correctness posture (never render canonical text in a generic app font).

## 10. Reference-content presentation

Duas/Prophets/Etiquette/Major-Sins/Science/Topics all follow the same hub → list → detail
structure and the same small-grid entry pattern from Home.
- **KEEP AS UX PRINCIPLE**: a single, consistent drill-down shape across many content categories
  reduces cognitive load — worth preserving structurally.
- **DO NOT COPY EXACTLY**: the specific 8-category roster and its icon artwork are reference
  choices tied to content Tahfeez does not yet have rights to or a roadmap for; Tahfeez should
  decide its own reference-content categories and only add an equivalent grid once real content
  exists (`docs/reference/11_HOME_SPEC.md` §6).

## 11. Screenshots note

The reference repository's own promotional screenshots live under
`fastlane/metadata/android/en-US/images/phoneScreenshots/`. Per `docs/CLEAN_ROOM_RULES.md`, these
were **not copied into Tahfeez** and must never be embedded in the Tahfeez repository, design
files, or shipped app. This document's observations were derived from reading the app's Compose
source directly (structure and composition), not from viewing or transcribing these screenshots.

## 12. Summary judgment

The reference app is a well-organized, competent, moderately dense Material 3 application. Its
information hierarchy and interaction patterns (bottom-sheet secondary actions, collapsing reader
chrome, persistent-ish mini player, card-based grouped lists, hub→list→detail reference content,
brief onboarding) are broadly reusable UX wisdom and score as KEEP items. Its specific visual
execution — icon set, exact palette, exact spacing/radius constants, exact card compositions,
exact reference-content roster — is DO NOT COPY territory, and Tahfeez's stated direction (more
spacious, softer, stronger light mode, memorization-forward) already prescribes concrete,
independent evolutions of nearly every KEEP item above. This supports, rather than undermines,
the 50–60% familiarity target: a QuranApp user would recognize *where things are and how to get
things done* in Tahfeez, without mistaking one product for the other.
