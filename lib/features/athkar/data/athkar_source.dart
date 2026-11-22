import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/gunzip.dart';
import '../domain/athkar.dart';

/// Hisn al-Muslim's athkar, bundled (built by tool/athkar/build_athkar.py
/// from hisnmuslim.com's Arabic and English).
const kAthkarAsset = 'assets/athkar/athkar.json.gz';

AthkarBook _parse(String raw) =>
    AthkarBook.fromJson(jsonDecode(raw) as Map<String, Object?>);

/// The athkar, read once (off the main isolate).
final athkarBookProvider = FutureProvider<AthkarBook>((ref) async {
  final data = await rootBundle.load(kAthkarAsset);
  final raw = await gunzipText(data.buffer.asUint8List());
  return compute(_parse, raw);
});
