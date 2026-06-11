import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/locale/locale_cubit.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_cubit.dart';
import 'l10n/app_localizations.dart';

class HudooriApp extends StatefulWidget {
  const HudooriApp({super.key});

  @override
  State<HudooriApp> createState() => _HudooriAppState();
}

/// Kept for backwards compatibility in imports/tests.
typedef BioTimeApp = HudooriApp;

class _HudooriAppState extends State<HudooriApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = sl<AuthCubit>();
    _router = createRouter(auth);
    auth.restoreSession();
    sl<LocaleCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<AuthCubit>()),
        BlocProvider.value(value: sl<LocaleCubit>()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            title: AppLocalizations(locale).appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
