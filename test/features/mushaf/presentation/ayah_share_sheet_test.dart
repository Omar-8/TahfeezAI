import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/sharing/image_sharer.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_share_sheet.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/quran/application/ayah_reading_extras.dart';
import 'package:tahfeez_ai/quran/application/canonical_ayah_word_text.dart';

class _Sharer implements ImageSharer {
  Uint8List? png;
  String? name;
  Rect? origin;

  @override
  Future<void> sharePng(
    Uint8List png, {
    required String fileName,
    Rect? origin,
  }) async {
    this.png = png;
    name = fileName;
    this.origin = origin;
  }
}

/// An ayah shared as an image: the card drawn to a PNG, named after the
/// ayah, handed to the share sheet from the Share button (where an iPad's
/// popover points).
void main() {
  testWidgets('Share: the card as a PNG, 112:1\'s name, from the button', (
    tester,
  ) async {
    final sharer = _Sharer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageSharerProvider.overrideWithValue(sharer),
          canonicalAyahTextProvider(ayahId: 112001)
              .overrideWith((ref) async => 'قُلْ هُوَ ٱللَّهُ أَحَدٌ'),
          ayahTranslationsProvider.overrideWith((ref, id) async => const {}),
          indexedSurahsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAyahShareSheet(context, ayahId: 112001),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('قُلْ هُوَ ٱللَّهُ أَحَدٌ'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Share'));
      for (var i = 0; i < 50 && sharer.png == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(sharer.name, 'tahfeezai-112-1.png');
    // A PNG (its signature).
    expect(sharer.png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(sharer.origin, isNotNull);
    expect(sharer.origin!.isEmpty, isFalse);
  });
}
