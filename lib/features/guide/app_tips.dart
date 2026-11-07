import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/browser_storage.dart';
import '../../core/ui/first_run.dart';

/// "Did you know" tips about features easily missed. Never while reciting
/// or listening: Listen's as Play is pressed, before it plays ("Show me"
/// opens the translations, and it plays once they close; Close plays at
/// once); the page themes' while reading — both spaced out and at random
/// ([tipChance]); the checking's over a session's results, when the
/// session called for it. "Don't show tips again" ends them all.
enum AppTip {
  /// Listen's Play, without a translation read after each ayah.
  listenTranslation,

  /// Reading the Mushaf: its page themes.
  pageTheme,

  /// Over a session's results, when one of the first recitations marked
  /// many tajweed rules: tajweed checking can be turned off.
  tajweedOff,

  /// Over a session's results, when one of the first recitations marked
  /// many vowels: pronunciation checking can be made lenient.
  lenient,

  /// Once, over the results of the first session with mistakes: a marked
  /// word opens its word sheet (what was expected, what was heard).
  tapMistake,

  /// Before playback that streams a reciter not downloaded (the phones):
  /// downloading plays smoother, offline too.
  downloadReciter,
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
  if (await _off(storage, tip)) return false;
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

/// Whether [tip] may still be shown: not turned off, nor all tips.
Future<bool> appTipOn(BrowserStorage storage, AppTip tip) async =>
    !await _off(storage, tip);

/// Starts the first day if not started (the reader opened).
Future<void> appTipsStart(BrowserStorage storage, DateTime now) async {
  if (await storage.getString(_firstKey) == null) {
    await storage.setString(_firstKey, now.toIso8601String());
  }
}

/// [tip] not shown again.
Future<void> appTipOff(BrowserStorage storage, AppTip tip) =>
    storage.setBool('$_offKey.${tip.name}', true);

/// No tip shown again ("Don't show tips again").
Future<void> appTipsAllOff(BrowserStorage storage) =>
    storage.setBool(_allOffKey, true);

Future<bool> _off(BrowserStorage storage, AppTip tip) async =>
    (await storage.getBool(_allOffKey) ?? false) ||
    (await storage.getBool('$_offKey.${tip.name}') ?? false);

const _firstKey = 'appTips.firstSeen';
const _lastKey = 'appTips.lastShown';
const _offKey = 'appTips.off';
const _allOffKey = 'appTips.allOff';

/// Whether tips come at all: with the first-run prompts (off in tests that
/// walk through the app, unless asked for).
final appTipsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(firstRunPromptsProvider),
);

/// The tips' clock and coin (fixed in tests).
final appTipsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final appTipsRandomProvider = Provider<Random>((ref) => Random());
