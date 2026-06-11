import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';

class MyAttendancePage extends StatefulWidget {
  const MyAttendancePage({super.key});

  @override
  State<MyAttendancePage> createState() => _MyAttendancePageState();
}

class _MyAttendancePageState extends State<MyAttendancePage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await api.myAttendance();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  StatusTagType _tag(String status) {
    final s = status.toLowerCase();
    if (s.contains('present') || s.contains('حاضر')) return StatusTagType.success;
    if (s.contains('absent') || s.contains('غائب')) return StatusTagType.danger;
    if (s.contains('leave') || s.contains('إجازة')) return StatusTagType.info;
    return StatusTagType.warning;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(
            title: 'حضوري',
            subtitle: 'سجلات الحضور من BioTime',
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            SellixCard(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
          else if (_items.isEmpty)
            const SellixCard(child: Text('لا توجد سجلات حضور في هذه الفترة'))
          else
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final item in _items)
                    ListTile(
                      title: Text(item['date']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${item['checkIn'] ?? '-'} → ${item['checkOut'] ?? '-'}  |  ${item['shiftName'] ?? ''}'),
                      trailing: StatusTag(label: item['status']?.toString() ?? '-', type: _tag(item['status']?.toString() ?? '')),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
