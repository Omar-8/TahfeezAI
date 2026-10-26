import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/script_direction.dart';
import '../../../core/theme/quran_text_style.dart';
import '../application/mushaf_word_overlay.dart';
import '../../../quran/application/ayah_reading_extras.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/application/tafsir_selection_controller.dart';
import '../../../quran/application/tafsir_verse_text.dart';
import '../../../quran/domain/models/ayah_models.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../../quran/presentation/meaning_resource_names.dart';
import '../../../quran/presentation/translation_block.dart';
import '../../../quran/quran_providers.dart';
import '../application/mushaf_page_translations.dart';
import '../domain/mushaf_appearance.dart';

// What an ayah shows in Ayah mode and in the ayah sheet alike: its words
// (each with its meaning), transliteration, translations and tafsir, as
// [AyahViewPreferences] says.

/// An ayah's canonical words.
final ayahCanonicalWordsProvider = FutureProvider.autoDispose
    .family<List<AyahWord>, int>((ref, ayahId) {
      return ref
          .watch(quranRepositoryProvider)
          .getWordsForAyah(
            ayahId,
            scriptCode: ref.watch(quranScriptCodeProvider),
          );
    });

class AyahWordView extends StatefulWidget {
  const AyahWordView({
    super.key,
    required this.text,
    required this.meaning,
    required this.hidden,
    required this.style,
    required this.colors,
    required this.fontFamily,
    this.mark,
    this.onTap,
    this.onLongPress,
  });

  final String fontFamily;
  final String text;
  final String? meaning;
  final bool hidden;
  final ({Color color, bool ink})? style;
  final MushafAppearanceColors colors;

  /// The recitation's mark on it, for its animation as it changes.
  final MushafWordMark? mark;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<AyahWordView> createState() => _AyahWordViewState();
}

enum _WordEffect { reveal, hide, glow, sway }

/// As the printed page's words do: recited right, a soft glow; a mistake,
/// a sway; revealed, its ink fading in; hidden, fading out.
class _AyahWordViewState extends State<AyahWordView>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  _WordEffect? _effect;

  static const _mistakes = {
    MushafWordMark.wrong,
    MushafWordMark.skipped,
    MushafWordMark.tashkeel,
    MushafWordMark.tajweed,
  };

  void _play(_WordEffect effect, int ms) {
    // The phone's "remove animations": none.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final c = _controller ??= AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _effect = null);
        }
      });
    _effect = effect;
    c
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  @override
  void didUpdateWidget(AyahWordView old) {
    super.didUpdateWidget(old);
    if (old.hidden && !widget.hidden) {
      _play(_WordEffect.reveal, 400);
    } else if (!old.hidden && widget.hidden) {
      _play(_WordEffect.hide, 400);
    } else if (old.mark != widget.mark) {
      if (widget.mark == MushafWordMark.correct) {
        _play(_WordEffect.glow, 650);
      } else if (_mistakes.contains(widget.mark)) {
        _play(_WordEffect.sway, 420);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _effect == null) return _word(context, 0);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _word(context, controller.value),
    );
  }

  Widget _word(BuildContext context, double t) {
    final mark = widget.style;
    final colors = widget.colors;
    final ink = mark != null && mark.ink ? mark.color : colors.text;
    final band = mark != null && !mark.ink ? mark.color : null;
    final smooth = t * t * (3 - 2 * t);
    // Hidden: its place kept (the line does not reflow), the word not
    // shown — fading out as it is hidden, in as it is revealed.
    final inkAlpha = switch (_effect) {
      _WordEffect.reveal => smooth,
      _WordEffect.hide => 1 - smooth,
      _ => widget.hidden ? 0.0 : 1.0,
    };
    final word = Text(
      widget.text,
      textDirection: TextDirection.rtl,
      style: quranTextStyle(
        color: inkAlpha == 0
            ? Colors.transparent
            : ink.withValues(alpha: ink.a * inkAlpha),
        fontFamily: widget.fontFamily,
        fontSize: 28,
      ),
    );
    final glow = _effect == _WordEffect.glow
        ? [
            BoxShadow(
              color: ink.withValues(alpha: 0.45 * (1 - t)),
              blurRadius: 6 + 10 * t,
            ),
          ]
        : null;
    final dx = _effect == _WordEffect.sway
        ? math.sin(t * math.pi * 6) * (1 - t) * 4
        : 0.0;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(dx, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color:
                    band ??
                    (widget.hidden && _effect != _WordEffect.hide
                        ? colors.secondaryText.withValues(alpha: 0.14)
                        : null),
                borderRadius: BorderRadius.circular(6),
                boxShadow: glow,
              ),
              child: word,
            ),
          ),
          if (widget.meaning != null && !widget.hidden)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                widget.meaning!,
                textAlign: TextAlign.center,
                textDirection: meaningDirection(widget.meaning!),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colors.secondaryText),
              ),
            ),
        ],
      ),
    );
  }
}

