import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Runs a timing integration test (integration_test/effects_perf_test.dart),
/// writing each traced part's frame summary to
/// `build/perf/<part>.timeline_summary.json`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    for (final MapEntry(:key, :value) in data.entries) {
      final timeline = driver.Timeline.fromJson(value as Map<String, dynamic>);
      await driver.TimelineSummary.summarize(timeline).writeTimelineToFile(
        key,
        destinationDirectory: 'build/perf',
        pretty: true,
        includeSummary: true,
      );
    }
  },
);
