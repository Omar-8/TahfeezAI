import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How a listening run plays (the Mushaf's Listen menu): each ayah's and
/// the whole range's repetitions, following the pages, highlighting the
/// ayah being recited. Kept for the app's lifetime, not persisted.
class ListenOptions {
  const ListenOptions({
    this.ayahRepeats = 1,
    this.rangeRepeats = 1,
    this.followPages = true,
    this.highlight = true,
  });

  final int ayahRepeats, rangeRepeats;
  final bool followPages, highlight;

  ListenOptions copyWith({
    int? ayahRepeats,
    int? rangeRepeats,
    bool? followPages,
    bool? highlight,
  }) => ListenOptions(
    ayahRepeats: ayahRepeats ?? this.ayahRepeats,
    rangeRepeats: rangeRepeats ?? this.rangeRepeats,
    followPages: followPages ?? this.followPages,
    highlight: highlight ?? this.highlight,
  );
}

class ListenOptionsController extends Notifier<ListenOptions> {
  @override
  ListenOptions build() => const ListenOptions();

  void set(ListenOptions options) => state = options;
}

final listenOptionsProvider =
    NotifierProvider<ListenOptionsController, ListenOptions>(
      ListenOptionsController.new,
    );

/// Playback speeds offered in the bar, cycled in order.
const listenSpeeds = [0.75, 1.0, 1.25, 1.5];
