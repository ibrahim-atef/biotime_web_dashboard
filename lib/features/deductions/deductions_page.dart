import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/employee_search_field.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';

class DeductionsPage extends StatefulWidget {
  const DeductionsPage({super.key});

  @override
  State<DeductionsPage> createState() => _DeductionsPageState();
}

class _DeductionsPageState extends State<DeductionsPage> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _types = [];
  bool _loading = true;
  String? _stateFilter;

  Map<String, String> get _typeLabels => {
        for (final t in _types) t['value']?.toString() ?? '': t['label']?.toString() ?? '',
      };

  List<Map<String, dynamic>> get _filtered {
    if (_stateFilter == null) return _items;
    return _items.where((d) => d['state']?.toString() == _stateFilter).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await api.deductionsList(state: _stateFilter);
      final types = await api.deductionTypes();
      if (mounted) setState(() { _items = items; _types = types; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  StatusTagType _tag(String s) {
    if (s == 'applied') return StatusTagType.success;
    if (s == 'cancelled') return StatusTagType.danger;
    return StatusTagType.warning;
  }

  String _stateAr(String s) {
    switch (s) {
      case 'pending': return 'معلّق';
      case 'applied': return 'مطبّق';
      case 'cancelled': return 'ملغي';
      default: return s;
    }
  }

  String _typeLabel(String code) => _typeLabels[code] ?? code;

  Future<void> _add() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _DeductionFormDialog(types: _types));
    if (ok == true) _load();
  }

  Future<void> _cancel(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الاستقطاع'),
        content: Text('إلغاء استقطاع ${d['employeeName']} بمبلغ ${d['amount']}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إلغاء الاستقطاع')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deductionCancel(d['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(
            title: 'الاستقطاعات',
            subtitle: 'خصومات الموظفين — تُحفظ في Odoo',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 18), label: const Text('استقطاع جديد')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('الكل'),
                selected: _stateFilter == null,
                onSelected: (_) {
                  setState(() => _stateFilter = null);
                  _load();
                },
              ),
              FilterChip(
                label: const Text('معلّق'),
                selected: _stateFilter == 'pending',
                onSelected: (_) {
                  setState(() => _stateFilter = 'pending');
                  _load();
                },
              ),
              FilterChip(
                label: const Text('مطبّق'),
                selected: _stateFilter == 'applied',
                onSelected: (_) {
                  setState(() => _stateFilter = 'applied');
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (items.isEmpty)
            const SellixCard(child: Text('لا توجد استقطاعات'))
          else
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final d in items)
                    ListTile(
                      title: Text('${d['employeeName']} — ${d['amount']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${d['deductionTypeLabel'] ?? _typeLabel(d['deductionType']?.toString() ?? '')}  •  ${d['date']}  •  ${d['name']}'
                        '${d['payrollId'] != null && d['payrollId'] != false ? '  •  كشف #${d['payrollId']}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusTag(label: _stateAr(d['state']?.toString() ?? ''), type: _tag(d['state']?.toString() ?? '')),
                          if (d['state'] == 'pending')
                            IconButton(
                              tooltip: 'إلغاء',
                              icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
                              onPressed: () => _cancel(d),
                            ),
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

class _DeductionFormDialog extends StatefulWidget {
  const _DeductionFormDialog({required this.types});
  final List<Map<String, dynamic>> types;

  @override
  State<_DeductionFormDialog> createState() => _DeductionFormDialogState();
}

class _DeductionFormDialogState extends State<_DeductionFormDialog> {
  String? _employeeId;
  String _type = 'manual_debit';
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_employeeId == null) return;
    setState(() => _saving = true);
    try {
      await api.deductionCreate({
        'employeeId': _employeeId,
        'deductionType': _type,
        'amount': double.tryParse(_amount.text) ?? 0,
        'note': _note.text,
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
      title: const Text('استقطاع جديد'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmployeeSearchField(onSelected: (id, _) => _employeeId = id),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'نوع الخصم'),
              items: [
                for (final t in widget.types)
                  DropdownMenuItem(value: t['value']?.toString(), child: Text(t['label']?.toString() ?? '')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            TextField(controller: _amount, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظات')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('حفظ')),
      ],
    );
  }
}
