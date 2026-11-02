// The owner's own recitations that showed tracker bugs, replayed through the
// tracker so none comes back. Their audio is personal and stays out of the
// repository: the model's frames for each (.f32, from bench_run.py) and the
// expected placements live in model_work/artifacts (git-ignored). Without
// them, as on CI, these tests are skipped.
//
// After a deliberate tracker change, review the differences these tests
// print, then accept them with:
//   OWNER_SESSIONS_UPDATE=1 flutter test test/ai/matching/owner_sessions_test.dart
// After a model change, re-run bench_run.py for each pack first.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/hifz/hifz_judge.dart';
import 'package:tahfeez_ai/features/recitation/application/acoustic_verification_controller.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

import '../acoustic/acoustic_test_support.dart';
import 'corpus_fixture.dart';
import 'position_fixture_support.dart';

const _dir = 'tool/acoustic_verification/model_work/artifacts';
final _expectedFile = File('$_dir/owner_sessions_expected.json');

/// A session as the app ran it: the page on screen, searched only.
typedef _Session = ({String tag, String note, int from, int to});

const _sessions = <_Session>[
  (
    tag: 'owner1102_v37',
    note: '13:39 Al-Fatiha, English played before and during it',
    from: 1001,
    to: 1007,
  ),
  (
    tag: 'owner1102b_v37',
    note: '13:52 Al-Fatiha, English during ayah 3 (was: jump back to ayah 1)',
    from: 1001,
    to: 1007,
  ),
  (
    tag: 'owner1102c_v37',
    note: '14:30 Al-Ikhlas–Al-Falaq, a mistake in 113:5 then the correction',
    from: 112001,
    to: 114006,
  ),
  (
    tag: 'owner1102d_v37',
    note: '14:38 Al-Ikhlas, mumbling in ayah 3 (was: shown green)',
    from: 112001,
    to: 114006,
  ),
  (
    tag: 'owner1102e_v37',
    note: '15:44 An-Nisa, «ٱلَّذِينَ» with a word left out (was: to 4:74)',
    from: 4066,
    to: 4074,
  ),
  (
    tag: 'owner1102f_v37',
    note: '20:56 page 600 after a basmala (was: held 8 s, «إِنَّ» dropped)',
    from: 100006,
    to: 102008,
  ),
  (
    tag: 'owner1102g_v37',
    note: '21:16 pages 600–601, wrong vowels on ayah ends said on',
    from: 100006,
    to: 102008,
  ),
];

AcousticFrames? _frames(String tag) {
  final file = File('$_dir/results/$tag.f32');
  if (!file.existsSync()) return null;
  final all = Float32List.sublistView(file.readAsBytesSync());
  return AcousticFrames(
    frames: all.length ~/ 43,
    classes: 43,
    logProbs: all,
    frameDuration: const Duration(milliseconds: 40),
  );
}

/// The app's way: chunks of 1.28 s, the page on screen searched only.
ReplayResult _replay(_Session s, AcousticFrames frames) => replay(
  PositionScenario(s.tag, {
    'note': s.note,
    'chunk_ends': [
      for (var e = 32; e < frames.frames; e += 32) e,
      frames.frames,
    ],
    'focus': [s.from, s.to],
    'anchor': s.from,
    'trust_anchor': false,
    'focus_only': true,
    'recited': <int>[],
  }),
  frames: frames,
);

/// Each placement as the log gives it, without its cost: "1:2:3 at 5..9".
List<String> _placements(ReplayResult r) => [
  for (final l in r.log)
    if (l.startsWith('placed ')) l.substring(7).split(' "').first,
];

Map<String, int> _verdicts(ReplayResult r) => {
  for (final e in r.verdicts.entries) e.key.name: e.value,
};

