import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/sharing/image_sharer.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/quran_text_style.dart';
import '../../../core/ui/script_direction.dart';
import '../../../quran/application/ayah_reading_extras.dart';
import '../../../quran/application/canonical_ayah_word_text.dart';
import '../../../quran/presentation/meaning_resource_names.dart';
import '../../quran/application/quran_index_providers.dart';
import '../application/mushaf_page_translations.dart';
import '../application/reader_mode.dart';

/// The shared image's width in pixels (a phone screen's, sharp in any
/// chat).
const kAyahImageWidth = 1080.0;

/// Shares ayah [ayahId] as an image: its canonical text in the reader's
/// Quran font, its reference, and (if chosen) its first translation with
/// the translator's name — light or dark.
Future<void> showAyahShareSheet(BuildContext context, {required int ayahId}) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context).shareAyahTitle,
      builder: (_) => _AyahShare(ayahId: ayahId),
    );

class _AyahShare extends ConsumerStatefulWidget {
  const _AyahShare({required this.ayahId});

  final int ayahId;

  @override
  ConsumerState<_AyahShare> createState() => _AyahShareState();
}

class _AyahShareState extends ConsumerState<_AyahShare> {
  final _card = GlobalKey();
  final _button = GlobalKey();
  bool _translation = true;

  /// The card's style: the app's own theme until chosen here.
  late bool _dark = Theme.of(context).brightness == Brightness.dark;
  bool _sharing = false;

  Future<void> _share() async {
    final boundary =
        _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final button = _button.currentContext;
    final origin = button == null ? null : shareOrigin(button);
    if (boundary == null) return;
    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(
        pixelRatio: kAyahImageWidth / boundary.size.width,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      final id = widget.ayahId;
      await ref
          .read(imageSharerProvider)
          .sharePng(
            data.buffer.asUint8List(),
            fileName: 'tahfeezai-${id ~/ 1000}-${id % 1000}.png',
            origin: origin,
          );
    } catch (_) {
      // Nothing shared.
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          // The preview is the image: drawn at this size, saved sharper.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // (The image square-cornered: no transparent corners in a
              // chat; only the preview rounded.)
              child: ClipRRect(
                borderRadius: BorderRadius.circular(TahfeezRadii.lg),
                child: RepaintBoundary(
                  key: _card,
                  child: AyahShareCard(
                    ayahId: widget.ayahId,
                    translation: _translation,
                    dark: _dark,
                  ),
                ),
              ),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('share-ayah-translation'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.tafsirShowTranslation),
            value: _translation,
            onChanged: (v) => setState(() => _translation = v),
          ),
          SegmentedButton<bool>(
            key: const ValueKey('share-ayah-style'),
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l10n.shareAyahLight),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text(l10n.shareAyahDark),
                icon: const Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {_dark},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _dark = s.first),
          ),
          FilledButton.icon(
            key: _button,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _sharing ? null : _share,
            icon: const Icon(Icons.share_outlined),
            label: Text(l10n.shareAyahShare),
          ),
        ],
      ),
    );
  }
}

/// The image itself: a calm card — the ayah, its reference, its
/// translation (with the translator), and the app's name small at the foot.
class AyahShareCard extends ConsumerWidget {
  const AyahShareCard({
    super.key,
    required this.ayahId,
    required this.translation,
    required this.dark,
  });

  final int ayahId;
  final bool translation, dark;

  static const _lightPaper = Color(0xFFF7F8F4);
  static const _lightInk = Color(0xFF18201D);
  static const _lightMuted = Color(0xFF5E6B65);
  static const _lightAccent = Color(0xFF176B5B);
  static const _darkPaper = Color(0xFF101513);
  static const _darkInk = Color(0xFFECF2EF);
  static const _darkMuted = Color(0xFFAAB6B0);
  static const _darkAccent = Color(0xFF68C6A8);

  static final _marker = RegExp(r'\[(\d+)\]');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final paper = dark ? _darkPaper : _lightPaper;
    final ink = dark ? _darkInk : _lightInk;
    final muted = dark ? _darkMuted : _lightMuted;
    final accent = dark ? _darkAccent : _lightAccent;
    final text = ref.watch(canonicalAyahTextProvider(ayahId: ayahId)).value;
    final font = ref.watch(ayahViewPreferencesProvider).quranFont;
    final surahNo = ayahId ~/ 1000, verseNo = ayahId % 1000;
    final surah = (ref.watch(indexedSurahsProvider).value ?? const [])
        .where((s) => s.surah.surahNo == surahNo)
        .firstOrNull;
    final name = surah?.localizedName ?? surah?.arabicName ?? '$surahNo';
    // The first chosen translation, as published (its note markers kept,
    // small), and who translated it.
    final translations = translation
        ? ref.watch(ayahTranslationsProvider(ayahId)).value
        : null;
    final verse = translations?.values.firstOrNull;
    final book = verse == null
        ? null
        : ref.watch(activeTranslationBooksProvider).value?[verse.slug];
    final body = Theme.of(context).textTheme.bodyLarge;

    return DecoratedBox(
      key: const ValueKey('share-ayah-card'),
      decoration: BoxDecoration(color: paper),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(
              text ?? '',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: quranTextStyle(
                color: ink,
                fontFamily: font.family,
                fontSize: 26,
              ),
            ),
            Text(
              l10n.homeDailyAyahReferenceNamed(name, verseNo),
              textAlign: TextAlign.center,
              style: body?.copyWith(color: accent, fontWeight: FontWeight.w600),
            ),
            if (verse != null) ...[
              Container(height: 1, color: muted.withValues(alpha: 0.25)),
              Text.rich(
                TextSpan(
                  children: [
                    for (final (i, part)
                        in verse.text.split(_marker).indexed) ...[
                      if (i > 0)
                        TextSpan(
                          text: _marker
                              .allMatches(verse.text)
                              .elementAt(i - 1)
                              .group(0),
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      TextSpan(text: part),
                    ],
                  ],
                ),
                textAlign: TextAlign.center,
                textDirection: meaningDirection(verse.text),
                style: body?.copyWith(color: ink, height: 1.5),
              ),
              if (book != null)
                Text(
                  translationName(l10n, book),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: muted),
                ),
            ],
            Text(
              'TahfeezAI',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: muted.withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
