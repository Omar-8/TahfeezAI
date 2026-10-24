// The ghunnah check (AcousticThresholds.ghunnahHold) at the app's settings,
// for each hold tried: how it reads the owner's ground truth and how often it
// flags correct recitation.
//
//   dart run tool/acoustic_verification/ghunnah_check.dart <tag> [hold ...]
//
// - Deliberate takes (pack ghown: 20 ayahs, each said with its ghunnah held
//   and cut): takes flagged on their ghunnah word, correct and cut.
// - The owner's everyday ghunnahs judged by ear
//   (model_work/artifacts/ghunnah_listen_labelled.json): flagged, by label.
// - Correct recitation: ghunnah flags per 100 doubled «ن» / «م» — the owner's
//   phone sets, Tarteel users, unseen Juz 30 reciters, amateurs (RetaSy).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _results = 'tool/acoustic_verification/model_work/artifacts/results';
const _art = 'tool/acoustic_verification/model_work/artifacts';

late QuranPhoneticReference _reference;

/// The app's (AcousticVerificationController: streaming error 3.6, letters
/// 4.1, learnerSounds).
const _appSounds = {
  SoundGroup.shadda: SoundMargins(uncertain: 2),
  SoundGroup.reducedVowel: SoundMargins(error: 0, uncertain: 2),
  SoundGroup.finalVowel: SoundMargins(error: 1, uncertain: 2),
  SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
  SoundGroup.nasal: SoundMargins(uncertain: 2),
  SoundGroup.hiddenNasal: SoundMargins(error: -1),
  SoundGroup.throat: SoundMargins(uncertain: 2),
  SoundGroup.similarLetter: SoundMargins(error: 4),
  SoundGroup.phoneWeak: SoundMargins(error: 2, uncertain: 2),
  SoundGroup.wordFinalVowel: SoundMargins(error: -2.6),
  SoundGroup.stopInFlow: SoundMargins(error: 1),
};

/// Each case of [pack]: its meta and verdicts at [hold].
Iterable<(Map<String, Object?>, List<PhonemeVerdict>)> _run(
  String pack,
  String tag,
  double hold,
) sync* {
  final file = File('$_results/${pack}_$tag.json');
  if (!file.existsSync()) {
    stderr.writeln('missing ${pack}_$tag');
    return;
  }
  final raw = jsonDecode(file.readAsStringSync());
  final meta = (raw is List ? raw : (raw as Map)['cases'] as List)
      .cast<Map<String, Object?>>();
  final bytes = File('$_results/${pack}_$tag.f32').readAsBytesSync();
  final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
  final th = AcousticThresholds(
    error: 3.6,
    letterError: 4.1,
    shaddaError: 3.6,
    sukunError: 3,
    missingVowelError: 3,
    qalqalaError: 2,
    correct: -1,
    pauseFrames: 4,
    tajweed: true,
    ghunnahHold: hold,
    sounds: _appSounds,
  );
  for (final m in meta) {
    final ayahId = m['ayahId']! as int;
    final expected = _reference.words(
      ayahId,
      m['firstWord']! as int,
      m['lastWord']! as int,
    );
    final units = {for (final t in expected) t.unit};
    final at = m['main']! as Map;
    final n = at['frames'] as int, off = at['offset'] as int;
    yield (
      m,
      QuranAcousticVerifier(thresholds: th).verify(
        AcousticFrames(
          frames: n,
          classes: 43,
          logProbs: Float32List.sublistView(all, off, off + n * 43),
          frameDuration: const Duration(milliseconds: 40),
        ),
        expected,
        pauses: {
          for (final e in _reference.pauseForms(ayahId).entries)
            if (units.contains(e.key)) e.key: e.value,
        },
        openStart: m['openStart']! as bool,
        openEnd: m['openEnd']! as bool,
      ),
    );
  }
}

bool _ghunnah(PhonemeVerdict v) => v.type == RecitationErrorType.ghunnahMissing;

void main(List<String> args) {
  final tag = args.first;
  final holds = args.length > 1
      ? [for (final a in args.skip(1)) double.parse(a)]
      : [1.0, 1.5, 2.0, 2.5, 3.0];
  _reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final labelled = (jsonDecode(
    File('$_art/ghunnah_listen_labelled.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  for (final hold in holds) {
    // Deliberate takes: flagged on the ghunnah word, by take.
    final takes = <String, (int, int)>{};
    for (final (m, vs) in _run('ghown', tag, hold)) {
      final words = (m['ghunnahWords']! as List).cast<int>().toSet();
      final hit = vs.any(
        (v) => _ghunnah(v) && words.contains(v.token.word.wordIndex),
      );
      final k = m['take']! as String;
      final (f, t) = takes[k] ?? (0, 0);
      takes[k] = (f + (hit ? 1 : 0), t + 1);
    }
    // Everyday ghunnahs judged by ear: flagged, by label.
    final byLabel = <String, (int, int)>{};
    final flaggedAt = <String, Set<(int, int)>>{};
    for (final pack in {for (final l in labelled) l['pack']! as String}) {
      var i = 0;
      for (final (_, vs) in _run(pack, tag, hold)) {
        flaggedAt['$pack:$i'] = {
          for (final v in vs.where(_ghunnah))
            (v.token.word.ayahId, v.token.word.wordIndex),
        };
        i++;
      }
    }
    for (final l in labelled) {
      final hit =
          flaggedAt['${l['pack']}:${l['clip']}']?.contains((
            l['ayahId']! as int,
            l['word']! as int,
          )) ??
          false;
      final k = l['label']! as String;
      final (f, t) = byLabel[k] ?? (0, 0);
      byLabel[k] = (f + (hit ? 1 : 0), t + 1);
    }
    // Correct recitation: flags per 100 doubled noons / meems.
    String rate(List<String> packs) {
      var flags = 0, ghunnahs = 0;
      for (final pack in packs) {
        for (final (m, vs) in _run(pack, tag, hold)) {
          final targets = (m['targetWords']! as List).cast<int>().toSet();
          for (final v in vs) {
            if (targets.contains(v.token.word.wordIndex)) continue;
            if (v.token.geminate &&
                (v.token.symbol == 'ن' || v.token.symbol == 'م')) {
              ghunnahs++;
              if (_ghunnah(v)) flags++;
            }
          }
        }
      }
      return '$flags/$ghunnahs '
          '(${(100 * flags / (ghunnahs == 0 ? 1 : ghunnahs)).toStringAsFixed(1)}%)';
    }

    String pair((int, int)? p) => p == null ? '-' : '${p.$1}/${p.$2}';
    stdout.writeln(
      'hold $hold | deliberate: cut caught ${pair(takes['cut'])}, correct '
      'flagged ${pair(takes['correct'])} | by ear: cut flagged '
      '${pair(byLabel['mistake'])}, correct flagged ${pair(byLabel['correct'])} '
      '| correct recitation flagged: owner '
      '${rate(['phone', 'phone2', 'phone3', 'phone4', 'phone6', 'phone7', 'phone8', 'phone9'])}, '
      'Tarteel-200 ${rate(['tlog'])}, Juz 30 ${rate(['juz30h'])}, '
      'amateurs ${rate(['retasy'])}',
    );
  }
}
