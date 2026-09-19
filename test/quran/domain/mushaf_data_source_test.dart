// Tests the GENERIC word-id -> (ayah, wordIndex) resolution logic in
// mushaf_data_source.dart using small synthetic fixtures. This tests the
// conversion mechanism itself, never real Mushaf layout/word content — no
// synthetic Mushaf layout data is shipped or treated as real anywhere in
// this project; see docs/QURAN_DATA_PROVENANCE.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/domain/mushaf_data_source.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';

class _FakeResolver implements MushafWordIdResolver {
  _FakeResolver(this._map);
  final Map<int, ({int ayahId, int wordIndex})> _map;

  @override
  ({int ayahId, int wordIndex})? resolve(int wordId) => _map[wordId];
}

void main() {
  group('resolveMushafLines', () {
    test('resolves a Quran-text line word range via the resolver', () {
      final layout = RawMushafLayout(
        editionCode: 'test-edition',
        pageCount: 1,
        linesPerPage: 2,
        lines: const [
          RawMushafLine(
            pageNumber: 1,
            lineNumber: 1,
            lineType: MushafLineType.surahHeader,
            isCentered: true,
            surahNo: 1,
          ),
          RawMushafLine(
            pageNumber: 1,
            lineNumber: 2,
            lineType: MushafLineType.quranText,
            isCentered: false,
            firstWordId: 10,
            lastWordId: 12,
          ),
        ],
      );
      final resolver = _FakeResolver({
        10: (ayahId: 1001, wordIndex: 0),
        12: (ayahId: 1001, wordIndex: 2),
      });

      final result = resolveMushafLines(
        layout: layout,
        resolver: resolver,
        mushafId: 1,
      );

      expect(result, hasLength(2));
      expect(result[0].lineType, MushafLineType.surahHeader);
      expect(result[0].startAyahId, isNull);
      expect(result[1].startAyahId, 1001);
      expect(result[1].startWordIndex, 0);
      expect(result[1].endAyahId, 1001);
      expect(result[1].endWordIndex, 2);
    });

    test('a header line with no word range needs no resolution', () {
      final layout = RawMushafLayout(
        editionCode: 'test-edition',
        pageCount: 1,
        linesPerPage: 1,
        lines: const [
          RawMushafLine(
            pageNumber: 1,
            lineNumber: 1,
            lineType: MushafLineType.bismillah,
            isCentered: true,
          ),
        ],
      );
      final result = resolveMushafLines(
        layout: layout,
        resolver: _FakeResolver(const {}),
        mushafId: 1,
      );
      expect(result.single.startAyahId, isNull);
      expect(result.single.endAyahId, isNull);
    });

    test('throws when the resolver cannot resolve a referenced word id', () {
      final layout = RawMushafLayout(
        editionCode: 'test-edition',
        pageCount: 1,
        linesPerPage: 1,
        lines: const [
          RawMushafLine(
            pageNumber: 3,
            lineNumber: 5,
            lineType: MushafLineType.quranText,
            isCentered: false,
            firstWordId: 999,
            lastWordId: 1000,
          ),
        ],
      );
      expect(
        () => resolveMushafLines(
          layout: layout,
          resolver: _FakeResolver(const {}),
          mushafId: 1,
        ),
        throwsA(
          isA<MushafWordIdResolutionException>()
              .having((e) => e.pageNumber, 'pageNumber', 3)
              .having((e) => e.lineNumber, 'lineNumber', 5),
        ),
      );
    });
  });
}
