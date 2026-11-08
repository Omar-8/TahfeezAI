import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/logging/recent_log.dart';
import 'package:tahfeez_ai/features/settings/application/problem_report.dart';

void main() {
  test('a problem report: the user\'s words first, then the app, then its '
      'latest messages', () {
    final body = problemReportBody(
      prompt: 'What happened?',
      version: '1.2.1',
      locale: 'en',
      log: '10:00:00 Summary: shown',
    );
    final lines = body.split('\n');
    expect(lines.first, 'What happened?');
    expect(body, contains('Tahfeez AI 1.2.1 · android · en'));
    expect(body.endsWith('10:00:00 Summary: shown'), isTrue);
  });

  test('the recent log keeps the newest lines, within its limits', () {
    final log = RecentLog.instance..clear();
    addTearDown(log.clear);
    for (var i = 0; i < RecentLog.maxLines + 50; i++) {
      log.add('line $i');
    }
    final all = log.latest(maxChars: 1 << 20).split('\n');
    expect(all, hasLength(RecentLog.maxLines));
    expect(all.last, endsWith('line ${RecentLog.maxLines + 49}'));
    // Cut to a size: the newest kept.
    final short = log.latest(maxChars: 100);
    expect(short.length, lessThanOrEqualTo(100));
    expect(short, endsWith('line ${RecentLog.maxLines + 49}'));
    log.add(null);
    log.add('');
    expect(
      log.latest(maxChars: 1 << 20).split('\n'),
      hasLength(RecentLog.maxLines),
    );
  });
}
