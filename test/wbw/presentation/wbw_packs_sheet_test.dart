import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';
import 'package:tahfeez_ai/wbw/domain/models/wbw_models.dart';
import 'package:tahfeez_ai/wbw/domain/wbw_pack_catalog.dart';
import 'package:tahfeez_ai/wbw/presentation/wbw_packs_sheet.dart';
import 'package:tahfeez_ai/wbw/wbw_providers.dart';

import '../wbw_test_fixtures.dart';

class _FakeWbwPackCatalog implements WbwPackCatalog {
  _FakeWbwPackCatalog(this._packs);

  final List<WbwLanguagePack> _packs;

  @override
  Future<List<WbwLanguagePack>> availablePacks() async => _packs;
}

void main() {
  Widget wrap(WbwDatabase db, {List<WbwLanguagePack> catalogPacks = const []}) {
    return ProviderScope(
      overrides: [
        wbwDatabaseProvider.overrideWith((ref) => db),
        wbwPackCatalogProvider.overrideWith(
          (ref) => _FakeWbwPackCatalog(catalogPacks),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showWbwPacksSheet(context),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows an empty state with no packs known', (tester) async {
    final db = WbwDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(
      find.text('No word-by-word language packs available yet.'),
      findsOneWidget,
    );
  });

  testWidgets('installing a cataloged pack marks it downloaded', (
    tester,
  ) async {
    final db = WbwDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db, catalogPacks: [buildTestWbwPack()]));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.download_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
