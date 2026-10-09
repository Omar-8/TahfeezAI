import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../domain/quran_audio_sources.dart';

const _prefKey = 'listen.reciter';

/// The chosen reciter's edition (Settings → Recitation audio).
class ReciterController extends Notifier<String> {
  @override
  String build() {
    _restore();
    return defaultReciter;
  }

  Future<void> _restore() async {
    final stored = await ref.read(browserStorageProvider).getString(_prefKey);
    if (stored != null &&
        reciters.any((r) => r.edition == stored) &&
        ref.mounted) {
      state = stored;
    }
  }

  Future<void> select(String edition) async {
    state = edition;
    await ref.read(browserStorageProvider).setString(_prefKey, edition);
  }
}

final reciterProvider = NotifierProvider<ReciterController, String>(
  ReciterController.new,
);
