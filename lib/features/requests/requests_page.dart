import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/list_picker_field.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await api.requestsMy();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateMenu() async {
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.beach_access), title: const Text('إجازة'), onTap: () => Navigator.pop(ctx, 'leave')),
            ListTile(leading: const Icon(Icons.money), title: const Text('قرض'), onTap: () => Navigator.pop(ctx, 'loan')),
            ListTile(leading: const Icon(Icons.schedule), title: const Text('تغيير شيفت'), onTap: () => Navigator.pop(ctx, 'shift')),
            ListTile(leading: const Icon(Icons.payments), title: const Text('طلب راتب'), onTap: () => Navigator.pop(ctx, 'salary')),
            ListTile(leading: const Icon(Icons.description), title: const Text('شهادة'), onTap: () => Navigator.pop(ctx, 'certificate')),
            ListTile(leading: const Icon(Icons.edit_calendar), title: const Text('تعديل حضور'), onTap: () => Navigator.pop(ctx, 'attendance')),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestFormDialog(type: type),
    );
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final leave = (_data['leave'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final loan = (_data['loan'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final shift = (_data['shiftChange'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final salary = (_data['salary'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final certificate = (_data['certificate'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final attendanceEdit = (_data['attendanceEdit'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: PageHeader(
            title: 'طلباتي',
            subtitle: 'تُحفظ محلياً في النظام — لا تُرسل إلى Odoo',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: _openCreateMenu,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('طلب جديد'),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          isScrollable: true,
          tabs: [
            Tab(text: 'إجازة (${leave.length})'),
            Tab(text: 'قرض (${loan.length})'),
            Tab(text: 'شيفت (${shift.length})'),
            Tab(text: 'راتب (${salary.length})'),
            Tab(text: 'شهادة (${certificate.length})'),
            Tab(text: 'حضور (${attendanceEdit.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _list(leave, (r) => '${r['leaveType']} • ${r['dateFrom']} → ${r['dateTo']} • ${r['state']}'),
              _list(loan, (r) => '${r['amount']} • ${r['repaymentMonths']} شهر • ${r['state']}'),
              _list(shift, (r) => '${r['dateFrom']} → ${r['dateTo']} • ${r['state']}'),
              _list(salary, (r) => '${r['amount']} • ${r['state']}'),
              _list(certificate, (r) => '${r['certificateType']} • ${r['state']}'),
              _list(attendanceEdit, (r) => '${r['date']} • ${r['state']}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) subtitle) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد طلبات'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => SellixCard(
        child: ListTile(
          title: Text(subtitle(items[i])),
        ),
      ),
    );
  }
}

class _RequestFormDialog extends StatefulWidget {
  const _RequestFormDialog({required this.type});
  final String type;

  @override
  State<_RequestFormDialog> createState() => _RequestFormDialogState();
}

class _RequestFormDialogState extends State<_RequestFormDialog> {
  final _reason = TextEditingController();
  final _amount = TextEditingController(text: '1000');
  final _months = TextEditingController(text: '3');
  String _leaveType = 'annual';
  String? _shiftId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 1));
  List<Map<String, dynamic>> _shifts = [];
  bool _loadingShifts = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'shift') _loadShifts();
  }

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    _months.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadShifts() async {
    setState(() => _loadingShifts = true);
    try {
      final shifts = await api.shiftsList();
      if (mounted) {
        setState(() {
          _shifts = shifts;
          if (shifts.isNotEmpty) _shiftId = shifts.first['id']?.toString();
          _loadingShifts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingShifts = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final reason = _reason.text.trim();
    try {
      if (widget.type == 'leave') {
        await api.leaveRequestCreate(
          leaveType: _leaveType,
          dateFrom: _fmt(_from),
          dateTo: _fmt(_to),
          reason: reason.isEmpty ? 'طلب إجازة' : reason,
        );
      } else if (widget.type == 'loan') {
        await api.loanRequestCreate(
          amount: double.tryParse(_amount.text) ?? 0,
          repaymentMonths: int.tryParse(_months.text) ?? 1,
          reason: reason.isEmpty ? 'طلب قرض' : reason,
        );
      } else if (widget.type == 'salary') {
        await api.salaryRequestCreate(
          amount: double.tryParse(_amount.text) ?? 0,
          reason: reason.isEmpty ? 'طلب راتب' : reason,
        );
      } else if (widget.type == 'certificate') {
        await api.certificateRequestCreate(
          certificateType: 'employment',
          reason: reason.isEmpty ? 'شهادة عمل' : reason,
        );
      } else if (widget.type == 'attendance') {
        await api.attendanceEditRequestCreate(
          date: _fmt(_from),
          reason: reason.isEmpty ? 'تصحيح بصمة' : reason,
          requestedCheckIn: '09:00',
          requestedCheckOut: '17:00',
        );
      } else if (widget.type == 'shift') {
        if (_shiftId == null) throw Exception('اختر الشيفت الجديد');
        await api.shiftChangeRequestCreate(
          newShiftId: _shiftId!,
          dateFrom: _fmt(_from),
          dateTo: _fmt(_to),
          reason: reason.isEmpty ? 'طلب تغيير شيفت' : reason,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String get _title {
    switch (widget.type) {
      case 'leave': return 'طلب إجازة';
      case 'loan': return 'طلب قرض';
      case 'shift': return 'طلب تغيير شيفت';
      case 'salary': return 'طلب راتب';
      case 'certificate': return 'طلب شهادة';
      case 'attendance': return 'طلب تعديل حضور';
      default: return 'طلب جديد';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.type == 'leave') ...[
                ListPickerField<String>(
                  label: 'نوع الإجازة',
                  value: _leaveType,
                  options: const [
                    (value: 'annual', label: 'سنوية'),
                    (value: 'sick', label: 'مرضية'),
                    (value: 'unpaid', label: 'بدون راتب'),
                  ],
                  onChanged: (v) => setState(() => _leaveType = v),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text('من ${_fmt(_from)}'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text('إلى ${_fmt(_to)}'))),
                ]),
              ],
              if (widget.type == 'loan') ...[
                TextField(controller: _amount, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
                TextField(controller: _months, decoration: const InputDecoration(labelText: 'أشهر السداد'), keyboardType: TextInputType.number),
              ],
              if (widget.type == 'salary')
                TextField(controller: _amount, decoration: const InputDecoration(labelText: 'المبلغ المطلوب'), keyboardType: TextInputType.number),
              if (widget.type == 'shift') ...[
                if (_loadingShifts)
                  const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                else if (_shifts.isEmpty)
                  const Text('لا توجد شيفتات — أنشئ شيفتاً أولاً')
                else
                  ListPickerField<String>(
                    label: 'الشيفت الجديد',
                    value: _shiftId,
                    options: [
                      for (final s in _shifts)
                        (value: s['id']?.toString() ?? '', label: '${s['code']} - ${s['name']}'),
                    ],
                    onChanged: (v) => setState(() => _shiftId = v),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text('من ${_fmt(_from)}'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text('إلى ${_fmt(_to)}'))),
                ]),
              ],
              if (widget.type == 'attendance')
                OutlinedButton(onPressed: () => _pickDate(true), child: Text('تاريخ ${_fmt(_from)}')),
              const SizedBox(height: 8),
              TextField(controller: _reason, decoration: const InputDecoration(labelText: 'السبب / ملاحظات')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('إرسال الطلب')),
      ],
    );
  }
}
