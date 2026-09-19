import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/components.dart';
import '../domain/models/translation_models.dart';
import 'quick_reference_sheet.dart';

/// One installed translation's stacked block under a verse's Arabic text
/// (`docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §2's "reader stacks each
/// selected translation's text ... each ending with a muted attribution
/// line"): inline footnote markers (`[n]` in [TranslationVerseText.text])
/// are individually tappable, opening the matching [TranslationFootnote]'s
/// text; [TranslationVerseText.crossReferences] render as a row of
/// [TahfeezActionChip]s opening [showQuickReferenceSheet]. Independently
/// designed — not the reference app's `AnnotatedString`/`withLink` markup.
class TranslationBlock extends StatelessWidget {
  const TranslationBlock({
    super.key,
    required this.verseText,
    required this.authorName,
  });

  final TranslationVerseText verseText;
  final String authorName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TahfeezSpacing.xs,
      children: [
        Text.rich(
          TextSpan(
            children: _buildSpans(context, bodyStyle, scheme),
            style: bodyStyle,
          ),
        ),
        if (verseText.crossReferences.isNotEmpty)
          Wrap(
            spacing: TahfeezSpacing.xs,
            runSpacing: TahfeezSpacing.xs,
            children: [
              for (final ref in verseText.crossReferences)
                TahfeezActionChip(
                  label: '${ref.chapterNo}:${ref.verseNo}',
                  icon: Icons.link,
                  onPressed: () => showQuickReferenceSheet(context, ref),
                ),
            ],
          ),
        Text(
          '— $authorName',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static final _footnoteMarkerPattern = RegExp(r'\[(\d+)\]');

  List<InlineSpan> _buildSpans(
    BuildContext context,
    TextStyle? bodyStyle,
    ColorScheme scheme,
  ) {
    final footnotesByMarker = {
      for (final f in verseText.footnotes) f.marker: f,
    };
    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in _footnoteMarkerPattern.allMatches(verseText.text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(text: verseText.text.substring(lastEnd, match.start)),
        );
      }
      final marker = int.parse(match.group(1)!);
      final footnote = footnotesByMarker[marker];
      if (footnote != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _showFootnote(context, footnote),
              child: Text(
                '[$marker]',
                style: bodyStyle?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: (bodyStyle.fontSize ?? 14) * 0.75,
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: match.group(0)));
      }
      lastEnd = match.end;
    }
    if (lastEnd < verseText.text.length) {
      spans.add(TextSpan(text: verseText.text.substring(lastEnd)));
    }
    return spans;
  }

  void _showFootnote(BuildContext context, TranslationFootnote footnote) {
    showTahfeezModalBottomSheet(
      context: context,
      title: 'Footnote ${footnote.marker}',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Text(footnote.text),
      ),
    );
  }
}
