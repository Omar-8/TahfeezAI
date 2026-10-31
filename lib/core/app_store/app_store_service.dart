import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The app's Google Play listing.
const kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=ai.tahfeez.tahfeez_ai';

/// The app's Apple ID (App Store Connect).
const kAppStoreId = '6829199977';

/// The App Store listing.
const kAppStoreUrl = 'https://apps.apple.com/app/id$kAppStoreId';

/// Apple's public lookup of a listing (its version among it): the iOS update
/// check. Asks for nothing but the app's ID.
const kAppStoreLookupUrl = 'https://itunes.apple.com/lookup?id=$kAppStoreId';

/// Whether [store] (e.g. "1.0.10") is a later version than [installed]
/// ("1.0.9"): number by number.
@visibleForTesting
bool isNewerVersion(String store, String installed) {
  List<int> parts(String v) => [
    for (final p in v.split('+').first.split('.')) int.tryParse(p) ?? 0,
  ];
  final a = parts(store), b = parts(installed);
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// The project's GitHub repository (public since 2026-10-19).
const kGitHubUrl = 'https://github.com/Omar-8/TahfeezAI';

/// The app's dealings with its store and the system: its version, updates
/// (Google Play's in-app update; on iOS the App Store listing's version and
/// page), rating (the store's in-app review),
/// sharing and opening links. Each fails quietly — a build not installed
/// from Google Play has no updates or review to offer.
abstract class AppStoreService {
  Future<String> version();

  /// Whether the store has a newer version — Google Play's (Android,
  /// installed from Play) or the App Store's listing (iOS); `null` if that
  /// can't be known here (offline, another build, the web).
  Future<bool?> updateAvailable();

  /// Google Play's update screen, else the store listing (iOS: the App
  /// Store's, where it is updated).
  Future<void> update();

  /// The store's own rating prompt (it decides whether to show it).
  Future<void> requestReview();

  /// The store listing, to rate the app there.
  Future<void> openListing();

  Future<void> share(String text);

  /// This platform's store listing, to link to.
  String get listingUrl;

  Future<bool> openUrl(String url);
}

class PlatformAppStoreService implements AppStoreService {
  PlatformAppStoreService({Future<String?> Function()? appStoreVersion})
    : _appStoreVersion = appStoreVersion ?? _lookUpAppStoreVersion;

  /// The App Store listing's version; `null` if it can't be had.
  final Future<String?> Function() _appStoreVersion;

  static Future<String?> _lookUpAppStoreVersion() async {
    final response = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        responseType: ResponseType.json,
      ),
    ).get<dynamic>(kAppStoreLookupUrl);
    var data = response.data;
    // (Apple answers as text/javascript: a string to decode.)
    if (data is String) data = jsonDecode(data);
    final results = (data as Map)['results'] as List?;
    if (results == null || results.isEmpty) return null;
    return (results.first as Map)['version'] as String?;
  }

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  String get listingUrl => _ios ? kAppStoreUrl : kPlayStoreUrl;

  @override
  Future<String> version() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  @override
  Future<bool?> updateAvailable() async {
    if (_ios) {
      try {
        final store = await _appStoreVersion();
        final installed = await version();
        if (store == null || installed.isEmpty) return null;
        return isNewerVersion(store, installed);
      } catch (_) {
        return null; // offline, or not in the App Store yet
      }
    }
    if (!_android) return null;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (_) {
      return null; // not installed from Google Play
    }
  }

  @override
  Future<void> update() async {
    try {
      if (_android) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
    } catch (_) {
      // Fall back to the listing.
    }
    // iOS: its App Store page, where it is updated (no in-app update).
    if (_ios) {
      await openUrl(kAppStoreUrl);
      return;
    }
    await openListing();
  }

  @override
  Future<void> requestReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (_) {
      // No prompt.
    }
  }

  @override
  Future<void> openListing() async {
    // On iOS straight to the App Store's review form.
    final url = _ios ? '$kAppStoreUrl?action=write-review' : listingUrl;
    if (!await openUrl(url)) {
      try {
        await InAppReview.instance.openStoreListing();
      } catch (_) {
        // Nothing to open.
      }
    }
  }

  @override
  Future<void> share(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // Nothing shared.
    }
  }

  @override
  Future<bool> openUrl(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

final appStoreServiceProvider = Provider<AppStoreService>(
  (ref) => PlatformAppStoreService(),
);

/// The installed version, e.g. "1.0.0".
final appVersionProvider = FutureProvider<String>(
  (ref) => ref.watch(appStoreServiceProvider).version(),
);
