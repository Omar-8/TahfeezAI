import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/networking/network_client.dart';
import '../../../../quran/domain/models/mushaf_token_models.dart';
import '../../../../quran/domain/models/quran_refs.dart';
import '../../domain/quran_engine/quran_engine_mushaf_backend.dart';
import '../../domain/quran_engine_ref_adapter.dart';
import '../../presentation/mushaf_page_render_model.dart';
import 'quran_engine_web_bridge.dart';

/// Web implementation of [QuranEngineMushafBackend], promoted from the
/// `poc/quran-engine` branch's evaluation
/// (`docs/poc/QURAN_ENGINE_POC.md`) to production quality: hits translate
/// through the shared [QuranEngineRefAdapter] and canonical
/// [WordRef]/[VerseRef] instead of the POC's own experimental key type,
/// and page delivery follows the exact same "unconfigured by default, HTTP
/// fetch via [NetworkClient], dedicated not-configured exception" pattern
/// [WebQpcPageFontManager] already established for the QPC V2 renderer's
/// own Web font delivery
/// (`lib/features/mushaf/data/web_qpc_page_font_manager.dart`).
///
/// Never fetches the full 604-page corpus — only the page a caller
/// actually asks for, plus a small preload window (see [preloadAround]).
/// Relies on ordinary browser HTTP caching for repeat visits; no custom
/// IndexedDB/OPFS cache is implemented (not measured to be necessary).
class QuranEngineWebBackend implements QuranEngineMushafBackend {
  QuranEngineWebBackend({
    required this.pageBaseUrl,
    required this.networkClient,
    required this.logger,
  });

  /// `QURAN_ENGINE_PAGE_BASE_URL`'s resolved value — `null`/empty means
  /// "not configured", never a hard-coded public default. Quran Engine's
  /// page corpus carries the same unresolved KFGQPC redistribution status
  /// as Tahfeez's existing QPC V2 fonts — this must never point at a
  /// public CDN by default.
  final String? pageBaseUrl;
  final NetworkClient networkClient;
  final AppLogger logger;

  QuranEngineWebBridge? _bridge;
  final Set<int> _loaded = {};
  final Map<int, Future<QuranEngineMushafPage>> _inFlight = {};

  bool get _isConfigured =>
      pageBaseUrl != null && pageBaseUrl!.trim().isNotEmpty;

  QuranEngineWebBridge get _requireBridge {
    final bridge = _bridge;
    if (bridge == null) {
      throw StateError(
        'QuranEngineWebBackend.initialize() must complete before use.',
      );
    }
    return bridge;
  }

  @override
  Future<String> initialize() async {
    final bridge = await QuranEngineWebBridge.initialize();
    _bridge = bridge;
    return bridge.engineVersionInfo;
  }

  @override
  Future<QuranEngineMushafPage> loadPage(int pageNumber) {
    if (!_isConfigured) {
      final exception = QuranEngineWebDeliveryNotConfiguredException(
        pageNumber,
      );
      logger.debug(exception.toString(), tag: 'QuranEngineWebBackend');
      return Future.error(exception);
    }

    final existing = _inFlight[pageNumber];
    if (existing != null) return existing;

    final future = _load(pageNumber);
    _inFlight[pageNumber] = future;
    return future;
  }

  Future<QuranEngineMushafPage> _load(int pageNumber) async {
    try {
      final response = await networkClient.getBytes(_pageUrl(pageNumber));
      final data = response.data;
      if (data == null) {
        throw StateError('Empty response body for ${_pageUrl(pageNumber)}');
      }
      final bytes = Uint8List.fromList(data);
      final enginePage = _requireBridge.loadPage(bytes);
      _loaded.add(pageNumber);
      return QuranEngineWebPageAdapter(
        pageNumber: pageNumber,
        page: enginePage,
      );
    } catch (e, st) {
      logger.error(
        'Failed to load Quran Engine page $pageNumber from '
        '${_pageUrl(pageNumber)}',
        tag: 'QuranEngineWebBackend',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      _inFlight.remove(pageNumber);
    }
  }

  String _pageUrl(int pageNumber) {
    final base = pageBaseUrl!.endsWith('/')
        ? pageBaseUrl!.substring(0, pageBaseUrl!.length - 1)
        : pageBaseUrl!;
    final key = pageNumber.toString().padLeft(3, '0');
    return '$base/$key.qvp';
  }

  @override
  void disposePage(QuranEngineMushafPage page) {
    _loaded.remove(page.pageNumber);
    page.dispose();
  }

  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) async {
    if (!_isConfigured) return;
    for (var distance = 1; distance <= radius; distance++) {
      for (final neighbor in [pageNumber - distance, pageNumber + distance]) {
        if (neighbor < 1 || neighbor > 604) continue;
        if (_loaded.contains(neighbor) || _inFlight.containsKey(neighbor)) {
          continue;
        }
        // Fire-and-forget: a neighbor failing or being slow to preload
        // must never affect the page currently on screen. The loaded
        // page itself is intentionally discarded here (not attached to
        // any widget) -- its value is the browser's own HTTP cache
        // already holding the bytes for the real load that follows when
        // the user actually swipes there.
        unawaited(
          loadPage(neighbor)
              .catchError((Object e) {
                logger.warning(
                  'Preload failed for Quran Engine page $neighbor: $e',
                  tag: 'QuranEngineWebBackend',
                );
                throw e;
              })
              .then((page) => disposePage(page), onError: (_) {}),
        );
      }
    }
  }
}

