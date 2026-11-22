import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// [bytes] (gzip) unzipped, as UTF-8 text.
Future<String> gunzipText(Uint8List bytes) async =>
    utf8.decode(GZipCodec().decode(bytes));
