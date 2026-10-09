import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/l10n.dart';

/// Breakpoints follow Material 3 window size classes.
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1200.0;
}

/// Bottom navigation on phones; a navigation rail on tablets and desktops.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (Icons.today_outlined, Icons.today, l.navToday),
      (Icons.menu_book_outlined, Icons.menu_book, l.navParsha),
      (Icons.insights_outlined, Icons.insights, l.navProgress),
      (Icons.forum_outlined, Icons.forum, l.navCommunity),
      (Icons.settings_outlined, Icons.settings, l.navSettings),
    ];
    final width = MediaQuery.sizeOf(context).width;

    if (width < Breakpoints.medium) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final (icon, selected, label) in items)
              NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Keyboard users reach the rail first, then the page.
            FocusTraversalGroup(
              child: NavigationRail(
                extended: width >= Breakpoints.expanded,
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _go,
                labelType: width >= Breakpoints.expanded ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(
                    header: true,
                    child: Text(
                      context.isHebrewUi ? 'ש״מ' : 'SM',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                destinations: [
                  for (final (icon, selected, label) in items)
                    NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: FocusTraversalGroup(child: shell)),
          ],
        ),
      ),
    );
  }
}
