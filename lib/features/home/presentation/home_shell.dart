import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Bottom-navigation shell wrapping the primary destinations, styled from the
/// "Cat-ch Mobile UI" design: a warm surface bar with Explore, CatDex, a raised
/// paw-print Capture button, and Guardian.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  static const _tabs = [AppRoutes.map, AppRoutes.catdex, AppRoutes.profile];

  int _indexFor(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final i = _tabs.indexOf(location);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexFor(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: _CozyNavBar(
        index: index,
        onSelect: (i) => context.go(_tabs[i]),
        onCapture: () => context.push(AppRoutes.capture),
      ),
    );
  }
}

class _CozyNavBar extends StatelessWidget {
  const _CozyNavBar({
    required this.index,
    required this.onSelect,
    required this.onCapture,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return SizedBox(
      height: 74 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The surface bar, anchored to the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(top: 8, bottom: bottomInset + 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outline),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.map_outlined,
                      activeIcon: Icons.map,
                      label: 'Explore',
                      selected: index == 0,
                      onTap: () => onSelect(0),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'CatDex',
                      selected: index == 1,
                      onTap: () => onSelect(1),
                    ),
                  ),
                  // Placeholder slot under the raised Capture button.
                  const Expanded(child: SizedBox.shrink()),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Guardian',
                      selected: index == 2,
                      onTap: () => onSelect(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The raised paw-print Capture button, floating over the 3rd slot.
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0.25, -1),
              child: _CaptureButton(onTap: onCapture),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? theme.colorScheme.tertiary : const Color(0xFFA08A76);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Capture a cat',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.apricot,
            border: Border.all(color: theme.colorScheme.surface, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppTheme.terracotta.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.pets, color: Color(0xFFFFF7EF), size: 28),
        ),
      ),
    );
  }
}
