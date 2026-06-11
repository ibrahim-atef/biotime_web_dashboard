import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/utils/api_connection_help.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_cubit.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users = await api.adminUsersList();
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _friendlyError(e); _loading = false; });
    }
  }

  Future<void> _copyEmail(String email) async {
    if (email.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $email'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Failed to fetch') || msg.contains('ClientException')) {
      return ApiConnectionHelp.connectionError(api.baseUrl);
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Users'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.go(AppRoutes.adminDashboard),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Create user', onPressed: () => context.go(AppRoutes.adminCreateUser)),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final u = _users[i];
                      final email = u['email']?.toString() ?? u['login']?.toString() ?? '';
                      final role = u['role']?.toString() ?? '';
                      return Card(
                        child: ListTile(
                          title: Text(u['name']?.toString() ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => _copyEmail(email),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          email,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(role, style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_outlined, size: 20),
                                tooltip: 'Copy email',
                                onPressed: email.isEmpty ? null : () => _copyEmail(email),
                              ),
                              if (u['active'] == false)
                                const Chip(label: Text('Inactive')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
