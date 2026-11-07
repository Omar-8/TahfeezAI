import 'package:flutter/services.dart';

/// Fonts only some readers use — another Quran font or Arabic UI font
/// chosen in the settings — kept out of `pubspec.yaml`'s `fonts:` and
/// loaded the first time they are asked for ([ensureFontFamily]). The
/// web downloads every `fonts:` file before the app's first frame:
/// these four families were ~1.2 MB of it on every visit (owner,
/// 2026-11-07: "waiting so long … before the app started" on phones).
/// Text set in one before it has loaded shows in the fallback font and is
/// redrawn when it arrives (the engine tells text of new fonts).
const lazyFontFamilies = <String, List<String>>{
  'Scheherazade New': ['assets/fonts/ScheherazadeNew-Regular.ttf'],
  'Lateef': ['assets/fonts/Lateef-Regular.ttf'],
  'Almarai': [
    'assets/fonts/Almarai-Light.ttf',
    'assets/fonts/Almarai-Regular.ttf',
    'assets/fonts/Almarai-Bold.ttf',
  ],
  'Tajawal': [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Medium.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ],
};

final _loading = <String, Future<void>>{};

/// [family] loaded, if it is one of [lazyFontFamilies] (others are always
/// there). Once per family; a failure is forgotten, to be tried again.
Future<void> ensureFontFamily(String family) {
  final files = lazyFontFamilies[family];
  if (files == null) return Future.value();
  return _loading[family] ??=
      () async {
        final loader = FontLoader(family);
        for (final file in files) {
          loader.addFont(rootBundle.load(file));
        }
        await loader.load();
      }().catchError((Object _) {
        _loading.remove(family);
      });
}
