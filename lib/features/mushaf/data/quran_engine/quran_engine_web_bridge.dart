import 'dart:math' as math;
// Web-only file (imports `dart:js_interop` and `package:web`) — never
// imported from platform-shared code; only `quran_engine_web_backend.dart`
// (itself only constructed on Web, see
// `../../application/mushaf_quran_engine_providers.dart`) touches this.
//
// A dedicated JS-interop bridge to the pinned, vendored `qvp.js` +
// `qvp_ffi.wasm` (`tool/quran_engine/fetch_web_runtime.sh`), so no
// `dart:js_interop` call is scattered through UI code. Promoted from the
// `poc/quran-engine` branch's evaluation
// (`docs/poc/QURAN_ENGINE_POC.md`) — deliberately kept low-level and
// engine-native (numeric word indices, not Tahfeez `WordRef`/`VerseRef`):
// `QuranEngineWebBackend` is the one place engine-native values are
// translated to/from Tahfeez's canonical types via `QuranEngineRefAdapter`,
// exactly mirroring how `QuranEngineAndroidBackend` treats `qvp_flutter`.
//
// Scope note, unchanged from the POC: this implements load, fit-render,
// tap hit-test, and highlight/mask/reveal — not `web/app.js`'s own
// pan/zoom/drag-selection pointer handling.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import '../../../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../domain/quran_engine/quran_engine_mushaf_backend.dart'
    show PageBand;

/// `window.QVP`, read via `getProperty` rather than a top-level `@JS('QVP')
/// external` getter — the latter produced a bare, stack-trace-free
/// `NoSuchMethodError` at runtime in the POC (caught by actually running
/// this in Chrome, not by `flutter analyze`). `getProperty` on
/// `web.window` is the verified-working way to reach an arbitrary JS
/// global from `dart:js_interop`.
JSObject? get _qvpGlobal => web.window.getProperty('QVP'.toJS) as JSObject?;

/// True once `web/quran_engine/qvp.js` has been injected and executed
/// (idempotent — safe to call [QuranEngineWebBridge.ensureScriptLoaded]
/// more than once across multiple page loads in the same session).
bool _scriptInjected = false;

class QuranEngineWebBridge {
  QuranEngineWebBridge._(this._engine);

  final JSObject _engine;

  static Future<void> ensureScriptLoaded() {
    if (_scriptInjected || _qvpGlobal != null) {
      _scriptInjected = true;
      return Future.value();
    }
    final completer = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = 'quran_engine/qvp.js'
      ..type = 'text/javascript';
    script.onLoad.listen((_) {
      _scriptInjected = true;
      completer.complete();
    });
    script.onError.listen((_) {
      completer.completeError(
        StateError(
          'Failed to load quran_engine/qvp.js — is it present under '
          'web/quran_engine/ (tool/quran_engine/fetch_web_runtime.sh)?',
        ),
      );
    });
    web.document.head!.appendChild(script);
    return completer.future;
  }

  /// Fetches the vendored WASM bytes and initializes the engine —
  /// `QVP.QvpEngine.init(wasmBytes)` in JS, per `web/app.js`'s own
  /// startup sequence. The WASM binary itself is always same-origin
  /// (served alongside the Flutter app from `web/quran_engine/`), unlike
  /// page data, which may come from a separately configured base URL —
  /// see `QuranEngineWebBackend`.
  static Future<QuranEngineWebBridge> initialize() async {
    await ensureScriptLoaded();
    final qvp = _qvpGlobal;
    if (qvp == null) {
      throw StateError('window.QVP is not defined after loading qvp.js.');
    }
    final response = await web.window
        .fetch('quran_engine/qvp_ffi.wasm'.toJS)
        .toDart;
    final buffer = await response.arrayBuffer().toDart;
    final wasmBytes = buffer.toDart.asUint8List();

    final engineCtor = qvp.getProperty('QvpEngine'.toJS) as JSObject;
    final enginePromise =
        engineCtor.callMethod('init'.toJS, wasmBytes.toJS) as JSPromise;
    final engine = await enginePromise.toDart as JSObject;
    return QuranEngineWebBridge._(engine);
  }

