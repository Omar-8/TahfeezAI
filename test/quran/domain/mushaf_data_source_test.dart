// Tests mushafLineFromRaw's field mapping using small synthetic fixtures.
// This tests the conversion mechanism itself, never real Mushaf layout
// content — no synthetic Mushaf layout data is shipped or treated as real
// anywhere in this project; see docs/QURAN_DATA_PROVENANCE.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/domain/mushaf_data_source.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';

void main() {
  group('mushafLineFromRaw', () {
    test('copies a Quran-text line\'s token range across directly', () {
      const raw = RawMushafLine(
        pageNumber: 1,
        lineNumber: 2,
        lineType: MushafLineType.quranText,
        isCentered: false,
        firstWordId: 10,
        lastWordId: 12,
      );

      final line = mushafLineFromRaw(raw, mushafId: 1);

      expect(line.mushafId, 1);
      expect(line.pageNumber, 1);
      expect(line.lineNumber, 2);
      expect(line.lineType, MushafLineType.quranText);
      expect(line.firstTokenId, 10);
      expect(line.lastTokenId, 12);
    });

    test('a header line with no token range stays null, not fabricated', () {
      const raw = RawMushafLine(
        pageNumber: 1,
        lineNumber: 1,
        lineType: MushafLineType.surahHeader,
        isCentered: true,
        surahNo: 1,
      );

      final line = mushafLineFromRaw(raw, mushafId: 1);

      expect(line.firstTokenId, isNull);
      expect(line.lastTokenId, isNull);
      expect(line.surahNo, 1);
    });
  });
}
