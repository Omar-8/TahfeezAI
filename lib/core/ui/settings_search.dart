import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// [s] as settings searches compare it: lower case, Arabic vowel marks
/// dropped.
String foldForSearch(String s) =>
    s.toLowerCase().replaceAll(RegExp('[ً-ٰٟ]'), '');

/// A settings search's text (folded), for the [SearchText]s under it —
/// Settings' and the Hifz settings'.
class SettingsSearchScope extends InheritedWidget {
  const SettingsSearchScope({
    super.key,
    required this.query,
    required super.child,
  });

  /// Folded ([foldForSearch]) and trimmed.
  final String query;

  static String of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SettingsSearchScope>()
          ?.query ??
      '';

  /// Whether any of [words] holds [query] (folded); every word with no
  /// query.
  static bool hits(String query, Iterable<String> words) =>
      query.isEmpty || words.any((w) => foldForSearch(w).contains(query));

  @override
  bool updateShouldNotify(SettingsSearchScope old) => query != old.query;
}

/// An option's name or description, highlighted while the search finds it:
/// where in an opened section the match is.
class SearchText extends StatelessWidget {
  const SearchText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final query = SettingsSearchScope.of(context);
    final found = query.length >= 2 && foldForSearch(text).contains(query);
    if (!found) return Text(text, style: style);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('settings-search-match'),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(TahfeezRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          style: (style ?? const TextStyle()).copyWith(
            color: scheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}

/// The first [SearchText] under [root] that [query] finds, scrolled into
/// view (it is highlighted) — once its section has opened.
void revealFirstSearchMatch(BuildContext root, String query) {
  if (query.length < 2) return;
  Element? first;
  void visit(Element e) {
    if (first != null) return;
    if (e.widget case SearchText(:final text)
        when foldForSearch(text).contains(query)) {
      first = e;
      return;
    }
    e.visitChildElements(visit);
  }

  (root as Element).visitChildElements(visit);
  if (first case final found?) {
    Scrollable.ensureVisible(
      found,
      alignment: 0.3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}
