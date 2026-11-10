// What the phone apps leave out of their bundle: data they get otherwise —
// the Quran's JSON datasets (the phones install ready-made databases) and
// the meaning packs (downloaded). Android's build and iOS's build phase
// must leave out the same, or one store's app grows by ~190 MB (iOS 1.2.3
// build 29: 465.7 MB) and the packs are carried twice.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final android = File('android/app/build.gradle.kts').readAsStringSync();
  final ios = File('ios/scripts/strip_unused_assets.sh').readAsStringSync();
  final xcode = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  const left = {
    'quran_dataset.json': 'quran/quran_dataset.json',
    'mushaf/': 'quran/mushaf/',
    'translations/': 'quran/translations/',
    'tafsir/': 'quran/tafsir/',
    'wbw/': 'quran/wbw/',
    'db/packs/': 'quran/db/packs/',
    'quran_engine/pages/': 'quran/quran_engine/pages/',
  };

  for (final MapEntry(key: what, value: path) in left.entries) {
    test('$what: left out on Android and on iOS', () {
      expect(android, contains('assets/$path'), reason: 'Android');
      final ios_ = what.endsWith('/')
          ? '"\$quran/${what.substring(0, what.length - 1)}"'
          : '"\$quran/$what"';
      expect(ios, contains(ios_), reason: 'iOS');
    });
  }

  test('the ready-made databases themselves stay', () {
    expect(android, isNot(contains('"**/assets/quran/db/**"')));
    expect(
      ios,
      isNot(
        contains(
          r'rm -rf "$quran/db"'
          '\n',
        ),
      ),
    );
  });

  test("iOS: the step runs in the app's build, after Thin Binary", () {
    final phases = RegExp(r'buildPhases = \(([^)]*)\);')
        .allMatches(xcode)
        .map((m) => m[1]!)
        .firstWhere((p) => p.contains('Thin Binary'));
    expect(
      phases.indexOf('Strip Unused Assets'),
      greaterThan(phases.indexOf('Thin Binary')),
    );
    expect(xcode, contains(r'$SRCROOT/scripts/strip_unused_assets.sh'));
  });

  test('the phones carry the pages 4 to a file instead; the web leaves '
      'those out (it serves the .qvp files)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/quran/quran_engine/page_groups/'));
    expect(pubspec, contains('- assets/quran/quran_engine/page_groups.json'));
    expect(
      File('tool/build_web.sh').readAsStringSync(),
      contains('build/web/assets/assets/quran/quran_engine/page_groups '),
    );
  });
}
