import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/storage_providers.dart';
import 'supported_locales.dart';

part 'locale_controller.g.dart';

const _localePrefKey = 'core.locale';

/// Persisted app-UI locale override.
///
/// `null` means "follow the system locale" (the default). Setting an
/// explicit [Locale] overrides the system, mirroring how the reference app
/// separates a stored language preference from the OS default (see
/// `docs/reference/15_LOCALIZATION_SPEC.md` §3) — Tahfeez keeps this same
/// independence between UI language and system language.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Locale? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_localePrefKey);
    if (stored == null) return;
    for (final locale in kTahfeezSupportedLocales) {
      if (locale.languageCode == stored) {
        state = locale;
        return;
      }
    }
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final storage = ref.read(browserStorageProvider);
    if (locale == null) {
      await storage.remove(_localePrefKey);
    } else {
      await storage.setString(_localePrefKey, locale.languageCode);
    }
  }
}
