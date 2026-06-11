import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('ar'), Locale('en')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  bool get isAr => locale.languageCode == 'ar';

  String get appName => isAr ? 'حضوري' : 'Hudoori';
  String get appTagline => isAr ? 'الحضور والرواتب' : 'Attendance & Payroll';
  String get signIn => isAr ? 'تسجيل الدخول' : 'Sign in';
  String get odooUrl => isAr ? 'رابط Odoo' : 'Odoo URL';
  String get emailOrLogin => isAr ? 'البريد / اسم المستخدم' : 'Email / Username';
  String get password => isAr ? 'كلمة المرور' : 'Password';
  String get login => isAr ? 'دخول' : 'Login';
  String get loginRequired => isAr ? 'أدخل البريد أو اسم المستخدم' : 'Enter email or username';
  String get passwordRequired => isAr ? 'أدخل كلمة المرور' : 'Enter your password';
  String get invalidEmail => isAr ? 'البريد الإلكتروني غير صحيح' : 'Enter a valid email address';
  String loginTooShort(int min) =>
      isAr ? 'اسم المستخدم قصير جداً (الحد الأدنى $min أحرف)' : 'Login is too short (min $min characters)';
  String loginTooLong(int max) =>
      isAr ? 'اسم المستخدم طويل جداً (الحد الأقصى $max حرف)' : 'Login is too long (max $max characters)';
  String passwordTooShort(int min) =>
      isAr ? 'كلمة المرور قصيرة جداً (الحد الأدنى $min أحرف)' : 'Password is too short (min $min characters)';
  String passwordTooLong(int max) =>
      isAr ? 'كلمة المرور طويلة جداً' : 'Password is too long (max $max characters)';
  String get invalidCredentials =>
      isAr ? 'بيانات الدخول غير صحيحة' : 'Invalid login or password';
  String get accountInactive =>
      isAr ? 'هذا الحساب غير مفعّل — تواصل مع المسؤول' : 'This account is inactive — contact your admin';
  String get logout => isAr ? 'تسجيل الخروج' : 'Logout';
  String get language => isAr ? 'اللغة' : 'Language';
  String get arabic => isAr ? 'العربية' : 'Arabic';
  String get english => 'English';
  String get home => isAr ? 'الرئيسية' : 'Home';

  String roleLabel({required bool isSystemAdmin, required bool isHrManager, required bool isEmployee}) {
    if (isSystemAdmin) return isAr ? 'مدير النظام' : 'System Admin';
    if (isHrManager) return isAr ? 'مدير HR' : 'HR Manager';
    if (isEmployee) return isAr ? 'موظف' : 'Employee';
    return isAr ? 'مستخدم' : 'User';
  }

  String menuLabel(String id, {String? fallback}) {
    final labels = _menus[isAr] ?? _menus[true]!;
    return labels[id] ?? fallback ?? id;
  }

  static const Map<bool, Map<String, String>> _menus = {
    true: {
      'dashboard': 'الرئيسية',
      'my_attendance': 'حضوري',
      'my_requests': 'طلباتي',
      'my_payslip': 'كشف راتبي',
      'hr_dashboard': 'لوحة HR',
      'employees': 'الموظفين',
      'shifts': 'الشيفتات',
      'shift_assignments': 'تعيين الشيفتات',
      'shift_grid': 'جدول الشيفتات',
      'attendance': 'الحضور',
      'deductions': 'الاستقطاعات',
      'advances': 'السلف',
      'payroll': 'الرواتب',
      'settings': 'إعدادات',
    },
    false: {
      'dashboard': 'Home',
      'my_attendance': 'My Attendance',
      'my_requests': 'My Requests',
      'my_payslip': 'My Payslip',
      'hr_dashboard': 'HR Dashboard',
      'employees': 'Employees',
      'shifts': 'Shifts',
      'shift_assignments': 'Shift Assignments',
      'shift_grid': 'Shift Grid',
      'attendance': 'Attendance',
      'deductions': 'Deductions',
      'advances': 'Advances',
      'payroll': 'Payroll',
      'settings': 'Settings',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
