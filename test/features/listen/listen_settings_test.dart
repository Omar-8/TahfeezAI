import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/listen/application/follow_along_controller.dart';
import 'package:tahfeez_ai/features/listen/application/listen_options.dart';

void main() {
  test('the speed and both menus\' choices are kept for next time', () async {
    final first = ProviderContainer();
    first.read(listenSpeedProvider.notifier).set(1.5);
    first
        .read(listenOptionsProvider.notifier)
        .set(const ListenOptions(ayahRepeats: 3, highlight: false));
    first
        .read(followAlongOptionsProvider.notifier)
        .set(
          const FollowAlongOptions(
            unit: FollowAlongUnit.range,
            reciterTimes: 2,
            userTimes: 4,
          ),
        );
    await Future<void>.delayed(Duration.zero);
    first.dispose();

    // The app opened again.
    final next = ProviderContainer();
    addTearDown(next.dispose);
    next.read(listenSpeedProvider);
    next.read(listenOptionsProvider);
    next.read(followAlongOptionsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(next.read(listenSpeedProvider), 1.5);
    final listen = next.read(listenOptionsProvider);
    expect((listen.ayahRepeats, listen.highlight), (3, false));
    final follow = next.read(followAlongOptionsProvider);
    expect(
      (follow.unit, follow.reciterTimes, follow.userTimes),
      (FollowAlongUnit.range, 2, 4),
    );
  });
}
