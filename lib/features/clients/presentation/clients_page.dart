import 'dart:async';

import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_button.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_card.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/data/autoref_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/data/client_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/data/company_lookup_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/data/vehicle_catalog_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/domain/client_vehicle_bundle.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/client.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/vehicle.dart';
import 'package:car_luxe_cleaning_flutter/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum ClientKindFilter { all, pro, individual }

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _searchController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();
  ClientKindFilter _kindFilter = ClientKindFilter.all;
  bool _loading = true;
  String? _error;
  List<ClientVehicleBundle> _bundles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repository = ref.read(clientRepositoryProvider);
      final bundles = await repository.listClients();
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

  Future<void> _openClientDialog([ClientVehicleBundle? bundle]) async {
    final result = await showDialog<_ClientFormResult>(
      context: context,
      builder: (context) => _ClientFormDialog(client: bundle?.client),
    );
    if (result == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(clientRepositoryProvider)
          .upsertClient(
            id: bundle?.client.id,
            name: result.name,
            email: result.email,
            phone: result.phone,
            address: result.address,
            isProfessional: result.isProfessional,
            companyName: result.companyName,
            vatNumber: result.vatNumber,
          );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _archiveClient(ClientVehicleBundle bundle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'Archiver le client',
        message:
            'Le client restera dans les donnees locales, mais il ne sera plus affiche dans la liste active.',
        confirmLabel: 'Archiver',
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    await ref.read(clientRepositoryProvider).archiveClient(bundle.client.id);
    await _load();
  }

  Future<void> _openVehicleDialog(
    ClientVehicleBundle bundle, [
    Vehicle? vehicle,
  ]) async {
    final result = await showDialog<_VehicleFormResult>(
      context: context,
      builder: (context) =>
          _VehicleFormDialog(client: bundle.client, vehicle: vehicle),
    );
    if (result == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(clientRepositoryProvider)
          .upsertVehicle(
            id: vehicle?.id,
            clientId: bundle.client.id,
            make: result.make,
            model: result.model,
            year: result.year,
            licensePlate: result.licensePlate,
            vin: result.vin,
            color: result.color,
            size: result.size,
          );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'Supprimer la voiture',
        message: 'Cette voiture sera retiree de la fiche client.',
        confirmLabel: 'Supprimer',
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    await ref.read(clientRepositoryProvider).deleteVehicle(vehicle.id);
    await _load();
  }

  List<ClientVehicleBundle> get _filteredBundles {
    final search = _searchController.text.trim().toLowerCase();
    final vehicleQuery = _vehicleController.text.trim().toLowerCase();
    final plateQuery = _plateController.text.trim().toLowerCase();

    return _bundles.where((bundle) {
      if (_kindFilter == ClientKindFilter.pro &&
          !bundle.client.isProfessional) {
        return false;
      }
      if (_kindFilter == ClientKindFilter.individual &&
          bundle.client.isProfessional) {
        return false;
      }
      if (search.isNotEmpty && !bundle.searchIndex.contains(search)) {
        return false;
      }
      if (vehicleQuery.isNotEmpty) {
        final hit = bundle.vehicles.any(
          (vehicle) => [
            vehicle.make,
            vehicle.model,
            vehicle.color,
            vehicle.vin,
          ].whereType<String>().join(' ').toLowerCase().contains(vehicleQuery),
        );
        if (!hit) return false;
      }
      if (plateQuery.isNotEmpty) {
        final hit = bundle.vehicles.any(
          (vehicle) => vehicle.licensePlate.toLowerCase().contains(plateQuery),
        );
        if (!hit) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: EdgeInsets.all(isMobile ? 20 : 28),
            child: SectionHeader(
              eyebrow: 'Base client',
              title: 'Clients',
              subtitle:
                  'Recherche, vehicules, plaques et coordonnees repris de la logique TypeScript.',
              trailing: isMobile
                  ? null
                  : AppButton(
                      label: 'Nouveau client',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: _openClientDialog,
                    ),
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            child: Column(
              children: [
                _ClientFilters(
                  searchController: _searchController,
                  vehicleController: _vehicleController,
                  plateController: _plateController,
                  kindFilter: _kindFilter,
                  onKindChanged: (value) => setState(() => _kindFilter = value),
                  onChanged: () => setState(() {}),
                  onCreate: _openClientDialog,
                  isMobile: isMobile,
                ),
                const SizedBox(height: 22),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(color: AppColors.navy),
                  )
                else if (_error != null)
                  _ErrorState(message: _error!)
                else
                  _ClientTable(
                    bundles: _filteredBundles,
                    onEditClient: _openClientDialog,
                    onArchiveClient: _archiveClient,
                    onAddVehicle: _openVehicleDialog,
                    onEditVehicle: (bundle, vehicle) =>
                        _openVehicleDialog(bundle, vehicle),
                    onDeleteVehicle: _deleteVehicle,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Corbeille',
              icon: Icons.delete_outline_rounded,
              tone: AppButtonTone.secondary,
              onPressed: () => context.go('/trash'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientFilters extends StatelessWidget {
  const _ClientFilters({
    required this.searchController,
    required this.vehicleController,
    required this.plateController,
    required this.kindFilter,
    required this.onKindChanged,
    required this.onChanged,
    required this.onCreate,
    required this.isMobile,
  });

  final TextEditingController searchController;
  final TextEditingController vehicleController;
  final TextEditingController plateController;
  final ClientKindFilter kindFilter;
  final ValueChanged<ClientKindFilter> onKindChanged;
  final VoidCallback onChanged;
  final VoidCallback onCreate;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final filters = [
      _SearchField(
        label: 'Recherche',
        hint: 'Nom, email, telephone, societe',
        icon: Icons.search_rounded,
        controller: searchController,
        onChanged: onChanged,
      ),
      _SearchField(
        label: 'Vehicule',
        hint: 'BMW, Golf, noir...',
        icon: Icons.directions_car_filled_outlined,
        controller: vehicleController,
        onChanged: onChanged,
      ),
      _SearchField(
        label: 'Plaque',
        hint: '1-ABC-123',
        icon: Icons.tag_rounded,
        controller: plateController,
        onChanged: onChanged,
      ),
    ];

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: 'Tous',
          selected: kindFilter == ClientKindFilter.all,
          onTap: () => onKindChanged(ClientKindFilter.all),
        ),
        _FilterChip(
          label: 'Pro',
          selected: kindFilter == ClientKindFilter.pro,
          onTap: () => onKindChanged(ClientKindFilter.pro),
        ),
        _FilterChip(
          label: 'Perso',
          selected: kindFilter == ClientKindFilter.individual,
          onTap: () => onKindChanged(ClientKindFilter.individual),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        children: [
          for (final filter in filters) ...[filter, const SizedBox(height: 12)],
          Align(alignment: Alignment.centerLeft, child: chips),
          const SizedBox(height: 12),
          AppButton(
            label: 'Nouveau client',
            icon: Icons.person_add_alt_1_rounded,
            expanded: true,
            onPressed: onCreate,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: filters[0],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: filters[1],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: filters[2],
          ),
        ),
        chips,
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label.toUpperCase(),
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.muted),
      ),
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label.toUpperCase()),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.navy,
      backgroundColor: Colors.transparent,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      side: BorderSide(color: selected ? AppColors.navy : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _ClientTable extends StatelessWidget {
  const _ClientTable({
    required this.bundles,
    required this.onEditClient,
    required this.onArchiveClient,
    required this.onAddVehicle,
    required this.onEditVehicle,
    required this.onDeleteVehicle,
  });

  final List<ClientVehicleBundle> bundles;
  final ValueChanged<ClientVehicleBundle> onEditClient;
  final ValueChanged<ClientVehicleBundle> onArchiveClient;
  final ValueChanged<ClientVehicleBundle> onAddVehicle;
  final void Function(ClientVehicleBundle bundle, Vehicle vehicle)
  onEditVehicle;
  final ValueChanged<Vehicle> onDeleteVehicle;

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text('Aucun client trouve.', style: AppTextStyles.body),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const _TableHeader(),
          for (var index = 0; index < bundles.length; index += 1) ...[
            _ClientRow(
              bundle: bundles[index],
              onEditClient: onEditClient,
              onArchiveClient: onArchiveClient,
              onAddVehicle: onAddVehicle,
              onEditVehicle: onEditVehicle,
              onDeleteVehicle: onDeleteVehicle,
            ),
            if (index < bundles.length - 1) const _FadeDivider(),
          ],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 4, child: _HeaderLabel('Client')),
          SizedBox(width: 16),
          Expanded(flex: 3, child: _HeaderLabel('Contact')),
          SizedBox(width: 16),
          Expanded(flex: 4, child: _HeaderLabel('Vehicules')),
          SizedBox(width: 16),
          SizedBox(width: 52, child: _HeaderLabel('Ouvrir')),
        ],
      ),
    );
  }
}

class _FadeDivider extends StatelessWidget {
  const _FadeDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x00E5E7EB),
            Color(0xFFE5E7EB),
            Color(0xFFE5E7EB),
            Color(0x00E5E7EB),
          ],
          stops: [0, 0.10, 0.90, 1],
        ),
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(), style: AppTextStyles.eyebrow);
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.bundle,
    required this.onEditClient,
    required this.onArchiveClient,
    required this.onAddVehicle,
    required this.onEditVehicle,
    required this.onDeleteVehicle,
  });

  final ClientVehicleBundle bundle;
  final ValueChanged<ClientVehicleBundle> onEditClient;
  final ValueChanged<ClientVehicleBundle> onArchiveClient;
  final ValueChanged<ClientVehicleBundle> onAddVehicle;
  final void Function(ClientVehicleBundle bundle, Vehicle vehicle)
  onEditVehicle;
  final ValueChanged<Vehicle> onDeleteVehicle;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final actions = _RowActions(
      onEditClient: () => onEditClient(bundle),
      onAddVehicle: () => onAddVehicle(bundle),
      onArchiveClient: () => onArchiveClient(bundle),
    );

    final content = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ClientIdentity(client: bundle.client)),
                  const SizedBox(width: 12),
                  actions,
                ],
              ),
              const SizedBox(height: 16),
              _ClientContact(client: bundle.client),
              const SizedBox(height: 16),
              _VehicleLine(
                vehicles: bundle.vehicles,
                onEdit: (vehicle) => onEditVehicle(bundle, vehicle),
                onDelete: onDeleteVehicle,
              ),
            ],
          )
        : Row(
            children: [
              Expanded(flex: 4, child: _ClientIdentity(client: bundle.client)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _ClientContact(client: bundle.client)),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _VehicleLine(
                  vehicles: bundle.vehicles,
                  onEdit: (vehicle) => onEditVehicle(bundle, vehicle),
                  onDelete: onDeleteVehicle,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 52,
                child: Align(alignment: Alignment.centerRight, child: actions),
              ),
            ],
          );

    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 24,
        vertical: 20,
      ),
      child: content,
    );
  }
}

