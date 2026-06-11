import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/file_download.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';

class PayrollDetailPage extends StatefulWidget {
  const PayrollDetailPage({super.key, required this.payrollId});
  final String payrollId;

  @override
  State<PayrollDetailPage> createState() => _PayrollDetailPageState();
}

class _PayrollDetailPageState extends State<PayrollDetailPage> {
  Map<String, dynamic> _payroll = {};
  bool _loading = true;
  bool _busy = false;

  List<Map<String, dynamic>> get _lines {
    final lines = _payroll['lines'];
    if (lines is List) return lines.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await api.payrollGet(widget.payrollId);
      if (mounted) setState(() { _payroll = p; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _run(Future<dynamic> Function() fn, String success) async {
    setState(() => _busy = true);
    try {
      await fn();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد وإرسال نهائي'),
        content: const Text('سيتم تأكيد كشف الرواتب محلياً في النظام فقط.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تنفيذ')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await api.payrollFinalize(widget.payrollId, actions: ['confirm']);
    }, 'تم التنفيذ');
  }

  Future<void> _downloadExport(Future<Map<String, dynamic>> Function() fetch, String fallbackName) async {
    try {
      final r = await fetch();
      final filename = r['filename']?.toString() ?? fallbackName;
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final mime = r['mimeType']?.toString() ?? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      if (base64.isEmpty) throw Exception('ملف فارغ من الخادم');
      downloadBase64File(base64, filename, mime);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تنزيل $filename')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _exportFawry() => _downloadExport(() => api.payrollExportFawry(widget.payrollId), 'fawry.xlsx');

  Future<void> _exportPayroll() => _downloadExport(() => api.payrollExportXlsx(widget.payrollId), 'payroll.xlsx');

  Future<void> _exportCashFawry() => _downloadExport(() => api.payrollExportCashFawry(widget.payrollId), 'cash_fawry.xlsx');

  String _stateAr(String s) {
    switch (s) {
      case 'draft': return 'مسودة';
      case 'calculated': return 'محسوب';
      case 'confirmed': return 'مؤكد';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final state = _payroll['state']?.toString() ?? '';
    final canEdit = state != 'confirmed';
    final canFinalize = state == 'draft' || state == 'calculated';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: _payroll['name']?.toString() ?? 'كشف رواتب',
            subtitle: '${_payroll['dateFrom']} → ${_payroll['dateTo']}  •  ${_payroll['employeeCount']} موظف  •  ${_stateAr(state)}',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              IconButton(onPressed: () => context.go(AppRoutes.hrPayroll), icon: const Icon(Icons.arrow_back)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canEdit && (state == 'draft' || state == 'calculated'))
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(() => api.payrollCalculate(widget.payrollId), 'تم الحساب'),
                  icon: const Icon(Icons.calculate, size: 18),
                  label: const Text('حساب'),
                ),
              if (state == 'calculated')
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(() => api.payrollLinkDeductions(widget.payrollId), 'تم ربط الخصومات'),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('ربط خصومات وسلف'),
                ),
              if (state == 'calculated')
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _run(() => api.payrollConfirm(widget.payrollId), 'تم التأكيد'),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('تأكيد'),
                ),
              if (canFinalize)
                FilledButton.icon(
                  onPressed: _busy ? null : _finalize,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('إرسال نهائي'),
                ),
              OutlinedButton.icon(
                onPressed: _exportPayroll,
                icon: const Icon(Icons.table_chart, size: 18),
                label: const Text('كشف Excel'),
              ),
              OutlinedButton.icon(
                onPressed: _exportFawry,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Fawry'),
              ),
              OutlinedButton.icon(
                onPressed: _exportCashFawry,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('نقدي'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _totalCard('إجمالي المستحقات', _payroll['totalEarnings']),
              const SizedBox(width: 8),
              _totalCard('إجمالي الخصومات', _payroll['totalDeductions']),
              const SizedBox(width: 8),
              _totalCard('صافي الرواتب', _payroll['totalNet'], highlight: true),
            ],
          ),
          const SizedBox(height: 16),
          SellixCard(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('كود')),
                  DataColumn(label: Text('الموظف')),
                  DataColumn(label: Text('أساسي')),
                  DataColumn(label: Text('أيام')),
                  DataColumn(label: Text('إضافي')),
                  DataColumn(label: Text('مستحقات')),
                  DataColumn(label: Text('خصومات')),
                  DataColumn(label: Text('صافي')),
                ],
                rows: [
                  for (final line in _lines)
                    DataRow(cells: [
                      DataCell(Text(line['employeeCode']?.toString() ?? '')),
                      DataCell(Text(line['employeeName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text('${line['basicSalary'] ?? 0}')),
                      DataCell(Text('${line['workingDays'] ?? 0}')),
                      DataCell(Text('${line['overtimeHours'] ?? 0}')),
                      DataCell(Text('${line['totalEarnings'] ?? 0}')),
                      DataCell(Text('${line['totalDeductions'] ?? 0}')),
                      DataCell(Text('${line['netSalary'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                    ], onSelectChanged: canEdit ? (_) => _editLine(line) : null),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalCard(String title, dynamic value, {bool highlight = false}) {
    return Expanded(
      child: Card(
        color: highlight ? AppColors.primaryLight : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: highlight ? AppColors.primary : null)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editLine(Map<String, dynamic> line) async {
    final fields = <String, TextEditingController>{
      'basicSalary': TextEditingController(text: '${line['basicSalary'] ?? 0}'),
      'workingDays': TextEditingController(text: '${line['workingDays'] ?? 0}'),
      'overtimeHours': TextEditingController(text: '${line['overtimeHours'] ?? 0}'),
      'manualDebit': TextEditingController(text: '${line['manualDebit'] ?? 0}'),
      'fines': TextEditingController(text: '${line['fines'] ?? 0}'),
      'deductionChecks': TextEditingController(text: '${line['deductionChecks'] ?? 0}'),
      'groupedChecks': TextEditingController(text: '${line['groupedChecks'] ?? 0}'),
      'healthCertificatesDeduction': TextEditingController(text: '${line['healthCertificatesDeduction'] ?? 0}'),
      'fractionDeduction': TextEditingController(text: '${line['fractionDeduction'] ?? 0}'),
      'documentsDeduction': TextEditingController(text: '${line['documentsDeduction'] ?? 0}'),
      'socialInsurance': TextEditingController(text: '${line['socialInsurance'] ?? 0}'),
      'medicalInsurance': TextEditingController(text: '${line['medicalInsurance'] ?? 0}'),
      'adminDeduction': TextEditingController(text: '${line['adminDeduction'] ?? 0}'),
    };

    final labels = <String, String>{
      'basicSalary': 'الراتب الأساسي',
      'workingDays': 'أيام العمل',
      'overtimeHours': 'ساعات إضافي',
      'manualDebit': 'مانيول ديبت',
      'fines': 'غرامات',
      'deductionChecks': 'شيكات شخصية',
      'groupedChecks': 'شيكات مجمعة',
      'healthCertificatesDeduction': 'شهادات صحية',
      'fractionDeduction': 'كسر',
      'documentsDeduction': 'خصم أوراق',
      'socialInsurance': 'تأمينات اجتماعية',
      'medicalInsurance': 'تأمين طبي',
      'adminDeduction': 'خصم إداري',
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(line['employeeName']?.toString() ?? ''),
        content: SizedBox(
          width: 380,
          height: 420,
          child: ListView(
            children: [
              for (final entry in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(labelText: labels[entry.key], isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );

    if (ok != true) {
      for (final c in fields.values) {
        c.dispose();
      }
      return;
    }

    try {
      final payload = <String, dynamic>{};
      for (final entry in fields.entries) {
        payload[entry.key] = double.tryParse(entry.value.text) ?? 0;
      }
      for (final c in fields.values) {
        c.dispose();
      }
      await api.payrollLineUpdate(line['id'], payload);
      _load();
    } catch (e) {
      for (final c in fields.values) {
        c.dispose();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
