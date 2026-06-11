import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

class HudooriLogo extends StatelessWidget {
  const HudooriLogo({
    super.key,
    this.iconSize = 40,
    this.showName = true,
    this.nameSize = 22,
    this.axis = Axis.horizontal,
  });

  final double iconSize;
  final bool showName;
  final double nameSize;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final icon = Icon(Icons.fingerprint, size: iconSize, color: AppColors.primary);
    if (!showName) return icon;

    final name = Text(
      l10n.appName,
      style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w800, color: AppColors.primary),
    );

    if (axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(height: 8), name],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        name,
      ],
    );
  }
}
