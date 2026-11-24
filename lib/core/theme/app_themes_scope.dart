import 'package:flutter/material.dart';

/// The app's light and dark themes both, whichever is in use — for a part
/// that follows something else's brightness (the recitation bar, the
/// Mushaf page's theme under it; owner, 2026-11-24).
class AppThemesScope extends InheritedWidget {
  const AppThemesScope({
    super.key,
    required this.light,
    required this.dark,
    required super.child,
  });

  final ThemeData light, dark;

  /// The theme for a ground of [brightness]: the app's own of that
  /// brightness, else the one in use.
  static ThemeData of(BuildContext context, Brightness brightness) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemesScope>();
    if (scope == null) return Theme.of(context);
    return brightness == Brightness.dark ? scope.dark : scope.light;
  }

  @override
  bool updateShouldNotify(AppThemesScope old) =>
      old.light != light || old.dark != dark;
}
