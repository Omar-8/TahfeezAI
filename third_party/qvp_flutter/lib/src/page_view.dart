// QvpPageView — the Flutter host renderer for a QvpPage.
//
// Draw order per frame (same as web/qvp.js CanvasRenderer):
//   highlight bands → cached base ink → styled paths → mask boxes
// The engine decides everything (layout, hit-testing, colours, boxes); this
// widget only converts geometry into ui.Path objects once, caches the
// unstyled ink as an image at the current transform, and forwards gestures
// to the engine's hit test / selection.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'engine.dart';

/// Layout parameters of [QvpPageView] (viewport size is taken from the widget's constraints).
/// Spacing only opens up: `lineSpacing` < 1 is clamped by the engine.
/// Pinch limits as multiples of the fitted scale; the same pair on every platform.
const double kMinZoom = 0.5;
const double kMaxZoom = 12;

@immutable
class QvpViewLayout {
  // ── Tahfeez patch (qvp_flutter 0.2.2 → third_party/qvp_flutter) ──
  // `toSpec()` below used to hard-code `maxAspectSlack: QvpDefaults.aspectSlack`
  // (1.15), with no constructor parameter to override it, even though the
  // lower-level `QvpLayoutSpec` this builds already accepts any value
  // (`0` documented as "no bound") and the native engine already honors
  // it — confirmed by reading `QvpLayoutSpec.maxAspectSlack`'s own doc
  // comment in engine.dart and its straight FFI pass-through in
  // `QvpPage._writeSpec`/`layout()` (nothing in this Dart wrapper computes
  // or clamps anything using this value itself). So this ceiling was a
  // widget-level default becoming an unconditional limit, not an engine
  // limitation. Tahfeez's Mushaf pages need to use the actual available
  // viewport at whatever aspect ratio it has (see
  // docs/QURAN_ENGINE_MIGRATION.md's "Mushaf page display" notes) without
  // being held to within 15% of the page's own printed width — this one
  // field is now a normal, nullable constructor parameter, named to match
  // `QvpLayoutSpec.maxAspectSlack` exactly, defaulting to `null` (meaning
  // "use the upstream default", unchanged from 0.2.2's own behavior) so
  // every existing call site keeps its exact original behavior unless it
  // opts in. See third_party/qvp_flutter/PATCHES.md for the full record.
  const QvpViewLayout({
    this.padTop = 24,
    this.padBottom = 24,
    this.padSide = 16,
    this.lineSpacing = 1,
    this.fillHeight = false,
    this.gridLines = 0,
    this.maxAspectSlack,
  });
  final double padTop, padBottom, padSide, lineSpacing;
  final bool fillHeight;
  final int gridLines;

  /// `null` (the default) keeps upstream's own built-in behavior
  /// (`QvpDefaults.aspectSlack`, 1.15 — the content is never wider than
  /// `viewportH · pageW / pageH · 1.15`). An explicit `0` removes that
  /// ceiling entirely ("no bound", per `QvpLayoutSpec.maxAspectSlack`'s
  /// own doc comment) — the engine still computes and owns the resulting
  /// uniform scale/centering, this only changes the ceiling passed into
  /// that existing, already-supported parameter.
  final double? maxAspectSlack;

  QvpViewLayout copyWith({
    double? padTop,
    double? padBottom,
    double? padSide,
    double? lineSpacing,
    bool? fillHeight,
    int? gridLines,
    double? maxAspectSlack,
  }) => QvpViewLayout(
    padTop: padTop ?? this.padTop,
    padBottom: padBottom ?? this.padBottom,
    padSide: padSide ?? this.padSide,
    lineSpacing: lineSpacing ?? this.lineSpacing,
    fillHeight: fillHeight ?? this.fillHeight,
    gridLines: gridLines ?? this.gridLines,
    maxAspectSlack: maxAspectSlack ?? this.maxAspectSlack,
  );

  QvpLayoutSpec toSpec(double viewportW, double viewportH) => QvpLayoutSpec(
    viewportW: viewportW,
    viewportH: viewportH,
    padTop: padTop,
    padBottom: padBottom,
    padLeft: padSide,
    padRight: padSide,
    lineSpacing: lineSpacing,
    fillHeight: fillHeight,
    gridLines: gridLines,
    maxAspectSlack: maxAspectSlack ?? QvpDefaults.aspectSlack,
  );

  @override
  bool operator ==(Object other) =>
      other is QvpViewLayout &&
      other.padTop == padTop &&
      other.padBottom == padBottom &&
      other.padSide == padSide &&
      other.lineSpacing == lineSpacing &&
      other.fillHeight == fillHeight &&
      other.gridLines == gridLines &&
      other.maxAspectSlack == maxAspectSlack;

  @override
  int get hashCode => Object.hash(
    padTop,
    padBottom,
    padSide,
    lineSpacing,
    fillHeight,
    gridLines,
    maxAspectSlack,
  );
}