class _ClientIdentity extends StatelessWidget {
  const _ClientIdentity({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final company =
        client.isProfessional && (client.companyName ?? '').isNotEmpty
        ? client.companyName!
        : null;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: client.isProfessional
                ? AppColors.navy
                : AppColors.background,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _initialsFor(client),
            style: TextStyle(
              color: client.isProfessional
                  ? Colors.white
                  : const Color(0xFF3F3F46),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    client.isProfessional
                        ? Icons.apartment_rounded
                        : Icons.person_outline_rounded,
                    color: client.isProfessional
                        ? AppColors.gold
                        : AppColors.muted,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      client.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                (company ??
                        (client.isProfessional
                            ? 'Professionnel'
                            : 'Particulier'))
                    .toUpperCase(),
                style: AppTextStyles.eyebrow.copyWith(letterSpacing: 2.5),
                overflow: TextOverflow.ellipsis,
              ),
              if ((client.vatNumber ?? '').isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  'TVA ${client.vatNumber}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF4D7C0F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ClientContact extends StatelessWidget {
  const _ClientContact({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ContactLine(icon: Icons.phone_outlined, text: client.phone),
        _ContactLine(
          icon: Icons.mail_outline_rounded,
          text: client.email,
          fallback: 'Email non renseigne',
        ),
        if (client.address.trim().isNotEmpty)
          _ContactLine(icon: Icons.place_outlined, text: client.address),
      ],
    );
  }
}

class _RowActions extends StatefulWidget {
  const _RowActions({
    required this.onEditClient,
    required this.onAddVehicle,
    required this.onArchiveClient,
  });

  final VoidCallback onEditClient;
  final VoidCallback onAddVehicle;
  final VoidCallback onArchiveClient;

  @override
  State<_RowActions> createState() => _RowActionsState();
}

class _RowActionsState extends State<_RowActions> {
  bool _hovering = false;

  void _select(String value) {
    switch (value) {
      case 'edit':
        widget.onEditClient();
        return;
      case 'vehicle':
        widget.onAddVehicle();
        return;
      case 'archive':
        widget.onArchiveClient();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: PopupMenuButton<String>(
        tooltip: 'Actions client',
        color: Colors.white,
        elevation: 12,
        offset: const Offset(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: _select,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'edit',
            child: _MenuLine(icon: Icons.edit_rounded, label: 'Modifier'),
          ),
          PopupMenuItem(
            value: 'vehicle',
            child: _MenuLine(
              icon: Icons.directions_car_filled_outlined,
              label: 'Ajouter voiture',
            ),
          ),
          PopupMenuItem(
            value: 'archive',
            child: _MenuLine(icon: Icons.archive_outlined, label: 'Archiver'),
          ),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _hovering ? Colors.white : const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF0F172A,
                ).withValues(alpha: _hovering ? 0.14 : 0.08),
                blurRadius: _hovering ? 18 : 8,
                offset: Offset(0, _hovering ? 8 : 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.text,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.text),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.tone = _MiniIconTone.neutral,
    this.compact = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final _MiniIconTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final danger = tone == _MiniIconTone.danger;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          width: compact ? 24 : 38,
          height: compact ? 24 : 38,
          decoration: BoxDecoration(
            color: compact
                ? Colors.white.withValues(alpha: 0.72)
                : danger
                ? const Color(0xFFFFF2F1)
                : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(compact ? 999 : 14),
            border: compact
                ? null
                : Border.all(
                    color: danger
                        ? AppColors.danger.withValues(alpha: 0.18)
                        : AppColors.border,
                  ),
          ),
          child: Icon(
            icon,
            size: compact ? 13 : 18,
            color: danger ? AppColors.danger : AppColors.text,
          ),
        ),
      ),
    );
  }
}

