import 'package:flutter/material.dart';

import '../tahfeez_icon_sizes.dart';
import 'tahfeez_list_row.dart';

/// A settings-list row: an icon, a title, a value/description subtitle, and
/// either a disclosure chevron (navigates somewhere) or a trailing switch
/// (toggles inline) — covering both settings-row shapes
/// `docs/reference/10_SETTINGS_SPEC.md` documents (navigation rows and the
/// Arabic-text-toggle switch row).
class TahfeezSettingsTile extends StatelessWidget {
  const TahfeezSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
  }) : switchValue = null,
       onSwitchChanged = null;

  const TahfeezSettingsTile.switchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required bool this.switchValue,
    required ValueChanged<bool> this.onSwitchChanged,
  }) : onTap = null;

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TahfeezListRow(
      title: title,
      subtitle: subtitle,
      leading: icon == null
          ? null
          : Icon(
              icon,
              size: TahfeezIconSize.lg,
              color: scheme.onSurfaceVariant,
            ),
      trailing: switchValue != null
          ? Switch(value: switchValue!, onChanged: onSwitchChanged)
          : (onTap != null
                ? Icon(
                    Icons.chevron_right,
                    size: TahfeezIconSize.md,
                    color: scheme.onSurfaceVariant,
                  )
                : null),
      onTap: onTap,
    );
  }
}
