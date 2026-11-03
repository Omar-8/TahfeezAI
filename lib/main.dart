import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app/bootstrap.dart';

void main() {
  // The released web app writes nothing to the browser's console (its
  // messages, and its libraries'); debug and profile builds keep them.
  if (kIsWeb && kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
    runZoned(
      bootstrap,
      zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
    );
    return;
  }
  bootstrap();
}
