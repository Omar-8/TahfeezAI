import 'package:flutter/material.dart';

/// Tahfeez's app bar: a thin wrapper over [AppBar] so every screen's top
/// bar comes from one place, even though today it just defers to the
/// already-themed Material [AppBar]. Screens should use this instead of
/// [AppBar] directly, so a future Tahfeez-specific app-bar treatment (e.g.
/// the collapsing reader chrome from `docs/reference/04_READER_SPEC.md` §3,
/// reinterpreted per `docs/DESIGN_DIRECTION.md`) only needs to change here.
class TahfeezAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TahfeezAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
