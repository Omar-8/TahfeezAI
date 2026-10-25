import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

/// For the app's UI languages Flutter's own localizations lack (Material:
/// Hausa, Kurdish Sorani, Somali; Cupertino also Pashto): Flutter's few
/// built-in strings (date pickers, the system dialogs' buttons) in English,
/// and Kurdish laid out right to left, which Flutter does not know it is.
const kFallbackLocalizationsDelegates = <LocalizationsDelegate<Object>>[
  _FallbackMaterial(),
  _FallbackCupertino(),
  _FallbackWidgets(),
];

/// Right-to-left UI languages Flutter does not list as such.
const _rtl = {'ckb'};

class _FallbackMaterial extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterial();

  @override
  bool isSupported(Locale locale) =>
      !GlobalMaterialLocalizations.delegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_FallbackMaterial old) => false;
}

class _FallbackCupertino extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertino();

  @override
  bool isSupported(Locale locale) =>
      !GlobalCupertinoLocalizations.delegate.isSupported(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_FallbackCupertino old) => false;
}

class _FallbackWidgets extends LocalizationsDelegate<WidgetsLocalizations> {
  const _FallbackWidgets();

  @override
  bool isSupported(Locale locale) => _rtl.contains(locale.languageCode);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture<WidgetsLocalizations>(const _RtlWidgetsLocalizations());

  @override
  bool shouldReload(_FallbackWidgets old) => false;
}

class _RtlWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const _RtlWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.rtl;
}

/// [locale] for dates and numbers (intl), or English where intl has no
/// data for it — a missing locale would throw.
String intlLocaleOf(Locale locale) {
  final tag = locale.toLanguageTag();
  return DateFormat.localeExists(tag) && NumberFormat.localeExists(tag)
      ? tag
      : 'en';
}
