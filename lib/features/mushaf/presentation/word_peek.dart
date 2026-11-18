import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/ui/script_direction.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../../wbw/application/active_wbw_pack.dart';
import '../../../wbw/application/arabic_word_gloss.dart';
import '../../../wbw/application/word_root.dart';
import '../../../wbw/application/wbw_word_lookup.dart';
import '../application/mushaf_appearance_controller.dart';
import '../domain/mushaf_appearance.dart';
import '../application/mushaf_word_overlay.dart';
import '../application/mushaf_pages_on_screen.dart' show mushafWordRect;
import '../../recitation/application/mistake_hint.dart';
import '../../../wbw/presentation/word_detail_sheet.dart';
import '../../../quran/application/canonical_ayah_word_text.dart';
import '../../recitation/presentation/recitation_word_feedback.dart'
    show recitationFeedbackLines;
import '../../listen/application/quran_audio_player.dart';

/// A word tapped on the Mushaf page (owner, 2026-11-16): a small glass
/// pill just above it — its sound, its meaning (tapped, the word's sheet),
/// its ayah's sheet — gone by itself after a few seconds. The tap itself only moves
/// the blue band (the next recitation's start); the sheets are a tap away.
abstract final class WordPeek {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static final _visible = ValueNotifier(false);

  /// How long it stays.
  static const shownFor = Duration(milliseconds: 3500);
  static const _fade = Duration(milliseconds: 180);

  /// After its word's sound ends (its speaker pressed), how long it stays.
  static const afterSound = Duration(seconds: 2);

  /// Its speaker pressed and the sound still playing: kept until it ends.
  static var _holding = false;

