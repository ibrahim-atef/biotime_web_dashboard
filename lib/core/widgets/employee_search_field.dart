import 'package:flutter/material.dart';

import '../di/injection.dart';

class EmployeeSearchField extends StatefulWidget {
  const EmployeeSearchField({super.key, this.initialId, this.onSelected});
  final String? initialId;
  final void Function(String? employeeId, String name)? onSelected;

  @override
  State<EmployeeSearchField> createState() => _EmployeeSearchFieldState();
}

class _EmployeeSearchFieldState extends State<EmployeeSearchField> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  String? _selectedId;
  String _selectedName = '';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialId;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    try {
      final page = await api.employeesList(search: q, limit: 20);
      if (mounted) setState(() => _results = page.items);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: 'بحث موظف',
            hintText: _selectedName.isNotEmpty ? _selectedName : 'الاسم أو الكود',
            suffixIcon: _selectedId != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() { _selectedId = null; _selectedName = ''; _ctrl.clear(); });
                      widget.onSelected?.call(null, '');
                    },
                  )
                : null,
          ),
          onChanged: _search,
        ),
        if (_results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                for (final e in _results.take(8))
                  ListTile(
                    dense: true,
                    title: Text(e['displayName']?.toString() ?? e['name']?.toString() ?? ''),
                    subtitle: Text('كود: ${e['code']?.toString() ?? ''}'),
                    onTap: () {
                      final id = e['id']?.toString();
                      final name = e['displayName']?.toString() ?? e['name']?.toString() ?? '';
                      setState(() { _selectedId = id; _selectedName = name; _results = []; _ctrl.text = name; });
                      widget.onSelected?.call(id, name);
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
