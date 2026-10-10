import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';

/// A saved place: an ayah (`surah * 1000 + ayah`) or a whole surah.
class Bookmark {
  const Bookmark.ayah(int this.ayahId, this.savedAt) : surahNo = ayahId ~/ 1000;

  const Bookmark.surah(this.surahNo, this.savedAt) : ayahId = null;

  final int surahNo;

  /// `null` for a surah bookmark.
  final int? ayahId;
  final DateTime savedAt;

  bool get isSurah => ayahId == null;

  Map<String, Object> toJson() => {
    'surah': surahNo,
    'ayah': ?ayahId,
    'at': savedAt.toUtc().toIso8601String(),
  };

  static Bookmark? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}')?.toLocal() ?? DateTime(2026);
    return switch ((json['surah'], json['ayah'])) {
      (final int _, final int ayah) when ayah > 1000 => Bookmark.ayah(ayah, at),
      (final int surah, null) when surah >= 1 && surah <= 114 => Bookmark.surah(
        surah,
        at,
      ),
      _ => null,
    };
  }
}

/// The bookmarked ayahs and surahs, newest first. Saved with the app's
/// settings, so a backup (Settings → Export) carries them.
class BookmarksController extends Notifier<List<Bookmark>> {
  static const storageKey = 'bookmarks.v1';

  /// Changed before the saved list arrived: that list is stale.
  var _changed = false;

  @override
  List<Bookmark> build() {
    unawaited(_restore());
    return const [];
  }

  Future<void> _restore() async {
    try {
      final raw = await ref.read(browserStorageProvider).getString(storageKey);
      if (raw == null || _changed || !ref.mounted) return;
      state = [for (final j in jsonDecode(raw) as List) ?Bookmark.fromJson(j)];
    } catch (_) {
      // None.
    }
  }

  bool hasAyah(int ayahId) => state.any((b) => b.ayahId == ayahId);
  bool hasSurah(int surahNo) =>
      state.any((b) => b.isSurah && b.surahNo == surahNo);

  void toggleAyah(int ayahId) => _set(
    hasAyah(ayahId)
        ? [
            for (final b in state)
              if (b.ayahId != ayahId) b,
          ]
        : [Bookmark.ayah(ayahId, DateTime.now()), ...state],
  );

  void toggleSurah(int surahNo) => _set(
    hasSurah(surahNo)
        ? [
            for (final b in state)
              if (!(b.isSurah && b.surahNo == surahNo)) b,
          ]
        : [Bookmark.surah(surahNo, DateTime.now()), ...state],
  );

  void remove(Bookmark bookmark) => _set([
    for (final b in state)
      if (!identical(b, bookmark)) b,
  ]);

  void _set(List<Bookmark> bookmarks) {
    _changed = true;
    state = bookmarks;
    unawaited(
      ref
          .read(browserStorageProvider)
          .setString(
            storageKey,
            jsonEncode([for (final b in bookmarks) b.toJson()]),
          ),
    );
  }
}

final bookmarksProvider = NotifierProvider<BookmarksController, List<Bookmark>>(
  BookmarksController.new,
);