class AyahTransliteration extends ConsumerWidget {
  const AyahTransliteration({
    super.key,
    required this.ayahId,
    required this.colors,
  });

  final int ayahId;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(ayahTransliterationProvider(ayahId)).value;
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      key: ValueKey('ayah-mode-transliteration-$ayahId'),
      textDirection: TextDirection.ltr,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: colors.secondaryText,
        height: 1.5,
      ),
    );
  }
}

class AyahTranslations extends ConsumerWidget {
  const AyahTranslations({
    super.key,
    required this.ayahId,
    required this.colors,
  });

  final int ayahId;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(ayahTranslationsProvider(ayahId)).value;
    if (texts == null || texts.isEmpty) return const SizedBox.shrink();
    final books = ref.watch(activeTranslationBooksProvider).value ?? const {};
    return DefaultTextStyle.merge(
      style: TextStyle(color: colors.text),
      child: Column(
        key: ValueKey('ayah-mode-translation-$ayahId'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.sm,
        children: [
          for (final entry in texts.entries)
            TranslationBlock(
              verseText: entry.value,
              authorName: switch (books[entry.key]) {
                final book? => translationName(
                  AppLocalizations.of(context),
                  book,
                ),
                null => entry.key,
              },
              inlineFootnotes: true,
              textDirection:
                  rtlLanguages.contains(books[entry.key]?.languageCode)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
        ],
      ),
    );
  }
}

class AyahTafsir extends ConsumerWidget {
  const AyahTafsir({super.key, required this.verse, required this.colors});

  final VerseRef verse;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tafsirId = ref.watch(tafsirSelectionControllerProvider);
    if (tafsirId == null) return const SizedBox.shrink();
    final loaded = ref.watch(
      tafsirVerseTextProvider(
        chapterNo: verse.chapterNo,
        verseNo: verse.verseNo,
        tafsirId: tafsirId,
      ),
    );
    final theme = Theme.of(context);
    if (!loaded.hasValue) return const SizedBox.shrink();
    final text = loaded.value;
    if (text == null) {
      // A tafsir that comments only on some ayahs (Ahsan-ul-Bayan).
      return Text(
        AppLocalizations.of(context).tafsirNoNote,
        key: ValueKey(
          'ayah-mode-no-tafsir-${verse.chapterNo}:${verse.verseNo}',
        ),
        style: theme.textTheme.bodySmall?.copyWith(color: colors.secondaryText),
      );
    }
    return Container(
      key: ValueKey('ayah-mode-tafsir-${verse.chapterNo}:${verse.verseNo}'),
      padding: const EdgeInsets.all(TahfeezSpacing.smPlus),
      decoration: BoxDecoration(
        color: colors.secondaryText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TahfeezRadii.md),
      ),
      child: Text(
        text.text,
        // Its own language's direction (Al-Muyassar in the English app,
        // Al-Mukhtasar in the Arabic one).
        textDirection: rtlLanguages.contains(tafsirId.split('-').first)
            ? TextDirection.rtl
            : TextDirection.ltr,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.text,
          height: 1.6,
        ),
      ),
    );
  }
}

/// Languages written right to left (a translation's or tafsir's own).
const rtlLanguages = {'ar', 'ur', 'fa', 'he', 'ps', 'sd', 'ug', 'ckb'};
