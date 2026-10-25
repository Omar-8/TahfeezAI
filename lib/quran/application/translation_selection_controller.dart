import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/storage_providers.dart';
import 'meaning_defaults.dart';

part 'translation_selection_controller.g.dart';

const _activeTranslationSlugsPrefKey = 'translation.active_slugs';

/// Which installed translations are active in the reader right now, and in
/// what order their blocks stack under each verse
/// (`docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §2's "reader stacks each
/// selected translation's text ... in the order they were selected").
/// Independent of which translations are merely *installed*
/// (`TranslationRepository.getInstalledTranslations`) — the same
/// installed-vs-active separation `WbwSelectedPackController`
/// (`lib/wbw/application/wbw_preferences_controller.dart`) establishes for
/// word-by-word, generalized here to a multi-select, ordered list.
///
/// Persisted as a comma-joined slug list, like every other simple
/// `BrowserStorage`-backed preference in this codebase.
@Riverpod(keepAlive: true)
class TranslationSelectionController extends _$TranslationSelectionController {
  @override
  List<String> build() {
    _restored = _restore();
    // Until a choice is made: the default for the user's language.
    return defaultTranslationSlugs(meaningLanguage(ref));
  }

  late Future<void> _restored;

  /// The app's language changed from [from] to [to]: translations all in
  /// [from] (or [from]'s defaults) become [to]'s; a translation chosen in
  /// another language stays, with the rest.
  Future<void> follow(String from, String to) async {
    await _restored;
    if (!ref.mounted) return;
    final current = state;
    final inFrom =
        current.every((s) => s.split('-').first == from) ||
        _same(current, defaultTranslationSlugs(from));
    if (!inFrom) return;
    final next = defaultTranslationSlugs(to);
    if (!_same(current, next)) await _persist(next);
  }

  static bool _same(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_activeTranslationSlugsPrefKey);
    if (stored == null || !ref.mounted) return;
    state = stored.isEmpty ? const [] : stored.split(',');
  }

  Future<void> _persist(List<String> slugs) async {
    state = slugs;
    await ref
        .read(browserStorageProvider)
        .setString(_activeTranslationSlugsPrefKey, slugs.join(','));
  }

  Future<void> toggle(String slug) {
    return state.contains(slug)
        ? _persist(state.where((s) => s != slug).toList())
        : _persist([...state, slug]);
  }

  Future<void> reorder(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    return _persist(list);
  }
}
