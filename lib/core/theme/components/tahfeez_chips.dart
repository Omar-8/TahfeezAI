import 'package:flutter/material.dart';

/// A tappable action chip — a single-shot action (not a toggle), e.g.
/// "Manage" on a resource-update banner.
class TahfeezActionChip extends StatelessWidget {
  const TahfeezActionChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

/// A single- or multi-select filter chip — used for search filters, chapter
/// index filters (`docs/reference/02_SCREEN_INVENTORY.md` §5), and similar
/// "narrow the list" controls.
class TahfeezFilterChip extends StatelessWidget {
  const TahfeezFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}
