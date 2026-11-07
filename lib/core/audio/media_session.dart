import 'package:audio_service/audio_service.dart';

/// What the media session's buttons act on: the app's player.
abstract interface class MediaSessionTarget {
  Future<void> play();
  Future<void> pause();
  Future<void> stop();

  /// To [position] on the whole run's timeline (all its ayahs as one).
  Future<void> seekTimeline(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
}

/// Recitation audio as the system's media session: the Android
/// notification, the iPhone's lock screen, Control Center and Dynamic
/// Island, and the phones' other "now playing" places (HyperOS's island,
/// One UI's Now bar), which all read it. A run of ayahs shows as one item
/// — its surah, the reciter and the ayah playing, the whole run's length
/// and place — with play / pause, the previous and next ayah, stop and a
/// seek bar over the whole run.
class TahfeezMediaSession extends BaseAudioHandler with SeekHandler {
  /// The session, once started (bootstrap; never in a browser or tests).
  static TahfeezMediaSession? instance;

  /// Started with the app (before any player exists).
  static Future<void> start() async {
    instance = await AudioService.init(
      builder: TahfeezMediaSession.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'ai.tahfeez.tahfeez_ai.audio',
        androidNotificationChannelName: 'Recitation audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  /// The player the buttons act on.
  MediaSessionTarget? target;

  /// What is playing, as one item. (A [MediaItem] equals another of the
  /// same id: compared by what shows, or its length and ayah never update —
  /// the first estimate left on, and the position run on past the end.)
  void show(MediaItem item) {
    final now = mediaItem.value;
    if (now == null ||
        now.id != item.id ||
        now.title != item.title ||
        now.artist != item.artist ||
        now.duration != item.duration) {
      mediaItem.add(item);
    }
  }

  /// How it is playing: [position] on the run's timeline.
  void update({
    required bool playing,
    required AudioProcessingState processing,
    required Duration position,
    required double speed,
    required int index,
    required int count,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processing,
        playing: playing,
        updatePosition: position,
        speed: speed,
        queueIndex: index,
      ),
    );
  }

  /// Nothing playing any more: the notification goes.
  void clear() {
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle),
    );
  }

  @override
  Future<void> play() async => target?.play();

  @override
  Future<void> pause() async => target?.pause();

  @override
  Future<void> stop() async {
    await target?.stop();
    clear();
  }

  @override
  Future<void> seek(Duration position) async => target?.seekTimeline(position);

  @override
  Future<void> skipToNext() async => target?.skipToNext();

  @override
  Future<void> skipToPrevious() async => target?.skipToPrevious();
}
