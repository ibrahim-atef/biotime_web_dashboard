import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/employee_search_field.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';

class AdvancesPage extends StatefulWidget {
  const AdvancesPage({super.key});

  @override
  State<AdvancesPage> createState() => _AdvancesPageState();
}

class _AdvancesPageState extends State<AdvancesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _short = [];
  List<Map<String, dynamic>> _long = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
      final s = await api.advancesShortList();
      final l = await api.advancesLongList();
      if (mounted) setState(() { _short = s; _long = l; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewAdvance() async {
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نوع السلفة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('سلفة قصيرة'),
              onTap: () => Navigator.pop(ctx, 'short'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('سلفة طويلة (أقساط)'),
              onTap: () => Navigator.pop(ctx, 'long'),
            ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => type == 'short' ? const _ShortAdvanceForm() : const _LongAdvanceForm(),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(
            title: 'السلف',
            subtitle: 'سلف قصيرة وطويلة الأجل',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: _openNewAdvance,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('سلفة جديدة'),
              ),
            ],
          ),
          const HrLocalDataBanner(
            title: 'السلف — بيانات محلية',
            hint: 'BioTime يزامن الموظفين والبصمات فقط. السلف تُسجَّل هنا بزر «سلفة جديدة» بعد مزامنة الموظفين.',
          ),
          const SizedBox(height: 12),
          TabBar(controller: _tabs, tabs: const [Tab(text: 'قصيرة'), Tab(text: 'طويلة')]),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _AdvanceList(items: _short, isLong: false, onRefresh: _load),
                  _AdvanceList(items: _long, isLong: true, onRefresh: _load),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AdvanceList extends StatelessWidget {
  const _AdvanceList({required this.items, required this.isLong, required this.onRefresh});
  final List<Map<String, dynamic>> items;
  final bool isLong;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return HrEmptyListCard(
        message: isLong
            ? 'لا توجد سلف طويلة الأجل.\nأنشئ سلفة من «سلفة جديدة» واختر موظفاً مُزامَناً من BioTime.'
            : 'لا توجد سلف قصيرة.\nأنشئ سلفة من «سلفة جديدة» واختر موظفاً مُزامَناً من BioTime.',
      );
    }

    return SellixCard(
      padding: EdgeInsets.zero,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          final a = items[i];
          final title = isLong
              ? '${a['employeeName']} — ${a['totalAmount']} (${a['installments']} قسط)'
              : '${a['employeeName']} — ${a['amount']}';
          return ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(isLong ? '${a['startDate']}  •  متبقي: ${a['remainingAmount']}' : '${a['date']}  •  ${a['name']}'),
            trailing: StatusTag(label: a['state']?.toString() ?? '', type: StatusTagType.info),
            onLongPress: !isLong && a['state'] == 'pending' ? () async {
              await api.advanceShortCancel(a['id']);
              onRefresh();
            } : null,
          );
        },
      ),
    );
  }
}

class _ShortAdvanceForm extends StatefulWidget {
  const _ShortAdvanceForm();

  @override
  State<_ShortAdvanceForm> createState() => _ShortAdvanceFormState();
}

class _ShortAdvanceFormState extends State<_ShortAdvanceForm> {
  String? _employeeId;
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
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
      await api.advanceShortCreate({'employeeId': _employeeId, 'amount': double.tryParse(_amount.text) ?? 0});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('سلفة قصيرة'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          EmployeeSearchField(onSelected: (id, _) => setState(() => _employeeId = id)),
          TextField(controller: _amount, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('حفظ')),
      ],
    );
  }
}

class _LongAdvanceForm extends StatefulWidget {
  const _LongAdvanceForm();

  @override
  State<_LongAdvanceForm> createState() => _LongAdvanceFormState();
}

class _LongAdvanceFormState extends State<_LongAdvanceForm> {
  String? _employeeId;
  final _total = TextEditingController();
  final _installments = TextEditingController(text: '6');
  bool _saving = false;

  @override
  void dispose() {
    _total.dispose();
    _installments.dispose();
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
      final advance = await api.advanceLongCreate({
        'employeeId': _employeeId,
        'totalAmount': double.tryParse(_total.text) ?? 0,
        'installments': int.tryParse(_installments.text) ?? 1,
      });
      final id = advance['id'];
      if (id != null) await api.advanceLongConfirm(id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('سلفة طويلة (أقساط)'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          EmployeeSearchField(onSelected: (id, _) => setState(() => _employeeId = id)),
          TextField(controller: _total, decoration: const InputDecoration(labelText: 'إجمالي السلفة'), keyboardType: TextInputType.number),
          TextField(controller: _installments, decoration: const InputDecoration(labelText: 'عدد الأقساط'), keyboardType: TextInputType.number),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('حفظ وتفعيل')),
      ],
    );
  }
}
