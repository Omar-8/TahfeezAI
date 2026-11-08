import 'dart:collection';

/// The app's last messages and errors, in memory only: what a problem
/// report (Settings → Report a problem) carries, when the user sends one.
/// Never written to disk, never sent by itself.
class RecentLog {
  RecentLog._();

  static final instance = RecentLog._();

  /// The most kept; the oldest go first.
  static const maxLines = 400;

  final _lines = ListQueue<String>();

  void add(String? message) {
    if (message == null || message.isEmpty) return;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    _lines.addLast(
      '${two(now.hour)}:${two(now.minute)}:${two(now.second)} $message',
    );
    while (_lines.length > maxLines) {
      _lines.removeFirst();
    }
  }

  /// The latest lines, together no longer than [maxChars] (the newest
  /// kept).
  String latest({int maxChars = 6000}) {
    final kept = <String>[];
    var length = 0;
    for (final line in _lines.toList().reversed) {
      if (length + line.length + 1 > maxChars) break;
      kept.add(line);
      length += line.length + 1;
    }
    return kept.reversed.join('\n');
  }

  void clear() => _lines.clear();
}
