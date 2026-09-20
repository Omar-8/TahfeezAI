// CI guard (and a post-build check `tool/build_web.dart` also runs):
// scans a Web build output directory for the native-only, license-gated
// QPC V2 604-page-font package and fails loudly if any of it is present.
//
// The whole point of `tool/build_web.dart`'s pubspec staging is that this
// package (~200MB) must never ship in a Web build at all — Web has no
// hard offline requirement, and QPC V2 redistribution remains
// SHIP_BLOCKED_LICENSE (see docs/QURAN_DATA_PROVENANCE.md §8). This script
// is the automatable proof that held, not just an assumption.
//
// Usage:
//   dart run tool/verify_web_build_no_qpc_fonts.dart [build/web]
import 'dart:io';

Future<void> main(List<String> args) async {
  final buildWebDir = Directory(args.isNotEmpty ? args.first : 'build/web');
  if (!buildWebDir.existsSync()) {
    stderr.writeln(
      '${buildWebDir.path} does not exist — run `flutter build web` (or '
      '`dart run tool/build_web.dart`) first.',
    );
    exit(1);
  }

  var totalBytes = 0;
  var fileCount = 0;
  final offenders = <String>[];

  await for (final entity in buildWebDir.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    // Matched by path, not just ".ttf" extension, so this never
    // false-positives on the small Noto Sans/Noto Sans Arabic UI fonts
    // this app also ships (assets/fonts/, a completely different path).
    final normalized = entity.path.replaceAll(r'\', '/');
    if (normalized.contains('/quran/fonts/qpc_v2/')) {
      final size = await entity.length();
      totalBytes += size;
      fileCount++;
      offenders.add(entity.path);
    }
  }

  final mb = (totalBytes / 1024 / 1024).toStringAsFixed(2);
  stdout.writeln(
    'QPC bundled font bytes in ${buildWebDir.path}: $totalBytes ($mb MB, '
    '$fileCount files)',
  );

  if (totalBytes > 0) {
    stderr.writeln(
      'FAILED: found $fileCount QPC V2 native font file(s) in the Web '
      'build output. These must never ship to Web (SHIP_BLOCKED_LICENSE, '
      'and Web does not need offline font support) — see '
      'tool/build_web.dart.',
    );
    for (final path in offenders.take(10)) {
      stderr.writeln('  - $path');
    }
    if (offenders.length > 10) {
      stderr.writeln('  ... and ${offenders.length - 10} more');
    }
    exit(1);
  }

  stdout.writeln(
    'OK: no QPC V2 native font files found in the Web build output.',
  );
}