/// Pan / zoom on top of the engine layout. `view px = offsetX + layout px * scale`.
class QvpViewController extends ChangeNotifier {
  double scale = 1, offsetX = 0, offsetY = 0;
  bool _fitRequested = true;

  /// Size of the last laid-out viewport (logical px).
  Size viewport = Size.zero;

  void set({double? scale, double? offsetX, double? offsetY}) {
    this.scale = scale ?? this.scale;
    this.offsetX = offsetX ?? this.offsetX;
    this.offsetY = offsetY ?? this.offsetY;
    notifyListeners();
  }

  /// Repaints views using this controller.
  void refresh() => notifyListeners();

  /// Fits the page into the viewport on the next frame.
  void fit() {
    _fitRequested = true;
    notifyListeners();
  }

  /// Zooms by [factor] around a point in widget coordinates (default: centre).
  void zoomBy(
    double factor, {
    Offset? around,
    double minScale = kMinZoom,
    double maxScale = kMaxZoom,
  }) {
    final c = around ?? Offset(viewport.width / 2, viewport.height / 2);
    final ns = (scale * factor).clamp(minScale, maxScale);
    final k = ns / scale;
    set(
      scale: ns,
      offsetX: c.dx - (c.dx - offsetX) * k,
      offsetY: c.dy - (c.dy - offsetY) * k,
    );
  }

  /// Widget coordinates → layout viewport px (what the engine's `*View` calls take).
  Offset toView(Offset local) =>
      Offset((local.dx - offsetX) / scale, (local.dy - offsetY) / scale);
}

/// Tahfeez patch 0005 (`PATCHES.md`): a short animation on one word.
enum QvpWordEffectKind {
  /// A soft glow of [QvpWordEffect.color] (its alpha scaling the glow's)
  /// behind the word, fading out.
  bloom,

  /// The word's styled ink sways sideways a few times, settling.
  shake,

  /// The word's ink fades in from the paper (drawn over it, fading out).
  inkIn,

  /// The word's ink fades into the paper (drawn over it, fading in) over
  /// 400 ms — as [inkIn], mirrored — then held at the paper a moment, for
  /// the app to hide the word then.
  inkOut,
}

/// Tahfeez patch 0005: one running [QvpWordEffectKind] on page word [word].
@immutable
class QvpWordEffect {
  const QvpWordEffect(
    this.word,
    this.kind,
    this.color,
    this.startMs, {
    this.halo = true,
    this.letters = true,
  });

  final int word;
  final QvpWordEffectKind kind;
  final Color color;

  /// A [QvpWordEffectKind.bloom]'s soft band behind the whole word, with
  /// the glow around its letters (`false`: the letters' glow only — words
  /// glowing together then read as one).
  final bool halo;

  /// A [QvpWordEffectKind.bloom]'s blurred glow around the word's letters
  /// (`false`: the band only — cheap enough for many words at once).
  final bool letters;

  /// On [QvpWordEffects.nowMs]'s clock.
  final double startMs;

  double get durationMs => switch (kind) {
    QvpWordEffectKind.bloom => 650,
    QvpWordEffectKind.shake => 420,
    QvpWordEffectKind.inkIn => 400,
    QvpWordEffectKind.inkOut => 460,
  };
}

/// Tahfeez patch 0005: the word animations of a [QvpPageView]
/// ([QvpPageView.effects]) — played by the app, drawn over the page until
/// each ends.
class QvpWordEffects extends ChangeNotifier {
  static final Stopwatch _clock = Stopwatch()..start();
  static double get nowMs => _clock.elapsedMicroseconds / 1000;

  final _effects = <QvpWordEffect>[];

  /// Plays [kind] on [word], [delayMs] from now.
  void play(
    int word,
    QvpWordEffectKind kind, {
    Color color = const Color(0xFF43A047),
    double delayMs = 0,
    bool halo = true,
    bool letters = true,
  }) {
    _effects.add(
      QvpWordEffect(
        word,
        kind,
        color,
        nowMs + delayMs,
        halo: halo,
        letters: letters,
      ),
    );
    notifyListeners();
  }

  /// The effects not yet over at [now] (the finished ones dropped).
  List<QvpWordEffect> runningAt(double now) {
    _effects.removeWhere((e) => now > e.startMs + e.durationMs);
    return _effects;
  }
}

/// Renders a [QvpPage] with the engine's layout, animated highlights, masks,
/// styled paths, tap / long-press selection and pinch / pan.
class QvpPageView extends StatefulWidget {
  const QvpPageView({
    super.key,
    required this.page,
    this.layout = const QvpViewLayout(),
    this.paper = const Color(0xfffffdf7),
    this.defaultInk,
    this.controller,
    this.onWordTap,
    this.onDecorationTap,
    this.onEmptyTap,
    this.onWordLongPress,
    this.onSelectionChanged,
    this.hitMaxDistance = QvpDefaults.tapDistance,
    this.selectionEnabled = true,
    this.panZoomEnabled = true,
    this.selectionBand = QvpDefaults.selectionBand,
    this.paperShadow = true,
    this.minScale = kMinZoom,
    this.maxScale = kMaxZoom,
    this.effects,
  });

