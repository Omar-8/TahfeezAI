import 'package:flutter/widgets.dart';

/// [duration], or none where the phone's "remove animations" is on: the
/// animation then jumps straight to its end.
Duration motion(BuildContext context, Duration duration) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
    ? Duration.zero
    : duration;
