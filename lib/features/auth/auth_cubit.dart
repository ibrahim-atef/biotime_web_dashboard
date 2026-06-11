import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/api_config.dart';
import '../../core/config/platform_admin_config.dart';
import '../../core/storage/session_storage.dart';
import '../../data/api/biotime_api_client.dart';
import '../../l10n/app_localizations.dart';
import 'auth_state.dart';
import 'presentation/login_validators.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required BioTimeApiClient api,
    required SessionStorage session,
  })  : _api = api,
        _session = session,
        super(const AuthState());

  final BioTimeApiClient _api;
  final SessionStorage _session;

  Future<void> restoreSession() async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true, clearProfileWarning: true));
    try {
      final token = await _session.getToken();
      final baseUrl = await _session.getBaseUrl() ?? ApiConfig.baseUrl;
      _api.configure(baseUrl: baseUrl, token: token);
      if (token == null || token.isEmpty) {
        emit(state.copyWith(status: AuthStatus.unauthenticated, clearToken: true));
        return;
      }
      if (PlatformAdminConfig.isLocalToken(token)) {
        emit(AuthState(
          status: AuthStatus.authenticated,
          token: token,
          isPlatformAdmin: true,
          user: const BioTimeUser(
            id: 'platform-admin',
            name: 'Platform Admin',
            email: PlatformAdminConfig.login,
            isPlatformAdmin: true,
          ),
        ));
        return;
      }
      final valid = await _api.validateToken();
      if (!valid) {
        await _session.clearToken();
        emit(state.copyWith(status: AuthStatus.unauthenticated, clearToken: true));
        return;
      }
      final isPlatformAdmin = await _session.getPlatformAdmin();
      if (isPlatformAdmin) {
        emit(AuthState(
          status: AuthStatus.authenticated,
          token: token,
          isPlatformAdmin: true,
          user: BioTimeUser(id: '', name: 'Platform Admin', isPlatformAdmin: true),
        ));
        return;
      }
      await _loadProfile(baseUrl: baseUrl, token: token);
    } catch (_) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, clearToken: true));
    }
  }

  Future<void> signIn({
    required String login,
    required String password,
    String? baseUrl,
    String? database,
    AppLocalizations? l10n,
  }) async {
    final validationLogin = LoginValidators.login(l10n ?? _fallbackL10n, login);
    if (validationLogin != null) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: validationLogin));
      return;
    }
    final validationPassword = LoginValidators.password(l10n ?? _fallbackL10n, password);
    if (validationPassword != null) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: validationPassword));
      return;
    }

    emit(state.copyWith(status: AuthStatus.loading, clearError: true, clearProfileWarning: true));
    try {
      final trimmedLogin = LoginValidators.normalizeLogin(login);
      if (PlatformAdminConfig.matches(trimmedLogin, password)) {
        final server = _resolveServerUrl(baseUrl);
        _api.configure(baseUrl: server);
        try {
          final data = await _api.login(login: trimmedLogin, password: password);
          final token = data['token']?.toString() ?? '';
          if (token.isNotEmpty) {
            await _session.saveToken(token);
            await _session.saveBaseUrl(server);
            await _session.savePlatformAdmin(true);
            final loginUser = data['user'];
            final user = loginUser is Map
                ? BioTimeUser.fromJson(Map<String, dynamic>.from(loginUser))
                : const BioTimeUser(
                    id: 'platform-admin',
                    name: 'Platform Admin',
                    email: PlatformAdminConfig.login,
                    isPlatformAdmin: true,
                  );
            emit(AuthState(
              status: AuthStatus.authenticated,
              token: token,
              isPlatformAdmin: true,
              user: user,
            ));
            return;
          }
        } catch (_) {
          // Backend offline — fall back to local session for dashboard only
        }
        const token = PlatformAdminConfig.localToken;
        _api.configure(baseUrl: server, token: token);
        await _session.saveToken(token);
        await _session.saveBaseUrl(server);
        await _session.savePlatformAdmin(true);
        emit(AuthState(
          status: AuthStatus.authenticated,
          token: token,
          isPlatformAdmin: true,
          user: const BioTimeUser(
            id: 'platform-admin',
            name: 'Platform Admin',
            email: PlatformAdminConfig.login,
            isPlatformAdmin: true,
          ),
        ));
        return;
      }

      final server = _resolveServerUrl(baseUrl);
      final db = database?.trim();
      _api.configure(baseUrl: server);
      final data = await _api.login(
        login: trimmedLogin,
        password: password,
        db: db?.isNotEmpty == true ? db : ApiConfig.database,
      );
      final token = data['token']?.toString() ?? '';
      await _session.saveToken(token);
      await _session.saveBaseUrl(server);
      if (db?.isNotEmpty == true) await _session.saveDatabase(db!);
      final loginUser = data['user'];
      if (loginUser is Map && loginUser['isPlatformAdmin'] == true) {
        final user = BioTimeUser.fromJson(Map<String, dynamic>.from(loginUser));
        await _session.saveToken(token);
        await _session.savePlatformAdmin(true);
        emit(AuthState(
          status: AuthStatus.authenticated,
          token: token,
          user: user,
          isPlatformAdmin: true,
        ));
        return;
      }
      await _session.savePlatformAdmin(false);
      await _loadProfile(baseUrl: server, token: token, loginUser: loginUser);
    } on BioTimeApiException catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: _mapLoginError(e, l10n)));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: e.toString()));
    }
  }

  static final _fallbackL10n = AppLocalizations(const Locale('ar'));

  String _mapLoginError(BioTimeApiException e, AppLocalizations? l10n) {
    final loc = l10n ?? _fallbackL10n;
    switch (e.code) {
      case 'INVALID_CREDENTIALS':
        return loc.invalidCredentials;
      case 'LOGIN_REQUIRED':
        return loc.loginRequired;
      case 'PASSWORD_REQUIRED':
        return loc.passwordRequired;
      case 'INVALID_EMAIL':
        return loc.invalidEmail;
      case 'LOGIN_TOO_SHORT':
        return loc.loginTooShort(LoginValidators.loginMinLength);
      case 'PASSWORD_TOO_SHORT':
        return loc.passwordTooShort(LoginValidators.passwordMinLength);
      default:
        return e.message;
    }
  }

  Future<void> _loadProfile({
    required String baseUrl,
    required String token,
    dynamic loginUser,
  }) async {
    _api.configure(baseUrl: baseUrl, token: token);
    BioTimeUser? user;
    var roles = const BioTimeRoles();
    var menus = <BioTimeMenuItem>[];
    String? profileWarning;

    if (loginUser is Map) {
      final loginMap = Map<String, dynamic>.from(loginUser);
      user = BioTimeUser.fromJson(loginMap);
      final fromLogin = _profileFromBiotime(loginMap['biotime']);
      roles = fromLogin.roles;
      menus = fromLogin.menus;
    }

    try {
      final me = await _api.me();
      final userJson = me['user'];
      if (userJson is Map) user = BioTimeUser.fromJson(Map<String, dynamic>.from(userJson));
      final employee = me['employee'];
      final empName = employee is Map ? employee['name']?.toString() ?? '' : '';
      final empCode = employee is Map ? employee['code']?.toString() ?? '' : '';
      roles = BioTimeRoles.fromJson(me['roles'] as Map<String, dynamic>?);
      menus = (me['menus'] as List? ?? [])
          .whereType<Map>()
          .map((e) => BioTimeMenuItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      emit(AuthState(
        status: AuthStatus.authenticated,
        token: token,
        user: user,
        employeeName: empName,
        employeeCode: empCode,
        roles: roles,
        menus: menus,
        profileWarning: menus.length <= 1
            ? 'لا توجد قوائم كافية — تأكد من صلاحيات HR أو ترقية biotime_flutter_api على Odoo'
            : null,
      ));
      return;
    } on BioTimeApiException catch (e) {
      profileWarning = e.message;
    } catch (e) {
      profileWarning = e.toString();
    }

    profileWarning ??= menus.isEmpty ? 'فشل تحميل الملف الشخصي من الخادم' : null;

    emit(AuthState(
      status: AuthStatus.authenticated,
      token: token,
      user: user,
      roles: roles,
      menus: menus,
      profileWarning: profileWarning,
    ));
  }

  ({BioTimeRoles roles, List<BioTimeMenuItem> menus}) _profileFromBiotime(dynamic biotime) {
    if (biotime is! Map) {
      return (roles: const BioTimeRoles(), menus: <BioTimeMenuItem>[]);
    }
    final map = Map<String, dynamic>.from(biotime);
    final roles = BioTimeRoles.fromJson(map['roles'] as Map<String, dynamic>?);
    final menus = (map['menus'] as List? ?? [])
        .whereType<Map>()
        .map((e) => BioTimeMenuItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (roles: roles, menus: menus);
  }

  String _resolveServerUrl(String? baseUrl) {
    final raw = (baseUrl?.trim().isNotEmpty == true) ? baseUrl!.trim() : ApiConfig.baseUrl;
    if (raw.contains('odoo.com')) return ApiConfig.baseUrl;
    return raw;
  }

  Future<void> signOut() async {
    if (!PlatformAdminConfig.isLocalToken(state.token)) {
      try {
        await _api.logout();
      } catch (_) {}
    }
    await _session.clearToken();
    await _session.savePlatformAdmin(false);
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
