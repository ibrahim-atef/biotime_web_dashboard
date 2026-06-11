import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/my_attendance_page.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/auth/auth_state.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/hr/employee_detail_page.dart';
import '../../features/hr/employees_page.dart';
import '../../features/hr/hr_dashboard_page.dart';
import '../../features/hr/hr_attendance_page.dart';
import '../../features/hr/settings_page.dart';
import '../../features/requests/requests_page.dart';
import '../../features/advances/advances_page.dart';
import '../../features/deductions/deductions_page.dart';
import '../../features/payroll/my_payroll_page.dart';
import '../../features/payroll/payroll_detail_page.dart';
import '../../features/payroll/payroll_list_page.dart';
import '../../features/placeholder/placeholder_page.dart';
import '../../features/shift_assignments/shift_assignments_page.dart';
import '../../features/shift_grid/shift_grid_detail_page.dart';
import '../../features/shift_grid/shift_grid_list_page.dart';
import '../../features/shifts/shifts_page.dart';
import '../../features/admin/admin_create_user_page.dart';
import '../../features/admin/admin_dashboard_page.dart';
import '../../features/admin/admin_users_page.dart';
import '../../features/shell/biotime_shell.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const adminDashboard = '/admin/dashboard';
  static const adminUsers = '/admin/users';
  static const adminCreateUser = '/admin/users/create';
  static const dashboard = '/dashboard';
  static const myAttendance = '/attendance/my';
  static const requests = '/requests';
  static const myPayroll = '/payroll/my';
  static const hrDashboard = '/hr/dashboard';
  static const hrEmployees = '/hr/employees';
  static const hrShifts = '/hr/shifts';
  static const hrShiftAssignments = '/hr/shift-assignments';
  static const hrShiftGrid = '/hr/shift-grid';
  static const hrAttendance = '/hr/attendance';
  static const hrDeductions = '/hr/deductions';
  static const hrAdvances = '/hr/advances';
  static const hrPayroll = '/hr/payroll';
  static const hrSettings = '/hr/settings';
}

GoRouter createRouter(AuthCubit auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthRefresh(auth),
    redirect: (context, state) {
      final s = auth.state;
      final loggedIn = s.isAuthenticated;
      final location = state.matchedLocation;
      final boot = s.status == AuthStatus.initial || s.status == AuthStatus.loading;
      final isAuth = location == AppRoutes.signIn;

      final isAdminRoute = location.startsWith('/admin');
      final isPlatformAdmin = s.isPlatformAdmin;

      if (boot) return location == AppRoutes.splash ? null : AppRoutes.splash;
      if (location == AppRoutes.splash) {
        if (!loggedIn) return AppRoutes.signIn;
        return isPlatformAdmin ? AppRoutes.adminDashboard : AppRoutes.dashboard;
      }
      if (!loggedIn && !isAuth) return AppRoutes.signIn;
      if (loggedIn && isAuth) {
        return isPlatformAdmin ? AppRoutes.adminDashboard : AppRoutes.dashboard;
      }
      if (loggedIn && isPlatformAdmin && !isAdminRoute) return AppRoutes.adminDashboard;
      if (loggedIn && !isPlatformAdmin && isAdminRoute) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.signIn, builder: (_, __) => const SignInPage()),
      GoRoute(path: AppRoutes.adminDashboard, builder: (_, __) => const AdminDashboardPage()),
      GoRoute(path: AppRoutes.adminUsers, builder: (_, __) => const AdminUsersPage()),
      GoRoute(path: AppRoutes.adminCreateUser, builder: (_, __) => const AdminCreateUserPage()),
      ShellRoute(
        builder: (_, __, child) => BioTimeShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.dashboard, pageBuilder: (_, __) => const NoTransitionPage(child: DashboardPage())),
          GoRoute(path: AppRoutes.myAttendance, pageBuilder: (_, __) => const NoTransitionPage(child: MyAttendancePage())),
          GoRoute(path: AppRoutes.requests, pageBuilder: (_, __) => const NoTransitionPage(child: RequestsPage())),
          GoRoute(path: AppRoutes.myPayroll, pageBuilder: (_, __) => const NoTransitionPage(child: MyPayrollPage())),
          GoRoute(path: AppRoutes.hrDashboard, pageBuilder: (_, __) => const NoTransitionPage(child: HrDashboardPage())),
          GoRoute(
            path: AppRoutes.hrEmployees,
            pageBuilder: (_, __) => const NoTransitionPage(child: EmployeesPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(child: EmployeeDetailPage(employeeId: id));
                },
              ),
            ],
          ),
          GoRoute(path: AppRoutes.hrShifts, pageBuilder: (_, __) => const NoTransitionPage(child: ShiftsPage())),
          GoRoute(
            path: AppRoutes.hrShiftGrid,
            pageBuilder: (_, __) => const NoTransitionPage(child: ShiftGridListPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(child: ShiftGridDetailPage(gridId: id));
                },
              ),
            ],
          ),
          GoRoute(path: AppRoutes.hrAttendance, pageBuilder: (_, __) => const NoTransitionPage(child: HrAttendancePage())),
          GoRoute(path: AppRoutes.hrShiftAssignments, pageBuilder: (_, __) => const NoTransitionPage(child: ShiftAssignmentsPage())),
          GoRoute(path: AppRoutes.hrDeductions, pageBuilder: (_, __) => const NoTransitionPage(child: DeductionsPage())),
          GoRoute(path: AppRoutes.hrAdvances, pageBuilder: (_, __) => const NoTransitionPage(child: AdvancesPage())),
          GoRoute(
            path: AppRoutes.hrPayroll,
            pageBuilder: (_, __) => const NoTransitionPage(child: PayrollListPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(child: PayrollDetailPage(payrollId: id));
                },
              ),
            ],
          ),
          GoRoute(path: AppRoutes.hrSettings, pageBuilder: (_, __) => const NoTransitionPage(child: SettingsPage())),
        ],
      ),
    ],
  );
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._auth) {
    _auth.stream.listen((_) => notifyListeners());
  }
  final AuthCubit _auth;
}
