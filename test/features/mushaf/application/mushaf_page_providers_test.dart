import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_providers.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../mushaf_test_fixtures.dart';

void main() {
  test(
    'mushafPageDataProvider stays cached after its last listener drops -- '
    'keepAlive: true, so swiping back to an already-visited page reuses '
    "the cached bundle instead of re-querying the database and redoing "
    "that page's layout pass (a real, measurable scroll-jank contributor)",
    () async {
      final db = QuranDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await const QuranDatasetImporter().import(db, buildMushafTestPayload());

      final container = ProviderContainer(
        overrides: [
          quranDatabaseProvider.overrideWith((ref) => db),
          quranScriptCodeProvider.overrideWith((ref) => mushafTestScriptCode),
        ],
      );
      addTearDown(container.dispose);

      final provider = mushafPageDataProvider(mushafTestMushafId, 1);

      // Establish and resolve the provider, then drop every listener --
      // the point at which a plain (non-keepAlive) autoDispose provider
      // would tear itself down.
      final subscription = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      subscription.close();

      // Still resolved, synchronously, with no listener re-establishing
      // it -- proof the state survived rather than being disposed and
      // needing a fresh async fetch on the next read.
      final stillCached = container.read(provider);
      expect(stillCached.hasValue, isTrue);
      expect(stillCached.value?.pageNumber, 1);
    },
  );
}
