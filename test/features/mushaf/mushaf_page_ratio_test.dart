import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_pager.dart';

/// The web frame's size before a page reports its own (owner, 2026-11-15:
/// it opened the screen's whole width, then narrowed): every bundled page's
/// shape, from its .qvp header (width, height: floats at bytes 12 and 16).
void main() {
  test('every bundled page is the shape the web frame starts with', () {
    final pages = Directory('assets/quran/quran_engine/pages')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.qvp'))
        .toList();
    if (pages.isEmpty) {
      markTestSkipped('the page data is not on this machine');
      return;
    }
    expect(pages, hasLength(604));
    for (final f in pages) {
      final head = ByteData.sublistView(f.openSync().readSync(20));
      expect(String.fromCharCodes(head.buffer.asUint8List(0, 4)), 'QVP1');
      final w = head.getFloat32(12, Endian.little);
      final h = head.getFloat32(16, Endian.little);
      expect(w / h, closeTo(kMushafPageAspectRatio, 1e-6), reason: f.path);
    }
  });
}
