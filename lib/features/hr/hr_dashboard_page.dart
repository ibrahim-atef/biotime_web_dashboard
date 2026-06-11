import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/di/injection.dart';

class HrDashboardPage extends StatefulWidget {
  const HrDashboardPage({super.key});

  @override
  State<HrDashboardPage> createState() => _HrDashboardPageState();
}

class _HrDashboardPageState extends State<HrDashboardPage> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await api.dashboardStats();
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.sizeOf(context).width >= 900 ? 4 : (MediaQuery.sizeOf(context).width >= 600 ? 2 : 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'لوحة HR',
            subtitle: 'ملخص الحضور والرواتب',
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                StatCard(title: 'الموظفين', value: '${_stats['employees'] ?? 0}', icon: Icons.people_outline),
                StatCard(title: 'حضور اليوم', value: '${_stats['attendanceToday'] ?? 0}', icon: Icons.fact_check_outlined),
                StatCard(title: 'طلبات معلقة', value: '${_stats['pendingRequests'] ?? 0}', icon: Icons.assignment_outlined),
                StatCard(title: 'كشوف مسودة', value: '${_stats['payrollsDraft'] ?? 0}', icon: Icons.payments_outlined),
              ],
            ),
          const SizedBox(height: 20),
          const Text('الوصول السريع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final quickCols = c.maxWidth >= 800 ? 3 : 1;
              return GridView.count(
                crossAxisCount: quickCols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.8,
                children: [
                  _QuickLink(
                    title: 'جدول الشيفتات',
                    subtitle: 'توليد، مزامنة بصمات، تأكيد',
                    icon: Icons.grid_on_outlined,
                    color: AppColors.primary,
                    onTap: () => context.go(AppRoutes.hrShiftGrid),
                  ),
                  _QuickLink(
                    title: 'الاستقطاعات',
                    subtitle: 'إضافة وإلغاء خصومات الموظفين',
                    icon: Icons.remove_circle_outline,
                    color: AppColors.warning,
                    onTap: () => context.go(AppRoutes.hrDeductions),
                  ),
                  _QuickLink(
                    title: 'كشوف الرواتب',
                    subtitle: 'حساب، تأكيد، تصدير Fawry',
                    icon: Icons.payments_outlined,
                    color: AppColors.success,
                    onTap: () => context.go(AppRoutes.hrPayroll),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const SellixCard(
            child: Text(
              'كل العمليات تُحفظ مباشرة في Odoo — جدول الشيفتات، الاستقطاعات، والرواتب متاحة من القائمة الجانبية.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: SellixCard(
          child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
        ],
          ),
        ),
      ),
    );
  }
}
