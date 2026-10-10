import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/core_providers.dart';
import '../domain/quran_audio_sources.dart';

/// Every ayah of the Quran: the files a full download holds.
const _ayahCount = 6236;

/// One reciter's offline recitation.
class ReciterDownload {
  const ReciterDownload({
    this.files = 0,
    this.downloading = false,
    this.failed = false,
  });

  /// Ayah files on the device.
  final int files;
  final bool downloading;

  /// The last download stopped on an error (the connection, the storage).
  final bool failed;

  bool get complete => files >= _ayahCount;
  double get progress => files / _ayahCount;

  ReciterDownload copyWith({int? files, bool? downloading, bool? failed}) =>
      ReciterDownload(
        files: files ?? this.files,
        downloading: downloading ?? this.downloading,
        failed: failed ?? this.failed,
      );
}

/// Where downloaded recitations live: the app's own storage (removed with
/// the app); `null` where there is none (the web).
final reciterAudioDirectoryProvider = FutureProvider<Directory?>((ref) async {
  if (ref.watch(platformCapabilitiesProvider).isWeb) return null;
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'recitation_audio'));
});

/// Downloads a reciter's whole recitation (every ayah, from the same CDN
/// that streams it) for listening offline, and deletes it again. A download
/// runs while the app is open; stopped or interrupted, it goes on from
/// where it was. Edition → its download (only reciters with files).
class ReciterDownloads extends Notifier<Map<String, ReciterDownload>> {
  Directory? _root;
  final _tokens = <String, CancelToken>{};

  /// Deleted while its download ran: cleaned up again once it stops.
  final _deleted = <String>{};
  late final Future<void> _scanned;

  static const _parallel = 6;
  static const _tries = 3;

  @override
  Map<String, ReciterDownload> build() {
    ref.onDispose(() {
      for (final t in _tokens.values) {
        t.cancel();
      }
    });
    _scanned = _scan();
    return const {};
  }

  /// Once the files on the device are known (for the player).
  Future<void> ready() => _scanned;

  /// `null` if there is no storage to download to (the web, or it cannot
  /// be found): then everything streams.
  Future<Directory?> _rootDir() async {
    try {
      return _root ??= await ref.read(reciterAudioDirectoryProvider.future);
    } catch (_) {
      return null;
    }
  }

  /// The files already on the device, per reciter.
  Future<void> _scan() async {
    try {
      await _scanFiles();
    } catch (_) {
      // Unreadable: nothing counted as downloaded; playback streams.
    }
  }

  Future<void> _scanFiles() async {
    final root = await _rootDir();
    if (root == null || !await root.exists() || !ref.mounted) return;
    final found = <String, ReciterDownload>{};
    for (final r in reciters) {
      final dir = Directory(p.join(root.path, r.edition));
      if (!await dir.exists()) continue;
      final n = await dir.list().where((f) => f.path.endsWith('.mp3')).length;
      if (n > 0) found[r.edition] = ReciterDownload(files: n);
    }
    if (ref.mounted) state = {...found, ...state};
  }

  /// Downloads are possible here (not on the web).
  bool get supported => !ref.read(platformCapabilitiesProvider).isWeb;

  /// [ayahId]'s file for [reciter] if downloaded, for the player.
  String? localFile(int ayahId, Reciter reciter) {
    final root = _root;
    if (root == null || (state[reciter.edition]?.files ?? 0) == 0) {
      return null;
    }
    final file = File(_path(root, reciter.edition, globalAyahNumber(ayahId)));
    return file.existsSync() ? file.path : null;
  }

  static String _path(Directory root, String edition, int n) =>
      p.join(root.path, edition, '$n.mp3');

  /// Downloads every ayah of [edition] not on the device yet.
  Future<void> download(String edition) async {
    final root = await _rootDir();
    if (root == null || (state[edition]?.downloading ?? false)) return;
    final reciter = reciterFor(edition);
    final dir = Directory(p.join(root.path, edition));
    await dir.create(recursive: true);
    final missing = [
      for (var n = 1; n <= _ayahCount; n++)
        if (!File(_path(root, edition, n)).existsSync()) n,
    ];
    var files = _ayahCount - missing.length;
    final token = CancelToken();
    _tokens[edition] = token;
    _set(edition, ReciterDownload(files: files, downloading: true));
    final network = ref.read(networkClientProvider);
    var next = 0;
    var failed = false;
    var lastShown = DateTime.now();

    Future<void> worker() async {
      while (!token.isCancelled && next < missing.length) {
        final n = missing[next++];
        final target = _path(root, edition, n);
        final part = '$target.part';
        var done = false;
        for (var t = 0; t < _tries && !done && !token.isCancelled; t++) {
          try {
            await network.download(
              'https://cdn.islamic.network/quran/audio/${reciter.kbps}/'
              '$edition/$n.mp3',
              part,
              cancelToken: token,
            );
            await File(part).rename(target);
            done = true;
          } catch (_) {
            if (token.isCancelled) return;
            await Future<void>.delayed(Duration(seconds: 1 + t));
          }
        }
        if (!done) {
          if (!token.isCancelled) {
            failed = true;
            token.cancel();
          }
          return;
        }
        files++;
        final now = DateTime.now();
        if (now.difference(lastShown) > const Duration(milliseconds: 300)) {
          lastShown = now;
          if (ref.mounted) {
            _set(edition, ReciterDownload(files: files, downloading: true));
          }
        }
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
    _tokens.remove(edition);
    if (_deleted.remove(edition)) {
      // A file finishing after the delete may have brought the folder back.
      if (await dir.exists()) await dir.delete(recursive: true);
      return;
    }
    if (!ref.mounted) return;
    _set(edition, ReciterDownload(files: files, failed: failed));
  }

  /// Stops [edition]'s download (what is downloaded stays).
  void cancel(String edition) => _tokens[edition]?.cancel();

  /// Deletes [edition]'s downloaded recitation.
  Future<void> delete(String edition) async {
    if (_tokens.containsKey(edition)) _deleted.add(edition);
    cancel(edition);
    final root = await _rootDir();
    if (root == null) return;
    final dir = Directory(p.join(root.path, edition));
    if (await dir.exists()) await dir.delete(recursive: true);
    if (ref.mounted) state = {...state}..remove(edition);
  }

  void _set(String edition, ReciterDownload download) =>
      state = {...state, edition: download};
}

final reciterDownloadsProvider =
    NotifierProvider<ReciterDownloads, Map<String, ReciterDownload>>(
      ReciterDownloads.new,
    );
