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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final config = await api.configGet();
      final syncStatus = await api.syncStatus();
      if (mounted) {
        _serverIp.text = config['serverIp']?.toString() ?? '';
        _serverPort.text = '${config['serverPort'] ?? 80}';
        _username.text = config['username']?.toString() ?? '';
        setState(() {
          _config = config;
          _syncStatus = syncStatus;
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
          const SizedBox(height: 16),
          const Text('Sync status (local DB)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SellixCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Employees: ${counts['employees'] ?? _config['employeeCount'] ?? 0}  •  Punches: ${counts['transactions'] ?? _config['transactionCount'] ?? 0}'),
                Text('Departments: ${counts['departments'] ?? _config['totalDepartmentsSynced'] ?? 0}  •  Devices: ${counts['devices'] ?? _config['totalDevicesSynced'] ?? 0}'),
                if (_config['lastTransactionSync'] != null && _config['lastTransactionSync'] != false)
                  Text('Last punch sync: ${_config['lastTransactionSync']}', style: const TextStyle(fontSize: 12)),
                if (recentJobs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Last job: ${recentJobs.first['message']} (${recentJobs.first['status']})',
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
                label: const Text('Sync punches'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
