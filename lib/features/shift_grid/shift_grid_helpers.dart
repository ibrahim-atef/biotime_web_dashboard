class WeekGroup {
  const WeekGroup({required this.label, required this.colspan});
  final String label;
  final int colspan;
}

List<WeekGroup> buildWeekGroups(List<Map<String, dynamic>> dates) {
  if (dates.isEmpty) return [];
  const ordinals = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس'];
  final weeks = <WeekGroup>[];
  WeekGroup? current;
  for (final d in dates) {
    final weekday = d['weekday'] as int? ?? 0;
    if (current == null || weekday == 5) {
      current = WeekGroup(label: 'الأسبوع ${weeks.length + 1}', colspan: 0);
      weeks.add(current);
    }
    current = WeekGroup(label: current.label, colspan: current.colspan + 1);
    weeks[weeks.length - 1] = current;
  }
  for (var i = 0; i < weeks.length; i++) {
    weeks[i] = WeekGroup(
      label: 'الأسبوع ${ordinals.length > i ? ordinals[i] : '${i + 1}'}',
      colspan: weeks[i].colspan,
    );
  }
  return weeks;
}

List<MapEntry<String, List<Map<String, dynamic>>>> parseJobGroups(dynamic raw) {
  if (raw is! Map) return [];
  return raw.entries
      .map((e) => MapEntry(e.key.toString(), _employeeList(e.value)))
      .toList();
}

List<Map<String, dynamic>> _employeeList(dynamic value) {
  if (value is! List) return [];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

List<Map<String, dynamic>> parseDates(dynamic raw) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

List<Map<String, dynamic>> parseShifts(dynamic raw) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String stateLabel(String state) {
  switch (state) {
    case 'setup':
      return 'إعداد';
    case 'grid':
      return 'الجدول';
    case 'confirmed':
      return 'مؤكد';
    default:
      return state;
  }
}

/// Groups shift grids by their date range (dateFrom → dateTo), newest periods first.
List<MapEntry<String, List<Map<String, dynamic>>>> groupShiftGridsByPeriod(
  List<Map<String, dynamic>> items,
) {
  final buckets = <String, List<Map<String, dynamic>>>{};
  for (final item in items) {
    final from = item['dateFrom']?.toString() ?? '';
    final to = item['dateTo']?.toString() ?? '';
    final key = (from.isEmpty && to.isEmpty) ? 'بدون تاريخ' : '$from → $to';
    buckets.putIfAbsent(key, () => []).add(item);
  }

  final groups = buckets.entries.toList();
  groups.sort((a, b) {
    final aFrom = a.value.first['dateFrom']?.toString() ?? '';
    final bFrom = b.value.first['dateFrom']?.toString() ?? '';
    return bFrom.compareTo(aFrom);
  });

  for (final group in groups) {
    group.value.sort((a, b) {
      final aName = a['deviceName']?.toString() ?? a['name']?.toString() ?? '';
      final bName = b['deviceName']?.toString() ?? b['name']?.toString() ?? '';
      return aName.compareTo(bName);
    });
  }

  return groups;
}
