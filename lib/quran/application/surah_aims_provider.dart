import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/surah_aims.dart';

/// The bundled surah aims (`tool/quran_data/build_surah_aims.py`).
const kSurahAimsAsset = 'assets/quran/surah_aims.json';

/// Every surah's aims — read once, the first time a surah's are asked for.
final surahAimsProvider = FutureProvider<SurahAims>((ref) async {
  final raw = await rootBundle.loadString(kSurahAimsAsset);
  return SurahAims.fromJson(jsonDecode(raw) as Map<String, Object?>);
});
