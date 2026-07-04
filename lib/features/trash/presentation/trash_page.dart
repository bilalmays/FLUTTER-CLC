import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_button.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_card.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/data/client_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/domain/client_vehicle_bundle.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:car_luxe_cleaning_flutter/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<ClientVehicleBundle> _archives = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final archives = await ref
          .read(clientRepositoryProvider)
          .listArchivedClients();
      if (!mounted) return;
      setState(() {
        _archives = archives;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _restore(ClientVehicleBundle bundle) async {
    await ref.read(clientRepositoryProvider).restoreClient(bundle.client.id);
    await _load();
    if (!mounted) return;
    _showSnack('${bundle.client.name} restaure.');
  }

  Future<void> _deleteForever(ClientVehicleBundle bundle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Suppression definitive', style: AppTextStyles.cardTitle),
        content: Text(
          'Supprimer ${bundle.client.name} et ses vehicules de façon definitive ?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(clientRepositoryProvider)
        .deleteClientPermanently(bundle.client.id);
    await _load();
    if (!mounted) return;
    _showSnack('${bundle.client.name} supprime definitivement.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<ClientVehicleBundle> get _filteredArchives {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _archives;
    return _archives.where((bundle) {
      return bundle.searchIndex.contains(query) ||
          bundle.vehicles.any(
            (vehicle) => [
              vehicle.make,
              vehicle.model,
              vehicle.licensePlate,
              vehicle.color,
            ].whereType<String>().join(' ').toLowerCase().contains(query),
          );
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
              eyebrow: 'Corbeille',
              title: 'Elements archives',
              subtitle:
                  'Clients retires de la vue principale, avec restauration ou suppression definitive.',
              trailing: AppButton(
                label: 'Retour clients',
                icon: Icons.arrow_back_rounded,
                tone: AppButtonTone.secondary,
                onPressed: () => context.go('/clients'),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'RECHERCHE',
                    hintText: 'Nom, email, telephone, plaque...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(color: AppColors.navy),
                  )
                else if (_error != null)
                  _TrashMessage(
                    icon: Icons.warning_amber_rounded,
                    title: 'Chargement impossible',
                    text: _error!,
                  )
                else if (_filteredArchives.isEmpty)
                  const _TrashMessage(
                    icon: Icons.delete_outline_rounded,
                    title: 'Aucun element a restaurer',
                    text: 'La corbeille est vide pour le moment.',
                  )
                else
                  _ArchiveList(
                    archives: _filteredArchives,
                    onRestore: _restore,
                    onDeleteForever: _deleteForever,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveList extends StatelessWidget {
  const _ArchiveList({
    required this.archives,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final List<ClientVehicleBundle> archives;
  final ValueChanged<ClientVehicleBundle> onRestore;
  final ValueChanged<ClientVehicleBundle> onDeleteForever;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < archives.length; index += 1) ...[
            _ArchiveRow(
              bundle: archives[index],
              onRestore: () => onRestore(archives[index]),
              onDeleteForever: () => onDeleteForever(archives[index]),
            ),
            if (index < archives.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.bundle,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final ClientVehicleBundle bundle;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final vehicleCount = bundle.vehicles.length;
    final vehicles = bundle.vehicles
        .map((vehicle) => '${vehicle.make} ${vehicle.model}'.trim())
        .where((label) => label.isNotEmpty)
        .take(3)
        .join(' / ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_off_outlined,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bundle.client.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    bundle.client.phone,
                    bundle.client.email,
                    '$vehicleCount vehicule${vehicleCount > 1 ? 's' : ''}',
                    vehicles,
                  ].where((value) => value.trim().isNotEmpty).join(' - '),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore_rounded, size: 17),
                label: const Text('Restaurer'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.35),
                  ),
                ),
                onPressed: onDeleteForever,
                icon: const Icon(Icons.delete_forever_outlined, size: 17),
                label: const Text('Supprimer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrashMessage extends StatelessWidget {
  const _TrashMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(height: 18),
          Text(
            title.toUpperCase(),
            style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(text, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
