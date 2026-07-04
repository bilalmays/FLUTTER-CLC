import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/utils/date_money_formatters.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_card.dart';
import 'package:car_luxe_cleaning_flutter/features/subscriptions/data/subscription_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/subscriptions/domain/subscription_plan_meta.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/subscription.dart';
import 'package:car_luxe_cleaning_flutter/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CrmModule { subscriptions, courtesy }

enum SubscriptionView { list, timeline, upcoming, renewals }

class SubscriptionsPage extends ConsumerStatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  ConsumerState<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends ConsumerState<SubscriptionsPage> {
  CrmModule? _activeModule;
  SubscriptionView _view = SubscriptionView.list;
  bool _loading = true;
  String? _error;
  String? _pendingVisitId;
  bool _isImporting = false;
  List<SubscriptionBundle> _bundles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repository = ref.read(subscriptionRepositoryProvider);
      final bundles = await repository.listSubscriptions();
      if (!mounted) return;
      setState(() {
        _bundles = bundles;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addVisit(SubscriptionBundle bundle) async {
    setState(() => _pendingVisitId = bundle.subscription.id);
    try {
      final repository = ref.read(subscriptionRepositoryProvider);
      final updated = await repository.addVisit(
        bundle.subscription.id,
        DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _bundles = [
          for (final item in _bundles)
            if (item.subscription.id == updated.subscription.id)
              updated
            else
              item,
        ];
      });
    } finally {
      if (mounted) setState(() => _pendingVisitId = null);
    }
  }

  Future<void> _importExcelSubscriptions() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final created = await ref
          .read(subscriptionRepositoryProvider)
          .importExcelSeed();
      await _load();
      if (!mounted) return;
      _showSnack(
        created > 0
            ? '$created abonnement${created > 1 ? 's' : ''} importe${created > 1 ? 's' : ''}.'
            : 'Aucun nouvel abonnement importe. Donnees deja presentes.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack("L'import Excel n'a pas pu etre termine.");
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openNewSubscriptionDialog() async {
    if (_bundles.isEmpty) {
      _showSnack(
        'Ajoute un client et une voiture avant de creer un abonnement.',
      );
      return;
    }
    final result = await showDialog<_NewSubscriptionResult>(
      context: context,
      builder: (context) => _NewSubscriptionDialog(bundles: _bundles),
    );
    if (result == null || !mounted) return;

    final created = await ref
        .read(subscriptionRepositoryProvider)
        .createSubscription(
          source: result.source,
          plan: result.plan,
          startDate: result.startDate,
          amountPaid: result.amountPaid,
        );
    if (!mounted) return;
    setState(() {
      _bundles = [created, ..._bundles];
      _view = SubscriptionView.list;
      _activeModule = CrmModule.subscriptions;
    });
    _showSnack('Abonnement cree pour ${created.client.name}.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final activeTitle = switch (_activeModule) {
      CrmModule.subscriptions => 'Abonnements',
      CrmModule.courtesy => 'Voiture de courtoisie',
      null => 'CRM',
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_activeModule != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF71717A),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  onPressed: () => setState(() => _activeModule = null),
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  label: const Text('RETOUR'),
                ),
              Text(
                activeTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  height: 0.96,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (_activeModule == null)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        Responsive.isMobile(context) ||
                            constraints.maxWidth < 720
                        ? 1
                        : 2;
                    final gap = 16.0;
                    final width =
                        (constraints.maxWidth - (gap * (columns - 1))) /
                        columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        _CrmModuleCard(
                          width: width,
                          icon: Icons.workspace_premium_outlined,
                          label: 'Abonnements',
                          note:
                              'Clients abonnes, plan, paiements, passages et fin de contrat.',
                          onTap: () => setState(
                            () => _activeModule = CrmModule.subscriptions,
                          ),
                        ),
                        _CrmModuleCard(
                          width: width,
                          icon: Icons.directions_car_filled_outlined,
                          label: 'Voiture de courtoisie',
                          note:
                              'Suivi des voitures pretees, disponibilites et retours.',
                          onTap: () => setState(
                            () => _activeModule = CrmModule.courtesy,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          else if (_activeModule == CrmModule.courtesy)
            const _CourtesyPanel()
          else
            _buildSubscriptionsPanel(isMobile),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsPanel(bool isMobile) {
    return AppCard(
      color: const Color(0xFF18181B),
      borderColor: const Color(0x1CFFFFFF),
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUIVI ABONNEMENT',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Clients abonnes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      height: 0.98,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              if (!isMobile)
                _HeaderActions(
                  view: _view,
                  onViewChanged: (value) => setState(() => _view = value),
                  isImporting: _isImporting,
                  onImportExcel: _importExcelSubscriptions,
                  onCreateSubscription: _openNewSubscriptionDialog,
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 20),
            _HeaderActions(
              view: _view,
              onViewChanged: (value) => setState(() => _view = value),
              isImporting: _isImporting,
              onImportExcel: _importExcelSubscriptions,
              onCreateSubscription: _openNewSubscriptionDialog,
              isMobile: true,
            ),
          ],
          const SizedBox(height: 22),
          const Divider(color: Color(0x33E5E7EB)),
          const SizedBox(height: 22),
          if (_loading)
            const _LoadingState()
          else if (_error != null)
            _ErrorState(message: _error!)
          else ...[
            _StatsGrid(bundles: _bundles),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: switch (_view) {
                SubscriptionView.list => _SubscriptionList(
                  bundles: _bundles,
                  pendingVisitId: _pendingVisitId,
                  onAddVisit: _addVisit,
                ),
                SubscriptionView.timeline => _TimelineView(bundles: _bundles),
                SubscriptionView.upcoming => _SubscriptionList(
                  bundles: [..._bundles]
                    ..sort((a, b) => a.nextVisit.compareTo(b.nextVisit)),
                  pendingVisitId: _pendingVisitId,
                  onAddVisit: _addVisit,
                  compactHeader: 'Prochains passages',
                ),
                SubscriptionView.renewals => _SubscriptionList(
                  bundles: _bundles
                      .where((bundle) => _healthFor(bundle).isActionable)
                      .toList(),
                  pendingVisitId: _pendingVisitId,
                  onAddVisit: _addVisit,
                  compactHeader: 'A renouveler',
                ),
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CrmModuleCard extends StatelessWidget {
  const _CrmModuleCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.note,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 138),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF09090A),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SizedBox(
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x1AFFFFFF)),
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
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x1AFFFFFF)),
                      ),
                      child: Icon(icon, color: AppColors.accent, size: 21),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      note,
                      style: const TextStyle(
                        color: Color(0xFF71717A),
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

class _CourtesyPanel extends StatelessWidget {
  const _CourtesyPanel();

  @override
  Widget build(BuildContext context) {
    const cars = [
      ('Fiat 500', '1-CLC-001', 'Disponible'),
      ('VW Polo', '1-CLC-002', 'Reservee'),
      ('Toyota Yaris', '1-CLC-003', 'Entretien'),
    ];

    return AppCard(
      color: const Color(0xFF18181B),
      borderColor: const Color(0x1CFFFFFF),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FLOTTE INTERNE',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Voitures de courtoisie',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 0.98,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  Responsive.isMobile(context) || constraints.maxWidth < 760
                  ? 1
                  : 3;
              final gap = 14.0;
              final width =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final car in cars)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF202024),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.11),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_car_filled_outlined,
                              color: AppColors.accent,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    car.$1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    car.$2,
                                    style: const TextStyle(
                                      color: Color(0xFF71717A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: car.$3,
                              color: AppColors.accent.withValues(alpha: 0.12),
                              textColor: AppColors.accent,
                            ),
                          ],
                        ),
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
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.view,
    required this.onViewChanged,
    required this.isImporting,
    required this.onImportExcel,
    required this.onCreateSubscription,
    this.isMobile = false,
  });

  final SubscriptionView view;
  final ValueChanged<SubscriptionView> onViewChanged;
  final bool isImporting;
  final VoidCallback onImportExcel;
  final VoidCallback onCreateSubscription;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final tabs = {
      SubscriptionView.list: 'Liste',
      SubscriptionView.timeline: '12 mois',
      SubscriptionView.upcoming: 'Prochains',
      SubscriptionView.renewals: 'Renouvel.',
    };

    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            spacing: 4,
            children: [
              for (final entry in tabs.entries)
                ChoiceChip(
                  label: Text(entry.value.toUpperCase()),
                  selected: view == entry.key,
                  onSelected: (_) => onViewChanged(entry.key),
                  selectedColor: Colors.white,
                  backgroundColor: Colors.transparent,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: view == entry.key
                        ? AppColors.navy
                        : const Color(0xFFA1A1AA),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontSize: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: BorderSide.none,
                  ),
                ),
            ],
          ),
        ),
        _CrmToolbarButton(
          label: isImporting ? 'Import...' : 'Importer Excel',
          icon: Icons.upload_file_rounded,
          primary: false,
          onPressed: onImportExcel,
        ),
        _CrmToolbarButton(
          label: 'Nouvel abonnement',
          icon: Icons.add_rounded,
          primary: true,
          onPressed: onCreateSubscription,
        ),
      ],
    );

    if (isMobile) return controls;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: controls,
    );
  }
}

