import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_state.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

IconData menuIconFor(String icon) => switch (icon) {
      'schedule' => Icons.schedule_outlined,
      'assignment' => Icons.assignment_outlined,
      'payments' => Icons.payments_outlined,
      'people' => Icons.people_outline,
      'access_time' => Icons.access_time_outlined,
      'event_repeat' => Icons.event_repeat_outlined,
      'grid_on' => Icons.grid_on_outlined,
      'fact_check' => Icons.fact_check_outlined,
      'remove_circle_outline' => Icons.remove_circle_outline,
      'account_balance_wallet' => Icons.account_balance_wallet_outlined,
      'settings' => Icons.settings_outlined,
      _ => Icons.dashboard_outlined,
    };

List<NavItem> navItemsFromMenus(BuildContext context, List<BioTimeMenuItem> menus) {
  final l10n = AppLocalizations.of(context);
  if (menus.isEmpty) {
    return [NavItem(l10n.home, Icons.dashboard_outlined, '/dashboard')];
  }
  return menus
      .map((m) => NavItem(l10n.menuLabel(m.id, fallback: m.name), menuIconFor(m.icon), m.route))
      .toList();
}
