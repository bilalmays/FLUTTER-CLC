import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final colors = ClcThemeColors.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                'CRM',
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 48,
                  height: 0.96,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  'CAR LUXE CLEANING',
                  style: TextStyle(
                    color: colors.focus,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = isMobile
                  ? 1
                  : constraints.maxWidth < 980
                  ? 2
                  : 3;
              final gap = 16.0;
              final width =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _DashboardTile(
                    width: width,
                    icon: Icons.shopping_bag_outlined,
                    title: 'Composer mon panier',
                    description:
                        'Catalogue officiel, tailles vehicule, prestations et total actuel.',
                    onTap: () => context.go('/basket'),
                  ),
                  _DashboardTile(
                    width: width,
                    icon: Icons.description_outlined,
                    title: 'Documents',
                    description:
                        'Devis, carnets, acomptes, etats des lieux et pick-up.',
                    onTap: () => context.go('/documents'),
                  ),
                  _DashboardTile(
                    width: width,
                    icon: Icons.groups_2_outlined,
                    title: 'Clients',
                    description:
                        'Recherche client, contacts, plaques et vehicules.',
                    onTap: () => context.go('/clients'),
                  ),
                  _DashboardTile(
                    width: width,
                    icon: Icons.business_center_outlined,
                    title: 'CRM',
                    description:
                        'Abonnements, passages, renouvellements et import Excel.',
                    onTap: () => context.go('/subscriptions'),
                  ),
                  _DashboardTile(
                    width: width,
                    icon: Icons.auto_awesome_rounded,
                    title: 'Assistant IA',
                    description:
                        'Conversation, photos et recommandations via Gemini.',
                    onTap: () => context.go('/assistant'),
                  ),
                  _DashboardTile(
                    width: width,
                    icon: Icons.settings_outlined,
                    title: 'Reglages',
                    description:
                        'Parametres, catalogue services, sauvegarde et modules admin.',
                    onTap: () => context.go('/settings'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 142),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SizedBox(
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: colors.border),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.surfaceRaised,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(icon, color: colors.focus, size: 20),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(
                        color: colors.mutedStrong,
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
