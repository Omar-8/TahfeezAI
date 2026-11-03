import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_store/app_store_service.dart';
import '../core/localization/generated/app_localizations.dart';
import '../core/routing/app_router.dart';
import '../core/ui/first_run.dart';

/// The web app opened in a phone's browser: once a visit, a word that
/// TahfeezAI is an app for the phone, and where to get it — Google Play
/// on Android, the App Store on iPhone and iPad. Nothing elsewhere.
class GetTheAppPrompt extends ConsumerStatefulWidget {
  const GetTheAppPrompt({super.key, required this.child});

  final Widget child;

  /// Where it is offered: a phone's (or tablet's) browser.
  static bool get offered =>
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  ConsumerState<GetTheAppPrompt> createState() => _GetTheAppPromptState();
}

class _GetTheAppPromptState extends ConsumerState<GetTheAppPrompt> {
  static var _shown = false;

  @override
  void initState() {
    super.initState();
    if (!GetTheAppPrompt.offered || _shown) return;
    if (!ref.read(firstRunPromptsProvider)) return;
    _shown = true;
    // The app up first.
    Timer(const Duration(seconds: 2), _show);
  }

  Future<void> _show() async {
    final navigator = rootNavigatorKey.currentState;
    final context = navigator?.overlay?.context;
    if (!mounted || context == null) return;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final store = ios ? 'App Store' : 'Google Play';
    final open = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          key: const ValueKey('get-the-app'),
          icon: const Icon(Icons.install_mobile_rounded),
          title: Text(l10n.getAppTitle),
          content: Text(l10n.getAppBody(store)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.tipClose),
            ),
            FilledButton(
              key: const ValueKey('get-the-app-open'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.getAppOpen(store)),
            ),
          ],
        );
      },
    );
    if (open == true) {
      await ref
          .read(appStoreServiceProvider)
          .openUrl(ios ? kAppStoreUrl : kPlayStoreUrl);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
