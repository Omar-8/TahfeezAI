# Tahfeez's local patches to `qvp_flutter`

This is a vendored, locally-patched copy of the `qvp_flutter` package
(`https://pub.dev/packages/qvp_flutter`), used via a `pubspec.yaml`
`dependency_overrides: qvp_flutter: {path: third_party/qvp_flutter}`
entry instead of the plain pub.dev dependency. It is not a fork in the
sense of diverging development — it exists solely to carry one small,
isolated, well-documented patch until upstream either adopts it or a
future package version makes it unnecessary.

## Provenance

- **Vendored from**: `qvp_flutter` v0.2.2, exactly as published on
  pub.dev (`~/.pub-cache/hosted/pub.dev/qvp_flutter-0.2.2` at the time
  of vendoring — byte-identical copy, `LICENSE` included unmodified).
- **Upstream repository** (per the package's own `pubspec.yaml`):
  `https://github.com/quran-ws/quran-engine/tree/main/packages/flutter/qvp_flutter`.
- **Upstream commit**: not independently identifiable. pub.dev does not
  publish the exact commit a given package version was cut from, and
  the version of the engine monorepo Tahfeez has separately vendored
  for the Web build (`tool/quran_engine/README.md`'s pinned commit
  `a19ee9b16ec60689dfd9ef566c49d393f9a47459`) was checked directly and
  does **not** match this package's own compiled behavior — its C ABI
  (`crates/qvp-ffi/include/qvp.h` at that commit) has a materially
  different, smaller `QvpLayoutSpec` struct with no `max_aspect_slack`
  field at all, while `qvp_flutter` 0.2.2's own Dart FFI bindings
  (`lib/src/bindings.dart`) declare one. This is expected — this
  project's own docs already record "known upstream API drift between
  the pinned source commit and the published `qvp_flutter` package"
  (`docs/poc/QURAN_ENGINE_POC.md` §3) — but it means this patch is
  documented against the **published package version** (0.2.2), not a
  specific upstream git commit, since that commit isn't determinable
  from the information pub.dev publishes.
- **Native binaries**: `android/src/main/jniLibs/*/libqvp_ffi.so`
  (prebuilt, one per ABI) are carried over unmodified — this patch is
  Dart-source-only, see "Why this is safe" below.

## The patch

`patches/0001-expose-maxAspectSlack-on-QvpViewLayout.patch` — a unified
diff against `lib/src/page_view.dart`, already applied to this vendored
copy. Summary: adds an optional `maxAspectSlack` field to
`QvpViewLayout`'s constructor (`null` by default), threaded through to
`toSpec()` as `maxAspectSlack ?? QvpDefaults.aspectSlack` in place of the
previous unconditional `QvpDefaults.aspectSlack`. Also added to
`copyWith`/`operator==`/`hashCode` for completeness. Nothing else in the
package changed.

### Why

`QvpPageView`'s own convenience layout object, `QvpViewLayout`, builds a
`QvpLayoutSpec` (`toSpec()`) to pass to the engine's `QvpPage.layout()`
call. `QvpLayoutSpec.maxAspectSlack` is a real, already-supported,
already-documented field on that lower-level spec type — its own doc
comment states plainly: *"The content is never wider than `viewportH ·
pageW / pageH · maxAspectSlack` (0 = no bound)"* — and `QvpPage`'s
`_writeSpec()`/`layout()` do nothing but copy that value straight into
the FFI struct and call the native engine; no Dart-side clamping or
enforcement of any kind happens on top of it. In other words: **the
engine itself already fully supports an unbounded fit** (`0`), verified
by reading the actual Dart call chain, not assumed.

The only problem was that `QvpViewLayout` — the object `QvpPageView`'s
public widget API actually accepts — never exposed this field at all;
`toSpec()` unconditionally passed the library's own default,
`QvpDefaults.aspectSlack` (`1.15`), with no way for a caller to ask for
anything else. That made a widget-level default into an unconditional
ceiling: Quran Engine's own official rendering widget would never draw
a Mushaf page more than 15% wider than its natural print width, no
matter how much real screen space was actually available — visible as
persistent empty space beside the page that no amount of surrounding
Flutter layout changes could close, because the ceiling was being
enforced *inside* `QvpPageView` itself, not by anything wrapping it.

### Why this is safe

- Purely additive: the new field defaults to `null`, which preserves
  `QvpDefaults.aspectSlack` exactly — every existing call site (every
  other consumer of this package, and every prior Tahfeez call site)
  keeps its exact original behavior unless it explicitly opts in.
- Touches only `QvpViewLayout`, a plain, immutable Dart value object.
  `QvpPageView`'s own rendering (`_QvpPainter`), hit-testing (`_hitAt`/
  `_onTapUp`/`_onLongPressStart`), highlighting, masking/reveal, and
  gesture handling are completely untouched — this patch only changes
  what numeric ceiling gets written into one existing, already-defined
  field of a struct the engine was already reading.
- No native code, no FFI struct shape, no `.so` binary is touched. The
  patched value flows through the exact same `QvpLayoutSpecC` field and
  the exact same `qvp_layout()` native call every unpatched caller
  already uses — only the *number* Tahfeez chooses to put in it differs
  from the previous hardcoded default.

## Patch 0002: a word long-press callback

`patches/0002-word-long-press-on-QvpPageView.patch` adds
`QvpPageView.onWordLongPress` (`void Function(int word, QvpHit hit)?`).
When set, a long press on a word calls it (with a selection-click haptic)
instead of starting the widget's own drag selection; when `null`,
behaviour is exactly upstream's. Tahfeez uses it to highlight a word's
whole ayah and open the ayah sheet
(`quran_engine_android_backend.dart`, `onWordLongHit`). Re-apply it with
`patch -p1 < patches/0002-word-long-press-on-QvpPageView.patch` after
re-vendoring, like patch 0001.

## How Tahfeez uses this

`lib/features/mushaf/data/quran_engine/quran_engine_android_backend.dart`
passes `QvpViewLayout(maxAspectSlack: 0, ...)` — see that file for the
full reasoning and for the corresponding change to
`QuranEngineMushafPageContent` (which stopped pre-constraining the box
`QvpPageView` receives, once this ceiling no longer needed working
around from the outside).

## Maintenance

- **If upstream `qvp_flutter` ever exposes this parameter itself**
  (directly, or under a different name) in a published version: drop
  this override, remove `third_party/qvp_flutter/`, bump the plain
  `qvp_flutter` pub.dev dependency, and re-point
  `quran_engine_android_backend.dart` at whatever the real parameter
  ends up being called.
- **If Tahfeez needs to pick up a newer `qvp_flutter` release** before
  upstream adds this: re-vendor the new version into this same
  directory, re-apply `patches/0001-expose-maxAspectSlack-on-QvpViewLayout.patch`
  (`patch -p1 < patches/0001-expose-maxAspectSlack-on-QvpViewLayout.patch`
  from this directory, or replay the equivalent by hand if the
  surrounding code has changed shape), and confirm
  `flutter analyze`/`flutter test`/a real Android build all still pass.
- **To submit this upstream**: the patch file is a standard unified
  diff against the exact 0.2.2 source, ready to adapt into a PR against
  `https://github.com/quran-ws/quran-engine` (`packages/flutter/qvp_flutter`).

## Patch 0003 — slot-filling highlight bands

`patches/0003-slot-filling-highlight-bands.patch` adds
`QvpPage.slotFillHighlights` (highlight handles, cleared with
`clearHighlights`) and makes `QvpPageView` draw those highlights' band
boxes over their line's whole layout slot (`QvpLayout.slots`, top to
bottom) instead of the band's own height. Consecutive lines' bands then
meet with no gap, even when `fillHeight` spreads the lines unevenly —
which a band's `padY` could not do (the engine ignores it for
`'lineSpacing'`-height bands; measured on the device, 2026-10-11).

A slot-filling box also takes in an ayah mark (`QvpPage.decorations`) on
its line that sits beside it, so a mark hanging at a line's end is tinted
with its passage.

Used by `quran_engine_android_backend.dart` for the Mushaf's thematic
passage tints (`PageBand`). Re-apply with
`patch -p1 < patches/0003-slot-filling-highlight-bands.patch` after
re-vendoring.
