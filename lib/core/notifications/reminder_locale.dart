import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/locale_controller.dart';
import '../localization/supported_locales.dart';

/// The language of a reminder's text: the app's chosen one, else the
/// system's when the app has it, else the first supported.
Locale reminderLocale(Ref ref) {
  final chosen = ref.read(localeControllerProvider);
  if (chosen != null) return chosen;
  final system = PlatformDispatcher.instance.locale.languageCode;
  return kTahfeezSupportedLocales.firstWhere(
    (l) => l.languageCode == system,
    orElse: () => kTahfeezSupportedLocales.first,
  );
}
