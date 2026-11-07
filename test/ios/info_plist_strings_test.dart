import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS shows its microphone prompt from its own files, not Flutter's
/// translations: ios/Runner/<code>.lproj/InfoPlist.strings, generated from
/// `iosMicrophoneUsage` by tool/l10n/build_ios_strings.py. Every app language
/// needs its file, its place in the Xcode project and in Info.plist's
/// languages, or iOS falls back to English.
void main() {
  final arbs =
      Directory('lib/core/localization/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'app_\w+\.arb$').hasMatch(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  // iOS's code for the language: Simplified Chinese is zh-Hans there.
  String code(File arb) =>
      switch (RegExp(r'app_(\w+)\.arb$').firstMatch(arb.path)!.group(1)!) {
        'zh' => 'zh-Hans',
        final c => c,
      };
  // In the Xcode project, a name with a hyphen is quoted.
  String inProject(String c) => c.contains('-') ? '"$c"' : c;
  String text(File arb) =>
      (jsonDecode(arb.readAsStringSync()) as Map)['iosMicrophoneUsage']
          as String;
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final project = File('ios/Runner.xcodeproj/project.pbxproj')
      .readAsStringSync();

  test('every app language has the iOS microphone prompt, current', () {
    expect(arbs, hasLength(greaterThanOrEqualTo(19)));
    for (final arb in arbs) {
      final strings = File('ios/Runner/${code(arb)}.lproj/InfoPlist.strings');
      expect(
        strings.existsSync(),
        isTrue,
        reason:
            '${code(arb)}: run '
            'python3 tool/l10n/build_ios_strings.py',
      );
      final quoted = text(arb).replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      expect(
        strings.readAsStringSync(),
        contains('"NSMicrophoneUsageDescription" = "$quoted";'),
        reason: '${code(arb)}: run python3 tool/l10n/build_ios_strings.py',
      );
    }
  });

  test('Info.plist lists every language and holds the English prompt', () {
    final languages = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist)!.group(1)!;
    for (final arb in arbs) {
      expect(languages, contains('<string>${code(arb)}</string>'));
    }
    final english = arbs.firstWhere((a) => code(a) == 'en');
    expect(
      plist,
      contains(
        '<key>NSMicrophoneUsageDescription</key>\n'
        '\t<string>${text(english)}</string>',
      ),
    );
  });

  test('the Xcode project bundles every language\'s file', () {
    for (final arb in arbs) {
      expect(
        project,
        contains(
          'path = ${inProject('${code(arb)}.lproj/InfoPlist.strings')};',
        ),
      );
      expect(project, contains('\t\t\t\t${inProject(code(arb))},\n'));
    }
    expect(project, contains('/* InfoPlist.strings in Resources */,'));
  });
}
