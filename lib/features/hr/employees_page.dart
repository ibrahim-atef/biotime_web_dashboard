import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  static const _pageSize = 30;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _searchDebounce;

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _departments = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _departmentFilter;
  bool? _biotimeFilter;
  int _total = 0;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadDepartments();
    _reload(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || _loading) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await api.departmentsList();
      if (mounted) setState(() => _departments = depts);
    } catch (_) {}
  }

  Future<void> _reload({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _offset = 0;
        _items.clear();
      });
    }
    try {
      final page = await api.employeesList(
        search: _searchCtrl.text.trim(),
        departmentId: _departmentFilter,
        biotimeSynced: _biotimeFilter,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _offset = page.items.length;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_offset >= _total || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await api.employeesList(
        search: _searchCtrl.text.trim(),
        departmentId: _departmentFilter,
        biotimeSynced: _biotimeFilter,
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
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

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _reload(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'الموظفين',
            subtitle: _total > 0 ? '$_total موظف — بيانات من BioTime' : 'بيانات من BioTime بعد المزامنة',
            actions: [IconButton(onPressed: () => _reload(reset: true), icon: const Icon(Icons.refresh))],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'بحث بالاسم أو الكود',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _reload(reset: true);
                      },
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _reload(reset: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            value: _departmentFilter,
            decoration: const InputDecoration(labelText: 'القسم', isDense: true),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('كل الأقسام', overflow: TextOverflow.ellipsis),
              ),
              for (final d in _departments)
                DropdownMenuItem(
                  value: d['id']?.toString(),
                  child: Text(
                    d['name']?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              setState(() => _departmentFilter = v);
              _reload(reset: true);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('الكل'),
                selected: _biotimeFilter == null,
                onSelected: (_) {
                  setState(() => _biotimeFilter = null);
                  _reload(reset: true);
                },
              ),
              FilterChip(
                label: const Text('مرتبط BioTime'),
                selected: _biotimeFilter == true,
                onSelected: (_) {
                  setState(() => _biotimeFilter = true);
                  _reload(reset: true);
                },
              ),
              FilterChip(
                label: const Text('غير مرتبط'),
                selected: _biotimeFilter == false,
                onSelected: (_) {
                  setState(() => _biotimeFilter = false);
                  _reload(reset: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const SellixCard(child: Center(child: Text('لا يوجد موظفون مطابقون للفلتر')))
                    : SellixCard(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          controller: _scrollCtrl,
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }
                            return _EmployeeTile(
                              employee: _items[i],
                              onTap: () => context.go('${AppRoutes.hrEmployees}/${_items[i]['id']}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee, required this.onTap});

  final Map<String, dynamic> employee;
  final VoidCallback onTap;

  String get _displayName =>
      employee['displayName']?.toString().trim().isNotEmpty == true
          ? employee['displayName'].toString()
          : employee['name']?.toString() ?? '—';

  String get _initials {
    final parts = _displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.length >= 2 ? s.substring(0, 2) : s;
    }
    return '${parts.first[0]}${parts.last[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final code = employee['code']?.toString() ?? '';
    final dept = employee['department']?.toString() ?? '';
    final email = employee['workEmail']?.toString() ?? '';
    final phone = employee['mobilePhone']?.toString() ?? '';
    final synced = employee['biotimeSynced'] == true;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.primary,
        child: Text(_initials, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      title: Text(_displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (code.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('كود $code', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              if (dept.isNotEmpty)
                Text(dept, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (email.isNotEmpty || phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [if (email.isNotEmpty) email, if (phone.isNotEmpty) phone].join('  •  '),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: StatusTag(
        label: synced ? 'BioTime' : 'غير مرتبط',
        type: synced ? StatusTagType.success : StatusTagType.warning,
      ),
      onTap: onTap,
    );
  }
}
