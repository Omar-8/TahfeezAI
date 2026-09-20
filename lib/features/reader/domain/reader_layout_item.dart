import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../quran/domain/models/ayah_models.dart';
import '../../../quran/domain/models/surah_models.dart';

part 'reader_layout_item.freezed.dart';

/// One unit in a reading session's assembled content list.
///
/// Mirrors the structural-marker concept in
/// `docs/reference/04_READER_SPEC.md` §13 (`ReaderLayoutItem`/`ChapterInfo`/
/// `Bismillah`/`SectionMarker`) — independently modeled, not copied — so a
/// reading session over a Surah/Juz/Hizb/range/single Ayah is always the
/// *same* shape: a flat, orderable list an ordinary `ListView.builder` can
/// render lazily, with each verse an independent domain/presentation unit
/// per this milestone's explicit requirement.
///
/// [ReaderChapterInfoItem] marks *every* chapter entry point, not only the
/// session's opening one — an earlier design used a separate, much plainer
/// `ChapterTitle` marker for a chapter reached mid-session (continuous
/// scrolling, or a later segment of a Juz/Hizb range), but that made the
/// same kind of moment — "a new Surah begins here" — look different
/// depending on how the reader arrived at it (e.g. Al-Fatiha's own opening
/// card looking nothing like Al-Baqarah's marker one continuous scroll
/// later). Every chapter entry now gets the same card.
///
/// [ReaderVerseItem] deliberately carries only the immutable content
/// ([AyahWithWords], from the read-only [QuranRepository]) — never a
/// hard-coded string, satisfying "do not hard-code Quran text into
/// widgets". Per-verse *mutable* UI state (selection, current-playback
/// highlight, bookmark status) is tracked separately by
/// `ReaderSessionController`, not baked into this type, since the same
/// content item's display state can change without its content changing.
@freezed
sealed class ReaderLayoutItem with _$ReaderLayoutItem {
  /// A chapter-summary card, inserted once at the start of a reading
  /// session that begins a chapter (name, meaning, revelation place, verse
  /// count) — `docs/reference/04_READER_SPEC.md` §13's `ChapterInfo`.
  const factory ReaderLayoutItem.chapterInfo({
    required Surah surah,
    SurahLocalization? localization,
  }) = ReaderChapterInfoItem;

  /// A Bismillah marker, inserted before a chapter's content except Al-
  /// Fatiha (whose Bismillah is verse 1) and At-Tawbah (which conventionally
  /// omits it) — `docs/reference/04_READER_SPEC.md` §13's `Bismillah`.
  ///
  /// Carries no Arabic text of its own: [BismillahDivider]
  /// (`lib/features/reader/presentation/widgets/bismillah_divider.dart`)
  /// resolves the real text itself, from `bismillahTextProvider` — sourced
  /// from Al-Fatiha's own ayah 1, which *is* the Bismillah word-for-word,
  /// never a literal string written into a widget.
  const factory ReaderLayoutItem.bismillah() = ReaderBismillahItem;

  /// A lightweight inline label marking a structural boundary (a Ruku
  /// change) between verses — `docs/reference/04_READER_SPEC.md` §13's
  /// `SectionMarker`.
  const factory ReaderLayoutItem.sectionMarker({required String label}) =
      ReaderSectionMarkerItem;

  /// One verse, with its words in the active script.
  const factory ReaderLayoutItem.verse(AyahWithWords ayah) = ReaderVerseItem;
}

/// A stable key for [item] at [index] in a reading session's item list, for
/// `ListView.builder`'s `key:` — content-derived where content gives one
/// (a verse's/chapter's own id), position-derived only for markers that can
/// legitimately repeat within one session (a multi-chapter Juz/Hizb has one
/// Bismillah per chapter it touches).
Object readerLayoutItemKey(ReaderLayoutItem item, int index) {
  return switch (item) {
    ReaderChapterInfoItem(:final surah) => 'chapter-info-${surah.surahNo}',
    ReaderBismillahItem() => 'bismillah-$index',
    ReaderSectionMarkerItem(:final label) => 'section-$index-$label',
    ReaderVerseItem(:final ayah) => 'verse-${ayah.ayah.id}',
  };
}
