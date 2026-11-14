import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/supported_locales.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/tahfeez_motion.dart';
import '../../../core/ui/app_name_text.dart';
import '../../home/presentation/home_sky.dart';
import '../../khatmah/application/khatmah_controller.dart';
import '../../khatmah/domain/khatmah.dart';
import '../../listen/application/quran_audio_player.dart';
import '../../listen/application/reciter_controller.dart';
import '../../listen/domain/quran_audio_sources.dart';
import '../../listen/presentation/listen_sheet.dart' show reciterName;
import '../../listen/presentation/reciter_avatar.dart';
import '../../mushaf/application/reader_mode.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../mushaf/application/mushaf_word_overlay.dart';
import '../../mushaf/domain/mushaf_appearance.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../recitation/presentation/recitation_controls.dart';
import '../../../quran/application/meaning_packs.dart';
import '../../mushaf/application/mushaf_page_translations.dart';
import '../../mushaf/presentation/ayah_view_parts.dart';
import '../../../quran/application/ayah_reading_extras.dart';

/// Where a new user wants to begin.
enum SetupGoal { memorize, khatmah, read }

enum _Step { welcome, language, goal, reciter, demo }

/// The first start's setup, over Home's sky: a welcome (what the app is
/// for, and that its checking is still learning), then the language, what
/// to begin with (a khatmah's days chosen there), a reciter (a sample to
/// hear) and how reciting works — an ayah recited in front of them, its
/// words marked as the app marks them, then the ayah to try a word's tap
/// and long-press on. Each skippable, each applied as it is chosen. Also
/// from Settings, to run again.
Future<void> showFirstRunSetup(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'first-run-setup'),
        transitionDuration: TahfeezMotionDuration.slow,
        reverseTransitionDuration: TahfeezMotionDuration.medium,
        pageBuilder: (_, _, _) => const FirstRunSetup(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: TahfeezMotionCurves.standard,
          ),
          child: child,
        ),
      ),
    );

class FirstRunSetup extends ConsumerStatefulWidget {
  const FirstRunSetup({super.key});

  /// Al-Fātiḥah's first two ayahs: the reciter's sample.
  static const sample = [1001, 1002];

  @override
  ConsumerState<FirstRunSetup> createState() => _FirstRunSetupState();
}

class _FirstRunSetupState extends ConsumerState<FirstRunSetup> {
  var _index = 0;

  /// Forward (1) or back (-1): the way the steps slide.
  var _direction = 1;
  var _goal = SetupGoal.memorize;
  var _khatmahDays = 30;

  /// The reciter whose sample is playing.
  String? _sampling;

  List<_Step> get _steps => _Step.values;

  _Step get _step => _steps[_index];
  bool get _last => _index == _steps.length - 1;

  @override
  void dispose() {
    if (_sampling != null) {
      unawaited(ref.read(quranAudioPlayerProvider.notifier).stop());
    }
    super.dispose();
  }

  void _go(int by) {
    if (_sampling != null) _stopSample();
    setState(() {
      _direction = by;
      _index = (_index + by).clamp(0, _steps.length - 1);
    });
  }

  void _stopSample() {
    _sampling = null;
    unawaited(ref.read(quranAudioPlayerProvider.notifier).stop());
  }

  Future<void> _sample(Reciter reciter) async {
    if (_sampling == reciter.edition) {
      setState(_stopSample);
      return;
    }
    await ref.read(reciterProvider.notifier).select(reciter.edition);
    setState(() => _sampling = reciter.edition);
    final played = await ref
        .read(quranAudioPlayerProvider.notifier)
        .playAyahs(FirstRunSetup.sample);
    if (!played && mounted && _sampling == reciter.edition) {
      setState(() => _sampling = null);
    }
  }

