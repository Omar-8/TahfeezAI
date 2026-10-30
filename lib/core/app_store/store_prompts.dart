import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/browser_storage.dart';
import '../storage/storage_providers.dart';
import 'app_store_service.dart';

/// When the app offers an update or asks to be rated:
/// - an update, whenever the app opens while Google Play has one and
///   offers are on (Settings) — "Later" only closes it for that opening;
/// - a rating, only after [reviewAfterUse] of use and [reviewAfterAyahs]
///   ayahs recited, then on about one opening in four, at most once per
///   [reviewEvery] (the store limits its prompt further).
class StorePrompts {
  StorePrompts(
    this._storage,
    this._store, {
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random();

  final BrowserStorage _storage;
  final AppStoreService _store;
  final DateTime Function() _clock;
  final Random _random;

  static const notifyKey = 'store.updates.notify';
  static const _firstOpenKey = 'store.firstOpen';
  static const _reviewedKey = 'store.review.askedAt';

  static const reviewAfterUse = Duration(days: 3);
  static const reviewAfterAyahs = 20;
  static const reviewEvery = Duration(days: 60);

  Future<DateTime?> _date(String key) async =>
      DateTime.tryParse(await _storage.getString(key) ?? '');

  Future<bool> updateOffersOn() async =>
      await _storage.getBool(notifyKey) ?? true;

  Future<void> setUpdateOffers(bool on) => _storage.setBool(notifyKey, on);

  /// Whether to offer an update now.
  Future<bool> shouldOfferUpdate() async {
    if (!await updateOffersOn()) return false;
    return await _store.updateAvailable() ?? false;
  }

  /// Maybe asks for a rating, given the ayahs recited so far; whether it
  /// asked.
  Future<bool> maybeAskForReview({required int recitedAyahs}) async {
    final now = _clock();
    final first = await _date(_firstOpenKey);
    if (first == null) {
      await _storage.setString(_firstOpenKey, now.toIso8601String());
      return false;
    }
    if (now.difference(first) < reviewAfterUse) return false;
    if (recitedAyahs < reviewAfterAyahs) return false;
    final asked = await _date(_reviewedKey);
    if (asked != null && now.difference(asked) < reviewEvery) return false;
    if (_random.nextDouble() >= 0.25) return false;
    await _storage.setString(_reviewedKey, now.toIso8601String());
    await _store.requestReview();
    return true;
  }
}

final storePromptsProvider = Provider<StorePrompts>(
  (ref) => StorePrompts(
    ref.watch(browserStorageProvider),
    ref.watch(appStoreServiceProvider),
  ),
);
