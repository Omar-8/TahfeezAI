// The Mushaf's pages as the phones carry them: 4 to an xz file. Lossless —
// every page, unpacked, byte for byte its .qvp — and read as the reader
// needs them: a group unpacked once, kept with the last few, the next one
// unpacked ahead of time.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/data/quran_engine/quran_engine_page_groups.dart';

const _dir = 'assets/quran/quran_engine';

/// Unpacks as the phone's code would (the xz tool here).
Future<({Uint8List bytes, String sha256})> _xz(String asset) async {
  final out = await Process.run('xz', [
    '-d',
    '-c',
    asset,
  ], stdoutEncoding: null);
  final bytes = Uint8List.fromList(out.stdout as List<int>);
  return (bytes: bytes, sha256: sha256.convert(bytes).toString());
}

Future<String> _file(String asset) async => File(asset).readAsStringSync();

void main() {
  group('the packed pages', () {
    final index = jsonDecode(
      File('$_dir/page_groups.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final groups = index['groups'] as List;

    test('every page, in order, 4 to a group (a spread never split)', () {
      expect(index['groupSize'], 4);
      expect(index['pageCount'], 604);
      expect(groups, hasLength(151));
      expect([for (final g in groups) ...g['pages'] as List], hasLength(604));
    });

    test('lossless: every page unpacked is byte for byte its .qvp', () async {
      final pages = QuranEnginePageGroups(loadString: _file, unpack: _xz);
      for (var n = 1; n <= 604; n++) {
        final original = File('$_dir/pages/${n.toString().padLeft(3, '0')}.qvp')
            .readAsBytesSync();
        expect(await pages.page(n), original, reason: 'page $n');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('small to unpack: ~1 MB of memory at most (its dictionary)', () {
      for (final g in groups) {
        final total = (g['pages'] as List).cast<int>().fold(0, (a, b) => a + b);
        expect(total, lessThan(1 << 20), reason: g['asset'] as String);
      }
    });
  });

  group('reading them', () {
    // Three groups of 2 pages: "a1 a2", "b1 b2", "c1 c2", "d1 d2".
    final contents = [
      for (final g in ['a', 'b', 'c', 'd']) utf8.encode('${g}1${g}22'),
    ];
    late List<String> unpacked;
    late QuranEnginePageGroups pages;
    var corrupt = false;

    setUp(() {
      unpacked = [];
      corrupt = false;
      final index = {
        'groupSize': 2,
        'pageCount': 8,
        'groups': [
          for (final (i, c) in contents.indexed)
            {
              'asset': 'page_groups/$i.xz',
              'sha256': sha256.convert(c).toString(),
              'pages': [2, 3],
            },
        ],
      };
      pages = QuranEnginePageGroups(
        loadString: (_) async => jsonEncode(index),
        unpack: (asset) async {
          unpacked.add(asset.split('/').last);
          final i = int.parse(asset.split('/').last.split('.').first);
          final bytes = Uint8List.fromList(
            corrupt ? utf8.encode('broken') : contents[i],
          );
          return (bytes: bytes, sha256: sha256.convert(bytes).toString());
        },
      );
    });

    Future<String> page(int n) async => utf8.decode(await pages.page(n));

    test('each page cut from its group', () async {
      expect(await page(1), 'a1');
      expect(await page(2), 'a22');
      expect(await page(7), 'd1');
      expect(await page(8), 'd22');
    });

    test(
      'a group unpacked once: its other page, and back, cost nothing',
      () async {
        await page(3);
        await page(4);
        await page(3);
        expect(unpacked, ['1.xz']);
      },
    );

    test('asked twice at once: unpacked once', () async {
      await Future.wait([page(5), page(6)]);
      expect(unpacked, ['2.xz']);
    });

    test('only the last few kept', () async {
      for (final n in [1, 3, 5, 7]) {
        await page(n);
      }
      expect(pages.unpackedGroups, QuranEnginePageGroups.kept);
      unpacked.clear();
      await page(7); // kept
      await page(1); // the oldest, let go: unpacked again
      expect(unpacked, ['0.xz']);
    });

    test(
      'the groups either side unpacked ahead: reading on never waits',
      () async {
        await page(3);
        await pages.preloadAround(3);
        expect(unpacked.toSet(), {'0.xz', '1.xz', '2.xz'});
        unpacked.clear();
        await page(5);
        await page(2);
        expect(unpacked, isEmpty);
      },
    );

    test('ahead at the ends: nothing past the first or last', () async {
      await pages.preloadAround(1);
      await pages.preloadAround(8);
      expect(unpacked.toSet(), {'1.xz', '2.xz'});
    });

    test('a group failing its hash: an error, tried again next time', () async {
      corrupt = true;
      await expectLater(
        pages.page(1),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('hash verification'),
          ),
        ),
      );
      corrupt = false;
      expect(await page(1), 'a1');
    });

    test('no such page', () async {
      await expectLater(pages.page(0), throwsRangeError);
      await expectLater(pages.page(9), throwsRangeError);
    });
  });
}
