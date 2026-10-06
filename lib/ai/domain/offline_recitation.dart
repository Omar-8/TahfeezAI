/// Recitation AI may not touch the network: no remote model, no Google /
/// Web Speech, no audio sent anywhere (`--dart-define=
/// TAHFEEZ_OFFLINE_RECITATION=true`).
const offlineRecitation = bool.fromEnvironment('TAHFEEZ_OFFLINE_RECITATION');

/// Something tried to use the network for recitation in offline mode.
class OfflineRecitationViolation extends StateError {
  OfflineRecitationViolation(String what)
    : super('TAHFEEZ_OFFLINE_RECITATION is on: refusing $what');
}

/// Throws [OfflineRecitationViolation] if recitation is offline-only —
/// called at every point recitation audio or recognition could leave the
/// device, so a misconfiguration fails loudly instead of silently.
void ensureRecitationNetworkAllowed(String what) {
  if (offlineRecitation) throw OfflineRecitationViolation(what);
}
