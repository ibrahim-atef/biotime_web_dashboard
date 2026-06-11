import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import 'shift_grid_cell_style.dart';
import 'shift_grid_helpers.dart';

class ShiftGridDetailPage extends StatefulWidget {
  const ShiftGridDetailPage({super.key, required this.gridId});
  final String gridId;

  @override
  State<ShiftGridDetailPage> createState() => _ShiftGridDetailPageState();
}

class _ShiftGridDetailPageState extends State<ShiftGridDetailPage> {
  Map<String, dynamic> _grid = {};
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _shifts = [];
  bool _loading = true;
  String? _bulkValue;
  String _syncState = 'idle';
  int _syncProgress = 0;
  String _syncMessage = '';
  int _syncSynced = 0;
  int _syncTotal = 0;
  int _syncErrors = 0;
  Timer? _syncTimer;

  bool get _locked => _grid['state'] == 'confirmed';
  List<Map<String, dynamic>> get _dates => parseDates(_data['dates']);
  List<MapEntry<String, List<Map<String, dynamic>>>> get _jobGroups =>
      parseJobGroups(_data['job_groups']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stopSyncPoll();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await api.shiftGridGet(widget.gridId);
      if (!mounted) return;
      setState(() {
        _grid = Map<String, dynamic>.from(result['grid'] as Map? ?? {});
        _data = Map<String, dynamic>.from(result['data'] as Map? ?? {});
        _shifts = parseShifts(_data['shifts']);
        _syncState = _grid['syncState']?.toString() ?? 'idle';
        _syncProgress = (_grid['syncProgress'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
      if (_syncState == 'syncing') _startSyncPoll();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString());
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _startSyncPoll() {
    _stopSyncPoll();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollSync());
  }

  void _stopSyncPoll() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _pollSync() async {
    try {
      final s = await api.shiftGridSyncStatus(widget.gridId);
      if (!mounted) return;
      setState(() {
        _syncState = s['syncState']?.toString() ?? 'idle';
        _syncProgress = (s['syncProgress'] as num?)?.toInt() ?? 0;
        _syncMessage = s['syncMessage']?.toString() ?? '';
        _syncSynced = (s['syncSyncedCount'] as num?)?.toInt() ?? 0;
        _syncTotal = (s['syncTotalCount'] as num?)?.toInt() ?? 0;
        _syncErrors = (s['syncErrorsCount'] as num?)?.toInt() ?? 0;
      });
      if (_syncState != 'syncing') {
        _stopSyncPoll();
        if (_syncState == 'done') _snack('تمت المزامنة: $_syncSynced بصمة');
        await _load();
      }
    } catch (_) {}
  }

  Future<void> _syncStart() async {
    try {
      await api.shiftGridSyncStart(widget.gridId);
      setState(() => _syncState = 'syncing');
      _startSyncPoll();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _syncCancel() async {
    try {
      await api.shiftGridSyncCancel(widget.gridId);
      _stopSyncPoll();
      setState(() => _syncState = 'idle');
      _snack('تم إلغاء المزامنة');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _createPayroll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنشاء كشف رواتب'),
        content: Text(
          'سيتم إنشاء كشف رواتب من جدول ${_grid['dateFrom']} إلى ${_grid['dateTo']} وحفظه في Odoo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final payroll = await api.payrollCreate(shiftGridId: widget.gridId);
      final id = payroll['id'];
      if (!mounted) return;
      _snack('تم إنشاء كشف الرواتب');
      if (id != null) context.go('${AppRoutes.hrPayroll}/$id');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _action(Future<Map<String, dynamic>> Function() fn, {bool reload = true}) async {
    try {
      final r = await fn();
      if (r['grid'] is Map) _grid = Map<String, dynamic>.from(r['grid'] as Map);
      if (r['data'] is Map) {
        _data = Map<String, dynamic>.from(r['data'] as Map);
        _shifts = parseShifts(_data['shifts']);
      }
      if (reload) await _load();
      else if (mounted) setState(() {});
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _editCell(Map<String, dynamic> cell) async {
    if (_locked) return;
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CellEditorSheet(
        shifts: _shifts,
        current: ShiftGridCellStyle.cellSelectValue(cell),
      ),
    );
    if (value == null) return;
    try {
      final r = await api.shiftGridUpdateCell(
        gridId: widget.gridId,
        lineId: cell['line_id'] ?? cell['lineId'] ?? cell['id'],
        cellValue: value,
      );
      setState(() {
        cell['display_label'] = r['display_label'] ?? ShiftGridCellStyle.displayLabel(cell);
      });
      await _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _showPunches(Map<String, dynamic> cell) async {
    try {
      final r = await api.shiftGridDayPunches(cell['line_id'] ?? cell['lineId'] ?? cell['id']);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => _PunchesDialog(result: r),
      );
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _bulkRow(Object employeeId) async {
    if (_bulkValue == null || _bulkValue!.isEmpty) {
      _snack('اختر قيمة من التعيين الجماعي أولاً');
      return;
    }
    await _action(() => api.shiftGridBulkRow(
          gridId: widget.gridId,
          employeeId: employeeId,
          cellValue: _bulkValue!,
        ));
    _snack('تم تحديث الصف');
  }

  Future<void> _bulkColumn(String date) async {
    if (_bulkValue == null || _bulkValue!.isEmpty) {
      _snack('اختر قيمة من التعيين الجماعي أولاً');
      return;
    }
    await _action(() => api.shiftGridBulkColumn(
          gridId: widget.gridId,
          date: date,
          cellValue: _bulkValue!,
        ));
    _snack('تم تحديث العمود');
  }

  Future<void> _addEmployee() async {
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة موظف'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(labelText: 'كود الموظف'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _action(() => api.shiftGridAddEmployee(
          gridId: widget.gridId,
          employeeCode: codeCtrl.text.trim(),
        ));
    codeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    var rowNum = 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: _grid['name']?.toString() ?? 'جدول الشيفتات',
            subtitle:
                '${_grid['dateFrom']} → ${_grid['dateTo']}  •  ${_grid['deviceName'] ?? ''}  •  ${stateLabel(_grid['state']?.toString() ?? '')}',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              IconButton(
                onPressed: () => context.go(AppRoutes.hrShiftGrid),
                icon: const Icon(Icons.arrow_back),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ActionBar(
            locked: _locked,
            onSync: _syncStart,
            onClose: () => _action(() => api.shiftGridClose(widget.gridId)),
            onReopen: () => _action(() => api.shiftGridReopen(widget.gridId)),
            onConfirm: () => _action(() => api.shiftGridConfirm(widget.gridId)),
            onGenerate: () => _action(() => api.shiftGridGenerate(widget.gridId)),
            onCreatePayroll: _data.isNotEmpty ? _createPayroll : null,
            state: _grid['state']?.toString() ?? '',
          ),
          if (_syncState == 'syncing') ...[
            const SizedBox(height: 12),
            _SyncOverlay(
              progress: _syncProgress,
              message: _syncMessage,
              synced: _syncSynced,
              total: _syncTotal,
              errors: _syncErrors,
              onCancel: _syncCancel,
            ),
          ],
          if (_syncState == 'done' || _syncState == 'error') ...[
            const SizedBox(height: 12),
            _SyncResultBanner(
              state: _syncState,
              message: _syncMessage,
              synced: _syncSynced,
              errors: _syncErrors,
              onDismiss: () async {
                await api.shiftGridSyncReset(widget.gridId);
                setState(() => _syncState = 'idle');
              },
            ),
          ],
          const SizedBox(height: 12),
          if (_data.isEmpty || _dates.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد بيانات — اضغط "توليد الجدول"'),
              ),
            )
          else ...[
            _BulkBar(
              shifts: _shifts,
              locked: _locked,
              value: _bulkValue,
              onChanged: (v) => setState(() => _bulkValue = v),
              onAddEmployee: _locked ? null : _addEmployee,
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in _jobGroups) ...[
                        if (entry.key != 'بدون وظيفة')
                          Container(
                            width: 350.0 + _dates.length * 70,
                            color: const Color(0xFFF0C040),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              entry.key,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        Table(
                          defaultColumnWidth: const FixedColumnWidth(70),
                          columnWidths: const {
                            0: FixedColumnWidth(40),
                            1: FixedColumnWidth(90),
                            2: FixedColumnWidth(140),
                            3: FixedColumnWidth(56),
                          },
                          border: TableBorder.all(color: AppColors.border, width: 0.5),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFF343A40)),
                              children: [
                                _hdr('الرقم', width: 40, light: true),
                                _hdr('الوظيفة', width: 90, light: true),
                                _hdr('الاسم', width: 140, light: true),
                                _hdr('الكود', width: 56, light: true),
                                for (final d in _dates)
                                  _dateHdr(d, onBulk: _locked ? null : () => _bulkColumn(d['date'].toString())),
                              ],
                            ),
                            for (final emp in entry.value)
                              () {
                                rowNum++;
                                final n = rowNum;
                                return TableRow(
                                  children: [
                                    _cell(Text('$n', style: const TextStyle(fontSize: 11))),
                                    _cell(Text(emp['job_title']?.toString() ?? '', style: const TextStyle(fontSize: 10))),
                                    _cell(Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            emp['name']?.toString() ?? '',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!_locked)
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            icon: const Icon(Icons.play_arrow, size: 16),
                                            tooltip: 'تعيين جماعي للصف',
                                            onPressed: () => _bulkRow(emp['employee_id'] ?? emp['employeeId'] ?? ''),
                                          ),
                                      ],
                                    )),
                                    _cell(Text(emp['code']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
                                    for (final d in _dates)
                                      _buildCell(emp, d['date'].toString(), d['is_friday'] == true),
                                  ],
                                );
                              }(),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCell(Map<String, dynamic> emp, String date, bool isFriday) {
    final cells = emp['cells'] as Map?;
    final cell = cells?[date] is Map ? Map<String, dynamic>.from(cells![date] as Map) : null;
    final style = ShiftGridCellStyle.forCell(cell, isFriday: isFriday);
    final label = ShiftGridCellStyle.displayLabel(cell);

    return _cell(
      GestureDetector(
        onTap: cell == null ? null : () => _editCell(cell),
        onLongPress: cell == null ? null : () => _showPunches(cell),
        child: Container(
          width: 70,
          height: 32,
          alignment: Alignment.center,
          color: style.background,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: style.fontWeight,
              color: style.foreground,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

Widget _hdr(String text, {double? width, bool light = false}) {
  return _cell(
    Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: light ? 11 : 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

Widget _dateHdr(Map<String, dynamic> d, {VoidCallback? onBulk}) {
  final isFriday = d['is_friday'] == true;
  return _cell(
    Container(
      width: 70,
      padding: const EdgeInsets.all(4),
      color: isFriday ? const Color(0xFF4A5568) : null,
      child: Column(
        children: [
          Text(d['day_name']?.toString() ?? '', style: TextStyle(fontSize: 9, color: isFriday ? const Color(0xFFFFD700) : Colors.white, fontWeight: FontWeight.bold)),
          Text('${d['day_num']}-${d['month_name']}', style: TextStyle(fontSize: 10, color: isFriday ? const Color(0xFFFFD700) : Colors.white)),
          if (onBulk != null)
            InkWell(
              onTap: onBulk,
              child: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
            ),
        ],
      ),
    ),
  );
}

Widget _cell(Widget child) {
  return TableCell(
    verticalAlignment: TableCellVerticalAlignment.middle,
    child: child,
  );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.locked,
    required this.onSync,
    required this.onClose,
    required this.onReopen,
    required this.onConfirm,
    required this.onGenerate,
    required this.state,
    this.onCreatePayroll,
  });

  final bool locked;
  final VoidCallback onSync;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onConfirm;
  final VoidCallback onGenerate;
  final VoidCallback? onCreatePayroll;
  final String state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (state == 'setup')
          FilledButton.icon(onPressed: onGenerate, icon: const Icon(Icons.table_chart, size: 18), label: const Text('توليد الجدول')),
        if (state != 'setup') ...[
          FilledButton.icon(onPressed: onSync, icon: const Icon(Icons.sync, size: 18), label: const Text('مزامنة البصمات')),
          if (onCreatePayroll != null)
            FilledButton.tonalIcon(
              onPressed: onCreatePayroll,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('كشف رواتب'),
            ),
          if (!locked)
            OutlinedButton.icon(onPressed: onClose, icon: const Icon(Icons.lock, size: 18), label: const Text('إغلاق')),
          if (locked)
            OutlinedButton.icon(onPressed: onReopen, icon: const Icon(Icons.lock_open, size: 18), label: const Text('فتح')),
          if (!locked)
            FilledButton.tonalIcon(onPressed: onConfirm, icon: const Icon(Icons.check, size: 18), label: const Text('تأكيد التعيينات')),
        ],
      ],
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.shifts,
    required this.locked,
    required this.value,
    required this.onChanged,
    this.onAddEmployee,
  });

  final List<Map<String, dynamic>> shifts;
  final bool locked;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAddEmployee;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (onAddEmployee != null)
              OutlinedButton.icon(
                onPressed: onAddEmployee,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('إضافة موظف'),
              ),
            if (!locked) ...[
              const Text('تعيين جماعي:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: value,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  hint: const Text('-- اختر --'),
                  items: [
                    const DropdownMenuItem(value: 'off', child: Text('إجازة (off)')),
                    const DropdownMenuItem(value: 'present', child: Text('حاضر')),
                    const DropdownMenuItem(value: 'sick', child: Text('إجازة مرضية')),
                    const DropdownMenuItem(value: 'annual', child: Text('إجازة سنوية')),
                    const DropdownMenuItem(value: 'excluded', child: Text('عدم احتساب يوم')),
                    const DropdownMenuItem(value: 'bus_delay', child: Text('تأخير باص')),
                    for (final s in shifts)
                      DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Text('${s['code']} - ${s['name']}'),
                      ),
                    for (final s in shifts)
                      DropdownMenuItem(
                        value: 'bus_${s['id']}',
                        child: Text('${s['code']} 🚌'),
                      ),
                  ],
                  onChanged: onChanged,
                ),
              ),
              const Text('ثم ▶ على الصف أو ▼ على اليوم', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncOverlay extends StatelessWidget {
  const _SyncOverlay({
    required this.progress,
    required this.message,
    required this.synced,
    required this.total,
    required this.errors,
    required this.onCancel,
  });

  final int progress;
  final String message;
  final int synced;
  final int total;
  final int errors;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A237E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 8),
                Text('جاري مزامنة البصمات...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress / 100, minHeight: 20, color: const Color(0xFF42A5F5)),
            ),
            const SizedBox(height: 8),
            Text('$synced / $total بصمة  •  $progress%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (errors > 0) Text('$errors أخطاء', style: const TextStyle(color: Color(0xFFEF9A9A))),
            if (message.isNotEmpty) Text(message, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('إلغاء المزامنة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncResultBanner extends StatelessWidget {
  const _SyncResultBanner({
    required this.state,
    required this.message,
    required this.synced,
    required this.errors,
    required this.onDismiss,
  });

  final String state;
  final String message;
  final int synced;
  final int errors;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ok = state == 'done';
    return Card(
      color: ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
      child: ListTile(
        leading: Icon(ok ? Icons.check_circle : Icons.error, color: ok ? AppColors.success : AppColors.danger),
        title: Text(message.isNotEmpty ? message : (ok ? 'تمت المزامنة' : 'فشل المزامنة')),
        subtitle: Text('$synced بصمة${errors > 0 ? ' • $errors أخطاء' : ''}'),
        trailing: TextButton(onPressed: onDismiss, child: const Text('إغلاق')),
      ),
    );
  }
}

class _CellEditorSheet extends StatelessWidget {
  const _CellEditorSheet({required this.shifts, required this.current});
  final List<Map<String, dynamic>> shifts;
  final String current;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      builder: (_, scroll) => Material(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('تعديل الخلية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final opt in [
              ('off', 'إجازة (off)'),
              ('present', 'حاضر'),
              ('sick', 'إجازة مرضية'),
              ('annual', 'إجازة سنوية'),
              ('excluded', 'عدم احتساب يوم'),
              ('bus_delay', 'تأخير باص'),
            ])
              ListTile(
                title: Text(opt.$2),
                selected: current == opt.$1,
                onTap: () => Navigator.pop(context, opt.$1),
              ),
            for (final s in shifts)
              ListTile(
                title: Text('${s['code']} - ${s['name']}'),
                selected: current == s['id'].toString(),
                onTap: () => Navigator.pop(context, s['id'].toString()),
              ),
            for (final s in shifts)
              ListTile(
                title: Text('${s['code']} 🚌'),
                selected: current == 'bus_${s['id']}',
                onTap: () => Navigator.pop(context, 'bus_${s['id']}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PunchesDialog extends StatelessWidget {
  const _PunchesDialog({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final items = (result['items'] as List?)?.whereType<Map>().toList() ?? [];
    return AlertDialog(
      title: Text('بصمات ${result['employeeName']} — ${result['date']}'),
      content: SizedBox(
        width: 400,
        child: items.isEmpty
            ? const Text('لا توجد بصمات لهذا اليوم')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  return ListTile(
                    dense: true,
                    title: Text(p['punchTime']?.toString() ?? ''),
                    subtitle: Text('${p['terminalAlias'] ?? ''}  state=${p['punchState'] ?? ''}'),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
      ],
    );
  }
}
