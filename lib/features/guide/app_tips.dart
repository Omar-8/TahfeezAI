import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/browser_storage.dart';

/// "Did you know" tips about features easily missed, each at a moment it
/// fits. Spaced out, and at random times: none on the first day, then at
/// most one every [tipInterval], and at a moment one fits a coin decides
/// ([tipChance]). Each tip can be turned off for good ("Don't show this
/// again", or "Show me" — then it is known).
enum AppTip {
  /// While listening, without a translation read after each ayah.
  listenTranslation,

  /// Reading the Mushaf: its page themes.
  pageTheme,
}

const tipFirstAfter = Duration(days: 1);
const tipInterval = Duration(days: 2);
const tipChance = 0.5;

/// Whether [tip] shows now; if so, it is counted as shown (the next one at
/// least [tipInterval] later). The first call starts the first day.
Future<bool> appTipDue(
  BrowserStorage storage,
  AppTip tip, {
  required DateTime now,
  required Random random,
}) async {
  if (await storage.getBool('$_offKey.${tip.name}') ?? false) return false;
  final first = DateTime.tryParse(await storage.getString(_firstKey) ?? '');
  if (first == null) {
    await storage.setString(_firstKey, now.toIso8601String());
    return false;
  }
  if (now.difference(first) < tipFirstAfter) return false;
  final last = DateTime.tryParse(await storage.getString(_lastKey) ?? '');
  if (last != null && now.difference(last) < tipInterval) return false;
  if (random.nextDouble() >= tipChance) return false;
  await storage.setString(_lastKey, now.toIso8601String());
  return true;
}

/// Starts the first day if not started (the reader opened).
Future<void> appTipsStart(BrowserStorage storage, DateTime now) async {
  if (await storage.getString(_firstKey) == null) {
    await storage.setString(_firstKey, now.toIso8601String());
  }
}

/// [tip] not shown again.
Future<void> appTipOff(BrowserStorage storage, AppTip tip) =>
    storage.setBool('$_offKey.${tip.name}', true);

const _firstKey = 'appTips.firstSeen';
const _lastKey = 'appTips.lastShown';
const _offKey = 'appTips.off';

/// The tips' clock and coin (fixed in tests).
final appTipsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final appTipsRandomProvider = Provider<Random>((ref) => Random());
