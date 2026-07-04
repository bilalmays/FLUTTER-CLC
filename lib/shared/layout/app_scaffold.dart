import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNavItem {
  const AppNavItem({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
}

const appNavItems = [
  AppNavItem(
    path: '/basket',
    label: 'Composer mon panier',
    icon: Icons.shopping_bag_outlined,
  ),
  AppNavItem(
    path: '/documents',
    label: 'Documents',
    icon: Icons.description_outlined,
  ),
  AppNavItem(path: '/clients', label: 'Clients', icon: Icons.groups_2_outlined),
  AppNavItem(
    path: '/subscriptions',
    label: 'CRM',
    icon: Icons.business_center_outlined,
  ),
  AppNavItem(
    path: '/assistant',
    label: 'Assistant IA',
    icon: Icons.auto_awesome_rounded,
  ),
];

const appSettingsItem = AppNavItem(
  path: '/settings',
  label: 'Réglages',
  icon: Icons.settings_outlined,
);

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Row(
          children: [
            if (!isMobile) _SideNavigation(currentPath: currentPath),
            Expanded(
              child: Padding(
                padding: EdgeInsets.zero,
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFF050505)),
                  child: Padding(
                    padding: EdgeInsets.all(Responsive.pagePadding(context)),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isMobile
          ? _BottomNavigation(currentPath: currentPath)
          : null,
    );
  }
}

class _SideNavigation extends StatefulWidget {
  const _SideNavigation({required this.currentPath});

  final String currentPath;

  @override
  State<_SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<_SideNavigation> {
  int _secretTapCount = 0;

  void _handleThemeTap() {
    _secretTapCount += 1;
    if (_secretTapCount >= 7) {
      _secretTapCount = 0;
      context.go('/secret-document');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: AppColors.ink,
        border: const Border(right: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset('assets/clc-logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (
                    var index = 0;
                    index < appNavItems.length;
                    index += 1
                  ) ...[
                    _SidebarNavButton(
                      item: appNavItems[index],
                      active: appNavItems[index].path == widget.currentPath,
                    ),
                    if (index < appNavItems.length - 1) const _SidebarDivider(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.accent, blurRadius: 8)],
              ),
            ),
          ),
          const SizedBox(height: 26),
          _SidebarActionButton(
            icon: Icons.dark_mode_outlined,
            label: 'Mode sombre',
            onTap: _handleThemeTap,
          ),
          const SizedBox(height: 22),
          _SidebarActionButton(
            icon: appSettingsItem.icon,
            label: appSettingsItem.label,
            active: widget.currentPath == appSettingsItem.path,
            onTap: () => context.go(appSettingsItem.path),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatefulWidget {
  const _BottomNavigation({required this.currentPath});

  final String currentPath;

  @override
  State<_BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<_BottomNavigation> {
  int _secretTapCount = 0;

  void _handleThemeTap() {
    _secretTapCount += 1;
    if (_secretTapCount >= 7) {
      _secretTapCount = 0;
      context.go('/secret-document');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xF2090909),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final item in [...appNavItems, appSettingsItem])
              Expanded(
                child: _MobileNavButton(
                  item: item,
                  active: item.path == widget.currentPath,
                ),
              ),
            Expanded(
              child: _MobileActionButton(
                icon: Icons.dark_mode_outlined,
                label: 'Mode sombre',
                onTap: _handleThemeTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileActionButton extends StatelessWidget {
  const _MobileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.45),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SidebarNavButton extends StatelessWidget {
  const _SidebarNavButton({required this.item, required this.active});

  final AppNavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: () => context.go(item.path),
        child: SizedBox(
          height: 56,
          width: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                item.icon,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                size: 24,
              ),
              if (active)
                const Positioned(
                  left: 0,
                  child: SizedBox(
                    width: 4,
                    height: 32,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.accent),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 1,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SidebarActionButton extends StatelessWidget {
  const _SidebarActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: active
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.40),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _MobileNavButton extends StatelessWidget {
  const _MobileNavButton({required this.item, required this.active});

  final AppNavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(item.path),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                item.icon,
                color: active
                    ? Colors.black
                    : Colors.white.withValues(alpha: 0.45),
                size: 22,
              ),
              if (active)
                const Positioned(
                  bottom: 6,
                  child: SizedBox(
                    width: 4,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
