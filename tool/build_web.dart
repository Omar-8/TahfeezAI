// Deterministic Web build wrapper: excludes native-only, KFGQPC-derived
// Mushaf resources from build/web entirely — not just from what the app
// chooses to fetch/load at runtime — since Web has no hard offline
// requirement (`docs/QURAN_DATA_PROVENANCE.md` §8) for content whose
// redistribution is unresolved either way.
//
// Excludes two independent things, both pubspec `assets:` entries:
//   1. The QPC V2 604-page-font package (~200MB) — mandatory; every
//      pubspec on this codebase has this line.
//   2. Quran Engine's own vendored page corpus
//      (`assets/quran/quran_engine/pages/`,
//      feature/quran-engine-migration — docs/QURAN_ENGINE_MIGRATION.md) —
//      optional; only present once `tool/quran_engine/fetch_page_data.sh`
//      has been run. Same unresolved-redistribution status as QPC V2, a
//      different technical delivery mechanism for the same underlying
//      KFGQPC provenance question — confirmed to leak into a naive
//      `flutter build web` output the exact same way QPC V2 used to,
//      caught by actually inspecting a real build/web directory.
//
// Flutter's pubspec `assets:` declarations apply to every target platform
// built from the same pubspec.yaml — there is no native per-platform
// asset filter. This works around that the least fragile way available
// without forking the project into two Flutter apps: temporarily comment
// out the matched line(s) for the duration of `flutter build web`, then
// restore the original file byte-for-byte (in a `finally`, so an
// interrupted or failed build never leaves the repo modified).
//
// Left bundled on Web (deliberately NOT excluded): the Mushaf line/token
// dataset (`assets/quran/mushaf/kfgqpc_v2.json`) and the font manifest
// (`assets/quran/manifests/qpc_v2_fonts.json`) — Web Mushaf mode still
// needs both for line/word layout and to resolve which font a page needs
// (`WebQpcPageFontManager` derives its HTTP URL from that manifest); only
// the actual font *bytes* are native-only.
//
// Usage:
//   dart run tool/build_web.dart [-- extra flutter-build-web args]
//
// Example:
//   dart run tool/build_web.dart -- --dart-define=QPC_FONT_BASE_URL=https://example.test/fonts
import 'dart:io';

const _mandatoryTargetLine = '- assets/quran/fonts/qpc_v2/';
const _optionalTargetLine = '- assets/quran/quran_engine/pages/';
const _stagedComment =
    '# excluded for Web by tool/build_web.dart -- see its own doc comment';

Future<void> main(List<String> args) async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml not found — run this from the repo root.');
    exit(1);
  }
  final original = pubspecFile.readAsStringSync();
  final lines = original.split('\n');

  var foundMandatory = false;
  var foundOptional = false;
  final staged = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed == _mandatoryTargetLine) {
      foundMandatory = true;
      final indent = line.substring(0, line.indexOf('-'));
      staged.add('$indent$_stagedComment');
    } else if (trimmed == _optionalTargetLine) {
      foundOptional = true;
      final indent = line.substring(0, line.indexOf('-'));
      staged.add('$indent$_stagedComment');
    } else {
      staged.add(line);
    }
  }

  if (!foundMandatory) {
    stderr.writeln(
      'Could not find the expected pubspec.yaml line '
      '("$_mandatoryTargetLine") — pubspec.yaml may have changed shape. '
      'Refusing to build so this script never silently does nothing; '
      'update tool/build_web.dart to match before re-running.',
    );
    exit(1);
  }

  stdout.writeln(
    'Staging pubspec.yaml: excluding the native QPC V2 font package for Web build...',
  );
  if (foundOptional) {
    stdout.writeln(
      'Staging pubspec.yaml: excluding the Quran Engine page corpus for Web build...',
    );
  }
  pubspecFile.writeAsStringSync(staged.join('\n'));

  var buildExitCode = 0;
  try {
    stdout.writeln('Running: flutter build web --release ${args.join(' ')}');
    final process = await Process.start(
      'flutter',
      ['build', 'web', '--release', ...args],
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );
    buildExitCode = await process.exitCode;
  } finally {
    stdout.writeln('Restoring the original pubspec.yaml...');
    pubspecFile.writeAsStringSync(original);
    final restored = pubspecFile.readAsStringSync();
    if (restored != original) {
      stderr.writeln(
        'WARNING: pubspec.yaml restoration did not match the original '
        'byte-for-byte — please check `git diff pubspec.yaml` before '
        'committing anything.',
      );
    }
  }

  if (buildExitCode != 0) {
    stderr.writeln('flutter build web failed (exit $buildExitCode).');
    exit(buildExitCode);
  }

  stdout.writeln('Verifying build/web excludes the QPC V2 font package...');
  final verify = await Process.run('dart', [
    'run',
    'tool/verify_web_build_no_qpc_fonts.dart',
  ], runInShell: true);
  stdout.write(verify.stdout);
  stderr.write(verify.stderr);
  if (verify.exitCode != 0) {
    stderr.writeln('Web build verification FAILED.');
    exit(verify.exitCode);
  }

  if (foundOptional) {
    stdout.writeln(
      'Verifying build/web excludes the Quran Engine page corpus...',
    );
    final engineVerify = await Process.run('dart', [
      'run',
      'tool/quran_engine/verify_web_build_no_page_corpus.dart',
    ], runInShell: true);
    stdout.write(engineVerify.stdout);
    stderr.write(engineVerify.stderr);
    if (engineVerify.exitCode != 0) {
      stderr.writeln('Web build verification FAILED.');
      exit(engineVerify.exitCode);
    }
  }

  stdout.writeln(
    'Web build complete: build/web excludes the native QPC V2 font package'
    '${foundOptional ? ' and the Quran Engine page corpus' : ''}.',
  );
}
