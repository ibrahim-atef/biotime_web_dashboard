import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
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
    _tabs = TabController(length: 3, vsync: this);
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

  Future<void> _createLeave() async {
    final now = DateTime.now();
    try {
      await api.leaveRequestCreate(
        leaveType: 'annual',
        dateFrom: now.toIso8601String().slice(0, 10),
        dateTo: now.add(const Duration(days: 1)).toIso8601String().slice(0, 10),
        reason: 'Leave request',
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final leave = (_data['leave'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final loan = (_data['loan'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final shift = (_data['shiftChange'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: PageHeader(
            title: 'طلباتي',
            subtitle: 'Leave, loan & shift change',
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              IconButton(onPressed: _createLeave, icon: const Icon(Icons.add)),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          tabs: [
            Tab(text: 'Leave (${leave.length})'),
            Tab(text: 'Loan (${loan.length})'),
            Tab(text: 'Shift (${shift.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _list(leave, (r) => '${r['leaveType']} • ${r['dateFrom']} → ${r['dateTo']} • ${r['state']}'),
              _list(loan, (r) => '${r['amount']} • ${r['state']}'),
              _list(shift, (r) => '${r['dateFrom']} → ${r['dateTo']} • ${r['state']}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) subtitle) {
    if (items.isEmpty) {
      return const Center(child: Text('No requests yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => SellixCard(
        child: ListTile(
          title: Text(subtitle(items[i])),
          subtitle: Text(items[i]['reason']?.toString() ?? ''),
        ),
      ),
    );
  }
}

extension on String {
  String slice(int start, int end) => substring(start, end.clamp(0, length));
}
