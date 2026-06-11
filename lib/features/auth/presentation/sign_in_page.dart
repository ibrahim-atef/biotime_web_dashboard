import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/api_config.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/hudoori_logo.dart';
import '../../../core/widgets/language_toggle.dart';
import '../../../core/widgets/sellix_card.dart';
import '../../../l10n/app_localizations.dart';
import '../auth_cubit.dart';
import '../auth_state.dart';
import 'login_validators.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _serverFocus = FocusNode();
  final _loginFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _obscurePassword = true;
  bool _showServerField = kIsWeb;

  @override
  void initState() {
    super.initState();
    _loadSavedServer();
  }

  Future<void> _loadSavedServer() async {
    final saved = await session.getBaseUrl();
    final url = saved ?? ApiConfig.baseUrl;
    if (mounted) _serverCtrl.text = url;
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _serverFocus.dispose();
    _loginFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final server = _serverCtrl.text.trim();
    session.saveBaseUrl(server);
    context.read<AuthCubit>().signIn(
          login: LoginValidators.normalizeLogin(_loginCtrl.text),
          password: _passCtrl.text,
          baseUrl: server,
          l10n: AppLocalizations.of(context),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const PositionedDirectional(top: 12, start: 12, child: LanguageToggle()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocConsumer<AuthCubit, AuthState>(
                  listener: (context, state) {
                    if (state.status == AuthStatus.error && state.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.errorMessage!),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      context.read<AuthCubit>().clearError();
                    }
                  },
                  builder: (context, state) {
                    final loading = state.status == AuthStatus.loading;
                    return SellixCard(
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const HudooriLogo(iconSize: 48, nameSize: 24, axis: Axis.vertical),
                            const SizedBox(height: 12),
                            Text(
                              l10n.signIn,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (kIsWeb) ...[
                              const SizedBox(height: 8),
                              Text(
                                'لا تستخدم localhost من الهاتف — استخدم ngrok أو IP جهازك',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'مثال: https://xxxx.ngrok-free.app أو http://192.168.x.x:3000',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (!kIsWeb)
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton.icon(
                                  onPressed: () => setState(() => _showServerField = !_showServerField),
                                  icon: Icon(_showServerField ? Icons.expand_less : Icons.settings_outlined, size: 18),
                                  label: Text(_showServerField ? 'إخفاء إعدادات السيرفر' : 'إعدادات السيرفر'),
                                ),
                              ),
                            if (_showServerField) ...[
                              TextFormField(
                                controller: _serverCtrl,
                                focusNode: _serverFocus,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  labelText: 'رابط الباك اند',
                                  hintText: 'https://xxxx.ngrok-free.app',
                                  prefixIcon: Icon(Icons.dns_outlined, size: 20),
                                ),
                                validator: LoginValidators.serverUrl,
                                onFieldSubmitted: (_) => _loginFocus.requestFocus(),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _loginCtrl,
                              focusNode: _loginFocus,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(
                                labelText: l10n.emailOrLogin,
                                prefixIcon: const Icon(Icons.person_outline, size: 20),
                              ),
                              validator: (v) => LoginValidators.login(l10n, v),
                              onFieldSubmitted: (_) => _passFocus.requestFocus(),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              enableSuggestions: false,
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelText: l10n.password,
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => LoginValidators.password(l10n, v),
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: loading ? null : _submit,
                              child: loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(l10n.login),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
