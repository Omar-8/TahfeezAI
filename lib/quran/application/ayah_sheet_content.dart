import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';

/// What the Mushaf's ayah sheet (long-press) shows besides the ayah.
enum AyahSheetContent { translation, tafsir, both }

const _prefKey = 'ayah_sheet.content';

/// Persisted [AyahSheetContent]; both by default. Chosen in Settings →
/// Translation & tafsir.
class AyahSheetContentController extends Notifier<AyahSheetContent> {
  @override
  AyahSheetContent build() {
    _restore();
    return AyahSheetContent.both;
  }

  Future<void> _restore() async {
    final stored = await ref.read(browserStorageProvider).getString(_prefKey);
    for (final c in AyahSheetContent.values) {
      if (c.name == stored && ref.mounted) state = c;
    }
  }

  Future<void> set(AyahSheetContent content) async {
    state = content;
    await ref.read(browserStorageProvider).setString(_prefKey, content.name);
  }
}

final ayahSheetContentProvider =
    NotifierProvider<AyahSheetContentController, AyahSheetContent>(
      AyahSheetContentController.new,
    );
