// Deterministic native build wrapper — a thin, explicit counterpart to
// tool/build_web.dart, kept mainly for symmetry/discoverability and as a
// safety check.
//
// Native builds need no pubspec staging: the default, unmodified
// pubspec.yaml already declares the full QPC V2 font package, which
// Android/iOS require for complete offline Mushaf support (unchanged by
// the Web font-delivery work). The one thing worth guarding against is
// running a native build while pubspec.yaml is still staged from an
// interrupted `tool/build_web.dart` run (that script restores it in a
// `finally`, so this should never actually trigger in practice).
//
// Usage:
//   dart run tool/build_native.dart [apk|appbundle|ios] [-- extra flutter-build args]
//
// Defaults to `apk` if no target is given.
import 'dart:io';

const _expectedLine = '- assets/quran/fonts/qpc_v2/';

Future<void> main(List<String> args) async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml not found — run this from the repo root.');
    exit(1);
  }
  final content = pubspecFile.readAsStringSync();
  final hasFontPackage = content
      .split('\n')
      .any((line) => line.trim() == _expectedLine);
  if (!hasFontPackage) {
    stderr.writeln(
      'pubspec.yaml does not declare the QPC V2 font package '
      '("$_expectedLine") — it may still be staged from an interrupted '
      '`tool/build_web.dart` run. Check `git diff pubspec.yaml` before '
      'building native.',
    );
    exit(1);
  }

  final target = args.isNotEmpty ? args.first : 'apk';
  final extraArgs = args.isNotEmpty ? args.skip(1).toList() : const <String>[];

  stdout.writeln(
    'Running: flutter build $target --release ${extraArgs.join(' ')}',
  );
  final process = await Process.start(
    'flutter',
    ['build', target, '--release', ...extraArgs],
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  exit(exitCode);
}
