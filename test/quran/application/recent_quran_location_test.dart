import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/quran/application/recent_quran_location.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/quran_location_path.dart';

void main() {
  group('RecentQuranLocationController', () {
    test('starts null and records a location', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(recentQuranLocationControllerProvider), isNull);

      await container
          .read(recentQuranLocationControllerProvider.notifier)
          .record(const QuranLocation.surah(2));

      expect(
        container.read(recentQuranLocationControllerProvider),
        const QuranLocation.surah(2),
      );
    });

    test(
      'persists the recorded location as its canonical path string',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(recentQuranLocationControllerProvider.notifier)
            .record(const QuranLocation.juz(5));

        final stored = await container
            .read(browserStorageProvider)
            .getString('quran.recent_location');
        expect(stored, quranLocationPath(const QuranLocation.juz(5)));
      },
    );
  });
}