class _CrmToolbarButton extends StatelessWidget {
  const _CrmToolbarButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(primary ? 14 : 17),
        onTap: onPressed,
        child: Container(
          constraints: BoxConstraints(minHeight: primary ? 52 : 58),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: primary
                ? Colors.white
                : Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(primary ? 14 : 17),
            border: Border.all(
              color: primary
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: primary ? AppColors.navy : Colors.white,
              ),
              const SizedBox(width: 9),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: primary ? AppColors.navy : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewSubscriptionResult {
  const _NewSubscriptionResult({
    required this.source,
    required this.plan,
    required this.startDate,
    required this.amountPaid,
  });

  final SubscriptionBundle source;
  final SubscriptionPlan plan;
  final DateTime startDate;
  final int amountPaid;
}

class _NewSubscriptionDialog extends StatefulWidget {
  const _NewSubscriptionDialog({required this.bundles});

  final List<SubscriptionBundle> bundles;

  @override
  State<_NewSubscriptionDialog> createState() => _NewSubscriptionDialogState();
}

class _NewSubscriptionDialogState extends State<_NewSubscriptionDialog> {
  late SubscriptionBundle _source = widget.bundles.first;
  SubscriptionPlan _plan = SubscriptionPlan.platinium;
  DateTime _startDate = DateTime.now();
  late final TextEditingController _amountController = TextEditingController(
    text: metaForPlan(_plan).price.toString(),
  );

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount =
        int.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        metaForPlan(_plan).price;
    Navigator.of(context).pop(
      _NewSubscriptionResult(
        source: _source,
        plan: _plan,
        startDate: _startDate,
        amountPaid: amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Nouvel abonnement', style: AppTextStyles.cardTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<SubscriptionBundle>(
              initialValue: _source,
              decoration: const InputDecoration(labelText: 'CLIENT / VOITURE'),
              items: [
                for (final bundle in widget.bundles)
                  DropdownMenuItem(
                    value: bundle,
                    child: Text(
                      '${bundle.client.name} - ${bundle.vehicle.make} ${bundle.vehicle.model}'
                          .trim(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _source = value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<SubscriptionPlan>(
              initialValue: _plan,
              decoration: const InputDecoration(labelText: 'PLAN'),
              items: [
                for (final entry in subscriptionPlanMeta.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      '${entry.value.label} - ${formatMoney(entry.value.price)}',
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _plan = value;
                  _amountController.text = metaForPlan(value).price.toString();
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'MONTANT PAYE'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'DATE DEBUT'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatDate(_startDate),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          onPressed: _submit,
          child: const Text('Creer'),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.bundles});

  final List<SubscriptionBundle> bundles;

  @override
  Widget build(BuildContext context) {
    final expiring = bundles
        .where((bundle) => _healthFor(bundle).isActionable)
        .length;
    final upcoming = bundles
        .where((bundle) => daysUntil(bundle.nextVisit) >= 0)
        .length;
    final revenue = bundles.fold<int>(
      0,
      (sum, item) => sum + (item.subscription.amountPaid ?? 0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 760 ? 2 : 4;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _StatTile(
              width: width,
              icon: Icons.workspace_premium_outlined,
              label: 'Actifs',
              value: '${bundles.length}',
              detail: '$expiring a suivre',
            ),
            _StatTile(
              width: width,
              icon: Icons.warning_amber_rounded,
              label: 'A renouveler',
              value: '$expiring',
              detail: expiring == 0
                  ? 'Aucun risque'
                  : 'Plus proche: ${formatDate(_nearestRenewal(bundles))}',
            ),
            _StatTile(
              width: width,
              icon: Icons.schedule_rounded,
              label: 'Prochains passages',
              value: '$upcoming',
              detail: 'Prochain: ${formatDate(_nearestVisit(bundles))}',
            ),
            _StatTile(
              width: width,
              icon: Icons.euro_rounded,
              label: 'Encaisse',
              value: formatMoney(revenue),
              detail: '${bundles.length} abonnements',
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF202024),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: AppColors.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionList extends StatelessWidget {
  const _SubscriptionList({
    required this.bundles,
    required this.pendingVisitId,
    required this.onAddVisit,
    this.compactHeader,
  });

  final List<SubscriptionBundle> bundles;
  final String? pendingVisitId;
  final ValueChanged<SubscriptionBundle> onAddVisit;
  final String? compactHeader;

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) {
      return const AppCard(
        color: Color(0xFF202024),
        borderColor: Color(0x1CFFFFFF),
        child: Text(
          'Aucun abonnement dans cette vue.',
          style: TextStyle(
            color: Color(0xFFA1A1AA),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      key: ValueKey(compactHeader ?? 'list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compactHeader != null) ...[
          Text(
            compactHeader!.toUpperCase(),
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 14),
        ],
        for (final bundle in bundles) ...[
          _SubscriptionRow(
            bundle: bundle,
            loading: pendingVisitId == bundle.subscription.id,
            onAddVisit: () => onAddVisit(bundle),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    required this.bundle,
    required this.loading,
    required this.onAddVisit,
  });

  final SubscriptionBundle bundle;
  final bool loading;
  final VoidCallback onAddVisit;

  @override
  Widget build(BuildContext context) {
    final isCompact =
        Responsive.isMobile(context) || MediaQuery.sizeOf(context).width < 1100;
    final meta = metaForPlan(bundle.subscription.plan);
    final health = _healthFor(bundle);
    final progress = bundle.progress;

    final details = [
      _InfoBlock(
        label: 'Statut',
        child: StatusBadge(
          label: health.label,
          color: health.color,
          textColor: health.textColor,
        ),
      ),
      _InfoBlock(
        label: 'Paye',
        value: formatMoney(bundle.subscription.amountPaid ?? 0),
      ),
      _InfoBlock(
        label: 'Passages',
        value: '${bundle.visitCount} / 12',
        detail: 'Dernier: ${formatDate(bundle.lastVisit)}',
      ),
      _InfoBlock(
        label: 'Renouvellement',
        value: formatDate(bundle.subscription.endDate),
        detail: health.detail,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF202024),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SubscriptionIdentity(bundle: bundle, meta: meta),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  color: meta.color,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  minHeight: 8,
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 18, runSpacing: 18, children: details),
                const SizedBox(height: 18),
                _CrmMiniButton(
                  label: loading ? 'Ajout...' : 'Passage',
                  icon: Icons.check_rounded,
                  onPressed: loading ? null : onAddVisit,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _SubscriptionIdentity(bundle: bundle, meta: meta),
                ),
                Expanded(
                  flex: 7,
                  child: Row(
                    children: [
                      for (final detail in details) Expanded(child: detail),
                    ],
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        value: progress,
                        color: meta.color,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 18),
                      _CrmMiniButton(
                        label: loading ? 'Ajout...' : 'Passage',
                        icon: Icons.check_rounded,
                        onPressed: loading ? null : onAddVisit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SubscriptionIdentity extends StatelessWidget {
  const _SubscriptionIdentity({required this.bundle, required this.meta});

  final SubscriptionBundle bundle;
  final SubscriptionPlanMeta meta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 70,
          decoration: BoxDecoration(
            color: meta.color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bundle.client.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${bundle.vehicle.displayName} - ${bundle.vehicle.displayPlate}',
                style: const TextStyle(
                  color: Color(0xFFA1A1AA),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              StatusBadge(
                label: meta.label,
                color: AppColors.accent.withValues(alpha: 0.12),
                textColor: AppColors.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CrmMiniButton extends StatelessWidget {
  const _CrmMiniButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label.toUpperCase()),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, this.value, this.detail, this.child});

  final String label;
  final String? value;
  final String? detail;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 8),
          child ??
              Text(
                value ?? '-',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFA1A1AA),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.bundles});

  final List<SubscriptionBundle> bundles;

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (index) => DateTime(2026, index + 1));

    return SingleChildScrollView(
      key: const ValueKey('timeline'),
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF202024),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 250),
                for (final month in months)
                  SizedBox(
                    width: 76,
                    child: Text(
                      DateFormatMonth.label(month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final bundle in bundles)
              _TimelineRow(bundle: bundle, months: months),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.bundle, required this.months});

  final SubscriptionBundle bundle;
  final List<DateTime> months;

  @override
  Widget build(BuildContext context) {
    final color = metaForPlan(bundle.subscription.plan).color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 250,
            child: Text(
              bundle.client.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (final month in months)
            Container(
              width: 68,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _isActiveInMonth(bundle, month)
                    ? color
                    : Colors.white.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
        ],
      ),
    );
  }
}

class DateFormatMonth {
  const DateFormatMonth._();

  static String label(DateTime date) {
    const labels = [
      'JAN',
      'FEV',
      'MAR',
      'AVR',
      'MAI',
      'JUN',
      'JUL',
      'AOU',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return labels[date.month - 1];
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFF202024),
      borderColor: Color(0x3DB42318),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFFB4AB),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SubscriptionHealth {
  const _SubscriptionHealth({
    required this.label,
    required this.detail,
    required this.color,
    required this.textColor,
    required this.isActionable,
  });

  final String label;
  final String detail;
  final Color color;
  final Color textColor;
  final bool isActionable;
}

_SubscriptionHealth _healthFor(SubscriptionBundle bundle) {
  final days = daysUntil(bundle.subscription.endDate);
  if (days < 0) {
    return _SubscriptionHealth(
      label: 'Expire',
      detail: 'Depuis ${days.abs()} jours',
      color: const Color(0xFFFFE8E6),
      textColor: AppColors.danger,
      isActionable: true,
    );
  }
  if (days <= 30) {
    return _SubscriptionHealth(
      label: 'Expire bientot',
      detail: 'Dans $days jours',
      color: const Color(0xFFFFF5E6),
      textColor: AppColors.gold,
      isActionable: true,
    );
  }
  return _SubscriptionHealth(
    label: 'Actif',
    detail: 'Dans $days jours',
    color: const Color(0xFFEAF8F0),
    textColor: AppColors.success,
    isActionable: false,
  );
}

DateTime? _nearestRenewal(List<SubscriptionBundle> bundles) {
  final actionable =
      bundles.where((bundle) => _healthFor(bundle).isActionable).toList()..sort(
        (a, b) => a.subscription.endDate.compareTo(b.subscription.endDate),
      );
  return actionable.isEmpty ? null : actionable.first.subscription.endDate;
}

DateTime? _nearestVisit(List<SubscriptionBundle> bundles) {
  final upcoming =
      bundles.where((bundle) => daysUntil(bundle.nextVisit) >= 0).toList()
        ..sort((a, b) => a.nextVisit.compareTo(b.nextVisit));
  return upcoming.isEmpty ? null : upcoming.first.nextVisit;
}

bool _isActiveInMonth(SubscriptionBundle bundle, DateTime month) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1, 0);
  return !bundle.subscription.startDate.isAfter(end) &&
      !bundle.subscription.endDate.isBefore(start);
}
