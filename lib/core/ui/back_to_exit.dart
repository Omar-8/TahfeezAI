import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../localization/generated/app_localizations.dart';

/// When back was last pressed on a tab's first screen ([BackToExit]).
DateTime? _backPressedAt;
const _exitWindow = Duration(seconds: 2);

/// Forgets the last back press (tests run screens one after another).
@visibleForTesting
void resetBackToExit() => _backPressedAt = null;

/// A tab's first screen (Home, Quran, Memorize, Settings): back once to be
/// told, twice within 2 s to leave the app.
class BackToExit extends StatelessWidget {
  const BackToExit({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      final now = DateTime.now();
      final last = _backPressedAt;
      if (last != null && now.difference(last) < _exitWindow) {
        SystemNavigator.pop();
        return;
      }
      _backPressedAt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: _exitWindow,
            content: Text(AppLocalizations.of(context).homeBackToExit),
          ),
        );
    },
    child: child,
  );
}
