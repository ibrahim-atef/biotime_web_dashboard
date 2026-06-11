import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/entity_id.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import 'shift_grid_helpers.dart';

class ShiftGridListPage extends StatefulWidget {
  const ShiftGridListPage({super.key});

  @override
  State<ShiftGridListPage> createState() => _ShiftGridListPageState();
}

class _ShiftGridListPageState extends State<ShiftGridListPage> {
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
      final items = await api.shiftGridList();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateShiftGridDialog(),
    );
    if (created == true) _load();
  }

  StatusTagType _stateTag(String state) {
    if (state == 'confirmed') return StatusTagType.success;
    if (state == 'grid') return StatusTagType.info;
    return StatusTagType.warning;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(
            title: 'جدول الشيفتات',
            subtitle: 'إدارة جداول الشيفتات — نفس منطق Odoo',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('جدول جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            const SellixCard(child: Text('لا توجد جداول — أنشئ جدولاً جديداً'))
          else
            Column(
              children: [
                for (final group in groupShiftGridsByPeriod(_items)) ...[
                  _PeriodHeader(
                    label: group.key,
                    count: group.value.length,
                  ),
                  const SizedBox(height: 8),
                  SellixCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < group.value.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _GridListTile(
                            item: group.value[i],
                            stateTag: _stateTag(group.value[i]['state']?.toString() ?? ''),
                            onTap: () {
                              final id = group.value[i]['id'];
                              if (id != null) context.go('${AppRoutes.hrShiftGrid}/$id');
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count جدول',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridListTile extends StatelessWidget {
  const _GridListTile({required this.item, required this.stateTag, required this.onTap});
  final Map<String, dynamic> item;
  final StatusTagType stateTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final device = item['deviceName']?.toString() ?? '';
    final employees = item['employeeCount'] ?? 0;
    final days = item['daysCount'] ?? 0;

    return ListTile(
      title: Text(
        item['name']?.toString() ?? 'جدول',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (device.isNotEmpty) device,
          '$employees موظف',
          if (days != 0) '$days يوم',
        ].join('  •  '),
      ),
      trailing: StatusTag(
        label: stateLabel(item['state']?.toString() ?? ''),
        type: stateTag,
      ),
      onTap: onTap,
    );
  }
}

class _CreateShiftGridDialog extends StatefulWidget {
  const _CreateShiftGridDialog();

  @override
  State<_CreateShiftGridDialog> createState() => _CreateShiftGridDialogState();
}

class _CreateShiftGridDialogState extends State<_CreateShiftGridDialog> {
  final _locationCtrl = TextEditingController();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 6));
  String? _deviceId;
  List<String> _departmentIds = [];
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _departments = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final devices = await api.devicesList();
      final depts = await api.departmentsList();
      if (mounted) {
        setState(() {
          _devices = devices;
          _departments = depts;
          if (devices.isNotEmpty) _deviceId = EntityId.parse(devices.first['id']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from.add(const Duration(days: 6));
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر جهاز البصمة')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final location = _locationCtrl.text.trim();
      final hasLocation = location.isNotEmpty;
      final result = await api.shiftGridCreate(
        dateFrom: _fmt(_from),
        dateTo: _fmt(_to),
        deviceId: _deviceId,
        selectionMethod: hasLocation ? 'location' : 'department',
        departmentIds: hasLocation || _departmentIds.isEmpty ? null : _departmentIds,
        gridLocation: hasLocation ? location : null,
        generate: true,
      );
      if (!mounted) return;
      final grid = result['grid'] as Map<String, dynamic>?;
      final id = grid?['id'];
      Navigator.pop(context, true);
      if (id != null) context.go('${AppRoutes.hrShiftGrid}/$id');
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
      title: const Text('جدول شيفتات جديد'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String?>(
                      value: _deviceId,
                      decoration: const InputDecoration(labelText: 'جهاز البصمة'),
                      items: [
                        for (final d in _devices)
                          DropdownMenuItem(
                            value: EntityId.parse(d['id']),
                            child: Text(d['name']?.toString() ?? ''),
                          ),
                      ],
                      onChanged: (v) => setState(() => _deviceId = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(true),
                            child: Text('من: ${_fmt(_from)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(false),
                            child: Text('إلى: ${_fmt(_to)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الموقع (اختياري)',
                        hintText: 'Location filter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('الأقسام (اختياري — فارغ = حسب الجهاز)', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final d in _departments)
                          FilterChip(
                            label: Text(d['name']?.toString() ?? ''),
                            selected: _departmentIds.contains(EntityId.parse(d['id'])),
                            onSelected: (sel) {
                              setState(() {
                                final id = EntityId.parse(d['id']);
                                if (id == null) return;
                                if (sel) {
                                  _departmentIds = [..._departmentIds, id];
                                } else {
                                  _departmentIds = _departmentIds.where((x) => x != id).toList();
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('توليد الجدول'),
        ),
      ],
    );
  }
}
