import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/tahfeez_content_widths.dart';
import '../../../core/theme/tahfeez_motion.dart';
import '../../../core/theme/tahfeez_tones.dart';
import '../../../core/ui/bar_space.dart';
import '../../home/presentation/home_sky.dart';
import '../../mushaf/application/reader_mode.dart';
import '../../duas/application/saved_supplications.dart';
import '../../duas/presentation/saved_button.dart';
import '../application/athkar_audio.dart';
import '../application/athkar_haptics.dart';
import '../application/athkar_progress.dart';
import '../data/athkar_source.dart';
import '../domain/athkar.dart';
import 'athkar_look.dart';
import 'athkar_screen.dart' show AthkarHeading;

/// [categoryId] from the book, or `null` while it loads (or none such).
AthkarCategory? _category(WidgetRef ref, int categoryId) =>
    ref.watch(athkarBookProvider).value?.category(categoryId);

/// The athkar's own scaffold: the sky, the bar with [title], [actions].
class _AthkarScaffold extends StatelessWidget {
  const _AthkarScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SkyBackdrop(
    child: Scaffold(
      appBar: TahfeezAppBar(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        centerTitle: false,
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TahfeezContentWidth.maxReading,
            ),
            child: body,
          ),
        ),
      ),
    ),
  );
}

/// Listen to [file] (or stop it): from hisnmuslim.com, online.
class _ListenButton extends ConsumerWidget {
  const _ListenButton({super.key, required this.file});

  final String file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final playing = ref.watch(athkarAudioProvider) == file;
    return IconButton(
      tooltip: playing ? l10n.athkarStopListening : l10n.athkarListen,
      icon: Icon(
        playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final played = await ref
            .read(athkarAudioProvider.notifier)
            .toggle(file);
        if (!played) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.athkarAudioOffline)),
          );
        }
      },
    );
  }
}

