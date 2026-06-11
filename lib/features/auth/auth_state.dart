import 'package:equatable/equatable.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class BioTimeMenuItem extends Equatable {
  const BioTimeMenuItem({required this.id, required this.name, required this.icon, required this.route});
  final String id;
  final String name;
  final String icon;
  final String route;

  factory BioTimeMenuItem.fromJson(Map<String, dynamic> json) => BioTimeMenuItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        icon: json['icon']?.toString() ?? 'dashboard',
        route: json['route']?.toString() ?? '/dashboard',
      );

  @override
  List<Object?> get props => [id];
}

class BioTimeUser extends Equatable {
  const BioTimeUser({
    required this.id,
    required this.name,
    this.email = '',
    this.role = '',
    this.isPlatformAdmin = false,
  });
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isPlatformAdmin;

  factory BioTimeUser.fromJson(Map<String, dynamic> json) => BioTimeUser(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        isPlatformAdmin: json['isPlatformAdmin'] == true,
      );

  @override
  List<Object?> get props => [id, isPlatformAdmin];
}

class BioTimeRoles extends Equatable {
  const BioTimeRoles({
    this.isEmployee = false,
    this.isHrUser = false,
    this.isHrManager = false,
    this.isDeviceManager = false,
    this.isSystemAdmin = false,
    this.isPlatformAdmin = false,
  });
  final bool isEmployee;
  final bool isHrUser;
  final bool isHrManager;
  final bool isDeviceManager;
  final bool isSystemAdmin;
  final bool isPlatformAdmin;

  factory BioTimeRoles.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BioTimeRoles();
    return BioTimeRoles(
      isEmployee: json['isEmployee'] == true,
      isHrUser: json['isHrUser'] == true,
      isHrManager: json['isHrManager'] == true,
      isDeviceManager: json['isDeviceManager'] == true,
      isSystemAdmin: json['isSystemAdmin'] == true,
      isPlatformAdmin: json['isPlatformAdmin'] == true,
    );
  }

  @override
  List<Object?> get props => [isEmployee, isHrUser, isHrManager, isDeviceManager, isSystemAdmin, isPlatformAdmin];
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.token,
    this.user,
    this.employeeName = '',
    this.employeeCode = '',
    this.roles = const BioTimeRoles(),
    this.menus = const [],
    this.errorMessage,
    this.profileWarning,
    this.isPlatformAdmin = false,
  });

  final AuthStatus status;
  final String? token;
  final BioTimeUser? user;
  final String employeeName;
  final String employeeCode;
  final BioTimeRoles roles;
  final List<BioTimeMenuItem> menus;
  final String? errorMessage;
  final String? profileWarning;
  final bool isPlatformAdmin;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    BioTimeUser? user,
    String? employeeName,
    String? employeeCode,
    BioTimeRoles? roles,
    List<BioTimeMenuItem>? menus,
    String? errorMessage,
    String? profileWarning,
    bool? isPlatformAdmin,
    bool clearError = false,
    bool clearProfileWarning = false,
    bool clearToken = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: clearToken ? null : (token ?? this.token),
      user: user ?? this.user,
      employeeName: employeeName ?? this.employeeName,
      employeeCode: employeeCode ?? this.employeeCode,
      roles: roles ?? this.roles,
      menus: menus ?? this.menus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      profileWarning: clearProfileWarning ? null : (profileWarning ?? this.profileWarning),
      isPlatformAdmin: isPlatformAdmin ?? this.isPlatformAdmin,
    );
  }

  @override
  List<Object?> get props => [status, token, user, employeeName, roles, menus, errorMessage, profileWarning, isPlatformAdmin];
}