  /// `qvp.js`'s `QvpEngine` class exposes no name/version accessor at all
  /// (confirmed by reading the vendored source directly). A static,
  /// honest label, not a value read from the engine.
  String get engineVersionInfo => 'Quran Engine (Web/WASM)';

  /// `engine.loadPage(bytes); page.buildPaths();` — the exact two-call
  /// sequence `web/app.js`'s own `loadPage()` uses.
  QuranEngineWebPage loadPage(Uint8List bytes) {
    final page = _engine.callMethod('loadPage'.toJS, bytes.toJS) as JSObject;
    page.callMethod('buildPaths'.toJS);
    return QuranEngineWebPage._(page, _qvpGlobal!);
  }
}

/// A canvas element + `CanvasRenderer`, registered as a Flutter Web
/// platform view (`ui_web.platformViewRegistry`) so a Flutter widget can
/// host it. One instance per loaded page.
class QuranEngineWebPage {
  QuranEngineWebPage._(this._page, this._qvp) {
    _viewType = 'quran-engine-canvas-${_nextViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final canvas = web.HTMLCanvasElement()
        ..style.width = '100%'
        ..style.height = '100%';
      _canvas = canvas;
      if (_paperColorCss != null) {
        canvas.style.backgroundColor = _paperColorCss!;
      }
      // Flutter Web's `HtmlElementView` does not forward pointer events to
      // a wrapping `GestureDetector` (confirmed the hard way during the
      // POC) — listening on the canvas itself, in JS, is the correct
      // approach for a platform-view-hosted element, not a fallback.
      // `offsetX`/`offsetY` are already in the same CSS-pixel,
      // element-local coordinate space `hitTest`/`renderFit` use.
      canvas.addEventListener(
        'click',
        (web.MouseEvent event) {
          // A real, reproduced bug: this canvas has its own native DOM
          // click listener (see the comment above), which Flutter's own
          // modal-barrier hit-testing does not reliably suppress while a
          // sheet (e.g. the Mushaf appearance sheet) is open or has just
          // closed above it — the same physical click that selects an
          // appearance option or dismisses the sheet could also reach
          // here and open the word-detail popup. Ignored while any
          // Tahfeez modal sheet is active, plus a short cooldown after it
          // closes (`TahfeezModalSheetActivity`).
          if (TahfeezModalSheetActivity.isActive) return;
          // (The end of a long press: its ayah opened, not the word too.)
          if (_longPressed) {
            _longPressed = false;
            return;
          }
          _onTap?.call(event.offsetX.toDouble(), event.offsetY.toDouble());
        }.toJS,
      );
      // A long press, as on the phones (the word's ayah): a right-click or
      // a long touch (the browser's "contextmenu"; its own menu not shown),
      // or the mouse held down half a second.
      void longPress(double x, double y) {
        if (TahfeezModalSheetActivity.isActive) return;
        _longPressed = true;
        _onLongPress?.call(x, y);
      }

      canvas.addEventListener(
        'contextmenu',
        (web.MouseEvent event) {
          event.preventDefault();
          _holdTimer?.cancel();
          if (_longPressed) return;
          longPress(event.offsetX.toDouble(), event.offsetY.toDouble());
          // (A right-click has no click after it.)
          _longPressed = false;
        }.toJS,
      );
      canvas.addEventListener(
        'pointerdown',
        (web.PointerEvent event) {
          _longPressed = false;
          _holdTimer?.cancel();
          if (event.pointerType != 'mouse' || event.button != 0) return;
          final x = event.offsetX.toDouble(), y = event.offsetY.toDouble();
          _holdAt = (x, y);
          _holdTimer = Timer(
            const Duration(milliseconds: 500),
            () => longPress(x, y),
          );
        }.toJS,
      );
      void endHold(web.PointerEvent event) => _holdTimer?.cancel();
      canvas.addEventListener('pointerup', endHold.toJS);
      canvas.addEventListener('pointerleave', endHold.toJS);
      // The mouse over the page: what is under it (a marked word's hand
      // pointer and tooltip — `setHoverHint`); off it, nothing.
      canvas.addEventListener(
        'pointermove',
        (web.PointerEvent event) {
          if (event.pointerType != 'mouse' || event.buttons != 0) return;
          _onHover?.call(event.offsetX.toDouble(), event.offsetY.toDouble());
        }.toJS,
      );
      canvas.addEventListener(
        'pointerleave',
        ((web.PointerEvent event) => _onHover?.call(null, null)).toJS,
      );
      canvas.addEventListener(
        'pointermove',
        (web.PointerEvent event) {
          final at = _holdAt;
          if (at == null || _holdTimer?.isActive != true) return;
          final dx = event.offsetX - at.$1, dy = event.offsetY - at.$2;
          // Moved (a drag, a page turn): not a long press.
          if (dx * dx + dy * dy > 64) _holdTimer?.cancel();
        }.toJS,
      );
      // Real production testing (not the POC's simpler standalone screen)
      // surfaced a genuine race: platform-view creation in Flutter Web is
      // asynchronous relative to the widget tree's own frame callbacks —
      // a `renderFit` call arriving before this factory has run found
      // `_canvas == null`, returned silently, and was never retried,
      // leaving a permanently blank canvas with only its CSS background
      // visible. Re-applying any pending render here — the same "safe to
      // call early, applied lazily once the canvas exists" pattern
      // [paperColorCss] already used — closes that race instead of
      // requiring some other, unrelated rebuild to paper over it.
      final pending = _pendingRender;
      if (pending != null) pending();
      return canvas;
    });
  }

  static int _nextViewId = 0;

  final JSObject _page;
  final JSObject _qvp;
  late final String _viewType;
  web.HTMLCanvasElement? _canvas;
  void Function(double x, double y)? _onTap;
  void Function(double x, double y)? _onLongPress;
  void Function(double? x, double? y)? _onHover;
  String? _hoverHint;
  Timer? _holdTimer;
  (double, double)? _holdAt;
  bool _longPressed = false;
  String? _paperColorCss;
  void Function()? _pendingRender;

  set onTap(void Function(double x, double y)? handler) => _onTap = handler;

  set onLongPress(void Function(double x, double y)? handler) =>
      _onLongPress = handler;

  /// The mouse moving over the page (`null, null`: it left).
  set onHover(void Function(double? x, double? y)? handler) =>
      _onHover = handler;

  /// The hand pointer and [hint] as the page's tooltip (a word under the
  /// mouse that opens something); `null`: the plain pointer, no tooltip.
  void setHoverHint(String? hint) {
    final canvas = _canvas;
    if (canvas == null || hint == _hoverHint) return;
    _hoverHint = hint;
    canvas.style.cursor = hint == null ? '' : 'pointer';
    canvas.title = hint ?? '';
  }

  /// Sets the canvas element's own CSS background — the "paper" behind
  /// the engine's ink, since `CanvasRenderer.draw` itself never fills a
  /// background (confirmed against the real source). Safe to call before
  /// the platform view's factory has run; applied lazily once it has.
  set paperColorCss(String css) {
    _paperColorCss = css;
    _canvas?.style.backgroundColor = css;
  }

  String get viewType => _viewType;

  double get width =>
      (_page.getProperty('width'.toJS) as JSNumber).toDartDouble;
  double get height =>
      (_page.getProperty('height'.toJS) as JSNumber).toDartDouble;

  /// Renders the page fit-to-[size] at [devicePixelRatio] — a one-shot
  /// fit-and-draw (no interactive pan/zoom state), matching this bridge's
  /// documented scope. [inkColorInt] is `qvp.js`'s own `rgba()` 0xRRGGBBAA
  /// integer form (see `QuranEngineRefAdapter`-adjacent color conversion
  /// in `QuranEngineWebBackend`), applied via `page.setDefaultInk`.
  void renderFit(
    double widthPx,
    double heightPx,
    double devicePixelRatio,
    int inkColorInt,
  ) {
    _lastRender = () =>
        renderFit(widthPx, heightPx, devicePixelRatio, inkColorInt);
    final canvas = _canvas;
    if (canvas == null) {
      // The platform view hasn't mounted yet — save these params and
      // paint as soon as it does (see the factory callback above), rather
      // than silently dropping this frame's render request forever.
      _pendingRender = () =>
          renderFit(widthPx, heightPx, devicePixelRatio, inkColorInt);
      return;
    }
    _pendingRender = null;
    // Browser zoom and Flutter layout can hand platform views fractional
    // CSS-pixel sizes. If the backing canvas rounds those dimensions down
    // but the renderer still computes its fit against the larger fractional
    // box, the outer page art can be clipped by a pixel or more. Allocate
    // enough backing pixels, then render against the exact logical size that
    // backing store represents.
    canvas.width = (widthPx * devicePixelRatio).ceil();
    canvas.height = (heightPx * devicePixelRatio).ceil();
    final renderWidthPx = canvas.width / devicePixelRatio;
    final renderHeightPx = canvas.height / devicePixelRatio;
    // Pin the canvas element's on-screen (CSS) size to the widget's layout
    // box. The factory already sets `style.width/height: 100%`, which is
    // identical *if* Flutter Web places the platform view at exactly the
    // widget's size -- but HtmlElementView placement at devicePixelRatio
    // != 1 is a known source of mismatch, and a canvas rendered larger
    // than its layout slot spills past the page frame and the spread's
    // edges (visible as "page art cut at the sides", reachable by pan/
    // scroll). Stating the size in pixels makes it impossible for the DOM
    // canvas to display anything other than the exact box the layout gave.
    canvas.style.width = '${widthPx.toStringAsFixed(2)}px';
    canvas.style.height = '${heightPx.toStringAsFixed(2)}px';

    _page.callMethod('setDefaultInk'.toJS, inkColorInt.toJS);

    var scale = (renderHeightPx / height).clamp(0.0, renderWidthPx / width);
    var ox = (renderWidthPx - width * scale) / 2;
    var oy = (renderHeightPx - height * scale) / 2;
    if (textZoom != 1.0) {
      // Scale the drawing about the artwork's own center, so the text grows
      // in place. The page box/frame is unchanged; the artwork on these
      // pages is small enough that the zoomed text stays inside it.
      final c = _artworkCenter();
      if (c != null) {
        final cx = ox + c.x * scale, cy = oy + c.y * scale;
        scale *= textZoom;
        ox = cx - c.x * scale;
        oy = cy - c.y * scale;
      }
    }
    _lastView = (scale: scale, ox: ox, oy: oy);

    final rendererCtor = _qvp.getProperty('CanvasRenderer'.toJS) as JSFunction;
    final renderer = rendererCtor.callAsConstructor<JSObject>(canvas);
    final viewObj = JSObject()
      ..setProperty('scale'.toJS, scale.toJS)
      ..setProperty('ox'.toJS, ox.toJS)
      ..setProperty('oy'.toJS, oy.toJS);
    renderer.callMethod('draw'.toJS, _page, viewObj, devicePixelRatio.toJS);
    _renderer = renderer;
    _view = viewObj;
    _dpr = devicePixelRatio;
    _paintEffects(web.window.performance.now());
  }

  // ── Word effects (the phones' qvp_flutter ones, drawn over the canvas) ──

  JSObject? _renderer, _view;
  double _dpr = 1;
  final _effects = <_WordEffect>[];
  var _animating = false;

  /// Each word's ink boxes (page units, one per line it spans).
  late final Map<
    int,
    List<({int line, double x0, double y0, double x1, double y1})>
  >
  _wordBoxes = () {
    final out =
        <int, List<({int line, double x0, double y0, double x1, double y1})>>{};
    final boxes =
        (_page.callMethod('hitBoxes'.toJS) as JSArray<JSObject>).toDart;
    double n(JSObject b, String k) =>
        (b.getProperty<JSNumber>(k.toJS)).toDartDouble;
    for (final b in boxes) {
      (out[n(b, 'word').toInt()] ??= []).add((
        line: n(b, 'line').toInt(),
        x0: n(b, 'inkX0'),
        y0: n(b, 'inkY0'),
        x1: n(b, 'inkX1'),
        y1: n(b, 'inkY1'),
      ));
    }
    return out;
  }();

  /// Plays [kind] (`bloom`, `shake`, `inkIn`, `inkOut`) on page word
  /// [wordIndex] in [rgba] (0xRRGGBBAA), after [delayMs].
  void playEffect(String kind, int wordIndex, int rgba, double delayMs) {
    final start = web.window.performance.now() + delayMs;
    _effects
      ..removeWhere((e) => e.word == wordIndex && e.kind == kind)
      ..add(_WordEffect(kind, wordIndex, rgba, start));
    if (_animating) return;
    _animating = true;
    void frame(JSNumber _) {
      final now = web.window.performance.now();
      _effects.removeWhere((e) => now > e.start + e.duration);
      _drawFrame(now);
      if (_effects.isEmpty) {
        _animating = false;
        return;
      }
      web.window.requestAnimationFrame(frame.toJS);
    }

    web.window.requestAnimationFrame(frame.toJS);
  }

  void _drawFrame(double now) {
    final renderer = _renderer, view = _view;
    if (renderer == null || view == null || _canvas == null) return;
    renderer.callMethod('draw'.toJS, _page, view, _dpr.toJS);
    _paintEffects(now);
  }

  void _paintEffects(double now) {
    final canvas = _canvas, renderer = _renderer, view = _view;
    if (_effects.isEmpty || canvas == null || renderer == null) return;
    final c = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    c.save();
    c.setTransform(1.toJS, 0, 0, 1, 0, 0);
    for (final e in _effects) {
      final t = (now - e.start) / e.duration;
      if (t < 0) {
        // Not started: a word about to fade in stays covered.
        if (e.kind == 'inkIn') _cover(c, renderer, view!, e.word, 1);
        continue;
      }
      final k = t.clamp(0.0, 1.0);
      switch (e.kind) {
        case 'inkIn':
          _cover(c, renderer, view!, e.word, 1 - _ease(k));
        case 'inkOut':
          // To the paper in 400 of its 460 ms, then held.
          _cover(
            c,
            renderer,
            view!,
            e.word,
            _ease((k * 460 / 400).clamp(0, 1)),
          );
        case 'bloom':
          _band(c, renderer, view!, e, 0.45 * (1 - k), 2 + 6 * k);
        case 'shake':
          _band(
            c,
            renderer,
            view!,
            e,
            0.4 * (1 - k) * (0.6 + 0.4 * math.sin(k * math.pi * 6).abs()),
            2,
          );
      }
    }
    c.restore();
  }

  static double _ease(double t) => t * t * (3 - 2 * t);

  /// The word's boxes in canvas pixels, grown by [pad] CSS pixels.
  Iterable<({double x, double y, double w, double h})> _rects(
    JSObject renderer,
    JSObject view,
    int word,
    double pad,
  ) sync* {
    for (final b
        in _wordBoxes[word] ??
            const <
              ({int line, double x0, double y0, double x1, double y1})
            >[]) {
      final tf = (renderer.callMethod(
        'lineTransform'.toJS,
        _page,
        view,
        b.line.toJS,
        _dpr.toJS,
      ) as JSArray<JSNumber>).toDart;
      final scale = tf[0].toDartDouble, tx = tf[1].toDartDouble;
      final ty = tf[2].toDartDouble, p = pad * _dpr;
      yield (
        x: tx + b.x0 * scale - p,
        y: ty + b.y0 * scale - p,
        w: (b.x1 - b.x0) * scale + 2 * p,
        h: (b.y1 - b.y0) * scale + 2 * p,
      );
    }
  }

  /// The paper over the word's ink, [alpha] opaque.
  void _cover(
    web.CanvasRenderingContext2D c,
    JSObject renderer,
    JSObject view,
    int word,
    double alpha,
  ) {
    if (alpha <= 0) return;
    c.globalAlpha = alpha;
    c.globalCompositeOperation = 'source-over';
    c.fillStyle = (_paperColorCss ?? '#ffffff').toJS;
    for (final r in _rects(renderer, view, word, 1.5)) {
      c.fillRect(r.x, r.y, r.w, r.h);
    }
    c.globalAlpha = 1;
  }

  /// A soft band of the effect's colour behind the word's ink.
  void _band(
    web.CanvasRenderingContext2D c,
    JSObject renderer,
    JSObject view,
    _WordEffect e,
    double alpha,
    double pad,
  ) {
    if (alpha <= 0) return;
    final rgba = e.rgba;
    c.globalAlpha = alpha;
    // Behind what is drawn: the ink stays on top.
    c.globalCompositeOperation = 'destination-over';
    c.fillStyle =
        'rgb(${(rgba >> 24) & 0xff}, ${(rgba >> 16) & 0xff}, ${(rgba >> 8) & 0xff})'
            .toJS;
    for (final r in _rects(renderer, view, e.word, pad)) {
      c.beginPath();
      c.roundRect(r.x, r.y, r.w, r.h, (4 * _dpr).toJS);
      c.fill();
    }
    c.globalAlpha = 1;
    c.globalCompositeOperation = 'source-over';
  }

  /// Extra uniform scale applied to the printed text only (not the frame)
  /// when rendering; 1.0 = none. Used for the short opening pages.
  double textZoom = 1.0;

  ({double x, double y})? _artworkCenter() {
    final t = _qvp.getProperty('T'.toJS) as JSObject;
    final target = t.callMethod('page'.toJS) as JSObject;
    final opts = JSObject()
      ..setProperty('pad'.toJS, 0.toJS)
      ..setProperty('keepAyahMarks'.toJS, true.toJS);
    final box = _page.callMethod('cropBox'.toJS, target, opts) as JSObject?;
    if (box == null) return null;
    double n(String k) => (box.getProperty(k.toJS) as JSNumber).toDartDouble;
    return (x: (n('x0') + n('x1')) / 2, y: (n('y0') + n('y1')) / 2);
  }

  ({double scale, double ox, double oy})? _lastView;

  /// Widget-local tap coordinates → the engine's own hit test
  /// (`page.hitTestViewEx`). `word`/`deco` are `-1` (the WASM `NONE`
  /// sentinel, matching `qvp.js`'s own `_hitEx`) when nothing of that kind
  /// was hit — a resolved word index can legitimately be `0`.
  ({int word, int deco, String? wordKey, int? surahBanner})? hitTest(
    double localX,
    double localY,
  ) {
    final view = _lastView;
    if (view == null) return null;
    final vx = (localX - view.ox) / view.scale;
    final vy = (localY - view.oy) / view.scale;
    final opts = JSObject()..setProperty('maxDistance'.toJS, 6.0.toJS);
    final hit = _page.callMethod(
      'hitTestViewEx'.toJS,
      vx.toJS,
      vy.toJS,
      opts,
    ) as JSObject?;
    if (hit == null) return null;
    final word = (hit.getProperty('word'.toJS) as JSNumber).toDartInt;
    final deco = (hit.getProperty('deco'.toJS) as JSNumber).toDartInt;
    final wordKeyJs = hit.getProperty('wordKey'.toJS) as JSString?;
    // A surah's name banner (`page.decos[i]`: kind 1, with its surah).
    int? surahBanner;
    if (deco >= 0) {
      final info = (_page.getProperty(
        'decos'.toJS,
      ) as JSArray?)?.toDart.elementAtOrNull(deco) as JSObject?;
      final kind = (info?.getProperty('kind'.toJS) as JSNumber?)?.toDartInt;
      final surah = (info?.getProperty('surah'.toJS) as JSNumber?)?.toDartInt;
      if (kind == 1 && surah != null && surah > 0) surahBanner = surah;
    }
    return (
      word: word,
      deco: deco,
      wordKey: wordKeyJs?.toDart,
      surahBanner: surahBanner,
    );
  }

  /// `page.findWord(surah, ayah, word)` — resolves a canonical
  /// `(surah, ayah, word-in-ayah)` triple to the engine's own page-local
  /// word-array index (what `T.word(i)` and a hit's own `word` field use),
  /// exactly the same role `QvpPage.findWord` plays on Android. Returns
  /// `-1` if not found on this page.
  int findWord(int surahNo, int ayahNo, int engineWordInAyah) {
    return (_page.callMethod(
      'findWord'.toJS,
      surahNo.toJS,
      ayahNo.toJS,
      engineWordInAyah.toJS,
    ) as JSNumber).toDartInt;
  }

  int highlightWord(int wordIndex, {String mode = 'band'}) =>
      _highlight(_wordTarget(wordIndex), mode);

  int highlightAyah(int surahNo, int ayahNo, {String mode = 'band'}) =>
      _highlight(_ayahTarget(surahNo, ayahNo), mode);

  int _highlight(JSObject target, String mode) {
    final style = JSObject()..setProperty('mode'.toJS, mode.toJS);
    final handle = (_page.callMethod(
      'highlight'.toJS,
      target,
      style,
    ) as JSNumber).toDartInt;
    // Painted now (the ayah playing, a long-pressed ayah), not at the next
    // render something else happens to cause.
    _redraw();
    return handle;
  }

  void clearHighlights() {
    _page.callMethod('clearHighlights'.toJS);
    _redraw();
  }

  /// (surah, ayah, 1-based word) of every page word, in engine order.
  late final List<(int, int, int)> wordKeys = [
    for (final w in (_page.getProperty<JSArray<JSObject>>('words'.toJS)).toDart)
      (
        (w.getProperty<JSNumber>('surah'.toJS)).toDartInt,
        (w.getProperty<JSNumber>('ayah'.toJS)).toDartInt,
        (w.getProperty<JSNumber>('word'.toJS)).toDartInt,
      ),
  ];

  /// See `QuranEngineMushafPage.setHiddenWords`.
  void setHiddenWords(Set<int> hidden) {
    _page.callMethod('unmask'.toJS);
    if (hidden.isNotEmpty) {
      final t = _qvp.getProperty('T'.toJS) as JSObject;
      _page.callMethod('mask'.toJS, t.callMethod('page'.toJS), 'hide'.toJS);
      for (var i = 0; i < wordKeys.length; i++) {
        if (!hidden.contains(i)) _page.callMethod('revealWord'.toJS, i.toJS);
      }
    }
    _redraw();
  }

  /// Replaces every highlight at once, with a single repaint: first each
  /// of [bands] as one seamless band over its words, then each word
  /// [rgba]-coloured (0xRRGGBBAA) as a band, or on its letters with `ink`.
  void setWordHighlights(
    List<({int word, int rgba, bool ink})> highlights, {
    List<({PageBand band, int rgba})> bands = const [],
  }) {
    _page.callMethod('clearHighlights'.toJS);
    final t = _qvp.getProperty('T'.toJS) as JSObject;
    // The line pitch, from the page's height and line count.
    final height = (_page.getProperty<JSNumber>('height'.toJS)).toDartDouble;
    final lines = (_page.getProperty<JSNumber>('nLines'.toJS)).toDartInt;
    final padY = height / (lines > 0 ? lines : 15) * PageBand.fill;
    for (final (:band, :rgba) in bands) {
      final style = JSObject()
        ..setProperty('mode'.toJS, 'band'.toJS)
        ..setProperty('band'.toJS, rgba.toJS)
        ..setProperty('padY'.toJS, padY.toJS);
      final target = band.isAyahs
          ? t.callMethod(
              'ayahRange'.toJS,
              band.surah.toJS,
              band.fromAyah.toJS,
              band.toAyah.toJS,
            )
          : t.callMethod(
              'words'.toJS,
              [for (final w in band.words) w.toJS].toJS,
            );
      _page.callMethod('highlight'.toJS, target as JSObject, style);
    }
    for (final h in highlights) {
      final style = JSObject()
        ..setProperty('mode'.toJS, (h.ink ? 'ink' : 'band').toJS)
        ..setProperty((h.ink ? 'ink' : 'band').toJS, h.rgba.toJS);
      _page.callMethod('highlight'.toJS, _wordTarget(h.word), style);
    }
    _redraw();
  }

  /// A band highlight of [rgba] (0xRRGGBBAA) on the page word at [wordIndex].
  int highlightWordRgba(int wordIndex, int rgba) {
    final style = JSObject()
      ..setProperty('mode'.toJS, 'band'.toJS)
      ..setProperty('band'.toJS, rgba.toJS);
    final handle = (_page.callMethod(
      'highlight'.toJS,
      _wordTarget(wordIndex),
      style,
    ) as JSNumber).toDartInt;
    _redraw();
    return handle;
  }

  void maskWord(int wordIndex, {String mode = 'hide'}) =>
      _mask(_wordTarget(wordIndex), mode);

  void maskAyah(int surahNo, int ayahNo, {String mode = 'hide'}) =>
      _mask(_ayahTarget(surahNo, ayahNo), mode);

  void _mask(JSObject target, String mode) =>
      _page.callMethod('mask'.toJS, target, mode.toJS);

  void unmask() => _page.callMethod('unmask'.toJS);

  /// The most recent [renderFit] request, replayed by [_redraw] when page
  /// state (masks) changes without a layout change.
  void Function()? _lastRender;

  void _redraw() => _lastRender?.call();

  int get wordCount => (_page.getProperty<JSNumber>('nWords'.toJS)).toDartInt;

  /// See `QuranEngineMushafPage.ayahWordBoundaries`; read from `qvp.js`'s
  /// per-word `surah`/`ayah` fields.
  late final List<int> ayahWordBoundaries = () {
    final words = (_page.getProperty<JSArray<JSObject>>('words'.toJS)).toDart;
    String ayahOf(JSObject w) =>
        '${(w.getProperty<JSNumber>('surah'.toJS)).toDartInt}:'
        '${(w.getProperty<JSNumber>('ayah'.toJS)).toDartInt}';
    final keys = [for (final w in words) ayahOf(w)];
    return [
      for (var i = 1; i <= keys.length; i++)
        if (i == keys.length || keys[i] != keys[i - 1]) i,
    ];
  }();

  /// First and last (surah, ayah) with words on this page, or `null`.
  late final ({int firstSurah, int firstAyah, int lastSurah, int lastAyah})?
  verseSpan = () {
    final words = (_page.getProperty<JSArray<JSObject>>('words'.toJS)).toDart;
    if (words.isEmpty) return null;
    int field(JSObject w, String name) =>
        (w.getProperty<JSNumber>(name.toJS)).toDartInt;
    return (
      firstSurah: field(words.first, 'surah'),
      firstAyah: field(words.first, 'ayah'),
      lastSurah: field(words.last, 'surah'),
      lastAyah: field(words.last, 'ayah'),
    );
  }();

  /// See `QuranEngineMushafPage.setMemorizationMask`. In this `qvp.js`
  /// build the mask-based calls are `mask(T.page(), 'hide')` +
  /// `revealNext(n)` (Android's `qvp_flutter` names the latter
  /// `unmaskNext`) — not the greyed-page `revealStart` session.
  void setMemorizationMask({required bool hidden, int revealedWords = 0}) {
    _page.callMethod('unmask'.toJS);
    if (hidden) {
      final t = _qvp.getProperty('T'.toJS) as JSObject;
      _page.callMethod('mask'.toJS, t.callMethod('page'.toJS), 'hide'.toJS);
      if (revealedWords > 0) {
        _page.callMethod('revealNext'.toJS, revealedWords.toJS);
      }
    }
    _redraw();
  }

  bool _revealStarted = false;

  /// `qvp.js`'s `QvpPage` has no `revealPosition`/`revealStepCount` (that
  /// richer API is `qvp_flutter`'s own Android-side addition) — just
  /// `revealStart`, direct `revealNext(n)`, `revealGoto(at)`, `revealStop`.
  /// Lazily starts a reveal session on first use.
  void revealNext([int count = 1]) {
    if (!_revealStarted) {
      _page.callMethod('revealStart'.toJS);
      _revealStarted = true;
    }
    _page.callMethod('revealNext'.toJS, count.toJS);
  }

  /// `T.word(i)` / `T.ayah(s, a)` on `window.QVP.T` — the same target
  /// vocabulary the Android backend's `T.word`/`T.ayah` builders use.
  JSObject _wordTarget(int wordIndex) {
    final t = _qvp.getProperty('T'.toJS) as JSObject;
    return t.callMethod('word'.toJS, wordIndex.toJS) as JSObject;
  }

  JSObject _ayahTarget(int surahNo, int ayahNo) {
    final t = _qvp.getProperty('T'.toJS) as JSObject;
    return t.callMethod('ayah'.toJS, surahNo.toJS, ayahNo.toJS) as JSObject;
  }

  void dispose() {
    _page.callMethod('free'.toJS);
  }
}

/// A word effect under way ([QuranEngineWebPage.playEffect]).
class _WordEffect {
  _WordEffect(this.kind, this.word, this.rgba, this.start);

  final String kind;
  final int word, rgba;
  final double start;

  /// As the phones' (qvp_flutter's QvpWordEffectKind).
  double get duration => switch (kind) {
    'bloom' => 650,
    'shake' => 420,
    'inkIn' => 400,
    _ => 460,
  };
}
