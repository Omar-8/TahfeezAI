import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';

/// How the tafsir reader lays its ayahs out.
enum TafsirLayout {
  /// One ayah, with Previous / Next.
  paged,

  /// Ayah after ayah, scrolled through.
  continuous,
}

/// The tafsir reader's view: its layout, and whether each ayah shows the
/// chosen translations and its transliteration above the commentary.
@immutable
class TafsirReaderPreferences {
  const TafsirReaderPreferences({
    this.layout = TafsirLayout.paged,
    this.showTranslation = true,
    this.showTransliteration = false,
  });

  final TafsirLayout layout;
  final bool showTranslation, showTransliteration;

  TafsirReaderPreferences copyWith({
    TafsirLayout? layout,
    bool? showTranslation,
    bool? showTransliteration,
  }) => TafsirReaderPreferences(
    layout: layout ?? this.layout,
    showTranslation: showTranslation ?? this.showTranslation,
    showTransliteration: showTransliteration ?? this.showTransliteration,
  );
}

/// Saved with every change (local storage).
class TafsirReaderPreferencesController
    extends Notifier<TafsirReaderPreferences> {
  static const _layoutKey = 'tafsir.reader.layout';
  static const _translationKey = 'tafsir.reader.translation';
  static const _transliterationKey = 'tafsir.reader.transliteration';

  @override
  TafsirReaderPreferences build() {
    _restore();
    return const TafsirReaderPreferences();
  }

  Future<void> _restore() async {
    final storage = ref.read(browserStorageProvider);
    final layout = await storage.getString(_layoutKey);
    final translation = await storage.getBool(_translationKey);
    final transliteration = await storage.getBool(_transliterationKey);
    if (!ref.mounted) return;
    state = state.copyWith(
      layout: TafsirLayout.values.asNameMap()[layout],
      showTranslation: translation,
      showTransliteration: transliteration,
    );
  }

  Future<void> set(TafsirReaderPreferences value) async {
    state = value;
    final storage = ref.read(browserStorageProvider);
    await storage.setString(_layoutKey, value.layout.name);
    await storage.setBool(_translationKey, value.showTranslation);
    await storage.setBool(_transliterationKey, value.showTransliteration);
  }
}

final tafsirReaderPreferencesProvider =
    NotifierProvider<
      TafsirReaderPreferencesController,
      TafsirReaderPreferences
    >(TafsirReaderPreferencesController.new);
