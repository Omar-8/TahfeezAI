import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstraction over "are we online right now, and when does that change".
///
/// This exists so offline-aware UI (resource download screens, search
/// index freshness, home update banners) can depend on one small interface
/// instead of `package:connectivity_plus` directly. Per
/// `docs/PROJECT_BRIEF.md`'s offline-first philosophy, the *absence* of
/// connectivity must never block any capability that only needs
/// already-installed local data — this service is for gating
/// network-dependent affordances (downloads, manifest refreshes), not for
/// gating reading/search/bookmarks/memorization.
abstract class ConnectivityService {
  Future<bool> get isOnline;
  Stream<bool> get onConnectivityChanged;
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  Future<bool> get isOnline async =>
      _isOnline(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline);
}
