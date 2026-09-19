import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

void main() {
  group('against an empty (uninstalled) Quran database', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          quranDatabaseProvider.overrideWith(
            (ref) => QuranDatabase(NativeDatabase.memory()),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('indexedSurahs is empty', () async {
      expect(await container.read(indexedSurahsProvider.future), isEmpty);
    });

    test('indexedJuzList and indexedHizbList are empty', () async {
      expect(await container.read(indexedJuzListProvider.future), isEmpty);
      expect(await container.read(indexedHizbListProvider.future), isEmpty);
    });

    test('defaultMushaf is null', () async {
      expect(await container.read(defaultMushafProvider.future), isNull);
    });
  });

  group('against an installed Quran dataset', () {
    late QuranDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      container = ProviderContainer(
        overrides: [quranDatabaseProvider.overrideWith((ref) => db)],
      );
    });

    tearDown(() => container.dispose());

    test(
      'indexedSurahs resolves all 114 chapters with surah 1 localized',
      () async {
        final surahs = await container.read(indexedSurahsProvider.future);
        expect(surahs, hasLength(114));

        final first = surahs.first;
        expect(first.surah.surahNo, 1);
        expect(first.localizedName, 'Test Chapter One');
        // The fixture only localizes chapter 1 into English, none into
        // Arabic, so the Arabic name is honestly absent rather than
        // fabricated.
        expect(first.arabicName, isNull);

        final second = surahs[1];
        expect(second.localizedName, isNull);
      },
    );

    test('indexedJuzList groups ranges by unit number', () async {
      final juzList = await container.read(indexedJuzListProvider.future);
      expect(juzList, hasLength(1));
      expect(juzList.single.unitNo, 1);
      expect(juzList.single.start.surahNo, 1);
      expect(juzList.single.start.startAyahNo, 1);
    });

    test('indexedHizbList groups ranges by unit number', () async {
      final hizbList = await container.read(indexedHizbListProvider.future);
      expect(hizbList, hasLength(1));
      expect(hizbList.single.unitNo, 1);
    });

    test(
      'defaultMushaf is still null: the fixture uses a different script code '
      'than defaultQuranScriptCode, which is exactly the honest '
      '"no matching default Mushaf" state until Settings (Milestone 14) '
      'supplies a real script preference',
      () async {
        expect(await container.read(defaultMushafProvider.future), isNull);
      },
    );
  });
}
