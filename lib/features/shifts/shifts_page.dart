import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
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
      final items = await api.shiftsList();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _openForm([Map<String, dynamic>? shift]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ShiftFormDialog(shift: shift),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(
            title: 'الشيفتات',
            subtitle: 'قوالب الشيفت — إضافة وتعديل',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 18), label: const Text('شيفت جديد')),
            ],
          ),
          const HrLocalDataBanner(
            title: 'الشيفتات — بيانات محلية',
            hint: 'أنشئ قوالب الشيفت هنا، ثم عيّنها للموظفين في «تعيينات الشيفت» وجدول الشيفتات.',
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            const HrEmptyListCard(
              message: 'لا توجد شيفتات.\nأنشئ شيفتاً جديداً ثم عيّنه للموظفين المُزامَنين من BioTime.',
            )
          else
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final s in _items)
                    ListTile(
                      title: Text('${s['code']} — ${s['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s['startTimeDisplay'] ?? s['startTime']} → ${s['endTimeDisplay'] ?? s['endTime']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(s)),
                          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                            try {
                              await api.shiftDelete(s['id']);
                              _load();
                            } catch (e) { _snack(e.toString()); }
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShiftFormDialog extends StatefulWidget {
  const _ShiftFormDialog({this.shift});
  final Map<String, dynamic>? shift;

  @override
  State<_ShiftFormDialog> createState() => _ShiftFormDialogState();
}

class _ShiftFormDialogState extends State<_ShiftFormDialog> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _start = TextEditingController(text: '8');
  final _end = TextEditingController(text: '17');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.shift;
    if (s != null) {
      _name.text = s['name']?.toString() ?? '';
      _code.text = s['code']?.toString() ?? '';
      _start.text = '${s['startTime'] ?? 8}';
      _end.text = '${s['endTime'] ?? 17}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'code': _code.text.trim(),
      'startTime': double.tryParse(_start.text) ?? 8,
      'endTime': double.tryParse(_end.text) ?? 17,
    };
    try {
      if (widget.shift != null) {
        await api.shiftUpdate(widget.shift!['id'], body);
      } else {
        await api.shiftCreate(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.shift == null ? 'شيفت جديد' : 'تعديل شيفت'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'الكود')),
            Row(children: [
              Expanded(child: TextField(controller: _start, decoration: const InputDecoration(labelText: 'بداية (8 = 8:00)'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _end, decoration: const InputDecoration(labelText: 'نهاية'))),
            ]),
            const SizedBox(height: 8),
            const Text('الوقت بالساعات العشرية (8 = 8:00)', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ')),
      ],
    );
  }
}