/// A chapter of athkar: with one, the zikr itself; with more, each as a
/// tile — ticked once said as many times as it is — and Start (or
/// Continue) to say them one after another.
class AthkarCategoryScreen extends ConsumerWidget {
  const AthkarCategoryScreen({super.key, required this.categoryId});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final category = _category(ref, categoryId);
    final language = Localizations.localeOf(context).languageCode;
    if (category == null) {
      return _AthkarScaffold(
        title: l10n.athkarTitle,
        body: ref.watch(athkarBookProvider).isLoading
            ? const Center(child: CircularProgressIndicator())
            : TahfeezEmptyView(message: l10n.athkarLoadError),
      );
    }
    if (category.athkar.length == 1) {
      return AthkarReaderScreen(categoryId: categoryId);
    }
    final counts = ref.watch(athkarProgressProvider);
    final (:done, :of) = athkarDone(category, counts);
    final firstLeft = category.athkar.indexWhere(
      (z) => (counts[z.id] ?? 0) < z.repeat,
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context);
    final font = ref.watch(ayahViewPreferencesProvider).quranFont.family;
    return _AthkarScaffold(
      title: l10n.athkarTitle,
      actions: [
        SavedSupplicationButton(SavedSupplications.chapterKey(category.id)),
        _ListenButton(
          key: const ValueKey('athkar-listen-category'),
          file: category.audio,
        ),
      ],
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: withBarSpace(
              context,
              const EdgeInsets.all(TahfeezSpacing.md),
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                // Its name, whole (owner, 2026-11-21: cut short in the bar).
                SliverToBoxAdapter(
                  child: AthkarHeading(
                    category.titleIn(language),
                    full: category.fullTitleIn(language),
                  ),
                ),
                SliverToBoxAdapter(
                  child: TahfeezCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: TahfeezSpacing.sm,
                      children: [
                        Row(
                          spacing: TahfeezSpacing.smPlus,
                          children: [
                            Icon(
                              athkarCategoryIcon(category.id),
                              color: scheme.primary,
                            ),
                            Expanded(
                              child: Text(
                                l10n.athkarDoneOf(done, of),
                                key: const ValueKey('athkar-done-of'),
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            TahfeezRadii.pill,
                          ),
                          child: LinearProgressIndicator(
                            value: of == 0 ? 0 : done / of,
                            minHeight: 6,
                            backgroundColor: scheme.progressTrack,
                          ),
                        ),
                        Wrap(
                          spacing: TahfeezSpacing.sm,
                          runSpacing: TahfeezSpacing.xs,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey('athkar-start'),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                done == 0 || firstLeft < 0
                                    ? l10n.athkarStart
                                    : l10n.athkarContinue,
                              ),
                              onPressed: () => context.push(
                                AppRoutes.athkarRead(
                                  category.id,
                                  at: firstLeft < 0 ? 0 : firstLeft,
                                ),
                              ),
                            ),
                            if (done > 0 ||
                                category.athkar.any(
                                  (z) => (counts[z.id] ?? 0) > 0,
                                ))
                              TextButton.icon(
                                key: const ValueKey('athkar-start-again'),
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: Text(l10n.athkarStartAgain),
                                onPressed: () => ref
                                    .read(athkarProgressProvider.notifier)
                                    .reset(category),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: TahfeezSpacing.md),
                ),
                SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: scale.scale(220),
                    mainAxisExtent: scale.scale(150),
                    crossAxisSpacing: TahfeezSpacing.sm,
                    mainAxisSpacing: TahfeezSpacing.sm,
                  ),
                  itemCount: category.athkar.length,
                  itemBuilder: (context, i) {
                    final zikr = category.athkar[i];
                    final count = counts[zikr.id] ?? 0;
                    final finished = count >= zikr.repeat;
                    return TahfeezCard(
                      key: ValueKey('athkar-zikr-${zikr.id}'),
                      onTap: () => context.push(
                        AppRoutes.athkarRead(category.id, at: i),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: scheme.primaryContainer,
                                child: Text(
                                  '${i + 1}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (finished)
                                Icon(
                                  Icons.check_circle_rounded,
                                  key: ValueKey('athkar-zikr-done-${zikr.id}'),
                                  color: scheme.primary,
                                )
                              else
                                Text(
                                  count > 0
                                      ? '$count / ${zikr.repeat}'
                                      : '× ${zikr.repeat}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: count > 0
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: TahfeezSpacing.sm),
                          Expanded(
                            child: Text(
                              zikr.arabic,
                              textDirection: TextDirection.rtl,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: font,
                                height: 1.6,
                                color: finished
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A chapter's athkar one after another, from its [start]th: each a card
/// counted with a tap (on the card or its counter); swiped between, and
/// on to the next by itself once one is said as many times as it is
/// (owner, 2026-11-21). Then, with more than one, "All done".
class AthkarReaderScreen extends ConsumerStatefulWidget {
  const AthkarReaderScreen({
    super.key,
    required this.categoryId,
    this.start = 0,
  });

  final int categoryId;
  final int start;

  /// How long a finished zikr stays before the next comes.
  static const advanceAfter = Duration(milliseconds: 700);

  @override
  ConsumerState<AthkarReaderScreen> createState() => _AthkarReaderState();
}

class _AthkarReaderState extends ConsumerState<AthkarReaderScreen> {
  /// The pages: the rest of the height, or (when [short]) most of it.
  static Widget sized(bool short, double height, Widget pages) => short
      ? SizedBox(height: height < 275 ? 220 : height * 0.8, child: pages)
      : Expanded(child: pages);

  late final _pages = PageController(initialPage: widget.start);
  late var _page = widget.start;
  Timer? _advance;

  @override
  void dispose() {
    _advance?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _pages.jumpToPage(page);
    } else {
      unawaited(
        _pages.animateToPage(
          page,
          duration: TahfeezMotionDuration.slow,
          curve: TahfeezMotionCurves.standard,
        ),
      );
    }
  }

  void _count(AthkarCategory category, int index) {
    final zikr = category.athkar[index];
    final progress = ref.read(athkarProgressProvider.notifier);
    if (progress.isDone(zikr)) return;
    final finished = progress.count(zikr);
    ref.read(athkarHapticsProvider)(done: finished);
    if (!finished) return;
    // On to the next (or "All done") by itself.
    final last = category.athkar.length == 1 ? index : category.athkar.length;
    if (index >= last) return;
    _advance?.cancel();
    _advance = Timer(AthkarReaderScreen.advanceAfter, () {
      if (mounted && _page == index) _go(index + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final category = _category(ref, widget.categoryId);
    final language = Localizations.localeOf(context).languageCode;
    if (category == null) {
      return _AthkarScaffold(
        title: l10n.athkarTitle,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final n = category.athkar.length;
    // With more than one: "All done" after the last.
    final pages = n == 1 ? 1 : n + 1;
    final onDone = _page >= n;
    final theme = Theme.of(context);
    // Previous at the start (right in Arabic), pointing that way.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final zikr = onDone ? null : category.athkar[_page];
    final count = zikr == null
        ? 0
        : ref.watch(athkarProgressProvider.select((c) => c[zikr.id] ?? 0));
    return _AthkarScaffold(
      title: l10n.athkarTitle,
      actions: [
        SavedSupplicationButton(SavedSupplications.chapterKey(category.id)),
        if (zikr?.audio != null)
          _ListenButton(
            key: ValueKey('athkar-listen-$_page'),
            file: zikr!.audio!,
          ),
      ],
      // A short landscape phone at large text: the page scrolls, the zikr
      // a fixed height, so the counter stays reachable.
      body: LayoutBuilder(
        builder: (context, box) {
          final short = box.maxHeight < 400;
          final children = <Widget>[
            // The chapter's name, whole, under the bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TahfeezSpacing.md,
                TahfeezSpacing.sm,
                TahfeezSpacing.md,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AthkarHeading(
                  category.titleIn(language),
                  full: category.fullTitleIn(language),
                ),
              ),
            ),
            sized(
              short,
              box.maxHeight,
              PageView.builder(
                key: const ValueKey('athkar-pages'),
                controller: _pages,
                itemCount: pages,
                onPageChanged: (p) {
                  _advance?.cancel();
                  setState(() => _page = p);
                },
                itemBuilder: (context, i) => i == n
                    ? _AllDone(category: category)
                    : _ZikrPage(
                        zikr: category.athkar[i],
                        onCount: () => _count(category, i),
                      ),
              ),
            ),
            // At the foot, in one row: back, the counter, on (owner,
            // 2026-11-21: they stood too high, one above the other).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TahfeezSpacing.md,
                TahfeezSpacing.xs,
                TahfeezSpacing.md,
                TahfeezSpacing.sm,
              ),
              child: Row(
                children: [
                  if (n > 1)
                    IconButton(
                      key: const ValueKey('athkar-previous'),
                      tooltip: l10n.commonPrevious,
                      iconSize: 32,
                      icon: Icon(
                        rtl
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                      ),
                      onPressed: _page > 0 ? () => _go(_page - 1) : null,
                    ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (zikr != null)
                          _Counter(
                            key: ValueKey('athkar-counter-${zikr.id}'),
                            count: count,
                            repeat: zikr.repeat,
                            onTap: () => _count(category, _page),
                          )
                        else
                          const SizedBox(height: _Counter.size),
                        const SizedBox(height: TahfeezSpacing.xs),
                        Text(
                          [
                            if (n > 1 && zikr != null) '${_page + 1} / $n',
                            if (zikr != null)
                              count >= zikr.repeat
                                  ? l10n.athkarTimes(zikr.repeat)
                                  : l10n.athkarTapToCount,
                          ].join('  ·  '),
                          key: const ValueKey('athkar-position'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (n > 1)
                    IconButton(
                      key: const ValueKey('athkar-next'),
                      tooltip: l10n.commonNext,
                      iconSize: 32,
                      icon: Icon(
                        rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                      ),
                      onPressed: _page < pages - 1
                          ? () => _go(_page + 1)
                          : null,
                    ),
                ],
              ),
            ),
          ];
          return short
              ? SingleChildScrollView(child: Column(children: children))
              : Column(children: children);
        },
      ),
    );
  }
}

/// One zikr: its Arabic (in the Ayah mode's font), its translation and
/// note (not in Arabic). A tap on it counts.
class _ZikrPage extends ConsumerWidget {
  const _ZikrPage({required this.zikr, required this.onCount});

  final Zikr zikr;
  final VoidCallback onCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final arabic = language == 'ar';
    final font = ref.watch(ayahViewPreferencesProvider).quranFont.family;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TahfeezSpacing.md),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              key: ValueKey('athkar-card-${zikr.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onCount,
              child: TahfeezCard(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(TahfeezSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: TahfeezSpacing.md,
                    children: [
                      Text(
                        zikr.arabic,
                        key: ValueKey('athkar-arabic-${zikr.id}'),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontFamily: font,
                          height: 1.9,
                        ),
                      ),
                      if (!arabic && zikr.note.isNotEmpty)
                        Text(
                          zikr.note,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      if (!arabic && zikr.english.isNotEmpty) ...[
                        Text(
                          zikr.english,
                          key: ValueKey('athkar-english-${zikr.id}'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (language != 'en')
                          Text(
                            l10n.athkarEnglishNote,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The counter: a round button, its ring filling as the zikr is said, the
/// times left in it (a tick once done).
class _Counter extends StatelessWidget {
  const _Counter({
    super.key,
    required this.count,
    required this.repeat,
    required this.onTap,
  });

  /// Its diameter.
  static const size = 76.0;

  final int count, repeat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final finished = count >= repeat;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      label: '${l10n.athkarTapToCount}, $count / $repeat',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          shape: const CircleBorder(),
          color: finished ? scheme.primary : scheme.primaryContainer,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: finished ? null : onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: repeat == 0 ? 0 : count / repeat),
                      duration: still
                          ? Duration.zero
                          : TahfeezMotionDuration.medium,
                      builder: (context, v, _) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 4,
                        color: finished ? scheme.onPrimary : scheme.primary,
                        backgroundColor: scheme.progressTrack,
                      ),
                    ),
                  ),
                ),
                if (finished)
                  Icon(Icons.check_rounded, size: 40, color: scheme.onPrimary)
                else
                  Text(
                    '${repeat - count}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// After a chapter's last zikr: all done (or how many are) — back to its
/// tiles, or start again.
class _AllDone extends ConsumerWidget {
  const _AllDone({required this.category});

  final AthkarCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counts = ref.watch(athkarProgressProvider);
    final (:done, :of) = athkarDone(category, counts);
    final all = done == of;
    return Center(
      key: const ValueKey('athkar-all-done'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TahfeezSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TahfeezSpacing.md,
          children: [
            Icon(
              all ? Icons.check_circle_rounded : Icons.pending_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            Text(
              all ? l10n.athkarAllDone : l10n.athkarDoneOf(done, of),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            FilledButton(
              key: const ValueKey('athkar-back-to-list'),
              onPressed: () => context.pop(),
              child: Text(l10n.athkarTitle),
            ),
          ],
        ),
      ),
    );
  }
}
