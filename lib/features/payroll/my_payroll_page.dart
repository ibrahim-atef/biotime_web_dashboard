import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';

class MyPayrollPage extends StatefulWidget {
  const MyPayrollPage({super.key});

  @override
  State<MyPayrollPage> createState() => _MyPayrollPageState();
}

class _MyPayrollPageState extends State<MyPayrollPage> {
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
      final items = await api.myPayroll();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(title: 'كشف راتبي', subtitle: 'مسيرات الرواتب المحسوبة', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            const SellixCard(child: Text('لا توجد كشوف رواتب'))
          else
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final item in _items)
                    () {
                      final line = item['line'] as Map<String, dynamic>? ?? {};
                      return ListTile(
                        title: Text(item['payrollName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${item['dateFrom']} → ${item['dateTo']}'),
                        trailing: Text('${line['netSalary'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      );
                    }(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
