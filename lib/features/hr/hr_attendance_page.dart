import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';

class HrAttendancePage extends StatefulWidget {
  const HrAttendancePage({super.key});

  @override
  State<HrAttendancePage> createState() => _HrAttendancePageState();
}

class _HrAttendancePageState extends State<HrAttendancePage> {
  List<Map<String, dynamic>> _records = [];
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
      final records = await api.attendanceList();
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final to = DateTime(now.year, now.month + 1, 0);
      await api.attendanceGenerate(
        dateFrom: from.toIso8601String().slice(0, 10),
        dateTo: to.toIso8601String().slice(0, 10),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance generated')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: PageHeader(
            title: 'الحضور',
            subtitle: 'Attendance records from local server',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Generate'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppDimensions.spaceMd),
                        itemCount: _records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final r = _records[i];
                          return SellixCard(
                            child: ListTile(
                              title: Text(r['employeeName']?.toString() ?? r['employee']?['name']?.toString() ?? ''),
                              subtitle: Text('${r['date']} • ${r['status']} • ${r['workedHours'] ?? 0}h'),
                              trailing: (r['lateMinutes'] as num? ?? 0) > 0
                                  ? Chip(label: Text('Late ${r['lateMinutes']}m'))
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

extension on String {
  String slice(int start, int end) => substring(start, end.clamp(0, length));
}
