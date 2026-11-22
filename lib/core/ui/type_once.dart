import 'dart:async';

import 'package:flutter/material.dart';

import 'motion.dart';

/// Text revealed the first time it shows in this run of the app (Home's
/// greeting and daily ayah as the app opens), word by word; shown whole
/// after. [builder] gets how far it has come (0–1) — see
/// [revealedWordSpans] — so the text is laid out whole from the start and
/// nothing moves as it appears.
/// None with the phone's "remove animations".
class TypeOnce extends StatefulWidget {
  const TypeOnce({
    super.key,
    required this.id,
    required this.length,
    required this.builder,
    this.delay = Duration.zero,
    this.perCharacter = const Duration(milliseconds: 18),
    this.longest = const Duration(milliseconds: 1600),
  });

  /// Typed once per run under this name.
  final String id;

  /// The text's length, for the typing's duration ([perCharacter] each, at
  /// most [longest]).
  final int length;
  final Duration delay, perCharacter, longest;
  final Widget Function(BuildContext context, double typed) builder;

  /// What has been typed already in this run.
  static final _typed = <String>{};

  /// For tests: every text types again.
  @visibleForTesting
  static void reset() => _typed.clear();

  @override
  State<TypeOnce> createState() => _TypeOnceState();
}

class _TypeOnceState extends State<TypeOnce>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Timer? _start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || TypeOnce._typed.contains(widget.id)) return;
    TypeOnce._typed.add(widget.id);
    final total = widget.perCharacter * widget.length;
    final duration = motion(
      context,
      total > widget.longest ? widget.longest : total,
    );
    if (duration == Duration.zero) return;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: duration,
    );
    _start = Timer(widget.delay, () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || controller.isCompleted) {
      return widget.builder(context, 1);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => widget.builder(context, controller.value),
    );
  }
}

/// [text] revealed word by word, [shown] of the way through (0–1): each
/// word fading in from transparent to [color] after the one before (owner,
/// 2026-11-21: as if revealed, not typed). Laid out whole from the start —
/// only colours change, so the lines stay put and Arabic letters stay
/// joined (a word is one span).
List<InlineSpan> revealedWordSpans(String text, double shown, Color color) {
  if (shown >= 1) return [TextSpan(text: text)];
  // Words with the spaces after them.
  final words = RegExp(r'\S+\s*').allMatches(text).map((m) => m[0]!).toList();
  final lead = text.length - text.trimLeft().length;
  final n = words.length;
  if (n == 0) return [TextSpan(text: text)];
  // Each word's fade a little longer than its turn: they overlap.
  final fade = 2.5 / (n + 1.5);
  final step = (1 - fade) / (n > 1 ? n - 1 : 1);
  return [
    if (lead > 0) TextSpan(text: text.substring(0, lead)),
    for (final (i, w) in words.indexed)
      TextSpan(
        text: w,
        style: TextStyle(
          color: color.withValues(
            alpha: color.a * ((shown - i * step) / fade).clamp(0.0, 1.0),
          ),
        ),
      ),
  ];
}
