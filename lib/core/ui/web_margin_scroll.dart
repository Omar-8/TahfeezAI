import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// [child], a column at most [maxWidth] wide centred in the space given; in
/// a browser, the mouse wheel over the margins beside it scrolls the column
/// too, as a web page does (the wheel replayed over the column, at the same
/// height). Elsewhere just the column.
class WebMarginScroll extends StatelessWidget {
  const WebMarginScroll({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final column = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
    if (!kIsWeb) return column;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final margin = (width - math.min(width, maxWidth)) / 2;
        if (margin <= 0) return column;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            final x = event.localPosition.dx;
            if (x >= margin && x <= width - margin) return;
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || !box.attached) return;
            final over = box.localToGlobal(
              Offset(width / 2, event.localPosition.dy),
            );
            // After this event is done: the same wheel over the column.
            scheduleMicrotask(
              () => GestureBinding.instance.handlePointerEvent(
                PointerScrollEvent(
                  timeStamp: event.timeStamp,
                  kind: event.kind,
                  device: event.device,
                  viewId: event.viewId,
                  position: over,
                  scrollDelta: event.scrollDelta,
                ),
              ),
            );
          },
          child: column,
        );
      },
    );
  }
}
