import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';

class PayrollListPage extends StatefulWidget {
  const PayrollListPage({super.key});

  @override
  State<PayrollListPage> createState() => _PayrollListPageState();
}

class _PayrollListPageState extends State<PayrollListPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await api.payrollList();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  StatusTagType _tag(String s) {
    if (s == 'confirmed') return StatusTagType.success;
    if (s == 'calculated') return StatusTagType.info;
    return StatusTagType.warning;
  }

  String _stateAr(String s) {
    switch (s) {
      case 'draft': return 'مسودة';
      case 'calculated': return 'محسوب';
      case 'confirmed': return 'مؤكد';
      default: return s;
    }
  }

  Future<void> _create() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      final p = await api.payrollCreate(dateFrom: fmt(from), dateTo: fmt(to));
      if (mounted && p['id'] != null) context.go('${AppRoutes.hrPayroll}/${p['id']}');
      else _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(
            title: 'كشوف الرواتب',
            subtitle: 'حساب وتأكيد وإرسال الرواتب',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add, size: 18), label: const Text('كشف جديد')),
            ],
          ),
          const HrLocalDataBanner(
            title: 'الرواتب — تُحسب محلياً',
            hint: 'بعد مزامنة البصمات والشيفتات: أنشئ كشفاً جديداً ثم احسبه من بيانات الحضور المحلية.',
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            HrEmptyListCard(
              message: 'لا توجد كشوف رواتب.\nأنشئ كشفاً جديداً للفترة الحالية ثم اضغط «حساب».',
              actionLabel: 'كشف جديد',
              onAction: _create,
            )
          else
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final p in _items)
                    ListTile(
                      title: Text(p['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${p['dateFrom']} → ${p['dateTo']}  •  ${p['employeeCount']} موظف  •  صافي: ${p['totalNet']}'),
                      trailing: StatusTag(label: _stateAr(p['state']?.toString() ?? ''), type: _tag(p['state']?.toString() ?? '')),
                      onTap: () => context.go('${AppRoutes.hrPayroll}/${p['id']}'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
