import 'dart:convert';

import 'package:flutter/services.dart';

/// Unpacks bundled [asset] (xz) into memory: its bytes and their SHA-256.
typedef PageGroupUnpacker = Future<({Uint8List bytes, String sha256})> Function(
  String asset,
);

/// The Mushaf's pages as the phones carry them: every 4 pages one xz file
/// (`assets/quran/quran_engine/page_groups/`, made by
/// `tool/quran_engine/pack_pages.py`; lossless — each page byte for byte
/// its .qvp). ~10 MB less to download than the 604 files, and ~49 MB less
/// on an iPhone (which keeps app files uncompressed).
///
/// A group is unpacked (natively, ~40 ms on a phone) when one of its pages
/// is needed, checked against its hash, and kept with the last few — so
/// its other pages, and turning back and forth, cost nothing; the next and
/// previous groups are unpacked ahead of time ([preloadAround]), so reading
/// on never waits for one.
class QuranEnginePageGroups {
  QuranEnginePageGroups({
    Future<String> Function(String asset)? loadString,
    PageGroupUnpacker? unpack,
  }) : _loadString = loadString ?? rootBundle.loadString,
       _unpack = unpack ?? nativeUnpack;

  final Future<String> Function(String asset) _loadString;
  final PageGroupUnpacker _unpack;

  static const dir = 'assets/quran/quran_engine';

  /// How many groups are kept unpacked (12 pages, ~1.6 MB).
  static const kept = 3;

  static const _channel = MethodChannel('tahfeez/bundled_db');

  /// The platform's own code unpacking an xz asset into memory (Android's
  /// BundledDatabaseChannel.kt, iOS's BundledDatabaseChannel.swift).
  static Future<({Uint8List bytes, String sha256})> nativeUnpack(
    String asset,
  ) async {
    final result = (await _channel.invokeMapMethod<String, Object?>(
      'unpackBytes',
      {'asset': asset},
    ))!;
    return (
      bytes: result['bytes']! as Uint8List,
      sha256: result['sha256']! as String,
    );
  }

  Future<_Index>? _index;

  /// Most recently used last.
  final _groups = <int, Future<Uint8List>>{};

  Future<_Index> _read() =>
      _index ??= _loadString('$dir/page_groups.json')
          .then((text) => _Index(jsonDecode(text) as Map<String, dynamic>));

  /// Page [pageNumber]'s .qvp bytes.
  Future<Uint8List> page(int pageNumber) async {
    final index = await _read();
    if (pageNumber < 1 || pageNumber > index.pageCount) {
      throw RangeError.range(pageNumber, 1, index.pageCount, 'pageNumber');
    }
    final group = (pageNumber - 1) ~/ index.groupSize;
    final bytes = await _group(index, group);
    final sizes = index.groups[group].pages;
    final within = (pageNumber - 1) % index.groupSize;
    var offset = 0;
    for (var i = 0; i < within; i++) {
      offset += sizes[i];
    }
    return Uint8List.sublistView(bytes, offset, offset + sizes[within]);
  }

  /// Unpacks the groups either side of [pageNumber]'s ahead of time.
  Future<void> preloadAround(int pageNumber) async {
    final index = await _read();
    final group = (pageNumber - 1) ~/ index.groupSize;
    await Future.wait([
      for (final g in [group + 1, group - 1])
        if (g >= 0 && g < index.groups.length)
          _group(index, g).then((_) {}, onError: (_) {}),
    ]);
  }

  /// How many groups are unpacked now (for tests).
  int get unpackedGroups => _groups.length;

  Future<Uint8List> _group(_Index index, int group) {
    final cached = _groups.remove(group);
    if (cached != null) {
      _groups[group] = cached;
      return cached;
    }
    final entry = index.groups[group];
    final future = _unpack('$dir/${entry.asset}').then((unpacked) {
      if (unpacked.sha256 != entry.sha256) {
        throw StateError(
          'Mushaf pages ${entry.asset} failed hash verification '
          '(expected ${entry.sha256}, got ${unpacked.sha256})',
        );
      }
      return unpacked.bytes;
    });
    _groups[group] = future;
    // (A failure isn't kept: tried again next time.)
    future.then(
      (_) {},
      onError: (_) {
        if (identical(_groups[group], future)) _groups.remove(group);
      },
    );
    while (_groups.length > kept) {
      _groups.remove(_groups.keys.first);
    }
    return future;
  }
}

class _Index {
  _Index(Map<String, dynamic> json)
    : groupSize = json['groupSize'] as int,
      pageCount = json['pageCount'] as int,
      groups = [
        for (final g in json['groups'] as List)
          (
            asset: g['asset'] as String,
            sha256: g['sha256'] as String,
            pages: (g['pages'] as List).cast<int>(),
          ),
      ];

  final int groupSize;
  final int pageCount;
  final List<({String asset, String sha256, List<int> pages})> groups;
}
