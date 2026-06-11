import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import 'widgets/sync_progress_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic> _config = {};
  Map<String, dynamic> _syncStatus = {};
  bool _loading = true;
  bool _busy = false;
  final _serverIp = TextEditingController();
  final _serverPort = TextEditingController(text: '8090');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _odooUrl = TextEditingController();
  final _odooDb = TextEditingController();
  final _odooLogin = TextEditingController();
  final _odooPassword = TextEditingController();
  Map<String, dynamic> _odooStatus = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serverIp.dispose();
    _serverPort.dispose();
    _username.dispose();
    _password.dispose();
    _odooUrl.dispose();
    _odooDb.dispose();
    _odooLogin.dispose();
    _odooPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final config = await api.configGet();
      final syncStatus = await api.syncStatus();
      final odooStatus = await api.odooConfigGet();
      final odooConfig = (odooStatus['config'] as Map?)?.cast<String, dynamic>() ?? {};
      if (mounted) {
        _serverIp.text = config['serverIp']?.toString() ?? '';
        _serverPort.text = '${config['serverPort'] ?? 80}';
        _username.text = config['username']?.toString() ?? '';
        _odooUrl.text = odooConfig['baseUrl']?.toString() ?? '';
        _odooDb.text = odooConfig['database']?.toString() ?? '';
        _odooLogin.text = odooConfig['login']?.toString() ?? '';
        setState(() {
          _config = config;
          _syncStatus = syncStatus;
          _odooStatus = odooStatus;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _saveServer() async {
    setState(() => _busy = true);
    try {
      final config = await api.configUpdate({
        'serverIp': _serverIp.text.trim(),
        'serverPort': int.tryParse(_serverPort.text.trim()) ?? 80,
        'username': _username.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
      });
      if (mounted) setState(() { _config = config; _busy = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _busy = true);
    try {
      final config = await api.configUpdate({key: value});
      if (mounted) setState(() { _config = config; _busy = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  bool _isSyncPath(String path) => path.contains('/sync');

  Future<void> _pollSyncJob(ValueNotifier<SyncDialogState> notifier, {String? jobId}) async {
    for (var i = 0; i < 180; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final status = await api.syncStatus();
        final jobs = (status['recentJobs'] as List?) ?? [];
        final counts = (status['counts'] as Map?)?.cast<String, dynamic>() ?? {};
        Map<String, dynamic>? job;
        for (final j in jobs) {
          if (j is! Map) continue;
          final m = Map<String, dynamic>.from(j);
          if (jobId == null || m['id']?.toString() == jobId) {
            job = m;
            break;
          }
        }
        final jobStatus = job?['status']?.toString() ?? 'running';
        notifier.value = notifier.value.copyWith(
          message: job?['message']?.toString() ?? 'جاري المزامنة...',
          progress: (job?['progress'] as num?)?.toInt() ?? notifier.value.progress,
          employees: (counts['employees'] as num?)?.toInt(),
          departments: (counts['departments'] as num?)?.toInt(),
          devices: (counts['devices'] as num?)?.toInt(),
          transactions: (counts['transactions'] as num?)?.toInt(),
          status: jobStatus,
        );
        if (jobStatus == 'done' || jobStatus == 'failed' || jobStatus == 'cancelled') {
          notifier.value = notifier.value.copyWith(
            done: jobStatus == 'done',
            failed: jobStatus != 'done',
            title: jobStatus == 'done' ? 'تمت المزامنة' : 'فشلت المزامنة',
            message: job?['message']?.toString() ?? jobStatus,
            progress: 100,
          );
          return;
        }
      } catch (_) {}
    }
    notifier.value = notifier.value.copyWith(
      failed: true,
      title: 'انتهت المهلة',
      message: 'المزامنة لا تزال قيد التشغيل على السيرفر',
    );
  }

  Future<void> _saveOdoo() async {
    setState(() => _busy = true);
    try {
      final status = await api.odooConfigUpdate({
        'baseUrl': _odooUrl.text.trim(),
        'database': _odooDb.text.trim(),
        'login': _odooLogin.text.trim(),
        if (_odooPassword.text.isNotEmpty) 'password': _odooPassword.text,
      });
      if (mounted) {
        setState(() {
          _odooStatus = status;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات Odoo')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _testOdoo() async {
    setState(() => _busy = true);
    try {
      final status = await api.odooTestConnection();
      if (mounted) {
        setState(() {
          _odooStatus = status;
          _busy = false;
        });
        final ok = (status['config'] as Map?)?['isConnected'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'متصل بـ Odoo' : (status['message']?.toString() ?? 'فشل الاتصال'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _pushOdoo() async {
    final notifier = ValueNotifier(const SyncDialogState(
      title: 'رفع إلى Odoo',
      message: 'جاري الرفع…',
    ));
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SyncProgressDialog(stateListenable: notifier),
      );
    }

    setState(() => _busy = true);
    try {
      final result = await api.odooPushAll(
        onProgress: (msg) {
          notifier.value = notifier.value.copyWith(message: msg);
        },
      );
      notifier.value = notifier.value.copyWith(
        done: true,
        title: 'تم الرفع',
        message: result['message']?.toString() ?? 'اكتمل',
        progress: 100,
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        setState(() => _busy = false);
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'تم الرفع إلى Odoo')),
        );
      }
    } catch (e) {
      notifier.value = notifier.value.copyWith(
        failed: true,
        title: 'فشل الرفع',
        message: e.toString(),
      );
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _syncPunchesFull() async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 90));
    setState(() => _busy = true);
    try {
      final result = await api.syncTransactions(
        dateFrom: from.toIso8601String().slice(0, 10),
        dateTo: now.toIso8601String().slice(0, 10),
      );
      if (mounted) {
        setState(() => _busy = false);
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'تمت مزامنة البصمات')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _run(String path, String label) async {
    final isSync = _isSyncPath(path);
    final notifier = ValueNotifier(const SyncDialogState());
    if (isSync && mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SyncProgressDialog(stateListenable: notifier),
      );
    }

    setState(() => _busy = true);
    try {
      final result = await api.configAction(path);
      if (!mounted) return;

      if (result['config'] is Map) {
        _config = Map<String, dynamic>.from(result['config'] as Map);
      }

      if (isSync && result['queued'] == true) {
        await _pollSyncJob(notifier, jobId: result['jobId']?.toString());
        await Future.delayed(const Duration(milliseconds: 600));
      } else if (isSync) {
        notifier.value = notifier.value.copyWith(
          done: true,
          title: 'تمت المزامنة',
          message: result['message']?.toString() ?? 'Done: $label',
          progress: 100,
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (isSync && mounted) Navigator.of(context, rootNavigator: true).pop();

      setState(() => _busy = false);
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['queued'] == true
                  ? (notifier.value.message)
                  : (result['message']?.toString() ?? 'Done: $label'),
            ),
          ),
        );
      }
    } catch (e) {
      if (isSync) {
        notifier.value = notifier.value.copyWith(
          failed: true,
          title: 'فشلت المزامنة',
          message: e.toString(),
        );
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final connected = _config['isConnected'] == true;
    final credentialsConfigured = _config['credentialsConfigured'] == true;
    final counts = (_syncStatus['counts'] as Map?)?.cast<String, dynamic>() ?? {};
    final recentJobs = (_syncStatus['recentJobs'] as List?) ?? [];
    final odooConfig = (_odooStatus['config'] as Map?)?.cast<String, dynamic>() ?? {};
    final odooTotals = (_odooStatus['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final odooSynced = (_odooStatus['synced'] as Map?)?.cast<String, dynamic>() ?? {};
    final odooConnected = odooConfig['isConnected'] == true;
    final odooCredentialsConfigured = odooConfig['credentialsConfigured'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'إعدادات البصمة',
            subtitle: 'BioTime Configuration — ${_config['name'] ?? ''}',
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          ),
          const SizedBox(height: 12),
          SellixCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(connected ? Icons.cloud_done : Icons.cloud_off,
                        color: connected ? AppColors.success : AppColors.danger),
                    const SizedBox(width: 8),
                    Text(connected ? 'متصل بـ BioTime' : 'غير متصل',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_config['connectionMessage']?.toString() ?? '',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('BioTime Server', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SellixCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BioTime API credentials (for sync only — not app login)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Node server connects directly to ZKTeco BioTime. App users are created in Admin Dashboard.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(controller: _serverIp, decoration: const InputDecoration(labelText: 'Server IP')),
                TextField(controller: _serverPort, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number),
                TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username')),
                TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                const SizedBox(height: 8),
                FilledButton(onPressed: _busy ? null : _saveServer, child: const Text('Save server settings')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Odoo — رفع البيانات', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'ليس مزامنة من Odoo. يُرفَع من التطبيق إلى Odoo يدوياً (سلف، استقطاعات، رواتب).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          SellixCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(odooConnected ? Icons.cloud_done : Icons.cloud_off,
                        color: odooConnected ? AppColors.success : AppColors.danger),
                    const SizedBox(width: 8),
                    Text(odooConnected ? 'متصل بـ Odoo' : 'غير متصل بـ Odoo',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                if (odooConfig['lastPushAt'] != null)
                  Text('آخر رفع: ${odooConfig['lastPushAt']}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                TextField(controller: _odooUrl, decoration: const InputDecoration(labelText: 'Odoo URL (https://…)'),
                    keyboardType: TextInputType.url),
                TextField(controller: _odooDb, decoration: const InputDecoration(labelText: 'Database')),
                TextField(controller: _odooLogin, decoration: const InputDecoration(labelText: 'Login')),
                TextField(controller: _odooPassword, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                const SizedBox(height: 8),
                FilledButton(onPressed: _busy ? null : _saveOdoo, child: const Text('حفظ إعدادات Odoo')),
                if (!odooCredentialsConfigured)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'أكمل URL و Database و Login و Password ثم احفظ — بعدها يُفعَّل زر «رفع لـ Odoo».',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'محلي: موظفون ${odooTotals['employees'] ?? 0}، استقطاعات ${odooTotals['deductions'] ?? 0}، '
                  'سلف ${(odooTotals['advancesShort'] as num? ?? 0) + (odooTotals['advancesLong'] as num? ?? 0)}، '
                  'رواتب ${odooTotals['payrolls'] ?? 0}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  'مُرفوع سابقاً: استقطاعات ${odooSynced['deduction'] ?? 0}، رواتب ${odooSynced['payroll'] ?? 0}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: (_busy || !odooCredentialsConfigured) ? null : _testOdoo,
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('اختبار Odoo'),
                    ),
                    FilledButton.icon(
                      onPressed: (_busy || !odooCredentialsConfigured) ? null : _pushOdoo,
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('رفع لـ Odoo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('ما يُزامَن من BioTime', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const SellixCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('من سيرفر BioTime (زر Sync):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(height: 6),
                Text('• الموظفين والأقسام\n• الأجهزة\n• البصمات (punches)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
                SizedBox(height: 10),
                Text('محلي في التطبيق (لا يُستورد من BioTime):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(height: 6),
                Text('• الشيفتات والجدول\n• السلف والاستقطاعات\n• كشوف الرواتب\n• طلبات الإجازة والسلف\n• سجلات الحضور (تُولَّد من البصمات)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SellixCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('خطوات بعد المزامنة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(height: 6),
                Text(
                  '1) Sync all — يجلب الموظفين والبصمات الجديدة\n'
                  '2) الشيفتات — أنشئ الشيفتات وجدول الشيفتات\n'
                  '3) الحضور — اضغط «توليد الحضور»\n'
                  '4) الرواتب — أنشئ كشفاً ثم «حساب»\n'
                  '5) السلف/الاستقطاعات — تُسجَّل يدوياً في التطبيق',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('حالة المزامنة (قاعدة البيانات)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SellixCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('موظفون: ${counts['employees'] ?? _config['employeeCount'] ?? 0}  •  بصمات: ${counts['transactions'] ?? _config['transactionCount'] ?? 0}'),
                Text('أقسام: ${counts['departments'] ?? _config['totalDepartmentsSynced'] ?? 0}  •  أجهزة: ${counts['devices'] ?? _config['totalDevicesSynced'] ?? 0}'),
                const SizedBox(height: 4),
                const Text(
                  'رقم «آخر مهمة» قد يختلف عن الإجمالي — المهمة تعرض ما جُلب من BioTime في هذه الجولة فقط.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                ),
                if (_config['lastTransactionSync'] != null && _config['lastTransactionSync'] != false)
                  Text('آخر مزامنة بصمات: ${_config['lastTransactionSync']}', style: const TextStyle(fontSize: 12)),
                if (recentJobs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('آخر مهمة: ${recentJobs.first['message']} (${recentJobs.first['status']})',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Auto sync (cron every 12h)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SellixCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push to BioTime on employee edit'),
                  subtitle: const Text('When HR updates employee locally, push to BioTime server'),
                  value: _config['autoPushToBiotime'] == true,
                  onChanged: _busy ? null : (v) => _toggle('autoPushToBiotime', v),
                ),
                SwitchListTile(
                  title: const Text('Sync employees'),
                  value: _config['autoSyncEmployees'] == true,
                  onChanged: _busy ? null : (v) => _toggle('autoSyncEmployees', v),
                ),
                SwitchListTile(
                  title: const Text('Sync departments'),
                  value: _config['autoSyncDepartments'] == true,
                  onChanged: _busy ? null : (v) => _toggle('autoSyncDepartments', v),
                ),
                SwitchListTile(
                  title: const Text('Sync punches'),
                  value: _config['autoSyncTransactions'] == true,
                  onChanged: _busy ? null : (v) => _toggle('autoSyncTransactions', v),
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
                onPressed: (_busy || !credentialsConfigured) ? null : () => _run('/api/biotime/config/test-connection', 'test'),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Test connection'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run('/api/biotime/config/sync-all', 'sync all'),
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sync all'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run('/api/biotime/config/sync-transactions', 'punches'),
                icon: const Icon(Icons.fingerprint, size: 18),
                label: const Text('مزامنة بصمات جديدة'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _syncPunchesFull,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('بصمات 90 يوم'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on String {
  String slice(int start, int end) => substring(start, end.clamp(0, length));
}
