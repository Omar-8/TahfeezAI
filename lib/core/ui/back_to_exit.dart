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
/// told, twice within 2 s to leave the app — unless a part of the screen
/// goes back a step itself ([claimBack]: the Quran tab's Topics, a topic
/// open).
class BackToExit extends StatelessWidget {
  const BackToExit({super.key, required this.child});

  final Widget child;

  static final _claims = <Object>{};

  /// [owner] takes the back button ([claimed]) — going back a step of its
  /// own — or gives it back. While any has it, back here says nothing.
  static void claimBack(Object owner, {required bool claimed}) {
    if (claimed) {
      _claims.add(owner);
    } else {
      _claims.remove(owner);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop || _claims.isNotEmpty) return;
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
