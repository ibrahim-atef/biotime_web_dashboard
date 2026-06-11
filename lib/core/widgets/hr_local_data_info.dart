import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'sellix_card.dart';

/// Explains that this HR screen is managed locally, not imported from BioTime sync.
class HrLocalDataBanner extends StatelessWidget {
  const HrLocalDataBanner({
    super.key,
    required this.title,
    this.hint,
  });

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SellixCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primary.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  hint ??
                      'لا يُستورد من سيرفر BioTime — أنشئ السجلات من هذا التطبيق بعد مزامنة الموظفين.',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HrEmptyListCard extends StatelessWidget {
  const HrEmptyListCard({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SellixCard(
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: AppColors.textMuted.withValues(alpha: 0.7)),
          const SizedBox(height: AppDimensions.spaceSm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
