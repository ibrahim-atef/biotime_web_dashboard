import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/utils/entity_id.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/employee_search_field.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';

class ShiftAssignmentsPage extends StatefulWidget {
  const ShiftAssignmentsPage({super.key});

  @override
  State<ShiftAssignmentsPage> createState() => _ShiftAssignmentsPageState();
}

class _ShiftAssignmentsPageState extends State<ShiftAssignmentsPage> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _shifts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await api.shiftAssignmentsList();
      final shifts = await api.shiftsList();
      if (mounted) setState(() { _items = items; _shifts = shifts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'permanent': return 'ثابت دائم';
      case 'date_range': return 'فترة محددة';
      case 'weekly': return 'أسبوعي دائم';
      case 'weekly_period': return 'أسبوعي بفترة';
      default: return t;
    }
  }

  Future<void> _openForm() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _AssignmentFormDialog(shifts: _shifts));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(
            title: 'تعيين الشيفتات',
            subtitle: 'ربط الموظفين بالشيفتات',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(onPressed: _openForm, icon: const Icon(Icons.add, size: 18), label: const Text('تعيين جديد')),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final a in _items)
                    ListTile(
                      title: Text(a['displayName']?.toString() ?? a['employeeName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${_typeLabel(a['assignmentType']?.toString() ?? '')}  •  ${a['dateFrom']} → ${a['dateTo']}'),
                      trailing: StatusTag(label: a['shiftCode']?.toString() ?? '-', type: StatusTagType.info),
                      onLongPress: () async {
                        try {
                          await api.shiftAssignmentDelete(a['id']);
                          _load();
                        } catch (_) {}
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignmentFormDialog extends StatefulWidget {
  const _AssignmentFormDialog({required this.shifts});
  final List<Map<String, dynamic>> shifts;

  @override
  State<_AssignmentFormDialog> createState() => _AssignmentFormDialogState();
}

class _AssignmentFormDialogState extends State<_AssignmentFormDialog> {
  String? _employeeId;
  String _type = 'weekly_period';
  String? _shiftId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_employeeId == null) return;
    setState(() => _saving = true);
    try {
      await api.shiftAssignmentCreate({
        'employeeId': _employeeId,
        'assignmentType': _type,
        if (_shiftId != null) 'shiftId': _shiftId,
        'dateFrom': _fmt(_from),
        'dateTo': _fmt(_to),
      });
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
      title: const Text('تعيين شيفت جديد'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmployeeSearchField(onSelected: (id, _) => _employeeId = id),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'نوع التعيين'),
                items: const [
                  DropdownMenuItem(value: 'weekly_period', child: Text('نمط أسبوعي مع فترة')),
                  DropdownMenuItem(value: 'date_range', child: Text('فترة زمنية + شيفت ثابت')),
                  DropdownMenuItem(value: 'permanent', child: Text('ثابت دائم')),
                  DropdownMenuItem(value: 'weekly', child: Text('نمط أسبوعي دائم')),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              if (_type == 'permanent' || _type == 'date_range') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _shiftId,
                  decoration: const InputDecoration(labelText: 'الشيفت'),
                  items: [
                    for (final s in widget.shifts)
                      DropdownMenuItem(
                        value: EntityId.parse(s['id']),
                        child: Text('${s['code']} - ${s['name']}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _shiftId = v),
                ),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () async {
                  final p = await showDatePicker(context: context, initialDate: _from, firstDate: DateTime(2020), lastDate: DateTime(2035));
                  if (p != null) setState(() => _from = p);
                }, child: Text('من ${_fmt(_from)}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () async {
                  final p = await showDatePicker(context: context, initialDate: _to, firstDate: DateTime(2020), lastDate: DateTime(2035));
                  if (p != null) setState(() => _to = p);
                }, child: Text('إلى ${_fmt(_to)}'))),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('حفظ')),
      ],
    );
  }
}