class QuranEngineWebPageAdapter implements QuranEngineMushafPage {
  QuranEngineWebPageAdapter({required this.pageNumber, required this.page});

  final QuranEngineWebPage page;

  @override
  final int pageNumber;

  @override
  double get aspectRatio => page.width / page.height;

  @override
  Widget buildView({
    required Color ink,
    required Color paper,
    ValueChanged<MushafTokenHitRect>? onWordHit,
    ValueChanged<MushafTokenHitRect>? onDecorationHit,
    VoidCallback? onEmptyHit,
  }) {
    page.paperColorCss = _cssHex(paper);
    return _QuranEngineWebPageView(
      page: page,
      ink: ink,
      onWordHit: onWordHit,
      onDecorationHit: onDecorationHit,
      onEmptyHit: onEmptyHit,
    );
  }

  @override
  int highlightWord(WordRef target, {String mode = 'band'}) =>
      page.highlightWord(_engineWordIndexOf(target), mode: mode);

  @override
  int highlightAyah(VerseRef target, {String mode = 'band'}) =>
      page.highlightAyah(target.chapterNo, target.verseNo, mode: mode);

  @override
  void clearHighlights() => page.clearHighlights();

  @override
  void maskWord(WordRef target, {String mode = 'hide'}) =>
      page.maskWord(_engineWordIndexOf(target), mode: mode);

  @override
  void maskAyah(VerseRef target, {String mode = 'hide'}) =>
      page.maskAyah(target.chapterNo, target.verseNo, mode: mode);

  @override
  void revealNext([int count = 1]) => page.revealNext(count);

  @override
  void unmask() => page.unmask();

  @override
  void dispose() => page.dispose();

  /// [QuranEngineWebPage.highlightWord]/`.maskWord` expect the engine's
  /// own page-local word-array index — resolved via `findWord`, exactly
  /// like `QuranEngineAndroidBackend._engineWordIndexOf`.
  int _engineWordIndexOf(WordRef ref) {
    final surahNo = ref.ayahId ~/ 1000;
    final ayahNo = ref.ayahId % 1000;
    final index = page.findWord(surahNo, ayahNo, ref.wordIndex + 1);
    if (index < 0) {
      throw StateError(
        'Word $ref (surah $surahNo, ayah $ayahNo, word ${ref.wordIndex + 1}) '
        'was not found on Quran Engine page $pageNumber.',
      );
    }
    return index;
  }
}

String _cssHex(Color c) {
  int channel(double v) => (v * 255).round().clamp(0, 255);
  final r = channel(c.r).toRadixString(16).padLeft(2, '0');
  final g = channel(c.g).toRadixString(16).padLeft(2, '0');
  final b = channel(c.b).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

/// `qvp.js`'s `rgba()` 0xRRGGBBAA integer form, used by
/// `page.setDefaultInk`/highlight styling — matches `QvpColor.fromColor`
/// on the Android side (`qvp_flutter`'s own conversion), kept independent
/// here since this file has no dependency on that package.
int _colorToRgbaInt(Color c) {
  int channel(double v) => (v * 255).round().clamp(0, 255);
  return (channel(c.r) << 24) |
      (channel(c.g) << 16) |
      (channel(c.b) << 8) |
      channel(c.a);
}

class _QuranEngineWebPageView extends StatefulWidget {
  const _QuranEngineWebPageView({
    required this.page,
    required this.ink,
    required this.onWordHit,
    required this.onDecorationHit,
    required this.onEmptyHit,
  });

  final QuranEngineWebPage page;
  final Color ink;
  final ValueChanged<MushafTokenHitRect>? onWordHit;
  final ValueChanged<MushafTokenHitRect>? onDecorationHit;
  final VoidCallback? onEmptyHit;

  @override
  State<_QuranEngineWebPageView> createState() =>
      _QuranEngineWebPageViewState();
}

class _QuranEngineWebPageViewState extends State<_QuranEngineWebPageView> {
  @override
  void initState() {
    super.initState();
    widget.page.onTap = _handleTap;
  }

  @override
  void dispose() {
    widget.page.onTap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.page.renderFit(
            width,
            height,
            MediaQuery.of(context).devicePixelRatio,
            _colorToRgbaInt(widget.ink),
          );
        });
        return HtmlElementView(viewType: widget.page.viewType);
      },
    );
  }

  void _handleTap(double localX, double localY) {
    // `word`/`deco` are -1 (the WASM NONE sentinel) when unresolved; a
    // real word index can be 0, so this must not check truthiness.
    final hit = widget.page.hitTest(localX, localY);
    if (hit == null) {
      widget.onEmptyHit?.call();
      return;
    }
    if (hit.word >= 0) {
      final rawKey = hit.wordKey;
      if (rawKey == null) return;
      final ref = QuranEngineRefAdapter.wordRefFromEngineKey(rawKey);
      widget.onWordHit?.call(
        MushafTokenHitRect(
          rect: Rect.zero,
          sourceTokenId: hit.word,
          tokenType: MushafTokenType.quranWord,
          canonicalAyahId: ref.ayahId,
          canonicalWordIndex: ref.wordIndex,
          text: '',
        ),
      );
      return;
    }
    if (hit.deco >= 0) {
      widget.onDecorationHit?.call(
        MushafTokenHitRect(
          rect: Rect.zero,
          sourceTokenId: hit.deco,
          tokenType: MushafTokenType.otherMarker,
          canonicalAyahId: null,
          canonicalWordIndex: null,
          text: '',
        ),
      );
      return;
    }
    widget.onEmptyHit?.call();
  }
}
