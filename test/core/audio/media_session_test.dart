import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/audio/media_session.dart';

void main() {
  test('the run shown anew as its length and ayah change (a MediaItem '
      'equals any other of its id)', () {
    final session = TahfeezMediaSession();
    session.show(
      const MediaItem(
        id: 'run-1',
        title: 'Al-Kafirun',
        artist: 'As-Sudais · 1',
        duration: Duration(seconds: 70),
      ),
    );
    session.show(
      const MediaItem(
        id: 'run-1',
        title: 'Al-Kafirun',
        artist: 'As-Sudais · 2',
        duration: Duration(seconds: 31),
      ),
    );
    expect(session.mediaItem.value?.duration, const Duration(seconds: 31));
    expect(session.mediaItem.value?.artist, 'As-Sudais · 2');
  });
}
