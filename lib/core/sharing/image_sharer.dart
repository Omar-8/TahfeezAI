import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands an image to the platform's share sheet (another app, saving it).
abstract interface class ImageSharer {
  /// [png] as [fileName]; [origin]: the button it came from, where an
  /// iPad's share popover points (required there).
  Future<void> sharePng(
    Uint8List png, {
    required String fileName,
    Rect? origin,
  });
}

class SharePlusImageSharer implements ImageSharer {
  const SharePlusImageSharer();

  @override
  Future<void> sharePng(
    Uint8List png, {
    required String fileName,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin,
      ),
    );
  }
}

final imageSharerProvider = Provider<ImageSharer>(
  (ref) => const SharePlusImageSharer(),
);

/// Where [context]'s widget is on screen — the origin an iPad's share
/// popover points from; `null` before it is laid out.
Rect? shareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
