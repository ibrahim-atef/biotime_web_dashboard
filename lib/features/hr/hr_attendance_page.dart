import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';

class HrAttendancePage extends StatefulWidget {
  const HrAttendancePage({super.key});

  @override
  State<HrAttendancePage> createState() => _HrAttendancePageState();
}

class _HrAttendancePageState extends State<HrAttendancePage> {
  static const _pageSize = 50;

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _records = [];
  Timer? _searchDebounce;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _total = 0;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  String get _dateFrom =>
      DateTime(_month.year, _month.month, 1).toIso8601String().slice(0, 10);

  String get _dateTo =>
      DateTime(_month.year, _month.month + 1, 0).toIso8601String().slice(0, 10);

  String get _monthLabel => DateFormat.yMMMM('ar').format(_month);

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || _loading) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _offset = 0;
        _records.clear();
      });
    }
    try {
      final page = await api.attendanceList(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        search: _searchCtrl.text.trim(),
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _records
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _offset = page.items.length;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_offset >= _total || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await api.attendanceList(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        search: _searchCtrl.text.trim(),
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _records.addAll(page.items);
        _offset += page.items.length;
        _total = page.total;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String? _generateMessage;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _generateMessage = 'جاري توليد الحضور… قد يستغرق دقائق';
    });
    try {
      final result = await api.attendanceGenerate(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        onProgress: (msg) {
          if (mounted) setState(() => _generateMessage = msg);
        },
      );
      await _load(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? 'تم توليد سجلات الحضور')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _generateMessage = null);
    }
  }

  String _displayName(Map<String, dynamic> r) {
    final name = r['employeeName']?.toString().trim() ??
        r['employee']?['displayName']?.toString().trim() ??
        r['employee']?['name']?.toString().trim() ??
        '';
    final code = r['employeeCode']?.toString().trim() ??
        r['employee']?['code']?.toString().trim() ??
        '';
    if (name.isNotEmpty && name != code) return name;
    if (code.isNotEmpty) return 'موظف $code';
    return 'موظف غير معروف';
  }

  String _subtitle(Map<String, dynamic> r) {
    final code = r['employeeCode']?.toString() ?? r['employee']?['code']?.toString() ?? '';
    final dept = r['departmentName']?.toString() ?? '';
    final status = _statusAr(r['status']?.toString() ?? '');
    final hours = r['workedHours'] ?? 0;
    final date = r['date']?.toString() ?? '';
    final parts = <String>[
      if (code.isNotEmpty) code,
      if (dept.isNotEmpty) dept,
      status,
      '${hours}h',
      date,
    ];
    return parts.join(' • ');
  }

  String _statusAr(String s) {
    switch (s) {
      case 'present': return 'حاضر';
      case 'absent': return 'غائب';
      case 'late': return 'متأخر';
      case 'leave': return 'إجازة';
      case 'off': return 'راحة';
      case 'sick': return 'مرضي';
      default: return s;
    }
  }

  StatusTagType _statusType(String s) {
    switch (s) {
      case 'present': return StatusTagType.success;
      case 'absent': return StatusTagType.danger;
      case 'late': return StatusTagType.warning;
      default: return StatusTagType.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: PageHeader(
            title: 'الحضور',
            subtitle: _loading && _records.isEmpty
                ? 'جاري التحميل…'
                : '$_monthLabel • عرض ${_records.length} من $_total',
            actions: [
              IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('توليد الحضور'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
          child: Row(
            children: [
              IconButton(
                tooltip: 'الشهر السابق',
                onPressed: _loading ? null : () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: Text(
                  _monthLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'الشهر التالي',
                onPressed: _loading ? null : () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spaceMd,
            0,
            AppDimensions.spaceMd,
            8,
          ),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'بحث بالاسم أو كود الموظف',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                        _load(reset: true);
                      },
                    )
                  : null,
              isDense: true,
            ),
            onChanged: (v) {
              setState(() {});
              _onSearchChanged(v);
            },
            onSubmitted: (_) => _load(reset: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
          child: const HrLocalDataBanner(
            title: 'الحضور — يُولَّد محلياً',
            hint: 'يُعرض شهر واحد في كل مرة لتسريع التحميل. بعد مزامنة البصمات اضغط «توليد الحضور».',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading && _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (_generateMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(_generateMessage!, textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                )
              : _error != null
                  ? Center(child: Text(_error!))
                  : _records.isEmpty
                      ? Center(
                          child: HrEmptyListCard(
                            message: _searchCtrl.text.trim().isNotEmpty
                                ? 'لا توجد نتائج لـ «${_searchCtrl.text.trim()}» في $_monthLabel'
                                : 'لا توجد سجلات حضور لـ $_monthLabel.\n1) مزامنة البصمات من الإعدادات\n2) توليد الحضور لهذا الشهر',
                            actionLabel: _searchCtrl.text.trim().isNotEmpty ? null : 'توليد الحضور',
                            onAction: _searchCtrl.text.trim().isNotEmpty ? null : _generate,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(reset: true),
                          child: ListView.separated(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(AppDimensions.spaceMd),
                            itemCount: _records.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              if (i >= _records.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final r = _records[i];
                              final status = r['status']?.toString() ?? '';
                              return SellixCard(
                                child: ListTile(
                                  title: Text(
                                    _displayName(r),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(_subtitle(r)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      StatusTag(label: _statusAr(status), type: _statusType(status)),
                                      if ((r['lateMinutes'] as num? ?? 0) > 0) ...[
                                        const SizedBox(width: 6),
                                        Chip(
                                          label: Text('تأخير ${r['lateMinutes']}د'),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

extension on String {
  String slice(int start, int end) => substring(start, end.clamp(0, length));
}