  /// [word]'s pill above [at] (global), replacing any shown — below it
  /// when above would be higher than [top] (global; the page's top: a
  /// word on the page's first line has it below, not over the bar above).
  static void show(
    BuildContext context, {
    required WordRef word,
    required Offset at,
    double? top,
    required VoidCallback onWord,
    required VoidCallback onAyah,
  }) {
    _remove();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final box = overlay.context.findRenderObject() as RenderBox?;
    final local = box == null ? at : box.globalToLocal(at);
    final localTop = top == null || box == null
        ? null
        : box.globalToLocal(Offset(0, top)).dy;
    _visible.value = false;
    final entry = OverlayEntry(
      builder: (context) => _WordPeekLayer(
        // (From the touch: above the word's line, not over it.)
        x: local.dx,
        aboveY: local.dy - 30,
        belowY: local.dy + 30,
        top: localTop,
        visible: _visible,
        onTapOutside: hide,
        pillKey: pillKey,
        child: _WordPeekPill(
          word: word,
          onWord: () {
            hide(now: true);
            onWord();
          },
          onAyah: () {
            hide(now: true);
            onAyah();
          },
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_entry == entry) _visible.value = true;
    });
    _timer = Timer(shownFor, hide);
    // Over a mistake's hint: that one gives way (owner, 2026-11-16).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mine = _rectOf(pillKey);
      if (mine != null) MistakePeek.hideIfOver(mine);
    });
  }

  /// The pill shown (its box on screen, for a collision).
  static final pillKey = GlobalKey(debugLabel: 'word-peek');

  /// Its word's sound asked for: kept while it plays ([soundEnded] then
  /// counts [afterSound]) — not gone before the word is heard.
  static void holdForSound() {
    if (_entry == null) return;
    _timer?.cancel();
    _holding = true;
  }

  /// Its word's sound over (or never begun): gone [afterSound] later.
  static void soundEnded() {
    if (_entry == null || !_holding) return;
    _holding = false;
    _timer?.cancel();
    _timer = Timer(afterSound, hide);
  }

  /// The pill faded away (or at once, [now]).
  static void hide({bool now = false}) {
    final entry = _entry;
    if (entry == null) return;
    _timer?.cancel();
    if (now) {
      _remove();
      return;
    }
    _visible.value = false;
    _timer = Timer(_fade, () {
      if (_entry == entry) _remove();
    });
  }

  /// Whether one is shown (for tests).
  static bool get isShown => _entry != null;

  static void _remove() {
    _holding = false;
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

/// The pill, centred above [at] (below it when there's no room above),
/// kept on the screen; a tap outside it puts it away.
class _WordPeekLayer extends StatelessWidget {
  const _WordPeekLayer({
    required this.x,
    required this.aboveY,
    required this.belowY,
    required this.top,
    required this.visible,
    required this.child,
    this.onTapOutside,
    this.pillKey,
  });

  /// The pill's centre across; its bottom at [aboveY], or (no room above)
  /// its top at [belowY].
  final double x, aboveY, belowY;
  final double? top;
  final ValueListenable<bool> visible;
  final Widget child;
  final VoidCallback? onTapOutside;
  final Key? pillKey;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return CustomSingleChildLayout(
      delegate: _AboveDelegate(
        x: x,
        aboveY: aboveY,
        belowY: belowY,
        top: top,
        padding: padding,
      ),
      child: TapRegion(
        key: pillKey,
        onTapOutside: (_) => onTapOutside?.call(),
        // (A click on it not reaching the web's Mushaf canvas under it.)
        child: CanvasClickShield(
          child: ValueListenableBuilder(
            valueListenable: visible,
            builder: (context, shown, child) => AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: WordPeek._fade,
              child: AnimatedScale(
                scale: shown ? 1 : 0.92,
                duration: WordPeek._fade,
                child: child,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AboveDelegate extends SingleChildLayoutDelegate {
  _AboveDelegate({
    required this.x,
    required this.aboveY,
    required this.belowY,
    required this.top,
    required this.padding,
  });

  final double x, aboveY, belowY;

  /// Above, not higher than this (the page's top).
  final double? top;
  final EdgeInsets padding;

  static const _margin = 12.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(constraints.maxWidth - 2 * _margin, constraints.maxHeight),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final left = (x - child.width / 2).clamp(
      _margin,
      size.width - child.width - _margin,
    );
    var y = aboveY - child.height;
    final limit = [padding.top + _margin, ?top].reduce(math.max);
    if (y < limit) y = belowY;
    return Offset(left, y);
  }

  @override
  bool shouldRelayout(_AboveDelegate old) =>
      old.x != x ||
      old.aboveY != aboveY ||
      old.belowY != belowY ||
      old.top != top ||
      old.padding != padding;
}

/// The marks' colours on the page, for the pill's dot.
const _markDots = {
  MushafWordMark.skipped: Color(0xFFE0A800),
  MushafWordMark.wrong: Color(0xFFD32F2F),
  MushafWordMark.mistake: Color(0xFFD32F2F),
  MushafWordMark.tashkeel: Color(0xFFEF6C00),
  MushafWordMark.tajweed: Color(0xFF039BE5),
};

/// The word in a glass pill, as the recitation bar's buttons are grouped:
/// its sound | its meaning (a dot first when the last recitation marked a
/// mistake on it) — tapped, its sheet | its ayah's sheet (owner,
/// 2026-11-16), in that order in every language.
class _WordPeekPill extends ConsumerWidget {
  const _WordPeekPill({
    required this.word,
    required this.onWord,
    required this.onAyah,
  });

  final WordRef word;
  final VoidCallback onWord;
  final VoidCallback onAyah;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The page's own theme (light, warm, sepia, dark, black — not the
    // app's): the pill is part of the page (owner, 2026-11-16).
    final page = ref.watch(mushafAppearanceControllerProvider).colors;
    final mark = ref.watch(
      mushafWordOverlayProvider.select((o) => o?.marks[word]),
    );
    final dot = _markDots[mark];
    final meaning = _meaning(context, ref);
    // Its word's sound over: it goes a moment later.
    ref.listen(quranAudioPlayerProvider, (was, now) {
      if ((was?.isWord ?? false) && !(now?.isWord ?? false)) {
        WordPeek.soundEnded();
      }
    });
    final ink = page.text;
    Widget divider() => VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 10,
      endIndent: 10,
      color: ink.withValues(alpha: 0.18),
    );
    // The bars' glass in the page's colours (PageGlass).
    return PageGlass(
      key: const ValueKey('word-peek'),
      colors: page,
      radius: _height / 2,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _height),
        // Sound | meaning | ayah, left to right in every language;
        // a long meaning on two lines, the pill taller (owner,
        // 2026-11-16), not cut short.
        child: IntrinsicHeight(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('word-peek-play'),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, _height),
                    minimumSize: const Size(44, _height),
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  color: ink,
                  icon: const Icon(Icons.volume_up_outlined),
                  tooltip: l10n.wordPlayAudio,
                  onPressed: () async {
                    WordPeek.holdForSound();
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    final offline = l10n.listenOffline;
                    final played = await ref
                        .read(quranAudioPlayerProvider.notifier)
                        .playWord(word.ayahId, word.wordIndex);
                    if (!played) {
                      WordPeek.soundEnded();
                      if (messenger != null) {
                        showListenOffline(messenger, offline);
                      }
                    }
                  },
                ),
                divider(),
                Flexible(
                  child: InkWell(
                    key: const ValueKey('word-peek-word'),
                    onTap: onWord,
                    child: Semantics(
                      button: true,
                      label: l10n.wordDetails,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 6,
                          children: [
                            if (dot != null)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: dot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Flexible(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
                                child: Text(
                                  meaning ?? '…',
                                  maxLines: 2,
                                  // As wide as its longest line,
                                  // not all the room it may take
                                  // (two lines were left with a
                                  // wide empty end — owner).
                                  textWidthBasis: TextWidthBasis.longestLine,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: meaningDirection(
                                    meaning ?? '',
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: ink,
                                  ),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: page.secondaryText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                divider(),
                IconButton(
                  key: const ValueKey('word-peek-ayah'),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, _height),
                    minimumSize: const Size(44, _height),
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  color: ink,
                  icon: const Icon(Icons.menu_book_outlined),
                  tooltip: l10n.ayahDetails,
                  onPressed: onAyah,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The word's meaning, one line: in Arabic al-Sirāj's, else its root
  /// («الجذر: قول»), else the word itself — never another language
  /// (owner, 2026-11-18); in other languages the word-by-word pack's
  /// (English's where it has none). `null` loading.
  String? _meaning(BuildContext context, WidgetRef ref) {
    if (Localizations.localeOf(context).languageCode == 'ar') {
      final at = (ayahId: word.ayahId, wordIndex: word.wordIndex);
      final gloss = ref.watch(arabicWordGlossProvider(at));
      if (gloss.value case final g?) return g;
      if (gloss.isLoading) return null;
      final root = ref.watch(wordRootProvider(at));
      if (root.value case final r?) {
        return '${AppLocalizations.of(context).wordRoot}: $r';
      }
      if (root.isLoading) return null;
      return ref
          .watch(
            canonicalAyahWordTextProvider(
              ayahId: word.ayahId,
              wordIndex: word.wordIndex,
            ),
          )
          .value;
    }
    final pack = ref.watch(activeWbwPackProvider).value;
    String? lookup(String packId) => ref
        .watch(
          wbwWordLookupProvider(
            packId: packId,
            ayahId: word.ayahId,
            wordIndex: word.wordIndex,
          ),
        )
        .value
        ?.translation;
    final own = pack == null ? null : lookup(pack.id);
    return own ?? lookup(englishWbwPackId) ?? '';
  }
}

/// Glass in the Mushaf page's own colours — mostly opaque (owner,
/// 2026-11-16: the more see-through version was too glassy), the blur
/// keeping the ink behind from fighting the text (the bars' frost — what
/// is behind
/// blurred, a see-through tint, a bright hairline — over the page's paper
/// and ink): the word pills (owner, 2026-11-16).
class PageGlass extends StatelessWidget {
  const PageGlass({
    super.key,
    required this.colors,
    required this.radius,
    required this.child,
  });

  final MushafAppearanceColors colors;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final paper = colors.background, ink = colors.text;
    final dark = paper.computeLuminance() < 0.3;
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    paper,
                    Colors.white,
                    dark ? 0.06 : 0.35,
                  )!.withValues(alpha: dark ? 0.7 : 0.72),
                  Color.lerp(
                    paper,
                    ink,
                    0.04,
                  )!.withValues(alpha: dark ? 0.84 : 0.86),
                ],
              ),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

/// [key]'s widget's box on the screen, if laid out.
Rect? _rectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// A sure mistake heard while reciting, as a hint in a small pill just
/// above its word (owner, 2026-11-16): its mark's dot and what was wrong,
/// one line — with "+2" when the ayah's check found others with it; no
/// buttons. Tapped, the word's sheet (its mistakes gone through there).
/// One at a time; corrected, it turns green and goes. The tap pill
/// ([WordPeek]) shown over it takes its place.
abstract final class MistakePeek {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static final _visible = ValueNotifier(false);
  static WordRef? _word;

  /// How long it stays (and, corrected, after).
  static const shownFor = Duration(milliseconds: 3000);
  static const afterCorrected = Duration(milliseconds: 1200);

  static final _key = GlobalKey(debugLabel: 'mistake-peek');

  /// The word its hint is on, while one is shown.
  static WordRef? get word => _entry == null ? null : _word;

  /// [word]'s hint above [rect] (its box on screen, global) — below it
  /// when above would be higher than [top] (the page's top) — with [more]
  /// other mistakes found with it.
  static void show(
    BuildContext context, {
    required WordRef word,
    required Rect rect,
    double? top,
    int more = 0,
    required VoidCallback onTap,
  }) {
    _remove();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final box = overlay.context.findRenderObject() as RenderBox?;
    final local = box == null
        ? rect
        : rect.shift(-box.localToGlobal(Offset.zero));
    final localTop = top == null || box == null
        ? null
        : box.globalToLocal(Offset(0, top)).dy;
    _word = word;
    _visible.value = false;
    final entry = OverlayEntry(
      builder: (context) => _WordPeekLayer(
        x: local.center.dx,
        aboveY: local.top - 6,
        belowY: local.bottom + 6,
        top: localTop,
        visible: _visible,
        pillKey: _key,
        child: _MistakePill(
          word: word,
          more: more,
          onTap: () {
            hide(now: true);
            onTap();
          },
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_entry == entry) _visible.value = true;
    });
    _timer = Timer(shownFor, hide);
  }

  /// Its word corrected: gone a moment later (green meanwhile).
  static void corrected() {
    if (_entry == null) return;
    _timer?.cancel();
    _timer = Timer(afterCorrected, hide);
  }

  /// Gone if it lies under [rect] (the tap pill's box).
  static void hideIfOver(Rect rect) {
    final mine = _rectOf(_key);
    if (mine != null && mine.overlaps(rect)) hide(now: true);
  }

  static void hide({bool now = false}) {
    final entry = _entry;
    if (entry == null) return;
    _timer?.cancel();
    if (now) {
      _remove();
      return;
    }
    _visible.value = false;
    _timer = Timer(WordPeek._fade, () {
      if (_entry == entry) _remove();
    });
  }

  /// Whether one is shown (for tests).
  static bool get isShown => _entry != null;

  static void _remove() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

/// The hint: the mark's dot (green once corrected), what was wrong, and
/// "+2" for the others found with it.
class _MistakePill extends ConsumerWidget {
  const _MistakePill({
    required this.word,
    required this.more,
    required this.onTap,
  });

  final WordRef word;
  final int more;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final page = ref.watch(mushafAppearanceControllerProvider).colors;
    final overlay = ref.watch(mushafWordOverlayProvider);
    final corrected = overlay?.corrected.contains(word) ?? false;
    ref.listen(
      mushafWordOverlayProvider.select(
        (o) => o?.corrected.contains(word) ?? false,
      ),
      (was, now) {
        if (now && !(was ?? false)) MistakePeek.corrected();
      },
    );
    final text = ref
        .watch(
          canonicalAyahWordTextProvider(
            ayahId: word.ayahId,
            wordIndex: word.wordIndex,
          ),
        )
        .value;
    final lines = recitationFeedbackLines(ref, l10n, word, text)?.lines;
    final line = corrected
        ? l10n.recFeedbackCorrected
        : lines?.firstOrNull ?? l10n.recFeedbackPronunciation;
    final dot = corrected
        ? const Color(0xFF43A047)
        : _markDots[overlay?.marks[word]] ?? const Color(0xFFD32F2F);
    final ink = page.text;
    return GestureDetector(
      key: const ValueKey('mistake-peek'),
      onTap: onTap,
      child: Semantics(
        button: true,
        liveRegion: true,
        label: '${l10n.wordDetails}: $line',
        child: PageGlass(
          colors: page,
          radius: 16,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (corrected)
                  Icon(Icons.check_rounded, size: 16, color: dot)
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textWidthBasis: TextWidthBasis.longestLine,
                      style: theme.textTheme.bodySmall?.copyWith(color: ink),
                    ),
                  ),
                ),
                if (more > 0 && !corrected)
                  Text(
                    '+$more',
                    key: const ValueKey('mistake-peek-more'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: page.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [hint]'s pill above its word — once the word is drawn (its page laid
/// out: a few frames' tries); not shown when it can't be placed, or a newer
/// hint came meanwhile. Tapped, the word's sheet. [top]: the page's top
/// (a word on its first line has it below). The Mushaf's and the first-run
/// guide's demo (owner, 2026-11-16).
void showMistakeHint(
  BuildContext context,
  WidgetRef ref,
  MistakeHint hint, {
  double? top,
  int tries = 0,
}) {
  if (!context.mounted || ref.read(mistakeHintProvider)?.id != hint.id) {
    return;
  }
  final rect = mushafWordRect(ref.read, hint.word);
  if (rect == null) {
    if (tries < 5) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showMistakeHint(context, ref, hint, top: top, tries: tries + 1),
      );
    }
    return;
  }
  MistakePeek.show(
    context,
    word: hint.word,
    rect: rect,
    top: top,
    more: hint.more,
    // Always the word's sheet (its mistakes gone through there).
    onTap: () {
      if (context.mounted) showWordDetailSheet(context, wordRef: hint.word);
    },
  );
}
