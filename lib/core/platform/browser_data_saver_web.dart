import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Whether the browser asks pages to save data (a data saver turned on,
/// `navigator.connection.saveData`; browsers without it: no).
bool get browserSavesData {
  try {
    final connection = (web.window.navigator as JSObject)['connection'];
    if (connection == null || !connection.isA<JSObject>()) return false;
    final saveData = (connection as JSObject)['saveData'];
    return saveData != null &&
        saveData.isA<JSBoolean>() &&
        (saveData as JSBoolean).toDart;
  } catch (_) {
    return false;
  }
}
