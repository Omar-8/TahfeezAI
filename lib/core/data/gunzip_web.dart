import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// [bytes] (gzip) unzipped by the browser, as UTF-8 text.
Future<String> gunzipText(Uint8List bytes) async {
  final unzip = web.DecompressionStream('gzip');
  final stream = web.Blob([bytes.toJS].toJS).stream().pipeThrough(
    web.ReadableWritablePair(
      readable: unzip.readable,
      writable: unzip.writable,
    ),
  );
  final text = await web.Response(stream).text().toDart;
  return text.toDart;
}
