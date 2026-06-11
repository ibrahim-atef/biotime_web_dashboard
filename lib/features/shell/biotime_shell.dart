import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/hudoori_logo.dart';
import '../../core/widgets/language_toggle.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'shell_nav.dart';

class BioTimeShell extends StatefulWidget {
  const BioTimeShell({super.key, required this.child});
  final Widget child;

  @override
  State<BioTimeShell> createState() => _BioTimeShellState();
}

class _BioTimeShellState extends State<BioTimeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final location = GoRouterState.of(context).matchedLocation;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        final l10n = AppLocalizations.of(context);
        final navItems = navItemsFromMenus(context, auth.menus);
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          drawer: mobile ? Drawer(child: _Sidebar(location: location, navItems: navItems, onTap: _closeDrawer)) : null,
          bottomNavigationBar: mobile ? _BottomNav(location: location, navItems: navItems) : null,
          body: Row(
            children: [
              if (!mobile) _Sidebar(location: location, navItems: navItems, collapsed: isTablet(context)),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      onMenu: mobile ? () => _scaffoldKey.currentState?.openDrawer() : null,
                      userName: auth.user?.name ?? auth.employeeName,
                      userRole: l10n.roleLabel(
                        isSystemAdmin: auth.roles.isSystemAdmin,
                        isHrManager: auth.roles.isHrManager,
                        isEmployee: auth.roles.isEmployee,
                      ),
                    ),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _closeDrawer() => Navigator.of(context).pop();
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location, required this.navItems, this.collapsed = false, this.onTap});
  final String location;
  final List<NavItem> navItems;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? AppDimensions.sidebarCollapsed : AppDimensions.sidebarWidth;
    return Container(
      width: width,
      color: AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: HudooriLogo(
              iconSize: collapsed ? 32 : 36,
              nameSize: 22,
              showName: !collapsed,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final item in navItems)
                  _SidebarTile(
                    item: item,
                    selected: location.startsWith(item.route),
                    collapsed: collapsed,
                    onTap: () {
                      context.go(item.route);
                      onTap?.call();
                    },
                  ),
              ],
            ),
          ),
          if (!collapsed)
            ListTile(
              leading: const Icon(Icons.logout, size: 20),
              title: Text(AppLocalizations.of(context).logout, style: const TextStyle(fontSize: 14)),
              onTap: () async {
                await context.read<AuthCubit>().signOut();
                if (context.mounted) context.go(AppRoutes.signIn);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.selected, required this.collapsed, required this.onTap});
  final NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 14, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: selected ? AppColors.primary : AppColors.textSecondary),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? AppColors.primaryDark : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onMenu, required this.userName, required this.userRole});
  final VoidCallback? onMenu;
  final String userName;
  final String userRole;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.background,
      child: Row(
        children: [
          if (onMenu != null) IconButton(onPressed: onMenu, icon: const Icon(Icons.menu)),
          const Spacer(),
          const LanguageToggle(),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLight,
            child: Icon(Icons.person, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(userRole, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.location, required this.navItems});
  final String location;
  final List<NavItem> navItems;

  @override
  Widget build(BuildContext context) {
    final items = navItems.take(4).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    var index = 0;
    for (var i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route)) index = i;
    }
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) => context.go(items[i].route),
      destinations: [for (final item in items) NavigationDestination(icon: Icon(item.icon), label: item.label)],
    );
  }
}