  final QvpPage page;

  /// Word animations drawn over the page (Tahfeez patch 0005).
  final QvpWordEffects? effects;
  final QvpViewLayout layout;

  /// Paper colour behind the ink (null = transparent).
  final Color? paper;

  /// Default ink; applied to the page with `setDefaultColor` when it changes. Anything [rgba] accepts.
  final Object? defaultInk;
  final QvpViewController? controller;

  /// Tap on a word (gap-aware). [hit] carries path / decoration / line / distance.
  final void Function(int word, QvpHit hit)? onWordTap;

  /// Tap on a decoration (ayah mark, surah banner, …) that is not a word.
  final void Function(QvpDecorationInfo decoration)? onDecorationTap;
  final VoidCallback? onEmptyTap;

  /// Long press on a word (gap-aware), in place of starting a drag
  /// selection. Tahfeez patch 0002 (`PATCHES.md`).
  final void Function(int word, QvpHit hit)? onWordLongPress;

  /// Whole-word selection changed through long-press-drag (empty list = cleared).
  final void Function(List<int> words)? onSelectionChanged;

  /// Max distance (page units) for the gap-aware tap.
  final double hitMaxDistance;
  final bool selectionEnabled, panZoomEnabled, paperShadow;

  /// Band colour of the drag selection (0xRRGGBBAA), drawn in [QvpLayer.selection].
  final int selectionBand;
  final double minScale, maxScale;

  @override
  State<QvpPageView> createState() => QvpPageViewState();
}

