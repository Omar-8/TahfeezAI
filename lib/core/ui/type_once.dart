import 'dart:async';

import 'package:flutter/material.dart';

import 'motion.dart';

/// Text typed out quickly the first time it shows in this run of the app
/// (Home's greeting and daily ayah as the app opens); shown whole after.
/// [builder] gets how much is typed (0–1) — see [typedSpans] — so the text
/// is laid out whole from the start and nothing moves as it is typed.
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

/// [text] with its first [typed] share shown and the rest laid out but
/// transparent (only the colour changes between the two, so the line
/// breaks stay put and Arabic letters stay joined).
List<InlineSpan> typedSpans(String text, double typed) {
  if (typed >= 1) return [TextSpan(text: text)];
  final n = (text.length * typed).round().clamp(0, text.length);
  return [
    TextSpan(text: text.substring(0, n)),
    TextSpan(
      text: text.substring(n),
      style: const TextStyle(color: Colors.transparent),
    ),
  ];
}
