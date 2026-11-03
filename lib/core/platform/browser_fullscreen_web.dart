import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The browser's own full screen, on or off (where the browser has one —
/// not iPhone Safari's pages). Asked from a tap, as browsers require.
void setBrowserFullscreen(bool on) {
  final document = web.document;
  try {
    if (on && document.fullscreenElement == null) {
      document.documentElement?.requestFullscreen().toDart.ignore();
    } else if (!on && document.fullscreenElement != null) {
      document.exitFullscreen().toDart.ignore();
    }
  } catch (_) {
    // No full screen here: the app's own focus mode only.
  }
}

/// [left] when the browser leaves full screen by itself (Escape, a phone's
/// Back gesture).
void onBrowserFullscreenLeft(void Function() left) {
  web.document.addEventListener(
    'fullscreenchange',
    ((web.Event _) {
      if (web.document.fullscreenElement == null) left();
    }).toJS,
  );
}