enum _MiniIconTone { neutral, danger }

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.text,
    this.fallback = '-',
  });

  final IconData icon;
  final String text;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final value = text.trim().isEmpty ? fallback : text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF3F3F46),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleLine extends StatelessWidget {
  const _VehicleLine({
    required this.vehicles,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Vehicle> vehicles;
  final ValueChanged<Vehicle> onEdit;
  final ValueChanged<Vehicle> onDelete;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEF2F7)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 16,
              color: AppColors.gold,
            ),
            SizedBox(width: 8),
            Text(
              'Aucun vehicule',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.gold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF2F7)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final vehicle in vehicles)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 12,
                    color: AppColors.text,
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text.rich(
                      TextSpan(
                        text: vehicle.make.toUpperCase(),
                        children: [
                          TextSpan(
                            text: ' ${vehicle.model}'.toUpperCase(),
                            style: const TextStyle(color: Color(0xFF374151)),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        fontSize: 10,
                        letterSpacing: 0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A0F172A),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      vehicle.displayPlate,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _MiniIconButton(
                    tooltip: 'Modifier la voiture',
                    icon: Icons.edit_rounded,
                    onPressed: () => onEdit(vehicle),
                    compact: true,
                  ),
                  _MiniIconButton(
                    tooltip: 'Supprimer la voiture',
                    icon: Icons.delete_outline_rounded,
                    tone: _MiniIconTone.danger,
                    onPressed: () => onDelete(vehicle),
                    compact: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ClientFormResult {
  const _ClientFormResult({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.isProfessional,
    required this.companyName,
    required this.vatNumber,
  });

  final String name;
  final String email;
  final String phone;
  final String address;
  final bool isProfessional;
  final String companyName;
  final String vatNumber;
}

class _VehicleFormResult {
  const _VehicleFormResult({
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.vin,
    required this.color,
    required this.size,
  });

  final String make;
  final String model;
  final String year;
  final String licensePlate;
  final String vin;
  final String color;
  final VehicleSize? size;
}

class _ClientFormDialog extends ConsumerStatefulWidget {
  const _ClientFormDialog({this.client});

  final Client? client;

  @override
  ConsumerState<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<_ClientFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _companyController;
  late final TextEditingController _vatController;
  bool _isProfessional = false;
  bool _companyLoading = false;
  String? _companyError;
  String? _formError;
  Timer? _companyDebounce;
  List<CompanyLookupResult> _companyResults = const [];

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _nameController = TextEditingController(text: client?.name ?? '');
    _emailController = TextEditingController(text: client?.email ?? '');
    _phoneController = TextEditingController(text: client?.phone ?? '');
    _addressController = TextEditingController(text: client?.address ?? '');
    _companyController = TextEditingController(text: client?.companyName ?? '');
    _vatController = TextEditingController(text: client?.vatNumber ?? '');
    _isProfessional = client?.isProfessional ?? false;
  }

  @override
  void dispose() {
    _companyDebounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  String get _companyQuery {
    final vatDigits = _vatController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (vatDigits.length >= 5) return _vatController.text;
    return _companyController.text;
  }

  void _scheduleCompanySearch() {
    _companyDebounce?.cancel();
    _companyDebounce = Timer(
      const Duration(milliseconds: 350),
      _searchCompanies,
    );
  }

  Future<void> _searchCompanies() async {
    final query = _companyQuery.trim();
    if (query.length < 2 &&
        query.replaceAll(RegExp(r'[^0-9]'), '').length < 5) {
      if (!mounted) return;
      setState(() {
        _companyResults = const [];
        _companyError = null;
      });
      return;
    }

    setState(() {
      _companyLoading = true;
      _companyError = null;
    });
    try {
      final results = await ref
          .read(companyLookupRepositoryProvider)
          .search(query);
      if (!mounted) return;
      setState(() {
        _companyResults = results;
        _companyLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _companyError = 'Recherche BCE indisponible pour le moment.';
        _companyLoading = false;
      });
    }
  }

  void _selectCompany(CompanyLookupResult company) {
    setState(() {
      _isProfessional = true;
      _companyController.text = company.title;
      _vatController.text = company.taxNumber;
      if (company.address.trim().isNotEmpty) {
        _addressController.text = company.address.trim();
      }
      if (_emailController.text.trim().isEmpty &&
          company.email.trim().isNotEmpty) {
        _emailController.text = company.email.trim();
      }
      if (_phoneController.text.trim().isEmpty &&
          company.phone.trim().isNotEmpty) {
        _phoneController.text = company.phone.trim();
      }
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = company.contactPerson.trim().isNotEmpty
            ? company.contactPerson.trim()
            : company.title;
      }
      _companyResults = const [];
      _companyError = null;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _formError = 'Le nom et le telephone sont obligatoires.');
      return;
    }

    Navigator.of(context).pop(
      _ClientFormResult(
        name: name,
        email: _emailController.text.trim(),
        phone: phone,
        address: _addressController.text.trim(),
        isProfessional: _isProfessional,
        companyName: _isProfessional ? _companyController.text.trim() : '',
        vatNumber: _isProfessional ? _vatController.text.trim() : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogHeader(
                  title: widget.client == null
                      ? 'Creer client'
                      : 'Modifier client',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 26),
                _SegmentedChoice(
                  leftLabel: 'Particulier',
                  rightLabel: 'Professionnel',
                  rightSelected: _isProfessional,
                  onChanged: (value) => setState(() => _isProfessional = value),
                ),
                const SizedBox(height: 26),
                if (_isProfessional) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 720;
                      final vat = _FormField(
                        label: 'Numero TVA',
                        controller: _vatController,
                        hint: 'BE0123456789',
                        prefixIcon: Icons.badge_outlined,
                        onChanged: (_) => _scheduleCompanySearch(),
                      );
                      final company = _FormField(
                        label: 'Denomination societe',
                        controller: _companyController,
                        hint: 'Nom de societe',
                        prefixIcon: Icons.search_rounded,
                        onChanged: (_) => _scheduleCompanySearch(),
                      );
                      if (stacked) {
                        return Column(
                          children: [vat, const SizedBox(height: 14), company],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: vat),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 72,
                            child: AppButton(
                              label: 'BCE',
                              onPressed: _companyLoading
                                  ? null
                                  : () => _searchCompanies(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: company),
                        ],
                      );
                    },
                  ),
                  if (_companyLoading || _companyError != null) ...[
                    const SizedBox(height: 10),
                    _LookupStatus(
                      loading: _companyLoading,
                      error: _companyError,
                      success: _companyResults.isNotEmpty
                          ? '${_companyResults.length} suggestion(s) BCE'
                          : null,
                    ),
                  ],
                  if (_companyResults.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _CompanyResults(
                      results: _companyResults,
                      onSelected: _selectCompany,
                    ),
                  ],
                  const SizedBox(height: 22),
                ],
                if (_formError != null) ...[
                  _InlineError(message: _formError!),
                  const SizedBox(height: 18),
                ],
                _DialogGrid(
                  children: [
                    _FormField(
                      label: 'Nom complet / contact',
                      controller: _nameController,
                      hint: 'Nom du client',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    _FormField(
                      label: 'Email',
                      controller: _emailController,
                      hint: 'contact@exemple.be',
                      prefixIcon: Icons.mail_outline_rounded,
                    ),
                    _FormField(
                      label: 'Telephone',
                      controller: _phoneController,
                      hint: '+32 ...',
                      prefixIcon: Icons.phone_outlined,
                    ),
                    _FormField(
                      label: 'Adresse complete',
                      controller: _addressController,
                      hint: 'Rue, code postal, ville',
                      prefixIcon: Icons.place_outlined,
                      maxLines: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _DialogActions(
                  onCancel: () => Navigator.of(context).pop(),
                  onSubmit: _submit,
                  submitLabel: widget.client == null
                      ? 'Creer la fiche'
                      : 'Enregistrer',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleFormDialog extends ConsumerStatefulWidget {
  const _VehicleFormDialog({required this.client, this.vehicle});

  final Client client;
  final Vehicle? vehicle;

  @override
  ConsumerState<_VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends ConsumerState<_VehicleFormDialog> {
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _plateController;
  late final TextEditingController _vinController;
  late final TextEditingController _colorController;
  VehicleSize? _size;
  bool _autorefLoading = false;
  String? _autorefStatus;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _makeController = TextEditingController(text: vehicle?.make ?? '');
    _modelController = TextEditingController(text: vehicle?.model ?? '');
    _yearController = TextEditingController(text: vehicle?.year ?? '');
    _plateController = TextEditingController(text: vehicle?.licensePlate ?? '');
    _vinController = TextEditingController(text: vehicle?.vin ?? '');
    _colorController = TextEditingController(text: vehicle?.color ?? '');
    _size = vehicle?.size;
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _vinController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _applyAutoref(AutorefVehicleResult result) {
    setState(() {
      if (result.make.isNotEmpty) _makeController.text = result.make;
      if (result.model.isNotEmpty) _modelController.text = result.model;
      if (result.year.isNotEmpty) _yearController.text = result.year;
      if (result.licensePlate.isNotEmpty) {
        _plateController.text = result.licensePlate;
      }
      if (result.vin.isNotEmpty) _vinController.text = result.vin;
      if (result.color.isNotEmpty) _colorController.text = result.color;
      _autorefStatus = 'Informations AutoRef recuperees.';
    });
  }

  Future<void> _lookupPlate() async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty) {
      setState(() => _autorefStatus = 'Entre une plaque avant la recherche.');
      return;
    }
    await _lookup(() => ref.read(autorefRepositoryProvider).lookupPlate(plate));
  }

  Future<void> _lookupVin() async {
    final vin = _vinController.text.trim();
    if (vin.length < 10) {
      setState(
        () => _autorefStatus = 'Entre un VIN valide avant la recherche.',
      );
      return;
    }
    await _lookup(() => ref.read(autorefRepositoryProvider).lookupVin(vin));
  }

  Future<void> _lookup(Future<AutorefVehicleResult?> Function() loader) async {
    setState(() {
      _autorefLoading = true;
      _autorefStatus = null;
    });
    try {
      final result = await loader();
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _autorefLoading = false;
          _autorefStatus = 'Aucun resultat AutoRef.';
        });
        return;
      }
      _applyAutoref(result);
      setState(() => _autorefLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _autorefLoading = false;
        _autorefStatus = 'AutoRef indisponible pour le moment.';
      });
    }
  }

  void _submit() {
    final make = _makeController.text.trim();
    final model = _modelController.text.trim();
    if (make.isEmpty || model.isEmpty) {
      setState(() => _formError = 'La marque et le modele sont obligatoires.');
      return;
    }
    Navigator.of(context).pop(
      _VehicleFormResult(
        make: make,
        model: model,
        year: _yearController.text.trim(),
        licensePlate: _plateController.text.trim(),
        vin: _vinController.text.trim(),
        color: _colorController.text.trim(),
        size: _size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogHeader(
                  title: widget.vehicle == null
                      ? 'Ajouter voiture'
                      : 'Modifier voiture',
                  subtitle: widget.client.name,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 24),
                if (_formError != null) ...[
                  _InlineError(message: _formError!),
                  const SizedBox(height: 18),
                ],
                _DialogGrid(
                  children: [
                    _VehicleSuggestField(
                      label: 'Marque',
                      hint: 'BMW, Audi, Porsche...',
                      controller: _makeController,
                    ),
                    _VehicleSuggestField(
                      label: 'Modele',
                      hint: 'Serie 3, Q5, Golf...',
                      controller: _modelController,
                      brandController: _makeController,
                      models: true,
                    ),
                    _FormField(
                      label: 'Plaque',
                      controller: _plateController,
                      hint: '1-ABC-123',
                      prefixIcon: Icons.pin_outlined,
                    ),
                    _FormField(
                      label: 'Annee',
                      controller: _yearController,
                      hint: '2026',
                      prefixIcon: Icons.calendar_month_outlined,
                    ),
                    _FormField(
                      label: 'Couleur',
                      controller: _colorController,
                      hint: 'Noir, blanc...',
                      prefixIcon: Icons.palette_outlined,
                    ),
                    _FormField(
                      label: 'VIN',
                      controller: _vinController,
                      hint: 'Numero de chassis',
                      prefixIcon: Icons.qr_code_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SizeChip(
                      label: 'S',
                      selected: _size == VehicleSize.s,
                      onTap: () => setState(() => _size = VehicleSize.s),
                    ),
                    _SizeChip(
                      label: 'M',
                      selected: _size == VehicleSize.m,
                      onTap: () => setState(() => _size = VehicleSize.m),
                    ),
                    _SizeChip(
                      label: 'L',
                      selected: _size == VehicleSize.l,
                      onTap: () => setState(() => _size = VehicleSize.l),
                    ),
                    _SizeChip(
                      label: 'Auto',
                      selected: _size == null,
                      onTap: () => setState(() => _size = null),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AppButton(
                      label: 'Plaque AutoRef',
                      icon: Icons.search_rounded,
                      tone: AppButtonTone.secondary,
                      onPressed: _autorefLoading ? null : _lookupPlate,
                    ),
                    AppButton(
                      label: 'VIN AutoRef',
                      icon: Icons.manage_search_rounded,
                      tone: AppButtonTone.secondary,
                      onPressed: _autorefLoading ? null : _lookupVin,
                    ),
                  ],
                ),
                if (_autorefLoading || _autorefStatus != null) ...[
                  const SizedBox(height: 12),
                  _LookupStatus(
                    loading: _autorefLoading,
                    success: _autorefStatus,
                  ),
                ],
                const SizedBox(height: 28),
                _DialogActions(
                  onCancel: () => Navigator.of(context).pop(),
                  onSubmit: _submit,
                  submitLabel: widget.vehicle == null
                      ? 'Ajouter voiture'
                      : 'Enregistrer',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleSuggestField extends ConsumerStatefulWidget {
  const _VehicleSuggestField({
    required this.label,
    required this.hint,
    required this.controller,
    this.brandController,
    this.models = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextEditingController? brandController;
  final bool models;

  @override
  ConsumerState<_VehicleSuggestField> createState() =>
      _VehicleSuggestFieldState();
}

class _VehicleSuggestFieldState extends ConsumerState<_VehicleSuggestField> {
  List<_VehicleSuggestionOption> _suggestions = const [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => _refresh(value));
  }

  Future<void> _refresh(String value) async {
    final repository = ref.read(vehicleCatalogRepositoryProvider);
    if (widget.models) {
      final results = await repository.modelSuggestions(
        query: value,
        brandName: widget.brandController?.text ?? '',
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results
            .map(
              (result) => _VehicleSuggestionOption(
                label: result.name,
                helper: result.brandName,
                brand: result.brandName,
              ),
            )
            .toList();
      });
      return;
    }

    final results = await repository.brandSuggestions(value);
    if (!mounted) return;
    setState(() {
      _suggestions = results
          .map((result) => _VehicleSuggestionOption(label: result.name))
          .toList();
    });
  }

  void _select(_VehicleSuggestionOption option) {
    widget.controller.text = option.label;
    if (widget.models &&
        option.brand.trim().isNotEmpty &&
        (widget.brandController?.text.trim().isEmpty ?? false)) {
      widget.brandController?.text = option.brand;
    }
    setState(() => _suggestions = const []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormField(
          label: widget.label,
          hint: widget.hint,
          controller: widget.controller,
          prefixIcon: widget.models
              ? Icons.directions_car_filled_outlined
              : Icons.business_rounded,
          onChanged: _schedule,
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.soft,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    suggestion.label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: suggestion.helper.isEmpty
                      ? null
                      : Text(
                          suggestion.helper,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                  onTap: () => _select(suggestion),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _VehicleSuggestionOption {
  const _VehicleSuggestionOption({
    required this.label,
    this.helper = '',
    this.brand = '',
  });

  final String label;
  final String helper;
  final String brand;
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.onClose,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.pageTitle.copyWith(fontSize: 38),
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: AppTextStyles.body),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Fermer',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _SegmentedChoice extends StatelessWidget {
  const _SegmentedChoice({
    required this.leftLabel,
    required this.rightLabel,
    required this.rightSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SegmentItem(
            label: leftLabel,
            selected: !rightSelected,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SegmentItem(
            label: rightLabel,
            selected: rightSelected,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: selected ? AppShadows.soft : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
      ),
    );
  }
}

class _DialogGrid extends StatelessWidget {
  const _DialogGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                if (child != children.last) const SizedBox(height: 16),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final child in children)
              SizedBox(width: (constraints.maxWidth - 18) / 2, child: child),
          ],
        );
      },
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label.toUpperCase(),
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceMuted,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
      ),
      style: const TextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    );
  }
}

class _CompanyResults extends StatelessWidget {
  const _CompanyResults({required this.results, required this.onSelected});

  final List<CompanyLookupResult> results;
  final ValueChanged<CompanyLookupResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: results.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final company = results[index];
          return ListTile(
            title: Text(
              company.title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              [
                company.taxNumber,
                company.address,
              ].where((value) => value.trim().isNotEmpty).join(' - '),
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => onSelected(company),
          );
        },
      ),
    );
  }
}

class _LookupStatus extends StatelessWidget {
  const _LookupStatus({required this.loading, this.error, this.success});

  final bool loading;
  final String? error;
  final String? success;

  @override
  Widget build(BuildContext context) {
    final message = loading ? 'Recherche en cours...' : error ?? success;
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    final isError = error != null;
    return Row(
      children: [
        if (loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            isError ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 18,
            color: isError ? AppColors.danger : AppColors.success,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: isError ? AppColors.danger : AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message.toUpperCase(),
        style: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label.toUpperCase()),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.navy,
      backgroundColor: AppColors.surfaceMuted,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.text,
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.onCancel,
    required this.onSubmit,
    required this.submitLabel,
  });

  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppButton(
          label: 'Annuler',
          tone: AppButtonTone.ghost,
          onPressed: onCancel,
        ),
        const SizedBox(width: 12),
        AppButton(label: submitLabel, onPressed: onSubmit),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: AppTextStyles.cardTitle),
      content: Text(message, style: AppTextStyles.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _initialsFor(Client client) {
  final base = ((client.companyName ?? '').trim().isNotEmpty)
      ? client.companyName!
      : client.name;
  final words = base
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final initials = words.take(2).map((word) => word[0]).join();
  return initials.isEmpty ? 'CL' : initials.toUpperCase();
}
