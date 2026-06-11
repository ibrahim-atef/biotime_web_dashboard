import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';

class OvertimePage extends StatefulWidget {
  const OvertimePage({super.key});

  @override
  State<OvertimePage> createState() => _OvertimePageState();
}

class _OvertimePageState extends State<OvertimePage> {
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
      final items = await api.overtimeList(state: 'pending');
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);
    setState(() => _loading = true);
    try {
      await api.overtimeGenerate(
        dateFrom: from.toIso8601String().slice(0, 10),
        dateTo: to.toIso8601String().slice(0, 10),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم توليد تحليل الإضافي')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _approve(String id) async {
    await api.overtimeApprove(id);
    _load();
  }

  Future<void> _reject(String id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(controller: c),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('رفض')),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    await api.overtimeReject(id, reason);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: PageHeader(
            title: 'تحليل الإضافي',
            subtitle: 'مراجعة واعتماد ساعات إضافية من بيانات البصمة',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('توليد من البصمات'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('لا توجد سجلات إضافي معلقة'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final o = _items[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SellixCard(
                            child: ListTile(
                              title: Text('${o['employeeName']} — ${o['date']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('إضافي: ${o['overtimeHours']} س  •  تأخير: ${o['lateMinutes']} د  •  ${o['attendanceStatus']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusTag(label: o['state']?.toString() ?? '', type: StatusTagType.info),
                                  IconButton(
                                    icon: Icon(Icons.check, color: AppColors.success),
                                    onPressed: () => _approve(o['id'].toString()),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: AppColors.danger),
                                    onPressed: () => _reject(o['id'].toString()),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

extension _DateSlice on String {
  String slice(int start, int end) => substring(start, end.clamp(0, length));
}
