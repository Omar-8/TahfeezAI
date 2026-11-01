import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/quran_text_style.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../memorization/domain/test_me.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/quran_providers.dart';
import '../../mushaf/application/reader_mode.dart';
import 'memorize_screen.dart';

/// An ayah's canonical words, in order (the safe display source, as
/// `canonicalAyahTextProvider`).
final testMeAyahWordsProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, ayahId) async {
      final words = await ref
          .watch(quranRepositoryProvider)
          .getWordsForAyah(
            ayahId,
            scriptCode: ref.watch(quranScriptCodeProvider),
          );
      return [for (final w in words) w.text];
    });

/// The Memorize tab's "Test me": the opening words of a random memorized
/// ayah ([TestMe.pick]); where it is stays hidden until asked; Start
/// opens the test there with those words given, the rest recited from
/// memory. Nothing when nothing is memorized yet.
class TestMeSection extends ConsumerStatefulWidget {
  const TestMeSection({super.key, required this.names, this.random});

  final Map<int, String> names;

  /// For tests: a seeded generator.
  final math.Random? random;

  @override
  ConsumerState<TestMeSection> createState() => _TestMeSectionState();
}

class _TestMeSectionState extends ConsumerState<TestMeSection> {
  late final math.Random _random = widget.random ?? math.Random();
  TestMeQuestion? _question;
  bool _shown = false;

  void _next() {
    final memories = ref.read(ayahMemoriesProvider).value;
    if (memories == null) return;
    setState(() {
      _question = TestMe.pick(
        memories,
        random: _random,
        now: ref.read(memorizationClockProvider)(),
        not: _question?.first,
      );
      _shown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(ayahMemoriesProvider).value;
    if (memories == null) return const SizedBox.shrink();
    // The first question once the memories are known; a new one when the
    // asked ayah is no longer memorized (unmarked).
    final asked = _question;
    if (asked == null || !TestMe.isMemorized(memories, asked.first)) {
      _question = TestMe.pick(
        memories,
        random: _random,
        now: ref.read(memorizationClockProvider)(),
      );
      _shown = false;
    }
    final question = _question;
    if (question == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final words = ref.watch(testMeAyahWordsProvider(question.first)).value;
    final page = ref.watch(ayahPagesProvider).value?[question.first];
    final font = ref.watch(ayahViewPreferencesProvider).quranFont;
    final prompt = words == null ? 0 : TestMe.promptWords(words.length);
    final where = [
      ayahRangeLabel(question.first, question.first, widget.names),
      if (page != null) l10n.memPage(page),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: TahfeezSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.sm,
        children: [
          TahfeezSectionHeader(
            title: l10n.memTestMe,
            icon: Icons.quiz_outlined,
          ),
          Text(
            l10n.memTestMeSub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TahfeezCard(
            key: const ValueKey('mem-test-me'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.sm,
              children: [
                SizedBox(
                  height: 64,
                  child: Center(
                    child: words == null
                        ? null
                        : Text(
                            '${words.take(prompt).join(' ')} …',
                            key: const ValueKey('mem-test-me-prompt'),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: quranTextStyle(
                              color: theme.colorScheme.onSurface,
                              fontFamily: font.family,
                              fontSize: 26,
                            ),
                          ),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: TahfeezSpacing.sm,
                  runSpacing: TahfeezSpacing.xs,
                  children: [
                    if (_shown)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TahfeezSpacing.sm,
                          vertical: TahfeezSpacing.smPlus,
                        ),
                        child: Text(
                          where,
                          key: const ValueKey('mem-test-me-where'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      TextButton.icon(
                        key: const ValueKey('mem-test-me-show'),
                        onPressed: () => setState(() => _shown = true),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(l10n.memTestMeWhere),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: TahfeezSpacing.xs,
                      children: [
                        IconButton(
                          key: const ValueKey('mem-test-me-another'),
                          tooltip: l10n.memTestMeAnother,
                          onPressed: _next,
                          icon: const Icon(Icons.shuffle),
                        ),
                        FilledButton.tonal(
                          key: const ValueKey('mem-test-me-start'),
                          onPressed: words == null
                              ? null
                              : () => reciteAyahs(
                                  context,
                                  ref,
                                  question.first,
                                  question.last,
                                  prompt: prompt,
                                ),
                          child: Text(l10n.memStart),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