class QvpPageViewState extends State<QvpPageView>
    with SingleTickerProviderStateMixin {
  late QvpViewController _ctl;
  late final Ticker _ticker;
  final Stopwatch _clock = Stopwatch()..start();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final _InkCache _cache = _InkCache();
  Size _size = Size.zero;
  QvpViewLayout? _laidOut;
  int _selHandle = 0, _selAnchor = -1;
  bool _selecting = false;

  // scale gesture
  double _gScale = 1, _gOx = 0, _gOy = 0;
  Offset _gFocal = Offset.zero;

  QvpViewController get controller => _ctl;
  QvpPage get page => widget.page;

  /// True while the engine is animating.
  bool get animating => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    _ctl = widget.controller ?? QvpViewController();
    _ticker = createTicker(_onTick);
    _attachPage();
    _applyInk();
    widget.effects?.addListener(_ensureTicking);
  }

  void _attachPage() {
    widget.page.addListener(_onPageChanged);
    _cache.attach(widget.page);
    _selHandle = 0;
    _selAnchor = -1;
    _laidOut = null;
    _ctl._fitRequested = true;
  }

  void _applyInk() {
    final ink = widget.defaultInk;
    if (ink != null && rgba(ink) != widget.page.defaultInk)
      widget.page.setDefaultColor(ink);
  }

  @override
  void didUpdateWidget(QvpPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller)
      _ctl =
          widget.controller ??
          (oldWidget.controller == null ? _ctl : QvpViewController());
    if (oldWidget.page != widget.page) {
      oldWidget.page.removeListener(_onPageChanged);
      _attachPage();
    }
    if (oldWidget.defaultInk != widget.defaultInk) _applyInk();
    if (oldWidget.effects != widget.effects) {
      oldWidget.effects?.removeListener(_ensureTicking);
      widget.effects?.addListener(_ensureTicking);
    }
    if (oldWidget.layout != widget.layout) _ctl._fitRequested = true;
  }

  @override
  void dispose() {
    widget.page.removeListener(_onPageChanged);
    widget.effects?.removeListener(_ensureTicking);
    _ticker.dispose();
    _cache.dispose();
    _frame.dispose();
    if (widget.controller == null) _ctl.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    // the app cleared the selection behind our back → drop our band
    if (_selHandle != 0 &&
        !_selecting &&
        !page.isDisposed &&
        page.selection().isEmpty) {
      final h = _selHandle;
      _selHandle = 0;
      page.removeHighlight(h);
      return; // removeHighlight notifies again
    }
    _ensureTicking();
  }

  void _ensureTicking() {
    if (!_ticker.isActive && mounted) _ticker.start();
  }

  double get nowMs => _clock.elapsedMicroseconds / 1000;

  void _onTick(Duration _) {
    if (page.isDisposed) {
      _ticker.stop();
      return;
    }
    final more = page.tick(nowMs);
    // Tahfeez patch 0005: ticking on while a word animation runs.
    final effects = widget.effects?.runningAt(QvpWordEffects.nowMs);
    _frame.value++;
    if (!more && (effects == null || effects.isEmpty)) _ticker.stop();
  }

  // ── layout & fit (engine layout, then pan/zoom on top) ──
  void _relayout(Size size) {
    final p = page;
    p.layout(widget.layout.toSpec(size.width, size.height));
    _laidOut = widget.layout;
    _size = size;
    _ctl.viewport = size;
  }

  void _fit(Size size) {
    final l = page.currentLayout!;
    _ctl.scale = l.fitScale;
    _ctl.offsetX = l.fitX;
    _ctl.offsetY = l.fitY;
    _ctl._fitRequested = false;
  }

  /// Re-runs the engine layout and fits the page.
  void fit() {
    if (_size == Size.zero) return;
    _relayout(_size);
    _fit(_size);
    _ctl.refresh();
  }

  // ── gestures ──
  QvpHit? _hitAt(Offset local, {double? maxDistance}) {
    final v = _ctl.toView(local);
    return page.hitTestView(
      v.dx,
      v.dy,
      QvpHitOptions(maxDistance: maxDistance ?? 0),
    );
  }

  void _onTapUp(TapUpDetails d) {
    final h = _hitAt(d.localPosition, maxDistance: widget.hitMaxDistance);
    if (h != null && h.word >= 0) {
      widget.onWordTap?.call(h.word, h);
    } else if (h != null && h.decoration >= 0) {
      widget.onDecorationTap?.call(page.decorations[h.decoration]);
    } else {
      widget.onEmptyTap?.call();
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gScale = _ctl.scale;
    _gOx = _ctl.offsetX;
    _gOy = _ctl.offsetY;
    _gFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!widget.panZoomEnabled) return;
    final ns = (_gScale * d.scale).clamp(widget.minScale, widget.maxScale);
    final k = ns / _gScale;
    final f = d.localFocalPoint;
    _ctl.set(
      scale: ns,
      offsetX: f.dx - (_gFocal.dx - _gOx) * k,
      offsetY: f.dy - (_gFocal.dy - _gOy) * k,
    );
  }

  void _onLongPressStart(LongPressStartDetails d) {
    final onWordLongPress = widget.onWordLongPress;
    if (onWordLongPress != null) {
      final h = _hitAt(d.localPosition, maxDistance: widget.hitMaxDistance);
      if (h == null || h.word < 0) return;
      HapticFeedback.selectionClick();
      onWordLongPress(h.word, h);
      return;
    }
    if (!widget.selectionEnabled) return;
    final h = _hitAt(d.localPosition, maxDistance: widget.hitMaxDistance);
    if (h == null || h.word < 0) return;
    _selecting = true;
    _selAnchor = h.word;
    HapticFeedback.selectionClick();
    _updateSelection(h.word);
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    if (!_selecting) return;
    final h = _hitAt(d.localPosition);
    if (h != null && h.word >= 0) _updateSelection(h.word);
  }

  void _updateSelection(int focus) {
    page.select(_selAnchor, focus);
    final ws = page.selection();
    if (_selHandle != 0) {
      page.moveHighlight(_selHandle, T.words(ws));
    } else {
      _selHandle = page.highlight(
        T.words(ws),
        QvpHighlightStyle(
          mode: 'band',
          band: widget.selectionBand,
          padX: 0.6,
          ms: 0,
          layer: QvpLayer.selection,
        ),
      );
    }
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    if (!_selecting) return;
    _selecting = false;
    widget.onSelectionChanged?.call(page.selection());
  }

  /// Clears the drag selection and its band.
  void clearSelection() {
    if (_selHandle != 0) {
      page.removeHighlight(_selHandle);
      _selHandle = 0;
    }
    page.clearSelection();
    widget.onSelectionChanged?.call(const []);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(
          c.maxWidth.isFinite ? c.maxWidth : 400,
          c.maxHeight.isFinite ? c.maxHeight : 600,
        );
        if (size != _size ||
            _laidOut != widget.layout ||
            page.currentLayout == null) {
          _relayout(size);
          _ctl._fitRequested = true;
        }
        if (_ctl._fitRequested) _fit(size);
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _onTapUp,
            onDoubleTap: fit,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMove,
            onLongPressEnd: _onLongPressEnd,
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                isComplex: true,
                painter: _QvpPainter(
                  page: page,
                  view: _ctl,
                  frame: _frame,
                  cache: _cache,
                  dpr: dpr,
                  paper: widget.paper,
                  paperShadow: widget.paperShadow,
                  effects: widget.effects,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Per-page render cache: ui.Path per engine path (page units) and the base ink image.
class _InkCache {
  QvpPage? page;
  List<ui.Path>? paths;
  ui.Image? image;
  ui.Picture? picture;
  String key = '';

  /// Stats of the last frame (for HUDs).
  int basePaths = 0, overlayPaths = 0, bands = 0;
  double baseMs = 0, overlayMs = 0;

  /// Each word's engine paths (Tahfeez patch 0005), built when first needed.
  List<List<int>>? wordPaths;

  /// Each path's bounds in page units (Tahfeez patch 0005), as measured.
  List<Rect?>? pathBounds;

  /// Tahfeez patch 0006: each line's paths, and its ink — the line's words
  /// in their colours — as an image at the current transform, rebuilt only
  /// when something on that line changes.
  List<List<int>>? linePaths;
  final lines = <int, _LineImage>{};

  List<List<int>> buildLinePaths(QvpPage p) {
    final cached = linePaths;
    if (cached != null) return cached;
    var n = 0;
    for (var i = 0; i < p.nPaths; i++) {
      n = math.max(n, p.pathLine(i) + 1);
    }
    final out = List.generate(n, (_) => <int>[], growable: false);
    for (var i = 0; i < p.nPaths; i++) {
      final ln = p.pathLine(i);
      if (ln >= 0) out[ln].add(i);
    }
    return linePaths = out;
  }

  List<List<int>> buildWordPaths(QvpPage p) {
    final cached = wordPaths;
    if (cached != null) return cached;
    final out = List.generate(p.nWords, (_) => <int>[], growable: false);
    for (var i = 0; i < p.nPaths; i++) {
      final w = p.pathWord(i);
      if (w >= 0 && w < out.length) out[w].add(i);
    }
    return wordPaths = out;
  }

  void attach(QvpPage p) {
    if (page == p) return;
    page = p;
    paths = null;
    wordPaths = null;
    pathBounds = null;
    linePaths = null;
    key = '';
    _dropImage();
  }

  void _dropImage() {
    image?.dispose();
    image = null;
    picture?.dispose();
    picture = null;
    for (final line in lines.values) {
      line.dispose();
    }
    lines.clear();
  }

  void dispose() {
    _dropImage();
    paths = null;
    page = null;
  }

  List<ui.Path> buildPaths(QvpPage p) {
    final cached = paths;
    if (cached != null) return cached;
    final t = p.table, ops = p.ops, pts = p.pts;
    final out = List<ui.Path>.generate(p.nPaths, (i) {
      final path = ui.Path();
      path.fillType = p.pathEvenOdd(i)
          ? PathFillType.evenOdd
          : PathFillType.nonZero;
      var o = t[i * 8];
      final oe = o + t[i * 8 + 1];
      var k = t[i * 8 + 2];
      for (; o < oe; o++) {
        switch (ops[o]) {
          case QvpOp.moveTo:
            path.moveTo(pts[k], pts[k + 1]);
            k += 2;
          case QvpOp.lineTo:
            path.lineTo(pts[k], pts[k + 1]);
            k += 2;
          case QvpOp.quadTo:
            path.quadraticBezierTo(pts[k], pts[k + 1], pts[k + 2], pts[k + 3]);
            k += 4;
          case QvpOp.cubicTo:
            path.cubicTo(
              pts[k],
              pts[k + 1],
              pts[k + 2],
              pts[k + 3],
              pts[k + 4],
              pts[k + 5],
            );
            k += 6;
          case QvpOp.close:
            path.close();
        }
      }
      return path;
    }, growable: false);
    return paths = out;
  }
}

/// Tahfeez patch 0006: one line's ink, rasterised, where it sits on the
/// canvas.
class _LineImage {
  _LineImage(this.key, this.rect, this.image, this.picture);

  final String key;
  final Rect rect;
  final ui.Image? image;
  final ui.Picture? picture;

  void dispose() {
    image?.dispose();
    picture?.dispose();
  }
}

class _QvpPainter extends CustomPainter {
  _QvpPainter({
    required this.page,
    required this.view,
    required ValueListenable<int> frame,
    required this.cache,
    required this.dpr,
    required this.paper,
    required this.paperShadow,
    this.effects,
  }) : super(repaint: Listenable.merge([page, view, frame]));

  final QvpPage page;
  final QvpViewController view;
  final _InkCache cache;
  final double dpr;
  final Color? paper;
  final bool paperShadow;
  final QvpWordEffects? effects;

  /// Tahfeez patch 0005: the running effects of one kind at [now], with
  /// each one's progress (0 → 1); those still waiting to start left out.
  Iterable<(QvpWordEffect, double)> _running(
    List<QvpWordEffect> all,
    QvpWordEffectKind kind,
    double now,
  ) sync* {
    for (final e in all) {
      if (e.kind != kind || now < e.startMs) continue;
      yield (e, ((now - e.startMs) / e.durationMs).clamp(0.0, 1.0));
    }
  }

  /// Tahfeez patch 0005: [word]'s paths drawn with [paint], each at its
  /// line's transform.
  void _drawWord(
    ui.Canvas canvas,
    QvpLayout? l,
    List<ui.Path> paths,
    int word,
    ui.Paint paint, {
    double blurPx = 0,
  }) {
    final wordPaths = cache.buildWordPaths(page);
    if (word < 0 || word >= wordPaths.length) return;
    for (final i in wordPaths[word]) {
      final (s, tx, ty) = _lineTf(l, page.pathLine(i));
      if (blurPx > 0) {
        paint.maskFilter = ui.MaskFilter.blur(BlurStyle.normal, blurPx / s);
      }
      canvas.save();
      canvas.translate(tx, ty);
      canvas.scale(s);
      canvas.drawPath(paths[i], paint);
      canvas.restore();
    }
  }

  /// Tahfeez patch 0005: [word]'s bounds on the canvas.
  Rect? _wordBounds(QvpLayout? l, List<ui.Path> paths, int word) {
    final wordPaths = cache.buildWordPaths(page);
    if (word < 0 || word >= wordPaths.length) return null;
    Rect? out;
    final bounds = cache.pathBounds ??= List<Rect?>.filled(paths.length, null);
    for (final i in wordPaths[word]) {
      final (s, tx, ty) = _lineTf(l, page.pathLine(i));
      final b = bounds[i] ??= paths[i].getBounds();
      final r = Rect.fromLTRB(
        tx + b.left * s,
        ty + b.top * s,
        tx + b.right * s,
        ty + b.bottom * s,
      );
      out = out == null ? r : out.expandToInclude(r);
    }
    return out;
  }

  /// Transform of one line: (scale, tx, ty) in logical px.
  (double, double, double) _lineTf(QvpLayout? l, int line) {
    final ls = l?.scale ?? 1, lox = l?.offsetX ?? 0, loy = l?.offsetY ?? 0;
    final dy = l != null && line < l.lineDy.length ? l.lineDy[line] : 0.0;
    return (
      view.scale * ls,
      view.offsetX + view.scale * lox,
      view.offsetY + view.scale * (loy + dy * ls),
    );
  }

  /// Tahfeez patch 0006: [ids] (one line's paths) drawn into an image of
  /// just that line's area — each in its colour, or the page's [ink]; the
  /// hidden (transparent) and the swaying ([shakes]) left out.
  _LineImage _rasterLine(
    QvpLayout? l,
    List<ui.Path> paths,
    List<Rect?> bounds,
    List<int> ids,
    Map<int, int> colorOf,
    Map<int, double> shakes,
    int ink,
    Size size,
    String key,
  ) {
    final (s, tx, ty) = _lineTf(l, page.pathLine(ids.first));
    Rect? area;
    for (final i in ids) {
      final b = bounds[i] ??= paths[i].getBounds();
      final r = Rect.fromLTRB(
        tx + b.left * s,
        ty + b.top * s,
        tx + b.right * s,
        ty + b.bottom * s,
      );
      area = area == null ? r : area.expandToInclude(r);
    }
    final rect = area!.inflate(2).intersect(Offset.zero & size);
    if (rect.isEmpty) return _LineImage(key, rect, null, null);
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.scale(dpr);
    c.translate(-rect.left, -rect.top);
    c.translate(tx, ty);
    c.scale(s);
    final paint = ui.Paint()..isAntiAlias = true;
    for (final i in ids) {
      final color = colorOf[i] ?? ink;
      if ((color & 0xff) == 0) continue;
      if (shakes.isNotEmpty && shakes.containsKey(page.pathWord(i))) continue;
      paint.color = QvpColor.toColor(color);
      c.drawPath(paths[i], paint);
    }
    final pic = rec.endRecording();
    try {
      final img = pic.toImageSync(
        (rect.width * dpr).ceil().clamp(1, 1 << 14),
        (rect.height * dpr).ceil().clamp(1, 1 << 14),
      );
      pic.dispose();
      return _LineImage(key, rect, img, null);
    } catch (_) {
      // No GPU image available: replay the picture, placed.
      final placed = ui.PictureRecorder();
      ui.Canvas(placed)
        ..translate(rect.left, rect.top)
        ..scale(1 / dpr)
        ..drawPicture(pic);
      return _LineImage(key, rect, null, placed.endRecording());
    }
  }

  void _drawBoxes(ui.Canvas c, List<QvpBox> boxes, {QvpLayout? layout}) {
    final slots = layout?.slots;
    // Tahfeez patch 0003: the ayah marks per line, in layout px — a
    // slot-filling box beside one (a mark hanging at the line's end, say)
    // takes it in.
    final marks = <int, List<(double, double)>>{};
    if (layout != null && page.slotFillHighlights.isNotEmpty) {
      for (final d in page.decorations) {
        if (d.decoration != QvpDecorationKind.ayahMark) continue;
        (marks[d.line] ??= []).add((
          layout.offsetX + d.x0 * layout.scale,
          layout.offsetX + d.x1 * layout.scale,
        ));
      }
    }
    if (boxes.isEmpty) return;
    c.save();
    c.translate(view.offsetX, view.offsetY);
    c.scale(view.scale);
    ui.Path? cur;
    var id = -1, col = 0;
    final paint = ui.Paint()..isAntiAlias = true;
    void flush() {
      if (cur != null) {
        paint.color = QvpColor.toColor(col);
        c.drawPath(cur!, paint);
        cur = null;
      }
    }

    for (final b in boxes) {
      if (cur == null || b.id != id || b.color != col) {
        flush();
        cur = ui.Path()..fillType = PathFillType.nonZero;
        id = b.id;
        col = b.color;
      }
      // Tahfeez patch 0003: a slot-filling highlight's box spans its
      // line's whole slot.
      final slot =
          slots != null &&
              page.slotFillHighlights.contains(b.id) &&
              b.line >= 0 &&
              b.line < slots.length
          ? slots[b.line]
          : null;
      var x0 = b.x0, x1 = b.x1;
      if (slot != null) {
        for (final (m0, m1) in marks[b.line] ?? const <(double, double)>[]) {
          // At the box's left edge (within a mark's width): its own
          // ayah's end — the Mushaf reads right to left, so an ayah's mark
          // follows it on the left. A mark at the box's right edge ends
          // the passage before and stays that one's.
          final w = m1 - m0;
          if (m1 >= x0 - w && m1 <= x0 + w) {
            x0 = x0 < m0 ? x0 : m0;
          }
        }
      }
      final r = slot == null
          ? Rect.fromLTRB(b.x0, b.y0, b.x1, b.y1)
          : Rect.fromLTRB(x0, slot.$1, x1, slot.$2);
      if (b.radius > 0) {
        cur!.addRRect(RRect.fromRectAndRadius(r, Radius.circular(b.radius)));
      } else {
        cur!.addRect(r);
      }
    }
    flush();
    c.restore();
  }

  @override
  void paint(ui.Canvas canvas, Size size) {
    if (page.isDisposed) return;
    final paths = cache.buildPaths(page);
    final l = page.currentLayout;
    final styled = page.styledPaths();
    final ink = page.defaultInk;

    // paper
    final paperColor = paper;
    if (paperColor != null) {
      final rect = Rect.fromLTWH(
        view.offsetX,
        view.offsetY,
        (l?.contentW ?? page.width) * view.scale,
        (l?.contentH ?? page.height) * view.scale,
      );
      if (paperShadow)
        canvas.drawShadow(
          ui.Path()..addRect(rect),
          const Color(0x66000000),
          6,
          false,
        );
      canvas.drawRect(rect, ui.Paint()..color = paperColor);
    }

    final sw = Stopwatch()..start();
    // 1. highlight bands (behind the ink)
    final bands = page.highlightBoxesView();
    _drawBoxes(canvas, bands, layout: l);

    // Tahfeez patch 0005: word glows, behind the ink — spreading as they
    // fade.
    final now = QvpWordEffects.nowMs;
    final fx = effects?.runningAt(now) ?? const <QvpWordEffect>[];
    final shakes = <int, double>{};
    if (fx.isNotEmpty) {
      for (final (e, t) in _running(fx, QvpWordEffectKind.bloom, now)) {
        // Rising fast, then fading: a soft halo behind the whole word…
        final rise = t < 0.15 ? t / 0.15 : 1.0;
        final fade = rise * (1 - t);
        final r = e.halo ? _wordBounds(l, paths, e.word) : null;
        if (r != null) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              r.inflate(3 + 5 * t),
              Radius.circular(r.height / 2),
            ),
            ui.Paint()
              ..color = e.color.withValues(alpha: e.color.a * 0.32 * fade)
              ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 6),
          );
        }
      }
      // …and a glow around its letters, spreading (Tahfeez patch 0006): the
      // words glowing together blurred together — a few blur passes for a
      // whole page's glow (in three steps of its spread), not one a word.
      final letters = [
        for (final (e, t) in _running(fx, QvpWordEffectKind.bloom, now))
          if (e.letters) (e, t),
      ];
      for (var step = 0; step < 3 && letters.isNotEmpty; step++) {
        final these = [
          for (final (e, t) in letters)
            if (math.min((t * 3).floor(), 2) == step) (e, t),
        ];
        if (these.isEmpty) continue;
        final sigma = 4 + 10 * (step + 0.5) / 3;
        Rect? area;
        for (final (e, _) in these) {
          final r = _wordBounds(l, paths, e.word);
          if (r != null) area = area == null ? r : area.expandToInclude(r);
        }
        if (area == null) continue;
        canvas.saveLayer(
          area.inflate(sigma * 3),
          ui.Paint()
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        );
        for (final (e, t) in these) {
          final rise = t < 0.15 ? t / 0.15 : 1.0;
          final fade = rise * (1 - t);
          final glow = ui.Paint()
            ..isAntiAlias = true
            ..color = e.color.withValues(alpha: e.color.a * 0.9 * fade);
          _drawWord(canvas, l, paths, e.word, glow);
        }
        canvas.restore();
      }
      for (final (e, t) in _running(fx, QvpWordEffectKind.shake, now)) {
        shakes[e.word] = math.sin(t * math.pi * 6) * (1 - t) * 3.5;
      }
    }

    // 2. the ink, line by line (Tahfeez patch 0006): each line's words in
    // their colours (a hidden word's transparent ink left out), as an
    // image rebuilt only when something on that line changes — a recited
    // word recolours one line, not the page; a swaying word drawn live.
    final colorOf = <int, int>{for (final s in styled) s.path: s.color};
    final lines = cache.buildLinePaths(page);
    final tkey =
        '${view.scale.toStringAsFixed(5)}|${view.offsetX.toStringAsFixed(2)}|${view.offsetY.toStringAsFixed(2)}|$dpr|$ink|${identityHashCode(l)}|${size.width}x${size.height}';
    final bounds = cache.pathBounds ??= List<Rect?>.filled(paths.length, null);
    final baseSw = Stopwatch()..start();
    var rebuilt = 0;
    for (var ln = 0; ln < lines.length; ln++) {
      final ids = lines[ln];
      if (ids.isEmpty) continue;
      final sig = StringBuffer(tkey);
      for (final i in ids) {
        final c = colorOf[i];
        if (c != null) sig.write(',$i:$c');
        if (shakes.isNotEmpty && shakes.containsKey(page.pathWord(i))) {
          sig.write(',$i~');
        }
      }
      final key = sig.toString();
      var line = cache.lines[ln];
      if (line == null || line.key != key) {
        line?.dispose();
        line = _rasterLine(
          l,
          paths,
          bounds,
          ids,
          colorOf,
          shakes,
          ink,
          size,
          key,
        );
        cache.lines[ln] = line;
        rebuilt++;
      }
      final img = line.image;
      if (img != null) {
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          line.rect,
          ui.Paint()..filterQuality = FilterQuality.none,
        );
      } else if (line.picture != null) {
        canvas.drawPicture(line.picture!);
      }
    }
    if (rebuilt > 0) {
      cache.basePaths = rebuilt;
      cache.baseMs = baseSw.elapsedMicroseconds / 1000;
    }

    // Tahfeez patch 0005: a shaking word's ink, swayed sideways.
    if (shakes.isNotEmpty) {
      final paint = ui.Paint()..isAntiAlias = true;
      final wordPaths = cache.buildWordPaths(page);
      for (final MapEntry(key: word, value: dx) in shakes.entries) {
        if (word < 0 || word >= wordPaths.length) continue;
        for (final i in wordPaths[word]) {
          final c = colorOf[i] ?? ink;
          if ((c & 0xff) == 0) continue;
          paint.color = QvpColor.toColor(c);
          final (sc, tx, ty) = _lineTf(l, page.pathLine(i));
          canvas.save();
          canvas.translate(tx + dx, ty);
          canvas.scale(sc);
          canvas.drawPath(paths[i], paint);
          canvas.restore();
        }
      }
    }

    // Tahfeez patch 0005: ink fading in — the paper over the word, fading
    // out — or fading out, the paper over it fading in.
    if (fx.isNotEmpty && paperColor != null) {
      for (final (e, t) in _running(fx, QvpWordEffectKind.inkOut, now)) {
        final r = _wordBounds(l, paths, e.word);
        if (r == null) continue;
        final p = (t * 460 / 400).clamp(0.0, 1.0);
        canvas.drawRect(
          r.inflate(1.5),
          ui.Paint()..color = paperColor.withValues(alpha: p * p * (3 - 2 * p)),
        );
      }
      for (final (e, t) in _running(fx, QvpWordEffectKind.inkIn, now)) {
        final r = _wordBounds(l, paths, e.word);
        if (r == null) continue;
        // The same curve as inkOut, mirrored: the two fades match.
        final ease = t * t * (3 - 2 * t);
        canvas.drawRect(
          r.inflate(1.5),
          ui.Paint()..color = paperColor.withValues(alpha: 1 - ease),
        );
      }
    }

    // 4. mask boxes (block / blur) on top
    _drawBoxes(canvas, page.maskBoxesView());
    cache.overlayMs = sw.elapsedMicroseconds / 1000;
    cache.overlayPaths = styled.length;
    cache.bands = bands.length;
  }

  @override
  bool shouldRepaint(_QvpPainter old) =>
      old.page != page ||
      old.view != view ||
      old.dpr != dpr ||
      old.paper != paper ||
      old.paperShadow != paperShadow ||
      old.cache != cache ||
      old.effects != effects;
}

/// Render statistics of a [QvpPageView] (base / overlay timings of the last frame).
extension QvpPageViewStats on QvpPageViewState {
  ({
    int basePaths,
    double baseMs,
    int overlayPaths,
    double overlayMs,
    int bands,
  })
  get stats => (
    basePaths: _cache.basePaths,
    baseMs: _cache.baseMs,
    overlayPaths: _cache.overlayPaths,
    overlayMs: _cache.overlayMs,
    bands: _cache.bands,
  );
}
