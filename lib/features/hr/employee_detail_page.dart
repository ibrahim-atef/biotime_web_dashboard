import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/entity_id.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';

class EmployeeDetailPage extends StatefulWidget {
  const EmployeeDetailPage({super.key, required this.employeeId});
  final String employeeId;

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  Map<String, dynamic> _emp = {};
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  bool _saving = false;

  final _name = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  String? _departmentId;
  String? _deviceId;
  String _gender = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  void _fillForm(Map<String, dynamic> emp) {
    _name.text = emp['name']?.toString() ?? '';
    _code.text = emp['identificationId']?.toString() ?? emp['code']?.toString() ?? '';
    _email.text = emp['workEmail']?.toString() ?? '';
    _phone.text = emp['workPhone']?.toString() ?? emp['mobilePhone']?.toString() ?? '';
    _location.text = emp['location']?.toString() ?? '';
    _departmentId = EntityId.parse(emp['departmentId']);
    _deviceId = EntityId.parse(emp['biotimeDeviceId']);
    _gender = emp['gender']?.toString() ?? '';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        api.employeeGet(widget.employeeId),
        api.departmentsList(),
        api.devicesList(),
      ]);
      if (!mounted) return;
      final emp = results[0] as Map<String, dynamic>;
      setState(() {
        _emp = emp;
        _departments = results[1] as List<Map<String, dynamic>>;
        _devices = results[2] as List<Map<String, dynamic>>;
        _fillForm(emp);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await api.employeeUpdate(widget.employeeId, {
        'name': _name.text.trim(),
        'identificationId': _code.text.trim(),
        'departmentId': _departmentId,
        'biotimeDeviceId': _deviceId,
        'workEmail': _email.text.trim(),
        'workPhone': _phone.text.trim(),
        if (_location.text.isNotEmpty) 'location': _location.text.trim(),
        if (_gender.isNotEmpty) 'gender': _gender,
      });
      if (mounted) {
        setState(() { _emp = updated; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ — القسم والبيانات تُحدَّث في Odoo وBioTime')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _action(Future<void> Function() fn, String ok) async {
    try {
      await fn();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Map<String, dynamic>? get _mapping {
    final m = _emp['mapping'];
    return m is Map ? Map<String, dynamic>.from(m) : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final mapping = _mapping;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: _emp['displayName']?.toString() ?? _emp['name']?.toString() ?? 'موظف',
            subtitle: 'كود: ${_emp['code'] ?? ''}${_emp['department'] != null && (_emp['department'] as String).isNotEmpty ? '  •  ${_emp['department']}' : ''}',
            actions: [
              IconButton(onPressed: () => context.go(AppRoutes.hrEmployees), icon: const Icon(Icons.arrow_back)),
            ],
          ),
          if (mapping != null) ...[
            const SizedBox(height: 8),
            SellixCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BioTime: ${mapping['biotimeEmpCode'] ?? ''} (id: ${mapping['biotimeEmpId'] ?? ''})',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    mapping['syncMessage']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: mapping['syncStatus'] == 'error' ? AppColors.danger : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SellixCard(
            child: Column(
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم')),
                const SizedBox(height: 12),
                TextField(controller: _code, decoration: const InputDecoration(labelText: 'كود البصمة / identification_id')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _departmentId,
                  decoration: const InputDecoration(labelText: 'القسم (يُحدَّث في BioTime)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('بدون قسم')),
                    for (final d in _departments)
                      DropdownMenuItem(value: EntityId.parse(d['id']), child: Text(d['name']?.toString() ?? '')),
                  ],
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _deviceId,
                  decoration: const InputDecoration(labelText: 'جهاز البصمة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('بدون جهاز')),
                    for (final d in _devices)
                      DropdownMenuItem(value: EntityId.parse(d['id']), child: Text(d['name']?.toString() ?? '')),
                  ],
                  onChanged: (v) => setState(() => _deviceId = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'البريد')),
                const SizedBox(height: 12),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'الهاتف')),
                const SizedBox(height: 12),
                TextField(controller: _location, decoration: const InputDecoration(labelText: 'الموقع (Location)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _gender.isEmpty ? null : _gender,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? ''),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 18),
                label: const Text('حفظ ومزامنة BioTime'),
              ),
              OutlinedButton.icon(
                onPressed: () => _action(() => api.employeePushBiotime(widget.employeeId), 'تم الدفع إلى BioTime'),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('دفع يدوي'),
              ),
              OutlinedButton.icon(
                onPressed: () => _action(() => api.employeeSyncDevice(widget.employeeId), 'تم جلب الجهاز'),
                icon: const Icon(Icons.fingerprint, size: 18),
                label: const Text('جلب جهاز من البصمات'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
