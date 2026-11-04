import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/browser_data_saver.dart';
import '../application/local_acoustic_inference_controller.dart';
import '../application/recitation_ai_config.dart';

/// The web app: the recitation model fetched in the background soon after
/// the app opens, not when a Mushaf page first does — by then it is ready,
/// or its download under way (the recitation bar shows how far). The
/// phones carry it in the app: nothing to do there. Not when the browser
/// asks to save data.
class WebModelPreload extends ConsumerStatefulWidget {
  const WebModelPreload({super.key, required this.child});

  final Widget child;

  /// After the app's first screens: their own loading goes first.
  static const delay = Duration(seconds: 3);

  @override
  ConsumerState<WebModelPreload> createState() => _WebModelPreloadState();
}

class _WebModelPreloadState extends ConsumerState<WebModelPreload> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _timer = Timer(WebModelPreload.delay, _start);
  }

  void _start() {
    if (!mounted || browserSavesData) return;
    final config = ref.read(recitationAiConfigProvider);
    if (config.acoustic != QuranAcousticBackend.local) return;
    // The same load the recitation bar waits on (a failure: tried again
    // there).
    unawaited(
      ref
          .read(localQuranAcousticModelProvider)
          .load()
          .then((_) {}, onError: (Object _) {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
