import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'full_bleed_content.g.dart';

/// Whether the app shell must let the active screen render edge-to-edge,
/// escaping the shell's reading-width cap (`TahfeezContentWidth.maxReading`).
///
/// The shell's cap exists to stop reflowable text from stretching into
/// unreadably long lines on a wide screen. It does not apply to a fixed-aspect
/// -ratio printed page (the Mushaf), whose own proportions already bound it —
/// and before this latch existed a Mushaf screen still inside the cap could
/// not paint past it anyway: the enclosing `Navigator`'s `Overlay`
/// (`Clip.hardEdge` by default) clips it. A two-page Mushaf spread therefore
/// requests full-bleed here, and `AppShell` responds by widening that branch's
/// content column to the full content area.
///
/// The latch is held by the spread-rendering `MushafPager` exactly while a
/// spread is active and released otherwise — verse-by-verse reading (and every
/// other screen) stays inside the reading column.
@Riverpod(keepAlive: true)
class FullBleedContent extends _$FullBleedContent {
  @override
  bool build() => false;

  void request() => state = true;

  void release() => state = false;
}