void main() {
  final available = {for (final s in _sessions) s.tag: ?_frames(s.tag)};
  final skip = available.length < _sessions.length
      ? 'the owner\'s session frames are not on this machine'
      : null;
  final update = Platform.environment['OWNER_SESSIONS_UPDATE'] == '1';

  group('owner sessions (2026-11-02)', () {
    final corpus = loadTestCorpus();
    final results = <String, ReplayResult>{};
    ReplayResult run(String tag) => results[tag] ??= _replay(
      _sessions.firstWhere((s) => s.tag == tag),
      available[tag]!,
    );
    int pos(int surah, int ayah, int word) =>
        corpus.positionOf((ayahId: surah * 1000 + ayah, wordIndex: word - 1))!;
    List<int> placedAt(ReplayResult r) => [for (final p in r.placed) p.$1];

    test('each replays as accepted: every word placed, every verdict', () {
      final expected = _expectedFile.existsSync()
          ? jsonDecode(_expectedFile.readAsStringSync()) as Map<String, Object?>
          : <String, Object?>{};
      final now = <String, Object?>{
        for (final s in _sessions)
          s.tag: {
            'note': s.note,
            'verdicts': _verdicts(run(s.tag)),
            'placed': _placements(run(s.tag)),
          },
      };
      if (update || expected.isEmpty) {
        _expectedFile.writeAsStringSync(
          const JsonEncoder.withIndent(' ').convert(now),
        );
        if (!update) fail('no expected placements yet: written, check them');
        return;
      }
      for (final s in _sessions) {
        final want = expected[s.tag] as Map<String, Object?>?;
        final got = now[s.tag]! as Map<String, Object?>;
        expect(want, isNotNull, reason: '${s.tag}: not in the expected file');
        final wantPlaced = (want!['placed']! as List).cast<String>();
        final gotPlaced = got['placed']! as List<String>;
        expect(
          gotPlaced,
          wantPlaced,
          reason:
              '${s.tag} (${s.note}): now also ${[for (final p in gotPlaced)
                if (!wantPlaced.contains(p)) p]}, no longer ${[for (final p in wantPlaced)
                if (!gotPlaced.contains(p)) p]}',
        );
        expect(got['verdicts'], want['verdicts'], reason: s.tag);
      }
    });

    // What each session's bug was, checked on its own (a re-accepted
    // expected file cannot quietly bring one back).

    test('English around Al-Fatiha is not placed as Quran; «بِسْمِ» kept', () {
      for (final tag in ['owner1102_v37', 'owner1102b_v37']) {
        final r = run(tag);
        final placed = placedAt(r);
        expect(placed.first, pos(1, 1, 1), reason: '$tag: ${r.log.take(4)}');
        expect(
          placed.where((p) => p > pos(1, 7, 9)),
          isEmpty,
          reason: '$tag: words past Al-Fatiha',
        );
      }
    });

    test('13:52: after the English in ayah 3, not back to the basmala', () {
      final placed = placedAt(run('owner1102b_v37'));
      final ayah2 = placed.indexOf(pos(1, 2, 1));
      expect(ayah2, isNonNegative);
      expect(
        placed.skip(ayah2).where((p) => p <= pos(1, 1, 4)),
        isEmpty,
        reason: 'the basmala\'s «ٱلرَّحْمَٰنِ ٱلرَّحِيمِ» taken again',
      );
    });

    test('14:30: the correction in 113:5 is heard; nothing in An-Nas', () {
      final r = run('owner1102c_v37');
      expect(placedAt(r).where((p) => p >= pos(114, 1, 1)), isEmpty);
      // The first correct «وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ», frames 1142–1204.
      final first = r.placed.firstWhere((p) => p.$1 == pos(113, 5, 1));
      expect(first.$2, lessThanOrEqualTo(1216));
    });

    test('14:38: mumbling in Al-Ikhlas 3 is not all green', () {
      final r = run('owner1102d_v37');
      expect(r.verdicts[HifzVerdict.wrong], greaterThanOrEqualTo(1));
    });

    test('15:44: «ٱلَّذِينَ» after 4:75:11 stays in 4:75', () {
      final placed = placedAt(run('owner1102e_v37'));
      final at = placed.indexOf(pos(4, 75, 11));
      expect(at, isNonNegative);
      expect(placed[at + 1], pos(4, 75, 13), reason: 'not 4:74:12');
    });

    test('20:56: page 600 after a basmala — «إِنَّ» heard at once, '
        'nothing off the page', () {
      final r = run('owner1102f_v37');
      expect(r.log, contains(startsWith('passed over 1:1:1')));
      final placed = placedAt(r);
      expect(placed.first, pos(100, 6, 1));
      // «إِنَّ» ends at frame 99: placed at most one chunk later (it was
      // frame ~300 on the phone, and «إِنَّ» never).
      expect(r.placed.first.$2, lessThanOrEqualTo(160));
      expect(placed.where((p) => p < pos(100, 6, 1)), isEmpty);
      expect(r.verdicts.keys, [HifzVerdict.correct]);
    });

    // An ayah's last vowel (the owner's rule): dropped at a stop, fine;
    // said on into the next ayah, it must be the right one. Checked as the
    // app checks an ayah: its words and the next ayah's first, the frames
    // from just before it to just after.
    List<PhonemeVerdict> mistakes(
      String tag,
      int from,
      int to,
      List<WordRef> words,
    ) {
      final span = loadTestReference().span(words);
      return const QuranAcousticVerifier(
            thresholds: AcousticVerificationController.calibratedThresholds,
          )
          .verify(
            available[tag]!.slice(from, to),
            span.tokens,
            pauses: span.pauses,
            openStart: true,
            openEnd: true,
          )
          .where((v) => v.type.isError)
          .toList();
    }

    List<WordRef> ayahThenNext(int ayahId, int words, int next) => [
      for (var w = 0; w < words; w++) (ayahId: ayahId, wordIndex: w),
      (ayahId: next, wordIndex: 0),
    ];

    test('21:16: «ٱلْقُبُورُ» said on into 100:10 is a wrong vowel', () {
      // 100:9 said again from frame 533; «وَحُصِّلَ» begins at 628.
      final found = mistakes(
        'owner1102g_v37',
        520,
        660,
        ayahThenNext(100009, 7, 100010),
      );
      expect(
        found.where(
          (v) =>
              v.token.word == (ayahId: 100009, wordIndex: 6) &&
              v.type == RecitationErrorType.wrongVowel,
        ),
        hasLength(1),
        reason: '$found',
      );
    });

    test('20:56: «ٱلْقُبُورْ», stopped, its vowel dropped: no mistake', () {
      // 0.35 s of silence (frames 450–459) before «وَحُصِّلَ».
      final found = mistakes(
        'owner1102f_v37',
        355,
        490,
        ayahThenNext(100009, 7, 100010),
      );
      expect(
        found.where((v) => v.token.word == (ayahId: 100009, wordIndex: 6)),
        isEmpty,
        reason: '$found',
      );
    });

    test('14:38: «أَحَدْ» with its qalqala, then «ٱللَّهُ»: a stop, no '
        'mistake', () {
      // Only 3 frames of silence: the qalqala (frame 138) is the stop.
      final found = mistakes(
        'owner1102d_v37',
        85,
        175,
        ayahThenNext(112001, 4, 112002),
      );
      expect(
        found.where((v) => v.token.word == (ayahId: 112001, wordIndex: 3)),
        isEmpty,
        reason: '$found',
      );
    });
  }, skip: skip);
}
