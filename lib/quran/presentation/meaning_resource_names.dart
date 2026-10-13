import '../../core/localization/generated/app_localizations.dart';
import '../domain/models/tafsir_models.dart';
import '../domain/models/translation_models.dart';
import 'meaning_language_names.dart';

/// A translation's name (its translator) in the app's language, for the
/// bundled ones; any other, as its pack names it.
String translationName(AppLocalizations l10n, TranslationBook book) =>
    switch (book.slug.split('-').last) {
      'rowwad' => l10n.packRowwad,
      'noor' => l10n.packNoor,
      'affairs' => l10n.packIndonesiaMinistry,
      'junagarhi' => l10n.packJunagarhi,
      _ => book.author,
    };

/// A translation's name with its language, where translations of several
/// languages are listed together (search's filters).
String translationNameWithLanguage(
  AppLocalizations l10n,
  TranslationBook book,
) =>
    '${translationName(l10n, book)} · ${nativeLanguageName(book.languageCode)}';

/// A tafsir's name in the app's language, for the bundled ones (Al-Mukhtasar
/// the same name in each of its languages); any other, as its pack names it.
String tafsirName(AppLocalizations l10n, TafsirWork work) =>
    switch (work.id.split('-').last) {
      'muyassar' => l10n.tafsirMuyassar,
      'mukhtasar' => l10n.tafsirMukhtasar,
      _ => work.displayName,
    };
