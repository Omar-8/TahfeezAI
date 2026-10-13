import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';

/// How the Mushaf's pages are shown: as printed, or ayah by ayah with
/// their translation, transliteration, tafsir and word meanings (Ayah
/// mode). Both serve the same pages, bar and modes.
enum ReaderMode { mushaf, ayah }

/// How Ayah mode moves through the Quran.
enum AyahLayout {
  /// The Mushaf's pages, swiped (or Previous / Next page).
  paged,

  /// One continuous scroll.
  continuous,
}

/// Ayah mode's view: its layout, and what each ayah shows under its
/// Arabic.
@immutable
class AyahViewPreferences {
  const AyahViewPreferences({
    this.layout = AyahLayout.paged,
    this.showTranslation = true,
    this.showTransliteration = false,
    this.showTafsir = false,
    this.showWordMeanings = false,
  });

  final AyahLayout layout;
  final bool showTranslation, showTransliteration, showTafsir;
  final bool showWordMeanings;

  AyahViewPreferences copyWith({
    AyahLayout? layout,
    bool? showTranslation,
    bool? showTransliteration,
    bool? showTafsir,
    bool? showWordMeanings,
  }) => AyahViewPreferences(
    layout: layout ?? this.layout,
    showTranslation: showTranslation ?? this.showTranslation,
    showTransliteration: showTransliteration ?? this.showTransliteration,
    showTafsir: showTafsir ?? this.showTafsir,
    showWordMeanings: showWordMeanings ?? this.showWordMeanings,
  );
}

/// The reader's mode, saved.
class ReaderModeController extends Notifier<ReaderMode> {
  static const _key = 'reader.mode';

  @override
  ReaderMode build() {
    _restore();
    return ReaderMode.mushaf;
  }

  Future<void> _restore() async {
    final stored = await ref.read(browserStorageProvider).getString(_key);
    final mode = ReaderMode.values.asNameMap()[stored];
    if (mode != null && ref.mounted) state = mode;
  }

  Future<void> set(ReaderMode mode) async {
    state = mode;
    await ref.read(browserStorageProvider).setString(_key, mode.name);
  }

  Future<void> toggle() =>
      set(state == ReaderMode.mushaf ? ReaderMode.ayah : ReaderMode.mushaf);
}

final readerModeProvider = NotifierProvider<ReaderModeController, ReaderMode>(
  ReaderModeController.new,
);

/// Ayah mode's view, saved with every change.
class AyahViewPreferencesController extends Notifier<AyahViewPreferences> {
  static const _prefix = 'reader.ayah.';

  @override
  AyahViewPreferences build() {
    _restore();
    return const AyahViewPreferences();
  }

  Future<void> _restore() async {
    final s = ref.read(browserStorageProvider);
    final layout = await s.getString('${_prefix}layout');
    final translation = await s.getBool('${_prefix}translation');
    final transliteration = await s.getBool('${_prefix}transliteration');
    final tafsir = await s.getBool('${_prefix}tafsir');
    final meanings = await s.getBool('${_prefix}meanings');
    if (!ref.mounted) return;
    state = state.copyWith(
      layout: AyahLayout.values.asNameMap()[layout],
      showTranslation: translation,
      showTransliteration: transliteration,
      showTafsir: tafsir,
      showWordMeanings: meanings,
    );
  }

  Future<void> set(AyahViewPreferences value) async {
    state = value;
    final s = ref.read(browserStorageProvider);
    await s.setString('${_prefix}layout', value.layout.name);
    await s.setBool('${_prefix}translation', value.showTranslation);
    await s.setBool('${_prefix}transliteration', value.showTransliteration);
    await s.setBool('${_prefix}tafsir', value.showTafsir);
    await s.setBool('${_prefix}meanings', value.showWordMeanings);
  }
}

final ayahViewPreferencesProvider =
    NotifierProvider<AyahViewPreferencesController, AyahViewPreferences>(
      AyahViewPreferencesController.new,
    );

/// An ayah Ayah mode should bring into view (the ayah sheet's "More", a
/// word's "Read full tafsir"); cleared once shown.
class AyahModeTarget extends Notifier<int?> {
  @override
  int? build() => null;

  void show(int ayahId) => state = ayahId;

  void done() => state = null;
}

final ayahModeTargetProvider = NotifierProvider<AyahModeTarget, int?>(
  AyahModeTarget.new,
);
