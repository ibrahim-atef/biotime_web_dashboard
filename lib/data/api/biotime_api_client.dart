import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';

class BioTimeApiException implements Exception {
  BioTimeApiException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class EmployeesPageResult {
  const EmployeesPageResult({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.offset,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final bool hasMore;
  final int offset;
}

class AttendancePageResult {
  const AttendancePageResult({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.offset,
    required this.dateFrom,
    required this.dateTo,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final bool hasMore;
  final int offset;
  final String dateFrom;
  final String dateTo;
}

class BioTimeApiClient {
  BioTimeApiClient({String? baseUrl}) : _baseUrl = _normalize(baseUrl ?? ApiConfig.baseUrl);

  String _baseUrl;
  String? _token;

  String get baseUrl => _baseUrl;

  void configure({String? baseUrl, String? token}) {
    if (baseUrl != null) _baseUrl = _normalize(baseUrl);
    if (token != null) _token = token;
  }

  static String _normalize(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
    String? db,
  }) async {
    final result = await _call('/api/auth/login', {
      'login': login,
      'password': password,
      if (db != null && db.isNotEmpty) 'db': db,
      'device_info': 'BioTime Flutter App',
    }, auth: false);
    if (result['success'] != true) {
      throw BioTimeApiException(
        result['message']?.toString() ?? 'فشل تسجيل الدخول',
        code: result['error_code']?.toString(),
      );
    }
    final data = result['data'] as Map<String, dynamic>? ?? {};
    _token = data['token']?.toString();
    return data;
  }

  Future<void> logout() async {
    if (_token == null) return;
    try {
      await _call('/api/auth/logout', {'token': _token}, auth: false);
    } finally {
      _token = null;
    }
  }

  Future<bool> validateToken() async {
    if (_token == null) return false;
    final result = await _call('/api/auth/validate', {'token': _token}, auth: false);
    return result['valid'] == true || result['success'] == true;
  }

  Future<Map<String, dynamic>> me() async {
    return _unwrap(await _call('/api/biotime/me', {}));
  }

  Future<Map<String, dynamic>> dashboardStats() async {
    return _unwrap(await _call('/api/biotime/dashboard/stats', {}));
  }

  Future<Map<String, dynamic>> dashboardCharts() async {
    return _unwrap(await _call('/api/biotime/dashboard/charts', {}));
  }

  Future<List<Map<String, dynamic>>> myAttendance({String? dateFrom, String? dateTo}) async {
    final data = _unwrap(await _call('/api/biotime/attendance/my', {
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    }));
    return _listFromData(data);
  }

  // --- Shift grid ---

  Future<List<Map<String, dynamic>>> shiftGridList({String? state, Object? deviceId}) async {
    final data = _unwrap(await _call('/api/biotime/shift-grid/list', {
      if (state != null) 'state': state,
      if (deviceId != null) 'deviceId': deviceId,
    }));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> shiftGridGet(Object gridId) async {
    return _unwrap(await _call('/api/biotime/shift-grid/get', {'gridId': gridId}));
  }

  Future<Map<String, dynamic>> shiftGridCreate({
    required String dateFrom,
    required String dateTo,
    String selectionMethod = 'department',
    List<Object>? departmentIds,
    List<Object>? employeeIds,
    Object? deviceId,
    String? gridLocation,
    bool generate = true,
  }) async {
    return _unwrap(await _call('/api/biotime/shift-grid/create', {
      'dateFrom': dateFrom,
      'dateTo': dateTo,
      'selectionMethod': selectionMethod,
      if (departmentIds != null) 'departmentIds': departmentIds,
      if (employeeIds != null) 'employeeIds': employeeIds,
      if (deviceId != null) 'deviceId': deviceId,
      if (gridLocation != null && gridLocation.isNotEmpty) 'gridLocation': gridLocation,
      'generate': generate,
    }));
  }

  Future<Map<String, dynamic>> shiftGridGenerate(Object gridId) async {
    return _unwrap(await _call('/api/biotime/shift-grid/generate', {'gridId': gridId}));
  }

  Future<Map<String, dynamic>> shiftGridUpdateCell({
    required Object gridId,
    required Object lineId,
    required String cellValue,
  }) async {
    return _unwrap(await _call('/api/biotime/shift-grid/cell/update', {
      'gridId': gridId,
      'lineId': lineId,
      'cellValue': cellValue,
    }));
  }

  Future<Map<String, dynamic>> shiftGridBulkRow({
    required Object gridId,
    required Object employeeId,
    required String cellValue,
  }) async {
    return _unwrap(await _call('/api/biotime/shift-grid/bulk/row', {
      'gridId': gridId,
      'employeeId': employeeId,
      'cellValue': cellValue,
    }));
  }

  Future<Map<String, dynamic>> shiftGridBulkColumn({
    required Object gridId,
    required String date,
    required String cellValue,
  }) async {
    return _unwrap(await _call('/api/biotime/shift-grid/bulk/column', {
      'gridId': gridId,
      'date': date,
      'cellValue': cellValue,
    }));
  }

  Future<Map<String, dynamic>> shiftGridAddEmployee({
    required Object gridId,
    required String employeeCode,
  }) async {
    return _unwrap(await _call('/api/biotime/shift-grid/add-employee', {
      'gridId': gridId,
      'employeeCode': employeeCode,
    }));
  }

  Future<Map<String, dynamic>> shiftGridDayPunches(Object lineId) async {
    return _unwrap(await _call('/api/biotime/shift-grid/punches', {'lineId': lineId}));
  }

  Future<Map<String, dynamic>> shiftGridSyncStart(Object gridId) async {
    return _unwrap(await _call('/api/biotime/shift-grid/sync/start', {'gridId': gridId}));
  }

  Future<Map<String, dynamic>> shiftGridSyncStatus(Object gridId) async {
    return _unwrap(await _call('/api/biotime/shift-grid/sync/status', {'gridId': gridId}));
  }

  Future<void> shiftGridSyncReset(Object gridId) async {
    _unwrap(await _call('/api/biotime/shift-grid/sync/reset', {'gridId': gridId}));
  }

  Future<void> shiftGridSyncCancel(Object gridId) async {
    _unwrap(await _call('/api/biotime/shift-grid/sync/cancel', {'gridId': gridId}));
  }

  Future<Map<String, dynamic>> shiftGridClose(Object gridId) async {
    return _unwrap(await _call('/api/biotime/shift-grid/close', {'gridId': gridId}));
  }

  Future<Map<String, dynamic>> shiftGridReopen(Object gridId) async {
    return _unwrap(await _call('/api/biotime/shift-grid/reopen', {'gridId': gridId}));
  }

  Future<Map<String, dynamic>> shiftGridConfirm(Object gridId) async {
    return _unwrap(await _call('/api/biotime/shift-grid/confirm', {'gridId': gridId}));
  }

  Future<List<Map<String, dynamic>>> shiftsList() async {
    final data = _unwrap(await _call('/api/biotime/shifts/list', {}));
    return _listFromData(data);
  }

  Future<List<Map<String, dynamic>>> devicesList() async {
    final data = _unwrap(await _call('/api/biotime/devices/list', {}));
    return _listFromData(data);
  }

  Future<List<Map<String, dynamic>>> departmentsList() async {
    final data = _unwrap(await _call('/api/biotime/departments/list', {}));
    return _listFromData(data);
  }

  // --- Shifts CRUD ---

  Future<Map<String, dynamic>> shiftGet(Object shiftId) async {
    final data = _unwrap(await _call('/api/biotime/shifts/get', {'shiftId': shiftId}));
    return Map<String, dynamic>.from(data['shift'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> shiftCreate(Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/shifts/create', body));
    return Map<String, dynamic>.from(data['shift'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> shiftUpdate(Object shiftId, Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/shifts/update', {'shiftId': shiftId, ...body}));
    return Map<String, dynamic>.from(data['shift'] as Map? ?? {});
  }

  Future<void> shiftDelete(Object shiftId) async {
    _unwrap(await _call('/api/biotime/shifts/delete', {'shiftId': shiftId}));
  }

  // --- Shift assignments ---

  Future<List<Map<String, dynamic>>> shiftAssignmentsList({Object? employeeId}) async {
    final data = _unwrap(await _call('/api/biotime/shift-assignments/list', {
      if (employeeId != null) 'employeeId': employeeId,
    }));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> shiftAssignmentGet(Object id) async {
    final data = _unwrap(await _call('/api/biotime/shift-assignments/get', {'assignmentId': id}));
    return Map<String, dynamic>.from(data['assignment'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> shiftAssignmentCreate(Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/shift-assignments/create', body));
    return Map<String, dynamic>.from(data['assignment'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> shiftAssignmentUpdate(Object id, Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/shift-assignments/update', {'assignmentId': id, ...body}));
    return Map<String, dynamic>.from(data['assignment'] as Map? ?? {});
  }

  Future<void> shiftAssignmentDelete(Object id) async {
    _unwrap(await _call('/api/biotime/shift-assignments/delete', {'assignmentId': id}));
  }

  Future<EmployeesPageResult> employeesList({
    String? search,
    Object? departmentId,
    bool? biotimeSynced,
    int limit = 30,
    int offset = 0,
  }) async {
    final data = _unwrap(await _call('/api/biotime/employees/list', {
      if (search != null && search.isNotEmpty) 'search': search,
      if (departmentId != null) 'departmentId': departmentId,
      if (biotimeSynced != null) 'biotimeSynced': biotimeSynced,
      'limit': limit,
      'offset': offset,
    }));
    final items = _listFrom(data['employees']);
    return EmployeesPageResult(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      hasMore: data['hasMore'] == true,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
    );
  }

  Future<Map<String, dynamic>> employeeGet(Object employeeId) async {
    final data = _unwrap(await _call('/api/biotime/employees/get', {'employeeId': employeeId}));
    return Map<String, dynamic>.from(data['employee'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> employeeUpdate(Object employeeId, Map<String, dynamic> fields, {bool pushToBiotime = true}) async {
    final data = _unwrap(await _call('/api/biotime/employees/update', {
      'employeeId': employeeId,
      'pushToBiotime': pushToBiotime,
      ...fields,
    }));
    return Map<String, dynamic>.from(data['employee'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> employeePushBiotime(Object employeeId) async {
    final data = _unwrap(await _call('/api/biotime/employees/push-biotime', {'employeeId': employeeId}));
    return Map<String, dynamic>.from(data['employee'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> employeeSyncDevice(Object employeeId) async {
    final data = _unwrap(await _call('/api/biotime/employees/sync-device', {'employeeId': employeeId}));
    return Map<String, dynamic>.from(data['employee'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> configGet() async {
    final data = _unwrap(await _call('/api/biotime/config/get', {}));
    return Map<String, dynamic>.from(data['config'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> configUpdate(Map<String, dynamic> fields) async {
    final data = _unwrap(await _call('/api/biotime/config/update', fields));
    return Map<String, dynamic>.from(data['config'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> configAction(String path) async {
    return _unwrap(await _call(path, {}));
  }

  Future<Map<String, dynamic>> syncStatus() async {
    return _unwrap(await _call('/api/biotime/config/sync-status', {}));
  }

  Future<Map<String, dynamic>> odooConfigGet() async {
    return _unwrap(await _call('/api/biotime/odoo/config/get', {}));
  }

  Future<Map<String, dynamic>> odooConfigUpdate(Map<String, dynamic> fields) async {
    return _unwrap(await _call('/api/biotime/odoo/config/update', fields));
  }

  Future<Map<String, dynamic>> odooTestConnection() async {
    return _unwrap(await _call('/api/biotime/odoo/config/test-connection', {}));
  }

  Future<Map<String, dynamic>> odooPushAll({void Function(String message)? onProgress}) async {
    final data = _unwrap(await _call('/api/biotime/odoo/push-all', {}));
    final jobId = data['jobId']?.toString();
    if (jobId != null && data['queued'] == true) {
      return _waitForJob(jobId, onProgress: onProgress);
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> syncJobsList() async {
    final data = _unwrap(await _call('/api/biotime/config/sync-jobs/list', {}));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> syncAll() async {
    return _unwrap(await _call('/api/biotime/config/sync-all', {}));
  }

  Future<Map<String, dynamic>> syncTransactions({String? dateFrom, String? dateTo}) async {
    return _unwrap(await _call('/api/biotime/config/sync-transactions', {
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    }));
  }

  Future<AttendancePageResult> attendanceList({
    String? dateFrom,
    String? dateTo,
    Object? employeeId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = _unwrap(await _call('/api/biotime/attendance/list', {
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
      if (employeeId != null) 'employeeId': employeeId,
      if (search != null && search.isNotEmpty) 'search': search,
      'limit': limit,
      'offset': offset,
    }));
    final items = _listFrom(data['records']);
    return AttendancePageResult(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      hasMore: data['hasMore'] == true,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      dateFrom: data['dateFrom']?.toString() ?? dateFrom ?? '',
      dateTo: data['dateTo']?.toString() ?? dateTo ?? '',
    );
  }

  Future<Map<String, dynamic>> attendanceGenerate({
    required String dateFrom,
    required String dateTo,
    Object? shiftGridId,
    bool skipExisting = false,
    void Function(String message)? onProgress,
  }) async {
    final data = _unwrap(await _call('/api/biotime/attendance/generate', {
      'dateFrom': dateFrom,
      'dateTo': dateTo,
      if (shiftGridId != null) 'shiftGridId': shiftGridId,
      'skipExisting': skipExisting,
    }));
    final jobId = data['jobId']?.toString();
    if (jobId != null && data['queued'] == true) {
      return _waitForJob(jobId, onProgress: onProgress);
    }
    return data;
  }

  Future<Map<String, dynamic>> jobStatus(String jobId) async {
    return _unwrap(await _call('/api/biotime/jobs/status', {'jobId': jobId}));
  }

  Future<Map<String, dynamic>> _waitForJob(String jobId, {void Function(String message)? onProgress}) async {
    for (var i = 0; i < 900; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final st = await jobStatus(jobId);
      final status = st['status']?.toString() ?? '';
      final message = st['message']?.toString() ?? '';
      onProgress?.call(message.isNotEmpty ? message : status);
      if (status == 'done') return st;
      if (status == 'failed' || status == 'cancelled') {
        throw BioTimeApiException(message.isNotEmpty ? message : 'فشلت العملية');
      }
    }
    throw BioTimeApiException('انتهت مهلة انتظار العملية — جرّب لاحقاً من شاشة الحضور');
  }

  Future<Map<String, dynamic>> requestsMy() async {
    return _unwrap(await _call('/api/biotime/requests/my', {}));
  }

  Future<Map<String, dynamic>> requestsPending() async {
    return _unwrap(await _call('/api/biotime/requests/pending', {}));
  }

  Future<Map<String, dynamic>> leaveRequestCreate({
    required String leaveType,
    required String dateFrom,
    required String dateTo,
    required String reason,
  }) async {
    return _unwrap(await _call('/api/biotime/requests/leave/create', {
      'leaveType': leaveType,
      'dateFrom': dateFrom,
      'dateTo': dateTo,
      'reason': reason,
    }));
  }

  Future<Map<String, dynamic>> loanRequestCreate({
    required double amount,
    required int repaymentMonths,
    required String reason,
  }) async {
    return _unwrap(await _call('/api/biotime/requests/loan/create', {
      'amount': amount,
      'repaymentMonths': repaymentMonths,
      'reason': reason,
    }));
  }

  // --- Payroll ---

  Future<List<Map<String, dynamic>>> payrollList({String? state}) async {
    final data = _unwrap(await _call('/api/biotime/payroll/list', {if (state != null) 'state': state}));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> payrollGet(Object payrollId) async {
    final data = _unwrap(await _call('/api/biotime/payroll/get', {'payrollId': payrollId}));
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollCreate({
    String? dateFrom,
    String? dateTo,
    Object? deviceId,
    Object? shiftGridId,
  }) async {
    final data = _unwrap(await _call('/api/biotime/payroll/create', {
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
      if (deviceId != null) 'deviceId': deviceId,
      if (shiftGridId != null) 'shiftGridId': shiftGridId,
    }));
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollCalculate(Object payrollId) async {
    final data = _unwrap(await _call('/api/biotime/payroll/calculate', {'payrollId': payrollId}));
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollConfirm(Object payrollId) async {
    final data = _unwrap(await _call('/api/biotime/payroll/confirm', {'payrollId': payrollId}));
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollLinkDeductions(Object payrollId) async {
    final data = _unwrap(await _call('/api/biotime/payroll/link-deductions', {'payrollId': payrollId}));
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollLineUpdate(Object lineId, Map<String, dynamic> fields) async {
    final data = _unwrap(await _call('/api/biotime/payroll/line/update', {'lineId': lineId, ...fields}));
    return Map<String, dynamic>.from(data['line'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollFinalize(Object payrollId, {List<String>? actions}) async {
    return _unwrap(await _call('/api/biotime/payroll/finalize', {
      'payrollId': payrollId,
      'actions': actions ?? ['confirm', 'journal'],
    }));
  }

  Future<Map<String, dynamic>> payrollExportFawry(Object payrollId) async {
    return _unwrap(await _call('/api/biotime/payroll/export-fawry', {'payrollId': payrollId}));
  }

  Future<Map<String, dynamic>> payrollExportXlsx(Object payrollId) async {
    return _unwrap(await _call('/api/biotime/payroll/export-xlsx', {'payrollId': payrollId}));
  }

  Future<Map<String, dynamic>> payrollExportCashFawry(Object payrollId) async {
    return _unwrap(await _call('/api/biotime/payroll/export-cash-fawry', {'payrollId': payrollId}));
  }

  Future<Map<String, dynamic>> shiftGridExportXlsx(Object gridId) async {
    return _unwrap(await _call('/api/biotime/shift-grid/export-xlsx', {'gridId': gridId}));
  }

  Future<Map<String, dynamic>> shiftGridImportXlsx(Object gridId, String base64) async {
    return _unwrap(await _call('/api/biotime/shift-grid/import-xlsx', {'gridId': gridId, 'base64': base64}));
  }

  Future<List<Map<String, dynamic>>> overtimeList({String? state}) async {
    final data = _unwrap(await _call('/api/biotime/overtime/list', {if (state != null) 'state': state}));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> overtimeGenerate({
    required String dateFrom,
    required String dateTo,
  }) async {
    final data = _unwrap(await _call('/api/biotime/overtime/generate', {
      'dateFrom': dateFrom,
      'dateTo': dateTo,
    }));
    final jobId = data['jobId']?.toString();
    if (jobId != null && data['queued'] == true) {
      return _waitForJob(jobId);
    }
    return data;
  }

  Future<void> overtimeApprove(Object id) async {
    _unwrap(await _call('/api/biotime/overtime/approve', {'id': id}));
  }

  Future<void> overtimeReject(Object id, String reason) async {
    _unwrap(await _call('/api/biotime/overtime/reject', {'id': id, 'reason': reason}));
  }

  Future<Map<String, dynamic>> salaryRequestCreate({
    required double amount,
    required String reason,
  }) async {
    return _unwrap(await _call('/api/biotime/requests/salary/create', {
      'amount': amount,
      'reason': reason,
    }));
  }

  Future<Map<String, dynamic>> shiftChangeRequestCreate({
    required String newShiftId,
    required String dateFrom,
    required String dateTo,
    String? currentShiftId,
    required String reason,
  }) async {
    return _unwrap(await _call('/api/biotime/requests/shift-change/create', {
      'newShiftId': newShiftId,
      if (currentShiftId != null) 'currentShiftId': currentShiftId,
      'dateFrom': dateFrom,
      'dateTo': dateTo,
      'reason': reason,
    }));
  }

  Future<Map<String, dynamic>> certificateRequestCreate({
    required String certificateType,
    required String reason,
  }) async {
    return _unwrap(await _call('/api/biotime/requests/certificate/create', {
      'certificateType': certificateType,
      'reason': reason,
    }));
  }

  Future<Map<String, dynamic>> attendanceEditRequestCreate({
    required String date,
    String? requestedCheckIn,
    String? requestedCheckOut,
    required String reason,
  }) async {
    return _unwrap(await _call('/api/biotime/requests/attendance-edit/create', {
      'date': date,
      if (requestedCheckIn != null) 'requestedCheckIn': requestedCheckIn,
      if (requestedCheckOut != null) 'requestedCheckOut': requestedCheckOut,
      'reason': reason,
    }));
  }

  Future<List<Map<String, dynamic>>> myPayroll() async {
    final data = _unwrap(await _call('/api/biotime/payroll/my', {}));
    return _listFromData(data);
  }

  // --- Deductions ---

  Future<List<Map<String, dynamic>>> deductionTypes() async {
    final data = _unwrap(await _call('/api/biotime/deductions/types', {}));
    final types = _listFrom(data['types']);
    if (types.isNotEmpty) return types;
    return _listFromData(data);
  }

  Future<List<Map<String, dynamic>>> deductionsList({String? state}) async {
    final data = _unwrap(await _call('/api/biotime/deductions/list', {if (state != null) 'state': state}));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> deductionCreate(Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/deductions/create', body));
    return Map<String, dynamic>.from(data['deduction'] as Map? ?? {});
  }

  Future<void> deductionCancel(Object id) async {
    _unwrap(await _call('/api/biotime/deductions/cancel', {'deductionId': id}));
  }

  // --- Advances ---

  Future<List<Map<String, dynamic>>> advancesShortList({String? state}) async {
    final data = _unwrap(await _call('/api/biotime/advances/short/list', {if (state != null) 'state': state}));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> advanceShortCreate(Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/advances/short/create', body));
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<void> advanceShortCancel(Object id) async {
    _unwrap(await _call('/api/biotime/advances/short/cancel', {'advanceId': id}));
  }

  Future<List<Map<String, dynamic>>> advancesLongList({String? state}) async {
    final data = _unwrap(await _call('/api/biotime/advances/long/list', {if (state != null) 'state': state}));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> advanceLongCreate(Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/advances/long/create', body));
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLongConfirm(Object id) async {
    final data = _unwrap(await _call('/api/biotime/advances/long/confirm', {'advanceId': id}));
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<List<Map<String, dynamic>>> adminUsersList() async {
    final data = _unwrap(await _call('/api/admin/users/list', {}));
    return _listFrom(data['users']);
  }

  Future<Map<String, dynamic>> adminUserCreate({
    required String name,
    required String login,
    required String password,
    String role = 'EMPLOYEE',
  }) async {
    return _unwrap(await _call('/api/admin/users', {
      'name': name,
      'login': login,
      'password': password,
      'role': role,
    }));
  }

  List<Map<String, dynamic>> _listFrom(dynamic items) {
    if (items is List) {
      return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _listFromData(Map<String, dynamic> data) {
    for (final key in [
      'items', 'records', 'employees', 'grids', 'payrolls', 'shifts',
      'assignments', 'deductions', 'advances', 'devices', 'departments', 'users', 'types',
    ]) {
      final list = _listFrom(data[key]);
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> result) {
    if (result['success'] != true) {
      throw BioTimeApiException(
        result['message']?.toString() ?? 'خطأ في الخادم',
        code: result['error_code']?.toString(),
      );
    }
    final data = result['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> _call(
    String path,
    Map<String, dynamic> params, {
    bool auth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {
        if (auth && _token != null) 'token': _token,
        ...params,
      },
      'id': DateTime.now().millisecondsSinceEpoch,
    });
    final headers = {
      'Content-Type': 'application/json',
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
    };
    final response = await http.post(uri, headers: headers, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BioTimeApiException('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['result'] is Map) {
      return Map<String, dynamic>.from(decoded['result'] as Map);
    }
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw BioTimeApiException('استجابة غير متوقعة من الخادم');
  }
}
