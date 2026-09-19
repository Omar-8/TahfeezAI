import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/quick_link_parser.dart';

void main() {
  const parser = QuickLinkParser();

  test('parses a verse jump', () {
    final links = parser.parse('2:255');
    expect(links, hasLength(1));
    expect(links.single.location, const QuranLocation.ayah(2, 255));
  });

  test('parses a verse-range jump', () {
    final links = parser.parse('2:255-257');
    expect(links, hasLength(1));
    expect(links.single.location, const QuranLocation.ayahRange(2, 255, 257));
  });

  test('rejects a verse-range where the end precedes the start', () {
    expect(parser.parse('2:257-255'), isEmpty);
  });

  test('rejects an out-of-range chapter number', () {
    expect(parser.parse('115:1'), isEmpty);
    expect(parser.parse('0:1'), isEmpty);
  });

  test('a bare chapter-range number resolves to both Surah and Juz', () {
    final links = parser.parse('5');
    expect(links, hasLength(2));
    expect(links[0].location, const QuranLocation.surah(5));
    expect(links[1].location, const QuranLocation.juz(5));
  });

  test('a bare number beyond the Juz count resolves to Surah only', () {
    final links = parser.parse('50');
    expect(links, hasLength(1));
    expect(links.single.location, const QuranLocation.surah(50));
  });

  test('a bare number beyond the chapter count resolves to nothing', () {
    expect(parser.parse('200'), isEmpty);
  });

  test('an unrecognized shape resolves to nothing', () {
    expect(parser.parse('hello world'), isEmpty);
    expect(parser.parse(''), isEmpty);
    expect(parser.parse('2:255:extra'), isEmpty);
  });
}
