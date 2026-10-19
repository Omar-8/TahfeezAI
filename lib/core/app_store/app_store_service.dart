import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The app's store listing (Google Play).
const kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=ai.tahfeez.tahfeez_ai';

/// The App Store listing, once the app has one
/// (`https://apps.apple.com/app/id<number>`). Empty: on iOS, rating opens
/// nothing beyond the in-app prompt, and sharing links Google Play.
const kAppStoreUrl = '';

/// Where feedback goes: the project's GitHub issues, once the repository
/// exists. Empty: Settings' "Send feedback" does nothing yet.
const kFeedbackUrl = '';

/// The project's GitHub repository (public since 2026-10-19).
const kGitHubUrl = 'https://github.com/Omar-8/TahfeezAI';

/// The app's dealings with its store and the system: its version, updates
/// (Google Play's in-app update), rating (the store's in-app review),
/// sharing and opening links. Each fails quietly — a build not installed
/// from Google Play has no updates or review to offer.
abstract class AppStoreService {
  Future<String> version();

  /// Whether Google Play has a newer version (Android, installed from
  /// Play); `null` if that can't be known here.
  Future<bool?> updateAvailable();

  /// Google Play's update screen, else the store listing.
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
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  String get listingUrl =>
      _ios && kAppStoreUrl.isNotEmpty ? kAppStoreUrl : kPlayStoreUrl;

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
    if (_ios && kAppStoreUrl.isEmpty) return;
    if (!await openUrl(listingUrl)) {
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
