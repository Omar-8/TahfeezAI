import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/matching/quran_stream_matcher.dart';
import 'package:tahfeez_ai/ai/speech/live_quran_recognizer.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_verses.dart';
import 'package:tahfeez_ai/features/recitation/application/live_recognition_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/mushaf_recitation_target.dart';
import 'package:tahfeez_ai/features/recitation/application/quran_match_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_session_controller.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';

import '../../ai/matching/corpus_fixture.dart';
import '../../ai/matching/quran_stream_matcher_cases_test.dart' show kursi;
import 'live_recognition_controller_test.dart' show FakeRecognizer;
import 'recitation_session_controller_test.dart'
    show FakeAudioSource, FakeRepository, FakeStore;

void main() {
  test(
    'live transcripts become canonical positions on the visible page',
    () async {
      final corpus = loadTestCorpus();
      final recognizer = FakeRecognizer();
      final container = ProviderContainer(
        overrides: [
          recitationAudioSourceFactoryProvider.overrideWithValue(
            FakeAudioSource.new,
          ),
          recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
          recitationSessionRepositoryProvider.overrideWithValue(
            FakeRepository(),
          ),
          liveQuranRecognizerFactoryProvider.overrideWithValue(
            () => recognizer,
          ),
          quranWordCorpusProvider.overrideWith((ref) async => corpus),
        ],
      );
      addTearDown(container.dispose);

      // Page 42 is on screen: 2:253–2:256.
      container
          .read(mushafRecitationTargetProvider.notifier)
          .show('screen', const QuranLocation.page(1, 42));
      container.read(mushafPageVersesProvider.notifier).report(42, (
        first: (chapterNo: 2, verseNo: 253),
        last: (chapterNo: 2, verseNo: 256),
      ));
      container.listen(liveRecognitionControllerProvider, (_, _) {});
      container.listen(quranMatchControllerProvider, (_, _) {});
      await container.read(quranWordCorpusProvider.future);
      final events = <QuranMatchEvent>[];
      container
          .read(quranMatchControllerProvider.notifier)
          .events
          .listen(events.add);

      final session = container.read(
        recitationSessionControllerProvider.notifier,
      );
      await session.start(startLocation: const QuranLocation.page(1, 42));
      await pumpEventQueue();

      final words = kursi.split(' ');
      for (var k = 1; k < words.length; k++) {
        recognizer.events_.add(LivePartialTranscript(words.take(k).join(' ')));
      }
      recognizer.events_.add(LiveFinalTranscript(kursi));
      await pumpEventQueue();
      session.pause(); // flushes the word held back from the final
      await pumpEventQueue();

      final state = container.read(quranMatchControllerProvider);
      final last =
          corpus.words[corpus.verseEndPosition((chapterNo: 2, verseNo: 255))!];
      expect(state.ready, isTrue);
      expect(state.current, last.ref);
      expect(state.confidence, greaterThan(0.9));
      expect(state.lastLog, isNotNull);
      expect(events.whereType<MatchRelocated>().single.scope, 'page');
      expect(events.whereType<WordConfirmed>(), hasLength(50));
      expect(events.whereType<PossibleMistake>(), isEmpty);
    },
  );
}
