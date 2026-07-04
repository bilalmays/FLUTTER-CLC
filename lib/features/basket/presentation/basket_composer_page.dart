import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/utils/date_money_formatters.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_button.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_card.dart';
import 'package:car_luxe_cleaning_flutter/features/basket/data/service_catalog.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BasketComposerPage extends StatefulWidget {
  const BasketComposerPage({super.key});

  @override
  State<BasketComposerPage> createState() => _BasketComposerPageState();
}

class _BasketComposerPageState extends State<BasketComposerPage> {
  int _step = 1;
  CatalogVehicleSize _size = CatalogVehicleSize.s;
  String _categoryId = officialServiceCategories.first.id;
  final Map<String, int> _selected = {};

  ServiceCategory get _activeCategory => officialServiceCategories.firstWhere(
    (category) => category.id == _categoryId,
  );

  int get _total {
    var total = 0;
    for (final category in officialServiceCategories) {
      for (final service in category.services) {
        final quantity = _selected[service.id] ?? 0;
        total += quantity * service.price.resolve(_size);
      }
    }
    return total;
  }

  bool get _canGoNext => _step != 3 || _selected.isNotEmpty;

  void _goNext() {
    if (_step >= 4 || !_canGoNext) return;
    setState(() => _step += 1);
  }

  void _goBack() {
    if (_step <= 1) return;
    setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PANIER',
                        style: TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          text: 'CAR ',
                          children: [
                            TextSpan(
                              text: 'LUXE',
                              style: TextStyle(color: AppColors.accent),
                            ),
                            TextSpan(text: ' CLEANING'),
                          ],
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.accent,
                  size: isMobile ? 24 : 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _BasketStepHeader(step: _step),
          const SizedBox(height: 18),
          _BasketStepCard(
            accentLabel: 'Etape $_step / 4',
            title: switch (_step) {
              1 => 'Choisir la prestation',
              2 => 'Gabarit du vehicule',
              3 => 'Personnaliser la prestation',
              _ => 'Finaliser le panier',
            },
            subtitle: switch (_step) {
              1 => 'Selectionne la famille de services avant le gabarit.',
              2 => 'Selectionne le format adapte a ton vehicule.',
              3 => 'Ajoute les services utiles avant de passer au devis.',
              _ => 'Verifie le panier puis continue vers le module devis.',
            },
            child: switch (_step) {
              1 => _CategoryGrid(
                value: _categoryId,
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              2 => _SizeSelector(
                value: _size,
                onChanged: (value) => setState(() => _size = value),
              ),
              3 => LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 980;
                  final services = _ServiceList(
                    category: _activeCategory,
                    size: _size,
                    selected: _selected,
                    onChanged: (id, quantity) {
                      setState(() {
                        if (quantity <= 0) {
                          _selected.remove(id);
                        } else {
                          _selected[id] = quantity;
                        }
                      });
                    },
                  );
                  final summary = _BasketSummary(
                    selected: _selected,
                    size: _size,
                    total: _total,
                    compact: true,
                  );
                  if (!twoColumns) {
                    return Column(
                      children: [services, const SizedBox(height: 18), summary],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: services),
                      const SizedBox(width: 18),
                      Expanded(flex: 3, child: summary),
                    ],
                  );
                },
              ),
              _ => _BasketSummary(
                selected: _selected,
                size: _size,
                total: _total,
              ),
            },
          ),
          const SizedBox(height: 18),
          _BasketStepActions(
            step: _step,
            canNext: _canGoNext,
            canContinue: _selected.isNotEmpty,
            onBack: _goBack,
            onNext: _goNext,
          ),
        ],
      ),
    );
  }
}

