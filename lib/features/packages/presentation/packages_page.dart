import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/utils/date_money_formatters.dart';
import 'package:car_luxe_cleaning_flutter/features/basket/data/service_catalog.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:flutter/material.dart';

class PackagesPage extends StatelessWidget {
  const PackagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final colors = ClcThemeColors.of(context);
    final columns = isMobile ? 1 : 3;
    final groups = _packageGroups
        .map((group) => (group: group, services: _servicesForGroup(group)))
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 18,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONFIGURATION',
                    style: TextStyle(
                      color: colors.focus,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Catalogue des Services',
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 46,
                      height: 0.96,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HeaderButton(
                    label: 'Sample_Data',
                    icon: Icons.storage_outlined,
                    muted: true,
                    onTap: () {},
                  ),
                  _HeaderButton(
                    label: 'Nouveau Service',
                    icon: Icons.add_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 44),
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = isMobile ? 18.0 : 28.0;
              final itemWidth =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in groups)
                    SizedBox(
                      width: itemWidth,
                      child: _PackageColumn(
                        group: item.group,
                        services: item.services,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static List<ServiceCatalogEntry> _servicesForGroup(_PackageGroup group) {
    return officialServiceCategories
        .where((category) => group.categoryIds.contains(category.id))
        .expand((category) => category.services)
        .toList();
  }
}

class _PackageGroup {
  const _PackageGroup({
    required this.label,
    required this.icon,
    required this.categoryIds,
  });

  final String label;
  final IconData icon;
  final Set<String> categoryIds;
}

const _packageGroups = [
  _PackageGroup(
    label: 'Protection & Ceramic',
    icon: Icons.shield_outlined,
    categoryIds: {'ceramique'},
  ),
  _PackageGroup(
    label: 'Interior Detailing',
    icon: Icons.auto_awesome_outlined,
    categoryIds: {'lavage', 'reconditionnement'},
  ),
  _PackageGroup(
    label: 'Exterior Care',
    icon: Icons.flash_on_outlined,
    categoryIds: {'polissage', 'supplements'},
  ),
];

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final background = muted ? Colors.transparent : colors.action;
    final foreground = muted ? colors.mutedStrong : colors.onAction;

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: muted ? colors.border : Colors.transparent,
            ),
            boxShadow: muted
                ? const []
                : [
                    BoxShadow(
                      color: colors.action.withValues(
                        alpha: colors.isLight ? 0.10 : 0.06,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageColumn extends StatelessWidget {
  const _PackageColumn({required this.group, required this.services});

  final _PackageGroup group;
  final List<ServiceCatalogEntry> services;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Icon(group.icon, color: colors.focus, size: 17),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.label.toUpperCase(),
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
              Text(
                '${services.length} ITEMS',
                style: TextStyle(
                  color: colors.mutedStrong,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (services.isEmpty)
          const _PackagePlaceholder()
        else
          for (var index = 0; index < services.length; index += 1) ...[
            _PackageCard(service: services[index]),
            if (index < services.length - 1) const SizedBox(height: 18),
          ],
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.service});

  final ServiceCatalogEntry service;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: colors.focus, width: 4),
          top: BorderSide(color: colors.border),
          right: BorderSide(color: colors.border),
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.label.toUpperCase(),
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 18,
                        height: 1.05,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _descriptionFor(service),
                      style: TextStyle(
                        color: colors.mutedStrong,
                        fontSize: 10,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _priceFor(service),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const _GhostIcon(icon: Icons.edit_outlined),
              const SizedBox(width: 4),
              const _GhostIcon(icon: Icons.delete_outline, danger: true),
            ],
          ),
        ],
      ),
    );
  }

  static String _priceFor(ServiceCatalogEntry service) {
    if (service.price.isFixed) return formatMoney(service.price.value ?? 0);
    final min = service.price.resolve(CatalogVehicleSize.s);
    final max = service.price.resolve(CatalogVehicleSize.l);
    return '${formatMoney(min)}\n${formatMoney(max)}';
  }

  static String _descriptionFor(ServiceCatalogEntry service) {
    if (service.price.isFixed) return 'Tarif fixe catalogue officiel.';
    return 'Tarif ajuste selon taille vehicule S / M / L.';
  }
}

class _GhostIcon extends StatelessWidget {
  const _GhostIcon({required this.icon, this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return IconButton(
      tooltip: danger ? 'Supprimer' : 'Modifier',
      onPressed: () {},
      icon: Icon(
        icon,
        size: 16,
        color: danger ? colors.danger : colors.mutedStrong,
      ),
    );
  }
}

class _PackagePlaceholder extends StatelessWidget {
  const _PackagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: colors.border, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sell_outlined, color: colors.mutedStrong, size: 34),
            const SizedBox(height: 14),
            Text(
              'PACKAGE_PLACEHOLDER',
              style: TextStyle(
                color: colors.mutedStrong,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
