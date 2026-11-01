import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/tajweed_models.dart';

/// The bundled tajweed colours (`tool/quran_data/build_tajweed.py`).
const kTajweedAsset = 'assets/quran/tajweed/tajweed.json';

TajweedIndex _parse(String raw) =>
    TajweedIndex.fromJson(jsonDecode(raw) as Map<String, Object?>);

/// Every word's tajweed colours — read once, the first time Ayah mode
/// shows them (off the UI thread where there is one).
final tajweedIndexProvider = FutureProvider<TajweedIndex>((ref) async {
  final raw = await rootBundle.loadString(kTajweedAsset);
  return compute(_parse, raw);
});
