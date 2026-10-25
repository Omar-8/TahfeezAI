import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/locale_controller.dart';
import '../../core/storage/storage_providers.dart';
import '../../wbw/application/wbw_preferences_controller.dart';
import 'tafsir_selection_controller.dart';
import 'translation_selection_controller.dart';

/// Keeps the translations, the tafsir and the word meanings in the app's
/// language: when it changes — chosen in Settings, or the phone's own
/// language changed since the app last ran — each one in the old language
/// becomes the new one's default. One the reader set to another language
/// stays. Started with the app.
class MeaningLanguageFollower extends Notifier<void> {
  /// The language the meanings last followed.
  static const storageKey = 'meaning.language';

  Future<void> _chain = Future.value();

  @override
  void build() {
    ref.listen(localeControllerProvider, (_, _) => _queue());
    _queue();
  }

  void _queue() => _chain = _chain.then((_) => _sync()).catchError((_) {});

  Future<void> _sync() async {
    final storage = ref.read(browserStorageProvider);
    final phone = PlatformDispatcher.instance.locale.languageCode;
    // The app's language (its stored choice, read directly: it may not be
    // restored yet), else the phone's.
    final override =
        ref.read(localeControllerProvider)?.languageCode ??
        await storage.getString(localePrefKey);
    if (!ref.mounted) return;
    final language = override ?? phone;
    final last = await storage.getString(storageKey);
    if (!ref.mounted || last == language) return;
    // Never followed before: the defaults were taken from the phone's
    // language (the app's may not have been restored yet).
    final from = last ?? phone;
    await storage.setString(storageKey, language);
    if (from == language || !ref.mounted) return;
    await Future.wait([
      ref
          .read(translationSelectionControllerProvider.notifier)
          .follow(from, language),
      ref
          .read(tafsirSelectionControllerProvider.notifier)
          .follow(from, language),
      ref.read(wbwSelectedPackControllerProvider.notifier).follow(from),
    ]);
  }
}

final meaningLanguageFollowerProvider =
    NotifierProvider<MeaningLanguageFollower, void>(
      MeaningLanguageFollower.new,
    );
