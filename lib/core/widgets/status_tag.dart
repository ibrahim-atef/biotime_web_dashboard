import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum StatusTagType { success, warning, danger, info, neutral }

class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.label, this.type = StatusTagType.neutral});
  final String label;
  final StatusTagType type;

  Color get _color => switch (type) {
        StatusTagType.success => AppColors.success,
        StatusTagType.warning => AppColors.warning,
        StatusTagType.danger => AppColors.danger,
        StatusTagType.info => AppColors.primary,
        StatusTagType.neutral => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