class _BasketStepHeader extends StatelessWidget {
  const _BasketStepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Prestation', 'Gabarit', 'Services', 'Devis'];
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFF09090B),
      borderColor: const Color(0x1AFFFFFF),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index += 1) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index + 1 == step
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: index + 1 == step
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  labels[index].toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: index + 1 == step ? Colors.black : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            if (index < labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _BasketStepCard extends StatelessWidget {
  const _BasketStepCard({
    required this.accentLabel,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String accentLabel;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFF050505),
      borderColor: const Color(0x1AFFFFFF),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.accent, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accentLabel.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720
            ? 1
            : constraints.maxWidth < 1080
            ? 2
            : 3;
        final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final category in officialServiceCategories)
              SizedBox(
                width: width,
                child: _CategoryCard(
                  category: category,
                  selected: category.id == value,
                  onTap: () => onChanged(category.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ServiceCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      category.label.toUpperCase(),
                      style: TextStyle(
                        color: selected ? AppColors.accent : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  _SelectionDot(selected: selected),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '${category.services.length} prestation(s)',
                style: AppTextStyles.body.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Lancer'.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white70,
                    size: 13,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: selected ? AppColors.accent : Colors.white24),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.black)
          : null,
    );
  }
}

class _SizeSelector extends StatelessWidget {
  const _SizeSelector({required this.value, required this.onChanged});

  final CatalogVehicleSize value;
  final ValueChanged<CatalogVehicleSize> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720 ? 1 : 3;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _SizeCard(
              width: width,
              size: CatalogVehicleSize.s,
              title: 'Taille S',
              subtitle: 'Citadine',
              examples: 'Fiat 500, Polo, Yaris',
              selected: value == CatalogVehicleSize.s,
              onTap: () => onChanged(CatalogVehicleSize.s),
            ),
            _SizeCard(
              width: width,
              size: CatalogVehicleSize.m,
              title: 'Taille M',
              subtitle: 'Berline / compacte',
              examples: 'Golf, Classe A, Serie 1',
              selected: value == CatalogVehicleSize.m,
              onTap: () => onChanged(CatalogVehicleSize.m),
            ),
            _SizeCard(
              width: width,
              size: CatalogVehicleSize.l,
              title: 'Taille L',
              subtitle: 'SUV / grande berline / van',
              examples: 'Q5, Serie 5, GLC, Transporter',
              selected: value == CatalogVehicleSize.l,
              onTap: () => onChanged(CatalogVehicleSize.l),
            ),
          ],
        );
      },
    );
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({
    required this.width,
    required this.size,
    required this.title,
    required this.subtitle,
    required this.examples,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final CatalogVehicleSize size;
  final String title;
  final String subtitle;
  final String examples;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final letter = switch (size) {
      CatalogVehicleSize.s => 'S',
      CatalogVehicleSize.m => 'M',
      CatalogVehicleSize.l => 'L',
    };

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.10),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        blurRadius: 28,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppColors.accent.withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.directions_car_outlined,
                        color: selected ? AppColors.accent : Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      letter,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: AppTextStyles.cardTitle.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    color: selected ? Colors.white70 : Colors.white54,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  examples,
                  style: TextStyle(
                    color: selected ? Colors.white70 : Colors.white60,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BasketStepActions extends StatelessWidget {
  const _BasketStepActions({
    required this.step,
    required this.canNext,
    required this.canContinue,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final bool canNext;
  final bool canContinue;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Precedent',
            icon: Icons.arrow_back_rounded,
            tone: AppButtonTone.secondary,
            onPressed: step <= 1 ? null : onBack,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            label: step >= 4 ? 'Continuer' : 'Suivant',
            icon: step >= 4
                ? Icons.arrow_forward_rounded
                : Icons.keyboard_arrow_right_rounded,
            onPressed: step >= 4
                ? canContinue
                      ? () => context.go('/documents?module=devis')
                      : null
                : canNext
                ? onNext
                : null,
          ),
        ),
      ],
    );
  }
}

class _ServiceList extends StatelessWidget {
  const _ServiceList({
    required this.category,
    required this.size,
    required this.selected,
    required this.onChanged,
  });

  final ServiceCategory category;
  final CatalogVehicleSize size;
  final Map<String, int> selected;
  final void Function(String id, int quantity) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final service in category.services)
          _ServiceRow(
            service: service,
            price: service.price.resolve(size),
            quantity: selected[service.id] ?? 0,
            onChanged: (quantity) => onChanged(service.id, quantity),
          ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.price,
    required this.quantity,
    required this.onChanged,
  });

  final ServiceCatalogEntry service;
  final int price;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? AppColors.accent
              : Colors.white.withValues(alpha: 0.10),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.label,
                  style: AppTextStyles.cardTitle.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  formatMoney(price),
                  style: AppTextStyles.body.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null,
            color: Colors.white,
            disabledColor: Colors.white24,
            icon: const Icon(Icons.remove_rounded),
          ),
          Container(
            width: 42,
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(quantity + 1),
            color: AppColors.accent,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _BasketSummary extends StatelessWidget {
  const _BasketSummary({
    required this.selected,
    required this.size,
    required this.total,
    this.compact = false,
  });

  final Map<String, int> selected;
  final CatalogVehicleSize size;
  final int total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selectedEntries = <({ServiceCatalogEntry service, int quantity})>[];
    for (final category in officialServiceCategories) {
      for (final service in category.services) {
        final quantity = selected[service.id] ?? 0;
        if (quantity > 0) {
          selectedEntries.add((service: service, quantity: quantity));
        }
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF050505),
      borderColor: AppColors.accent.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panier actuel'.toUpperCase(),
            style: AppTextStyles.eyebrow.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 18),
          if (selectedEntries.isEmpty)
            const Text(
              'Selectionne une prestation pour preparer un devis.',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            )
          else
            for (final entry in selectedEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.quantity} x ${entry.service.label}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(
                        entry.quantity * entry.service.price.resolve(size),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 18),
          const Text(
            'TOTAL ACTUEL',
            style: TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(total),
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 34,
              fontWeight: FontWeight.w300,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 22),
            AppButton(
              label: 'Continuer',
              icon: Icons.arrow_forward_rounded,
              expanded: true,
              onPressed: selectedEntries.isEmpty
                  ? null
                  : () => context.go('/documents?module=devis'),
            ),
          ],
        ],
      ),
    );
  }
}
