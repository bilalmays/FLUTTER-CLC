import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/app/theme_scope.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/presentation/auth_scope.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

void _openAdminRoute(BuildContext context) {
  final auth = AuthScope.maybeOf(context);
  if (auth?.session.isAdmin == true) {
    context.go('/secret-document');
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Acces reserve admin.')));
}

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
    final colors = ClcThemeColors.of(context);
    final pageColor = colors.isLight && currentPath == '/subscriptions'
        ? const Color(0xFFFAFBFE)
        : colors.bg;

    return Scaffold(
      backgroundColor: pageColor,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Row(
          children: [
            if (!isMobile)
              _SideNavigation(currentPath: currentPath)
                  .animate()
                  .fadeIn(duration: 420.ms)
                  .slideX(begin: -0.18, curve: Curves.easeOut),
            Expanded(
              child: Padding(
                padding: EdgeInsets.zero,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    color: pageColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMobile ? 0 : 32),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(Responsive.pagePadding(context)),
                    child: child.animate().fadeIn(duration: 420.ms, delay: 80.ms).moveY(begin: 18, curve: Curves.easeOut),
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
    AppThemeScope.of(context).toggleTheme();
    _secretTapCount += 1;
    if (_secretTapCount >= 7) {
      _secretTapCount = 0;
      _openAdminRoute(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final themeScope = AppThemeScope.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 100,
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: colors.shell,
        border: Border(right: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: colors.focus.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
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
            child: SingleChildScrollView(
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
          ),
          SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.focus,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: colors.focus, blurRadius: 8)],
              ),
            ),
          ),
          const SizedBox(height: 26),
          _SidebarActionButton(
            icon: themeScope.isLight
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            label: themeScope.isLight ? 'Mode sombre' : 'Mode clair',
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
    AppThemeScope.of(context).toggleTheme();
    _secretTapCount += 1;
    if (_secretTapCount >= 7) {
      _secretTapCount = 0;
      _openAdminRoute(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final themeScope = AppThemeScope.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.shell.withValues(alpha: colors.isLight ? 0.98 : 0.92),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: colors.borderStrong),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000).withValues(alpha: colors.isLight ? 0.10 : 0.28),
              blurRadius: 30,
              offset: const Offset(0, 14),
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
                icon: themeScope.isLight
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                label: themeScope.isLight ? 'Mode sombre' : 'Mode clair',
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
    final colors = ClcThemeColors.of(context);
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Icon(icon, color: colors.muted, size: 22),
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
    final colors = ClcThemeColors.of(context);
    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 64,
          width: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: active ? colors.focus : colors.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: colors.focus.withValues(alpha: 0.14),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
              ),
              Icon(
                item.icon,
                color: active ? colors.onFocus : colors.muted.withValues(alpha: 0.86),
                size: 24,
              ),
              if (active)
                Positioned(
                  left: 0,
                  child: SizedBox(
                    width: 4,
                    height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.focus,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 380.ms).moveY(begin: 6, curve: Curves.easeOut),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    return Container(
      width: 20,
      height: 1,
      decoration: BoxDecoration(
        color: colors.border,
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
    final colors = ClcThemeColors.of(context);
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
            color: active ? colors.focus : colors.muted,
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
    final colors = ClcThemeColors.of(context);
    return Tooltip(
      message: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(item.path),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: active ? colors.focus : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                item.icon,
                color: active ? colors.onFocus : colors.muted,
                size: 22,
              ),
              if (active)
                Positioned(
                  bottom: 6,
                  child: SizedBox(
                    width: 4,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.onFocus.withValues(alpha: 0.70),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 360.ms).moveY(begin: 8, curve: Curves.easeOut),
      ),
    );
  }
}
