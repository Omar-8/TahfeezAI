import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Runs a timing integration test (integration_test/effects_perf_test.dart),
/// writing each traced part's frame summary to
/// `build/perf/<part>.timeline_summary.json` — and, for parts reported as
/// `<name>.<nn>` (one run traced in pieces), all of a name's joined as
/// `build/perf/<name>.timeline_summary.json`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final joined = <String, List<Map<String, dynamic>>>{};
    for (final MapEntry(:key, :value) in data.entries) {
      final json = value as Map<String, dynamic>;
      await _write(key, driver.Timeline.fromJson(json));
      final dot = key.lastIndexOf('.');
      if (dot > 0) {
        joined.putIfAbsent(key.substring(0, dot), () => []).addAll([
          for (final e in json['traceEvents'] as List<dynamic>)
            e as Map<String, dynamic>,
        ]);
      }
    }
    for (final MapEntry(:key, :value) in joined.entries) {
      await _write(key, driver.Timeline.fromJson({'traceEvents': value}));
    }
  },
);

Future<void> _write(String name, driver.Timeline timeline) =>
    driver.TimelineSummary.summarize(timeline).writeTimelineToFile(
      name,
      destinationDirectory: 'build/perf',
      pretty: true,
      includeSummary: true,
    );
