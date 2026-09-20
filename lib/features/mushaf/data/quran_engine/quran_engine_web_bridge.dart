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
          _onTap?.call(event.offsetX.toDouble(), event.offsetY.toDouble());
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
  String? _paperColorCss;
  void Function()? _pendingRender;

  set onTap(void Function(double x, double y)? handler) => _onTap = handler;

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
    canvas.width = (widthPx * devicePixelRatio).round();
    canvas.height = (heightPx * devicePixelRatio).round();

    _page.callMethod('setDefaultInk'.toJS, inkColorInt.toJS);

    final scale = (heightPx / height).clamp(0.0, widthPx / width);
    final ox = (widthPx - width * scale) / 2;
    final oy = (heightPx - height * scale) / 2;
    _lastView = (scale: scale, ox: ox, oy: oy);

    final rendererCtor = _qvp.getProperty('CanvasRenderer'.toJS) as JSFunction;
    final renderer = rendererCtor.callAsConstructor<JSObject>(canvas);
    final viewObj = JSObject()
      ..setProperty('scale'.toJS, scale.toJS)
      ..setProperty('ox'.toJS, ox.toJS)
      ..setProperty('oy'.toJS, oy.toJS);
    renderer.callMethod('draw'.toJS, _page, viewObj, devicePixelRatio.toJS);
  }

  ({double scale, double ox, double oy})? _lastView;

  /// Widget-local tap coordinates → the engine's own hit test
  /// (`page.hitTestViewEx`). `word`/`deco` are `-1` (the WASM `NONE`
  /// sentinel, matching `qvp.js`'s own `_hitEx`) when nothing of that kind
  /// was hit — a resolved word index can legitimately be `0`.
  ({int word, int deco, String? wordKey})? hitTest(
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
    return (word: word, deco: deco, wordKey: wordKeyJs?.toDart);
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
    return (_page.callMethod(
      'highlight'.toJS,
      target,
      style,
    ) as JSNumber).toDartInt;
  }

  void clearHighlights() => _page.callMethod('clearHighlights'.toJS);

  void maskWord(int wordIndex, {String mode = 'hide'}) =>
      _mask(_wordTarget(wordIndex), mode);

  void maskAyah(int surahNo, int ayahNo, {String mode = 'hide'}) =>
      _mask(_ayahTarget(surahNo, ayahNo), mode);

  void _mask(JSObject target, String mode) =>
      _page.callMethod('mask'.toJS, target, mode.toJS);

  void unmask() => _page.callMethod('unmask'.toJS);

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
