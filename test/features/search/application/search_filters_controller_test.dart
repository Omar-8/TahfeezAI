import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/search/application/search_filters_controller.dart';
import 'package:tahfeez_ai/quran/domain/models/search_models.dart';

void main() {
  setUp(() async {
    final cleanup = ProviderContainer();
    await cleanup.read(browserStorageProvider).remove('search.filters');
    cleanup.dispose();
  });

  test('defaults to every domain enabled and no slug restriction', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final filters = container.read(searchFiltersControllerProvider);
    expect(filters.includeArabicText, isTrue);
    expect(filters.includeSurahs, isTrue);
    expect(filters.translationSlugs, isNull);
  });

  test('update replaces the filters and persists them', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(searchFiltersControllerProvider.notifier)
        .update(
          const SearchFilters(
            includeArabicText: false,
            translationSlugs: {'en-a', 'en-b'},
          ),
        );

    final filters = container.read(searchFiltersControllerProvider);
    expect(filters.includeArabicText, isFalse);
    expect(filters.includeSurahs, isTrue);
    expect(filters.translationSlugs, {'en-a', 'en-b'});

    final stored = await container
        .read(browserStorageProvider)
        .getString('search.filters');
    expect(stored, isNotNull);
  });

  test(
    'an empty translationSlugs set round-trips as empty, not null',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(searchFiltersControllerProvider.notifier)
          .update(const SearchFilters(translationSlugs: {}));

      expect(
        container.read(searchFiltersControllerProvider).translationSlugs,
        isEmpty,
      );
    },
  );
}