  /// Done: a khatmah begun (if none is under way), and Memorize opened
  /// for those who came to memorize.
  Future<void> _finish() async {
    final navigator = Navigator.of(context);
    final router = ref.read(appRouterProvider);
    if (_sampling != null) _stopSample();
    if (_goal == SetupGoal.khatmah) {
      final khatmah = ref.read(khatmahProvider.notifier);
      if (await ref.read(khatmahProvider.future) == null) {
        await khatmah.start(_khatmahDays);
      }
    }
    navigator.pop();
    if (_goal == SetupGoal.memorize) router.go(AppRoutes.memorize);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final steps = _steps;
    return PopScope(
      // Back: the step before (from the first, out).
      canPop: _index == 0,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _go(-1);
      },
      child: Scaffold(
        key: const ValueKey('first-run-setup'),
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: HomeSky(height: size.height * 0.9),
            ),
            TahfeezGlass(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TahfeezSpacing.lg,
                        TahfeezSpacing.sm,
                        TahfeezSpacing.sm,
                        0,
                      ),
                      child: Row(
                        children: [
                          _StepDots(count: steps.length, index: _index),
                          const SizedBox(width: TahfeezSpacing.sm),
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: _last
                                  ? null
                                  : TextButton(
                                      key: const ValueKey('setup-skip'),
                                      onPressed: () {
                                        if (_sampling != null) _stopSample();
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        l10n.setupSkip,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                            ),
                          ),
                          // (The same height with or without Skip.)
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: still
                            ? Duration.zero
                            : TahfeezMotionDuration.slow,
                        switchInCurve: TahfeezMotionCurves.standard,
                        switchOutCurve: TahfeezMotionCurves.exit,
                        transitionBuilder: (child, animation) {
                          final incoming = child.key == ValueKey(_step);
                          final dx = 0.08 * _direction * (incoming ? 1 : -1);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: Offset(dx, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _content(context, _step),
                        ),
                      ),
                    ),
                    // The real recitation bar, on the demo's ayah.
                    if (_step == _Step.demo &&
                        ref.watch(recitationBarVisibleProvider))
                      const LiveRecitationBar(key: ValueKey('setup-bar')),
                    _BottomBar(
                      first: _index == 0,
                      last: _last,
                      onBack: () => _go(-1),
                      onNext: _last ? _finish : () => _go(1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, _Step step) => switch (step) {
    _Step.welcome => const _Welcome(),
    _Step.language => const _Language(),
    _Step.goal => _Goal(
      goal: _goal,
      days: _khatmahDays,
      onGoal: (g) => setState(() => _goal = g),
      onDays: (d) => setState(() => _khatmahDays = d),
    ),
    _Step.reciter => _Reciters(sampling: _sampling, onSample: _sample),
    _Step.demo => const _Demo(),
  };
}

/// A step's column: centred, a reading column wide.
class _StepFrame extends StatelessWidget {
  const _StepFrame({
    required this.title,
    required this.subtitle,
    this.child,
    this.sliver,
    this.scrollKey,
  }) : assert((child == null) != (sliver == null));

  final String title, subtitle;

  /// The step's content under its title, scrolling with it…
  final Widget? child;

  /// …or a long list (a sliver), the title scrolling away above it.
  final Widget? sliver;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.lg,
        TahfeezSpacing.md,
        TahfeezSpacing.lg,
        TahfeezSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.sm,
        children: [
          TahfeezStar(
            color: theme.colorScheme.primary,
            size: 26,
            filled: false,
          ),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    const side = EdgeInsets.symmetric(horizontal: TahfeezSpacing.md);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: CustomScrollView(
          key: scrollKey,
          slivers: [
            SliverToBoxAdapter(child: header),
            SliverPadding(
              padding: side.copyWith(bottom: TahfeezSpacing.lg),
              sliver: sliver ?? SliverToBoxAdapter(child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// The emblem over a soft light, the app's name, its greeting, what it is
/// for — and that its checking is still learning.
class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final [about, ...note] = l10n.homeWelcomeBody.split('\n\n');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TahfeezSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            spacing: TahfeezSpacing.md,
            children: [
              Container(
                width: 196,
                height: 196,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.18),
                      scheme.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Image.asset(
                  'assets/branding/splash_emblem.png',
                  key: const ValueKey('setup-emblem'),
                  excludeFromSemantics: true,
                ),
              ),
              AppNameText(
                l10n.appName,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.homeSalam,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                about,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (note.isNotEmpty)
                TahfeezCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: TahfeezSpacing.smPlus,
                    children: [
                      Icon(Icons.auto_awesome_outlined, color: scheme.primary),
                      Expanded(
                        child: Text(
                          note.join('\n\n'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The interface's language, applied at once.
class _Language extends ConsumerWidget {
  const _Language();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current =
        ref.watch(localeControllerProvider)?.languageCode ??
        Localizations.localeOf(context).languageCode;
    // Larger text: wider tiles (fewer to a row), taller.
    final scale = MediaQuery.textScalerOf(context);
    return _StepFrame(
      title: l10n.setupLanguageTitle,
      subtitle: l10n.setupLanguageSub,
      scrollKey: const ValueKey('setup-languages'),
      sliver: SliverGrid.extent(
        maxCrossAxisExtent: scale.scale(240),
        childAspectRatio: scale.scale(240) / scale.scale(60),
        crossAxisSpacing: TahfeezSpacing.sm,
        mainAxisSpacing: TahfeezSpacing.sm,
        children: [
          for (final (code, flag, name) in kAppLanguages)
            _Choice(
              key: ValueKey('setup-language-$code'),
              selected: code == current,
              onTap: () => ref
                  .read(localeControllerProvider.notifier)
                  .setLocale(Locale(code)),
              child: Row(
                spacing: TahfeezSpacing.smPlus,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 22)),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Memorize, a khatmah (its days chosen here) or reading and listening.
class _Goal extends StatelessWidget {
  const _Goal({
    required this.goal,
    required this.days,
    required this.onGoal,
    required this.onDays,
  });

  final SetupGoal goal;
  final int days;
  final ValueChanged<SetupGoal> onGoal;
  final ValueChanged<int> onDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget option(SetupGoal g, IconData icon, String title, String sub) =>
        _Choice(
          key: ValueKey('setup-goal-${g.name}'),
          selected: g == goal,
          onTap: () => onGoal(g),
          tickAtTop: true,
          padding: const EdgeInsets.all(TahfeezSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: TahfeezSpacing.md,
                children: [
                  _IconBadge(icon: icon, selected: g == goal),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: TahfeezSpacing.xs,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(
                          sub,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // A khatmah's days, under it once chosen.
              AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : TahfeezMotionDuration.medium,
                curve: TahfeezMotionCurves.standard,
                alignment: Alignment.topCenter,
                child: g == SetupGoal.khatmah && goal == SetupGoal.khatmah
                    ? Padding(
                        padding: const EdgeInsets.only(top: TahfeezSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: TahfeezSpacing.sm,
                          children: [
                            Text(
                              l10n.khatmahFinishIn,
                              style: theme.textTheme.titleSmall,
                            ),
                            Wrap(
                              spacing: TahfeezSpacing.sm,
                              runSpacing: TahfeezSpacing.sm,
                              children: [
                                for (final d in Khatmah.dayChoices)
                                  ChoiceChip(
                                    key: ValueKey('setup-khatmah-$d'),
                                    label: Text(l10n.khatmahDays(d)),
                                    selected: d == days,
                                    onSelected: (_) => onDays(d),
                                  ),
                              ],
                            ),
                            Text(
                              l10n.khatmahPerDay((kKhatmahPages / days).ceil()),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
    return _StepFrame(
      title: l10n.setupGoalTitle,
      subtitle: l10n.setupGoalSub,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          option(
            SetupGoal.memorize,
            Icons.psychology_alt_outlined,
            l10n.setupGoalMemorize,
            l10n.setupGoalMemorizeSub,
          ),
          option(
            SetupGoal.khatmah,
            Icons.auto_stories_outlined,
            l10n.setupGoalKhatmah,
            l10n.setupGoalKhatmahSub,
          ),
          option(
            SetupGoal.read,
            Icons.headphones_outlined,
            l10n.setupGoalRead,
            l10n.setupGoalReadSub,
          ),
        ],
      ),
    );
  }
}

/// The reciters with their pictures; one chosen at a tap, ▶ plays a sample
/// (Al-Fātiḥah's opening) by them.
class _Reciters extends ConsumerWidget {
  const _Reciters({required this.sampling, required this.onSample});

  final String? sampling;
  final ValueChanged<Reciter> onSample;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chosen = ref.watch(reciterProvider);
    return _StepFrame(
      title: l10n.setupReciterTitle,
      subtitle: l10n.setupReciterSub,
      scrollKey: const ValueKey('setup-reciters'),
      sliver: SliverList.separated(
        itemCount: reciters.length,
        separatorBuilder: (_, _) => const SizedBox(height: TahfeezSpacing.sm),
        itemBuilder: (context, i) {
          final r = reciters[i];
          final playing = sampling == r.edition;
          return _Choice(
            key: ValueKey('setup-reciter-${r.edition}'),
            selected: r.edition == chosen,
            onTap: () => ref.read(reciterProvider.notifier).select(r.edition),
            padding: const EdgeInsetsDirectional.fromSTEB(
              TahfeezSpacing.smPlus,
              TahfeezSpacing.sm,
              TahfeezSpacing.xs,
              TahfeezSpacing.sm,
            ),
            child: Row(
              spacing: TahfeezSpacing.smPlus,
              children: [
                ReciterAvatar(reciter: r, size: 44),
                Expanded(
                  child: Text(
                    reciterName(context, r),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: ValueKey('setup-sample-${r.edition}'),
                  tooltip: l10n.setupReciterSample,
                  isSelected: playing,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  selectedIcon: const Icon(Icons.stop_circle_outlined),
                  color: theme.colorScheme.primary,
                  onPressed: () => onSample(r),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The demo's ayah: Al-Fātiḥah 1:2, from the app's own Quran text.
const _demoAyah = 1002;

/// Its page in the Mushaf (Al-Fātiḥah's).
const _demoPage = 1;

/// How reciting works: the ayah "recited" word by word — the next word
/// banded, the words said inked as the app inks them (one with a
/// pronunciation slip) — over and over, with the colours' key; then the
/// same ayah for real: a tap shows a word's meaning, a long-press its
/// translation, tafsir and recitation, and the recitation bar under the
/// step works on it as in the Mushaf (reported as all its page shows).
class _Demo extends ConsumerWidget {
  const _Demo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final words = ref.watch(ayahCanonicalWordsProvider(_demoAyah)).value;
    final font = ref.watch(ayahViewPreferencesProvider).quranFont.family;
    final mushafId = ref.watch(defaultMushafProvider).value?.id;
    final frame = _StepFrame(
      title: l10n.setupDemoTitle,
      subtitle: l10n.setupDemoSub,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          if (words != null) ...[
            _RecitingDemo(words: [for (final w in words) w.text], font: font),
            _TryDemo(
              words: [for (final w in words) (w.wordIndex, w.text)],
              font: font,
            ),
          ],
        ],
      ),
    );
    if (words == null || mushafId == null) return frame;
    return _DemoPageReport(
      wordCount: words.length,
      child: RecitationMushafAnchor(
        location: QuranLocation.page(mushafId, _demoPage),
        child: frame,
      ),
    );
  }
}

/// While the demo shows: its page reported as showing the demo's ayah
/// alone (so the bar's Recite, Loop, Listen and Follow along take it),
/// and the shell's own bar out of the way; what the page had reported
/// before is put back after.
class _DemoPageReport extends ConsumerStatefulWidget {
  const _DemoPageReport({required this.wordCount, required this.child});

  final int wordCount;
  final Widget child;

  @override
  ConsumerState<_DemoPageReport> createState() => _DemoPageReportState();
}

class _DemoPageReportState extends ConsumerState<_DemoPageReport> {
  // Captured up front: `ref` is unusable by the time dispose runs.
  late final _verses = ref.read(mushafPageVersesProvider.notifier);
  late final _ranges = ref.read(mushafPageWordRangesProvider.notifier);
  late final _hide = ref.read(mushafHideModeProvider.notifier);
  late final _elsewhere = ref.read(recitationBarElsewhereProvider.notifier);

  MushafPageVerseSpan? _span;
  MushafPageWordRange? _range;
  int? _wordCount;
  List<int>? _boundaries;

  @override
  void initState() {
    super.initState();
    _span = ref.read(mushafPageVersesProvider)[_demoPage];
    _range = ref.read(mushafPageWordRangesProvider)[_demoPage];
    final hide = ref.read(mushafHideModeProvider);
    _wordCount = hide.wordCounts[_demoPage];
    _boundaries = hide.ayahBoundaries[_demoPage];
    // (Providers can't change while the tree builds.)
    Future.microtask(() {
      if (!mounted) return;
      const verse = (chapterNo: 1, verseNo: 2);
      _verses.report(_demoPage, (first: verse, last: verse));
      _ranges.report(_demoPage, (
        first: (ayahId: _demoAyah, wordIndex: 0),
        last: (ayahId: _demoAyah, wordIndex: widget.wordCount - 1),
      ));
      _hide.reportPageWords(
        _demoPage,
        wordCount: widget.wordCount,
        ayahBoundaries: [widget.wordCount],
      );
      _elsewhere.set(true);
    });
  }

  @override
  void dispose() {
    final (span, range, count, ends) = (_span, _range, _wordCount, _boundaries);
    final verses = _verses, ranges = _ranges, hide = _hide;
    final elsewhere = _elsewhere;
    Future.microtask(() {
      if (span != null) verses.report(_demoPage, span);
      if (range != null) ranges.report(_demoPage, range);
      if (count != null) {
        hide.reportPageWords(
          _demoPage,
          wordCount: count,
          ayahBoundaries: ends ?? const [],
        );
      }
      elsewhere.set(false);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The recitation colours the demo shows (the Mushaf's own).
const _demoNext = Color(0x552F80ED);
const _demoRight = Color(0xFF43A047);
const _demoSlip = Color(0xFFEF6C00);
const _demoWrong = Color(0xFFD32F2F);

/// The word the demo's reciter slips on (its vowel).
const _demoSlipWord = 2;

class _RecitingDemo extends StatefulWidget {
  const _RecitingDemo({required this.words, required this.font});

  final List<String> words;
  final String font;

  @override
  State<_RecitingDemo> createState() => _RecitingDemoState();
}

class _RecitingDemoState extends State<_RecitingDemo> {
  /// Words said so far; past the last, a pause before it starts again.
  var _said = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      // Still: the ayah as it ends, every word marked.
      _said = widget.words.length;
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (!mounted) return;
      setState(() => _said = (_said + 1) % (widget.words.length + 3));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final listening = _said < widget.words.length;
    return TahfeezCard(
      key: const ValueKey('setup-demo-reciting'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          Row(
            spacing: TahfeezSpacing.sm,
            children: [
              _Pulse(active: listening, color: scheme.error),
              Expanded(
                child: Text(
                  listening ? l10n.setupDemoListening : l10n.modeRecite,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            textDirection: TextDirection.rtl,
            alignment: WrapAlignment.center,
            spacing: TahfeezSpacing.xs,
            runSpacing: TahfeezSpacing.xs,
            children: [
              for (final (i, word) in widget.words.indexed)
                _DemoWord(
                  text: word,
                  font: widget.font,
                  band: i == _said ? _demoNext : null,
                  ink: i < _said
                      ? (i == _demoSlipWord ? _demoSlip : _demoRight)
                      // Not yet said: faint, as a hidden ayah's.
                      : scheme.onSurface.withValues(alpha: 0.22),
                ),
            ],
          ),
          Wrap(
            spacing: TahfeezSpacing.md,
            runSpacing: TahfeezSpacing.xs,
            children: [
              _Key(color: _demoNext, label: l10n.setupDemoNext, band: true),
              _Key(color: _demoRight, label: l10n.setupDemoRight),
              _Key(color: _demoSlip, label: l10n.setupDemoSlip),
              _Key(color: _demoWrong, label: l10n.setupDemoWrong),
            ],
          ),
        ],
      ),
    );
  }
}

/// What a long-press opened under the ayah.
enum _Opened { actions, translation, tafsir }

/// The demo's ayah for real, as the Mushaf shows it while reciting (its
/// words hidden in hide mode, inked by the recitation): a tap shows a
/// word's meaning; a long-press its translation, tafsir and recitation.
class _TryDemo extends ConsumerStatefulWidget {
  const _TryDemo({required this.words, required this.font});

  final List<(int, String)> words;
  final String font;

  @override
  ConsumerState<_TryDemo> createState() => _TryDemoState();
}

class _TryDemoState extends ConsumerState<_TryDemo> {
  /// The word tapped.
  int? _word;
  _Opened? _opened;

  /// The Mushaf's marks: a band behind the next word (red over a mistake),
  /// recited words inked by how they went.
  static const _bands = {
    MushafWordMark.current: Color(0x552F80ED),
    MushafWordMark.mistake: Color(0x77E53935),
  };
  static const _inks = {
    MushafWordMark.correct: Color(0xFF43A047),
    MushafWordMark.skipped: Color(0xFFE0A800),
    MushafWordMark.wrong: Color(0xFFD32F2F),
    MushafWordMark.tashkeel: Color(0xFFEF6C00),
    MushafWordMark.tajweed: Color(0xFF039BE5),
    MushafWordMark.checking: Color(0xFFFFAB91),
    MushafWordMark.uncertain: Color(0xFFFBC02D),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meanings =
        ref.watch(ayahWordMeaningsProvider(_demoAyah)).value ?? const {};
    final overlay = ref.watch(mushafWordOverlayProvider);
    final hide = ref.watch(mushafHideModeProvider);
    // The reader's own colours for some marks (Hifz settings).
    final chosenInks = overlay?.inks ?? const <MushafWordMark, int>{};
    final playing = ref.watch(
      quranAudioPlayerProvider.select((p) => p?.ayahId == _demoAyah),
    );
    final colors = MushafAppearanceColors(
      background: scheme.surface,
      text: scheme.onSurface,
      secondaryText: scheme.onSurfaceVariant,
      headerInk: scheme.onSurface,
    );
    final word = _word, opened = _opened;
    final Widget answer;
    if (opened != null) {
      answer = Column(
        key: ValueKey('opened-${opened.name}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          Wrap(
            key: const ValueKey('setup-demo-actions'),
            spacing: TahfeezSpacing.sm,
            runSpacing: TahfeezSpacing.sm,
            children: [
              ChoiceChip(
                key: const ValueKey('setup-demo-translation'),
                avatar: const Icon(Icons.translate_rounded, size: 18),
                label: Text(l10n.tafsirShowTranslation),
                selected: opened == _Opened.translation,
                onSelected: (on) => setState(
                  () => _opened = on ? _Opened.translation : _Opened.actions,
                ),
              ),
              ChoiceChip(
                key: const ValueKey('setup-demo-tafsir'),
                avatar: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(l10n.readerTafsir),
                selected: opened == _Opened.tafsir,
                onSelected: (on) => setState(
                  () => _opened = on ? _Opened.tafsir : _Opened.actions,
                ),
              ),
              ActionChip(
                key: const ValueKey('setup-demo-listen'),
                avatar: Icon(
                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                label: Text(l10n.modeListen),
                onPressed: () {
                  final player = ref.read(quranAudioPlayerProvider.notifier);
                  unawaited(
                    playing ? player.stop() : player.playAyahs([_demoAyah]),
                  );
                },
              ),
            ],
          ),
          if (opened == _Opened.translation)
            if (ref.watch(activeTranslationBooksProvider).value?.isEmpty ??
                false)
              Text(l10n.ayahSheetNoTranslation)
            else
              AyahTranslations(ayahId: _demoAyah, colors: colors),
          if (opened == _Opened.tafsir)
            if (ref.watch(shownTafsirIdProvider) == null)
              Text(l10n.ayahSheetNoTafsir)
            else
              AyahTafsir(
                key: const ValueKey('setup-demo-tafsir-text'),
                verse: (chapterNo: 1, verseNo: 2),
                colors: colors,
              ),
        ],
      );
    } else if (word != null) {
      final (_, text) = widget.words.firstWhere((w) => w.$1 == word);
      answer = Row(
        key: ValueKey('meaning-$word'),
        spacing: TahfeezSpacing.smPlus,
        children: [
          Icon(Icons.translate_rounded, color: scheme.primary),
          Text(
            text,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: widget.font,
              fontSize: 22,
              color: scheme.primary,
            ),
          ),
          Expanded(
            child: Text(
              meanings[word] ?? '…',
              key: const ValueKey('setup-demo-meaning'),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      );
    } else {
      answer = Column(
        key: const ValueKey('hints'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.sm,
        children: [
          _Hint(icon: Icons.touch_app_outlined, text: l10n.setupDemoTap),
          _Hint(icon: Icons.back_hand_outlined, text: l10n.setupDemoLongPress),
          _Hint(
            icon: Icons.mic_none_rounded,
            // The bar's own names for its modes.
            text: l10n.setupDemoBar(
              [
                l10n.modeRecite,
                l10n.modeLoop,
                l10n.modeListen,
                l10n.modeFollow,
              ].join(', '),
            ),
          ),
        ],
      );
    }
    return TahfeezCard(
      key: const ValueKey('setup-demo-try'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          Text(l10n.setupDemoTry, style: theme.textTheme.titleSmall),
          AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : TahfeezMotionDuration.medium,
            padding: const EdgeInsets.all(TahfeezSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TahfeezRadii.md),
              color: opened != null
                  ? scheme.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
            ),
            child: Wrap(
              textDirection: TextDirection.rtl,
              alignment: WrapAlignment.center,
              spacing: TahfeezSpacing.xs,
              runSpacing: TahfeezSpacing.xs,
              children: [
                for (final (index, text) in widget.words)
                  Builder(
                    builder: (context) {
                      final at = (ayahId: _demoAyah, wordIndex: index);
                      final hidden = overlay != null && !overlay.followHideMode
                          ? overlay.isHidden(at)
                          : hide.isWordHidden(_demoPage, index);
                      final mark = overlay?.marks[at];
                      final ink = chosenInks[mark] ?? _inks[mark]?.toARGB32();
                      return GestureDetector(
                        key: ValueKey('setup-demo-word-$index'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          _word = index;
                          _opened = null;
                        }),
                        onLongPress: () => setState(() {
                          _word = null;
                          _opened = _Opened.actions;
                        }),
                        child: _DemoWord(
                          text: text,
                          font: widget.font,
                          band:
                              _bands[mark] ??
                              (index == word
                                  ? scheme.primary.withValues(alpha: 0.16)
                                  : null),
                          // Hidden: its place kept, the word not shown.
                          ink: hidden
                              ? Colors.transparent
                              : ink == null
                              ? scheme.onSurface
                              : Color(ink),
                          blank: hidden
                              ? scheme.onSurface.withValues(alpha: 0.10)
                              : null,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : TahfeezMotionDuration.medium,
            alignment: Alignment.topCenter,
            child: answer,
          ),
        ],
      ),
    );
  }
}

/// A word of the demo's ayah: [ink] its colour, [band] behind it.
class _DemoWord extends StatelessWidget {
  const _DemoWord({
    required this.text,
    required this.font,
    required this.ink,
    this.band,
    this.blank,
  });

  final String text, font;
  final Color ink;
  final Color? band;

  /// A hidden word's place, filled in.
  final Color? blank;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TahfeezMotionDuration.medium,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: band ?? blank ?? Colors.transparent,
      borderRadius: BorderRadius.circular(TahfeezRadii.sm),
    ),
    child: AnimatedDefaultTextStyle(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : TahfeezMotionDuration.medium,
      style: TextStyle(fontFamily: font, fontSize: 30, height: 1.9, color: ink),
      child: Text(text, textDirection: TextDirection.rtl),
    ),
  );
}

/// A colour of the key and what it means.
class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label, this.band = false});

  final Color color;
  final String label;
  final bool band;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Container(
        width: band ? 18 : 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(TahfeezRadii.pill),
        ),
      ),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    ],
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TahfeezSpacing.smPlus,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// A dot breathing while the app listens.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
    child: Icon(
      widget.active ? Icons.mic_rounded : Icons.mic_none_rounded,
      size: 20,
      color: widget.active ? widget.color : Theme.of(context).disabledColor,
    ),
  );
}

/// A frosted choice: chosen, it takes the primary's tint, edge and a tick.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.tickAtTop = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: TahfeezSpacing.md,
      vertical: TahfeezSpacing.sm,
    ),
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// The tick by the top (a tall choice), not halfway down.
  final bool tickAtTop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(TahfeezRadii.lg);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : TahfeezMotionDuration.medium,
        curve: TahfeezMotionCurves.standard,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.85)
              : scheme.surface.withValues(alpha: 0.62),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.7),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: tickAtTop
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Expanded(child: child),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : TahfeezMotionDuration.medium,
                    curve: TahfeezMotionCurves.emphasized,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: TahfeezSpacing.sm,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: scheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon in a soft circle, the primary's when [selected].
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : TahfeezMotionDuration.medium,
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : scheme.secondaryContainer,
      ),
      child: Icon(
        icon,
        size: 22,
        color: selected ? scheme.onPrimary : scheme.onSecondaryContainer,
      ),
    );
  }
}

/// Where the setup is: a dot for each step, the current one drawn long.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.index});

  final int count, index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${index + 1} / $count',
      child: Row(
        spacing: 6,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : TahfeezMotionDuration.medium,
              curve: TahfeezMotionCurves.standard,
              width: i == index ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                color: i <= index
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.18),
              ),
            ),
        ],
      ),
    );
  }
}

/// Back and Next (the first step: Get started, wide; the last: Start).
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.first,
    required this.last,
    required this.onBack,
    required this.onNext,
  });

  final bool first, last;
  final VoidCallback onBack, onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final big = FilledButton.styleFrom(
      minimumSize: const Size(0, 54),
      padding: const EdgeInsets.symmetric(horizontal: TahfeezSpacing.xl),
      shape: const StadiumBorder(),
      textStyle: Theme.of(context).textTheme.titleMedium,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.lg,
            TahfeezSpacing.sm,
            TahfeezSpacing.lg,
            TahfeezSpacing.md,
          ),
          child: first
              ? SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('setup-next'),
                    style: big,
                    onPressed: onNext,
                    child: Text(l10n.setupGetStarted),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TextButton.icon(
                        key: const ValueKey('setup-back'),
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(
                          l10n.setupBack,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: TahfeezSpacing.sm),
                    Flexible(
                      child: FilledButton(
                        key: ValueKey(last ? 'setup-done' : 'setup-next'),
                        style: big,
                        onPressed: onNext,
                        child: Text(
                          last ? l10n.setupDone : l10n.setupNext,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
