import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/athkar/data/athkar_source.dart';
import 'package:tahfeez_ai/features/athkar/domain/athkar.dart';
import 'package:tahfeez_ai/features/athkar/presentation/athkar_look.dart';

/// The bundled athkar (Hisn al-Muslim, from hisnmuslim.com — built by
/// tool/athkar/build_athkar.py): whole, and each chapter in one section.
void main() {
  final book = AthkarBook.fromJson(
    jsonDecode(utf8.decode(gzip.decode(File(kAthkarAsset).readAsBytesSync())))
        as Map<String, Object?>,
  );
  final athkar = [for (final c in book.categories) ...c.athkar];

  test('the whole book: 132 chapters, 267 athkar, each said at least once', () {
    expect(book.categories, hasLength(132));
    expect(athkar, hasLength(267));
    expect({for (final z in athkar) z.id}, hasLength(267), reason: 'ids');
    expect({for (final c in book.categories) c.id}, hasLength(132));
    for (final z in athkar) {
      expect(z.repeat, greaterThanOrEqualTo(1), reason: '${z.id}');
      expect(z.arabic.trim(), isNotEmpty, reason: '${z.id}');
    }
    for (final c in book.categories) {
      expect(c.arabic, isNotEmpty);
      expect(c.english, isNotEmpty);
      expect(c.athkar, isNotEmpty, reason: '${c.id}');
    }
  });

  test("Morning & Evening's athkar, as the book has them", () {
    final me = book.category(AthkarBook.morningEvening)!;
    expect(me.arabic, 'أذكار الصباح والمساء');
    expect(me.athkar, hasLength(24));
    // Ayat al-Kursi first, once; "SubhanAllah wa bihamdih" a hundred times.
    final bare = me.athkar.first.arabic.replaceAll(
      RegExp('[\u064B-\u0652]'),
      '',
    );
    expect(bare, contains('الله لا إله إلا هو الحي القيوم'));
    expect(me.athkar.first.repeat, 1);
    expect(me.athkar.map((z) => z.repeat), contains(100));
  });

  test('no presentation-form letters left (shown as ordinary letters)', () {
    // (The ornate brackets round the Quran quoted, U+FD3E-FD3F, are meant.)
    final forms = RegExp(r'[\uFB50-\uFD3D\uFD40-\uFDCF\uFE70-\uFEFF]');
    for (final c in book.categories) {
      expect(forms.hasMatch(c.arabic), isFalse, reason: c.arabic);
      for (final z in c.athkar) {
        expect(forms.hasMatch(z.arabic), isFalse, reason: '${z.id}');
      }
    }
  });

  test('every chapter in exactly one section, with an icon', () {
    final placed = [for (final g in AthkarGroup.values) ...g.categories];
    expect(placed, hasLength(132));
    expect(placed.toSet(), {for (final c in book.categories) c.id});
    for (final c in book.categories) {
      expect(AthkarGroup.of(c.id), isNotNull);
      expect(athkarCategoryIcon(c.id), isNotNull);
    }
  });

  test('audio from hisnmuslim.com, over https', () {
    final me = book.category(AthkarBook.morningEvening)!;
    expect(
      athkarAudioUri(me.audio).toString(),
      startsWith('https://www.hisnmuslim.com/audio/ar/'),
    );
    expect(
      athkar.where((z) => z.audio != null).length,
      greaterThan(260),
      reason: 'all but one have their own',
    );
  });

  test('names: short (Tahfeez\'s own — owner, 2026-11-21), the book\'s in '
      'full beside them; Arabic in Arabic, else English', () {
    final waking = book.category(1)!;
    expect(waking.english, 'Supplications for when you wake up');
    expect(waking.titleIn('en'), 'Waking up');
    expect(waking.titleIn('fr'), 'Waking up');
    expect(waking.fullTitleIn('en'), waking.english);
    expect(waking.titleIn('ar'), 'أذكار الاستيقاظ من النوم', reason: 'short');
    expect(book.category(110)!.titleIn('ar'), 'صياح الديك ونهيق الحمار');
    for (final c in book.categories) {
      expect(c.shortEnglish, isNotNull, reason: '${c.id}');
      expect(c.titleIn('en').length, lessThanOrEqualTo(36), reason: c.english);
      expect(c.titleIn('ar').length, lessThanOrEqualTo(36), reason: c.arabic);
    }
  });
}
