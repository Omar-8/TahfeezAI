import 'package:flutter/widgets.dart';

/// [padding] with room at its foot for what the screen is drawn under —
/// the glass navigation bar (the app shell extends screens beneath it, to
/// blur them), the phone's own gesture strip — so a list's last item can
/// scroll clear of them.
EdgeInsetsGeometry withBarSpace(
  BuildContext context,
  EdgeInsetsGeometry padding,
) => padding.add(EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom));
