import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/employee_search_field.dart';
import '../../core/widgets/list_picker_field.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';

const _kDeductionTypesFallback = [
  {'value': 'manual_debit', 'label': 'خصم يدوي'},
  {'value': 'check', 'label': 'شيك'},
  {'value': 'fine', 'label': 'غرامة'},
  {'value': 'admin', 'label': 'إداري'},
  {'value': 'absence', 'label': 'غياب'},
  {'value': 'late', 'label': 'تأخير'},
];

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
    var types = _types;
    if (types.isEmpty) {
      try {
        types = await api.deductionTypes();
        if (mounted && types.isNotEmpty) setState(() => _types = types);
      } catch (_) {}
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeductionFormDialog(types: types.isNotEmpty ? types : _kDeductionTypesFallback),
    );
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
            subtitle: 'خصومات الموظفين — بيانات محلية',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 18), label: const Text('استقطاع جديد')),
            ],
          ),
          const HrLocalDataBanner(
            title: 'الاستقطاعات — بيانات محلية',
            hint: 'تُنشأ في التطبيق وتُطبَّق على كشف الرواتب. مزامنة BioTime تجلب الموظفين والبصمات فقط.',
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
            HrEmptyListCard(
              message: _stateFilter == 'applied'
                  ? 'لا توجد استقطاعات مطبّقة.\nجرّب «الكل» أو «معلّق»، أو أنشئ استقطاعاً جديداً.'
                  : _stateFilter == 'pending'
                      ? 'لا توجد استقطاعات معلّقة.\nأضف استقطاعاً جديداً من الزر أعلاه.'
                      : 'لا توجد استقطاعات.\nأضف استقطاعاً جديداً واختر موظفاً مُزامَناً.',
              actionLabel: _stateFilter == null ? 'استقطاع جديد' : null,
              onAction: _stateFilter == null ? _add : null,
            )
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
  late String _type;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  List<Map<String, dynamic>> get _types =>
      widget.types.isNotEmpty ? widget.types : _kDeductionTypesFallback;

  List<({String value, String label})> get _typeOptions => [
        for (final t in _types)
          (value: t['value']?.toString() ?? '', label: t['label']?.toString() ?? ''),
      ];

  @override
  void initState() {
    super.initState();
    _type = _types.first['value']?.toString() ?? 'manual_debit';
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر موظفاً من نتائج البحث')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await api.deductionCreate({
        'employeeId': _employeeId,
        'type': _type,
        'amount': double.tryParse(_amount.text) ?? 0,
        'notes': _note.text.trim(),
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
    final maxH = MediaQuery.sizeOf(context).height * 0.55;

    return AlertDialog(
      title: const Text('استقطاع جديد'),
      content: SizedBox(
        width: 380,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmployeeSearchField(onSelected: (id, _) => setState(() => _employeeId = id)),
                const SizedBox(height: 12),
                ListPickerField<String>(
                  label: 'نوع الخصم',
                  value: _type,
                  options: _typeOptions,
                  onChanged: (v) => setState(() => _type = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amount,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظات')),
              ],
            ),
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
