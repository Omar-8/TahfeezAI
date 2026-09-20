// CI guard (and a post-build check `tool/build_web.dart` also runs when it
// staged the Quran Engine pages line): scans a Web build output directory
// for the vendored, KFGQPC-derived Quran Engine page corpus
// (`assets/quran/quran_engine/pages/`) and fails loudly if any of it is
// present.
//
// This corpus's public redistribution is unresolved (see
// docs/QURAN_ENGINE_MIGRATION.md's licensing section) exactly like QPC
// V2's is — see tool/verify_web_build_no_qpc_fonts.dart, which this
// mirrors. A naive `flutter build web` bundles Flutter `assets:`
// declarations unconditionally into `build/web/assets/...` regardless of
// platform; this script is the automatable proof that
// `tool/build_web.dart`'s pubspec staging kept this specific corpus out
// of that output — confirmed to actually leak in without this guard by
// inspecting a real build/web directory during the migration's own
// implementation.
//
// Usage:
//   dart run tool/quran_engine/verify_web_build_no_page_corpus.dart [build/web]
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
    final normalized = entity.path.replaceAll(r'\', '/');
    if (normalized.contains('/quran/quran_engine/pages/')) {
      final size = await entity.length();
      totalBytes += size;
      fileCount++;
      offenders.add(entity.path);
    }
  }

  final kb = (totalBytes / 1024).toStringAsFixed(2);
  stdout.writeln(
    'Quran Engine page-corpus bytes in ${buildWebDir.path}: '
    '$totalBytes ($kb KB, $fileCount files)',
  );

  if (totalBytes > 0) {
    stderr.writeln(
      'FAILED: found $fileCount Quran Engine page file(s) in the Web '
      'build output. This KFGQPC-derived corpus must never ship to Web '
      '(redistribution unresolved — see '
      'docs/QURAN_ENGINE_MIGRATION.md) — see tool/build_web.dart.',
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
    'OK: no Quran Engine page-corpus files found in the Web build output.',
  );
}
