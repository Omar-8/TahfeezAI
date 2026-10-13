import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';

/// Whether the first-run prompts appear at all (Home's welcome, the
/// reader's guide) — off in tests that walk through the app.
final firstRunPromptsProvider = Provider<bool>((ref) => true);

/// Whether [key]'s first-run prompt is still due: `true` once only — the
/// first call marks it shown for good.
Future<bool> firstRunDue(WidgetRef ref, String key) async {
  if (!ref.read(firstRunPromptsProvider)) return false;
  final storage = ref.read(browserStorageProvider);
  final storageKey = 'firstRun.$key';
  if (await storage.getBool(storageKey) ?? false) return false;
  await storage.setBool(storageKey, true);
  return true;
}
