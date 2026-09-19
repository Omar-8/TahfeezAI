import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/reader/application/reader_session_controller.dart';
import 'package:tahfeez_ai/features/reader/domain/reader_layout_item.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

void main() {
  late QuranDatabase db;
  late TranslationDatabase translationDb;
  late ProviderContainer container;

  setUp(() async {
    db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    translationDb = TranslationDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        // ReaderSession always watches `translationRepositoryProvider`
        // (even with no active translations selected), so it must never
        // fall through to the real drift_flutter connection in tests —
        // the same reasoning `quranDatabaseProvider`'s override exists for.
        translationDatabaseProvider.overrideWith((ref) => translationDb),
        // The synthetic fixture uses its own script code, not the
        // production default -- see `quranScriptCodeProvider`'s doc
        // comment for why this must be overridden rather than assumed.
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    translationDb.close();
  });

  group('full Surah', () {
    test('surah 1 (skips Bismillah): chapter info + all 7 verses', () async {
      final state = await container.read(
        readerSessionProvider(const QuranLocation.surah(1)).future,
      );

      expect(state.items.whereType<ReaderChapterInfoItem>(), hasLength(1));
      expect(state.items.whereType<ReaderBismillahItem>(), isEmpty);
      expect(state.items.whereType<ReaderVerseItem>(), hasLength(7));
      expect(state.scrollToAyahId, 1001);
      expect(state.canLoadMore, isTrue);
    });

    test('surah 2 gets a Bismillah (not chapter 1 or 9)', () async {
      final state = await container.read(
        readerSessionProvider(const QuranLocation.surah(2)).future,
      );

      expect(state.items.whereType<ReaderBismillahItem>(), hasLength(1));
      expect(state.items.whereType<ReaderVerseItem>(), hasLength(2));
    });

    test('surah 114 (the last chapter) cannot load more', () async {
      final state = await container.read(
        readerSessionProvider(const QuranLocation.surah(114)).future,
      );
      expect(state.canLoadMore, isFalse);
    });
  });

  group('individual Ayah', () {
    test(
      'loads the whole containing chapter, scrolled to that verse',
      () async {
        final state = await container.read(
          readerSessionProvider(const QuranLocation.ayah(1, 3)).future,
        );

        expect(state.items.whereType<ReaderVerseItem>(), hasLength(7));
        expect(state.scrollToAyahId, 1003);
      },
    );
  });

  group('verse range', () {
    test('loads only the requested range, not the whole chapter', () async {
      final state = await container.read(
        readerSessionProvider(const QuranLocation.ayahRange(2, 1, 2)).future,
      );

      final verses = state.items.whereType<ReaderVerseItem>().toList();
      expect(verses, hasLength(2));
      expect(state.items.whereType<ReaderChapterInfoItem>(), hasLength(1));
      // Ranges never insert a Bismillah -- they're a quoted excerpt, not a
      // chapter start.
      expect(state.items.whereType<ReaderBismillahItem>(), isEmpty);
      expect(state.scrollToAyahId, 2001);
    });
  });

  group('Juz', () {
    test('loads every chapter segment the Juz spans', () async {
      final state = await container.read(
        readerSessionProvider(const QuranLocation.juz(1)).future,
      );

      expect(state.items.whereType<ReaderVerseItem>(), hasLength(7));
      expect(state.scrollToAyahId, 1001);
    });

    test('an unknown Juz number resolves to no content', () async {
      final state = await container.read(
        readerSessionProvider(const QuranLocation.juz(999)).future,
      );
      expect(state.items, isEmpty);
    });
  });

  group('Hizb', () {
    test('loads every chapter segment the Hizb spans', () async {
      final state = await container.read(
        readerSessionProvider(const QuranLocation.hizb(1)).future,
      );
      expect(state.items.whereType<ReaderVerseItem>(), hasLength(7));
    });
  });

  group('continuous scrolling (loadMore)', () {
    test(
      'appends the next chapter with a ChapterTitle marker, not ChapterInfo',
      () async {
        const location = QuranLocation.surah(1);
        // Prime the provider.
        await container.read(readerSessionProvider(location).future);

        final notifier = container.read(
          readerSessionProvider(location).notifier,
        );
        await notifier.loadMore();

        final state = container.read(readerSessionProvider(location)).value!;
        expect(state.items.whereType<ReaderChapterTitleItem>(), hasLength(1));
        expect(state.items.whereType<ReaderChapterInfoItem>(), hasLength(1));
        // 7 verses from surah 1 + 2 from surah 2.
        expect(state.items.whereType<ReaderVerseItem>(), hasLength(9));
        expect(state.canLoadMore, isTrue);
      },
    );

    test('is a no-op once canLoadMore is false', () async {
      const location = QuranLocation.surah(114);
      await container.read(readerSessionProvider(location).future);

      final notifier = container.read(readerSessionProvider(location).notifier);
      final before = container.read(readerSessionProvider(location)).value!;
      await notifier.loadMore();
      final after = container.read(readerSessionProvider(location)).value!;

      expect(after.items.length, before.items.length);
    });

    test('concurrent calls only append the next chapter once', () async {
      const location = QuranLocation.surah(1);
      await container.read(readerSessionProvider(location).future);
      final notifier = container.read(readerSessionProvider(location).notifier);

      await Future.wait([notifier.loadMore(), notifier.loadMore()]);

      final state = container.read(readerSessionProvider(location)).value!;
      // Exactly one extra chapter (surah 2, 2 verses) appended -- not two.
      expect(state.items.whereType<ReaderVerseItem>(), hasLength(9));
    });
  });

  group('selection', () {
    test(
      'toggleSelection adds and removes; clearSelection empties it',
      () async {
        const location = QuranLocation.surah(1);
        await container.read(readerSessionProvider(location).future);
        final notifier = container.read(
          readerSessionProvider(location).notifier,
        );

        notifier.toggleSelection(1001);
        notifier.toggleSelection(1002);
        expect(
          container
              .read(readerSessionProvider(location))
              .value!
              .selectedAyahIds,
          {1001, 1002},
        );

        notifier.toggleSelection(1001);
        expect(
          container
              .read(readerSessionProvider(location))
              .value!
              .selectedAyahIds,
          {1002},
        );

        notifier.clearSelection();
        expect(
          container
              .read(readerSessionProvider(location))
              .value!
              .selectedAyahIds,
          isEmpty,
        );
      },
    );
  });
}
