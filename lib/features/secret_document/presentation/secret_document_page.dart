import 'dart:typed_data';

import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/utils/date_money_formatters.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_button.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_card.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/data/client_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/domain/client_vehicle_bundle.dart';
import 'package:car_luxe_cleaning_flutter/features/pdf/services/pdf_service.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/client.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

class SecretDocumentPage extends ConsumerStatefulWidget {
  const SecretDocumentPage({super.key});

  @override
  ConsumerState<SecretDocumentPage> createState() => _SecretDocumentPageState();
}

class _SecretDocumentPageState extends ConsumerState<SecretDocumentPage> {
  final _descriptionController = TextEditingController(
    text: 'Preparation esthetique premium',
  );
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '350');
  final _notesController = TextEditingController();
  final List<_SecretLineDraft> _lines = [
    const _SecretLineDraft(
      description: 'Preparation esthetique premium',
      quantity: 1,
      unitPrice: 350,
    ),
  ];

  List<ClientVehicleBundle> _bundles = const [];
  String? _clientId;
  String? _vehicleId;
  String _vehicleSize = 'Taille M';
  bool _showVatNumber = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final repository = ref.read(clientRepositoryProvider);
    final bundles = await repository.listClients();
    if (!mounted) return;
    setState(() {
      _bundles = bundles;
      _loading = false;
      if (bundles.isNotEmpty) {
        _clientId = bundles.first.client.id;
        _vehicleId = bundles.first.vehicles.isNotEmpty
            ? bundles.first.vehicles.first.id
            : null;
      }
    });
  }

  ClientVehicleBundle? get _selectedBundle {
    for (final bundle in _bundles) {
      if (bundle.client.id == _clientId) return bundle;
    }
    return _bundles.isEmpty ? null : _bundles.first;
  }

  Client get _selectedClient => _selectedBundle?.client ?? _fallbackClient;

  Vehicle get _selectedVehicle {
    final bundle = _selectedBundle;
    if (bundle == null || bundle.vehicles.isEmpty) return _fallbackVehicle;
    for (final vehicle in bundle.vehicles) {
      if (vehicle.id == _vehicleId) return vehicle;
    }
    return bundle.vehicles.first;
  }

  int get _total =>
      _lines.fold(0, (sum, line) => sum + (line.quantity * line.unitPrice));

  void _addLine() {
    final description = _descriptionController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    if (description.isEmpty || price <= 0) return;
    setState(() {
      _lines.add(
        _SecretLineDraft(
          description: description,
          quantity: quantity < 1 ? 1 : quantity,
          unitPrice: price,
        ),
      );
      _descriptionController.clear();
      _quantityController.text = '1';
      _priceController.clear();
    });
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    setState(() => _lines.removeAt(index));
  }

  Future<void> _export({required bool print}) async {
    final now = DateTime.now();
    final reference =
        'DOC-${isoDate(now).replaceAll('-', '')}-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
    final bytes = await ref
        .read(pdfServiceProvider)
        .buildSecretPdf(
          SecretPdfInput(
            reference: reference,
            date: now,
            client: _partyFromClient(_selectedClient),
            vehicle: _vehicleFromVehicle(_selectedVehicle),
            vehicleSize: _vehicleSize,
            items: [
              for (final line in _lines)
                DocumentLineItem(
                  description: line.description,
                  quantity: line.quantity,
                  unitPrice: line.unitPrice,
                  vatRate: 0,
                ),
            ],
            notes: _notesController.text.trim(),
            showVatNumber: _showVatNumber,
          ),
        );
    final data = Uint8List.fromList(bytes);
    if (print) {
      await Printing.layoutPdf(onLayout: (_) async => data);
      return;
    }
    await Printing.sharePdf(bytes: data, filename: 'document-secret-clc.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final colors = ClcThemeColors.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            color: colors.field,
            borderColor: colors.border,
            padding: EdgeInsets.all(isMobile ? 20 : 28),
            child: Wrap(
              spacing: 18,
              runSpacing: 18,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADMIN ONLY',
                      style: TextStyle(
                        color: colors.focus,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Document Secret',
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 42,
                        height: 0.96,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AppButton(
                      label: 'Imprimer',
                      icon: Icons.print_outlined,
                      tone: AppButtonTone.secondary,
                      onPressed: _lines.isEmpty
                          ? null
                          : () => _export(print: true),
                    ),
                    AppButton(
                      label: 'PDF',
                      icon: Icons.download_outlined,
                      onPressed: _lines.isEmpty
                          ? null
                          : () => _export(print: false),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            _DarkPanel(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: colors.focus),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 920;
                final formWidth = twoColumns
                    ? (constraints.maxWidth - 18) * 0.58
                    : constraints.maxWidth;
                final summaryWidth = twoColumns
                    ? (constraints.maxWidth - 18) * 0.42
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    SizedBox(width: formWidth, child: _buildForm()),
                    SizedBox(width: summaryWidth, child: _buildSummary()),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final bundle = _selectedBundle;
    final vehicles = bundle?.vehicles ?? const <Vehicle>[];
    final colors = ClcThemeColors.of(context);

    return _DarkPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.visibility_off_outlined,
            label: 'Dossier',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _clientId,
            decoration: _fieldDecoration(context, 'CLIENT'),
            dropdownColor: colors.surfaceRaised,
            iconEnabledColor: colors.focus,
            style: TextStyle(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
            items: [
              for (final item in _bundles)
                DropdownMenuItem(
                  value: item.client.id,
                  child: Text(item.client.name),
                ),
            ],
            onChanged: (value) {
              final selected = _bundles
                  .where((bundle) => bundle.client.id == value)
                  .firstOrNull;
              setState(() {
                _clientId = value;
                _vehicleId = selected?.vehicles.isNotEmpty == true
                    ? selected!.vehicles.first.id
                    : null;
              });
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: vehicles.any((vehicle) => vehicle.id == _vehicleId)
                ? _vehicleId
                : null,
            decoration: _fieldDecoration(context, 'VEHICULE'),
            dropdownColor: colors.surfaceRaised,
            iconEnabledColor: colors.focus,
            style: TextStyle(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
            items: [
              for (final vehicle in vehicles)
                DropdownMenuItem(
                  value: vehicle.id,
                  child: Text('${vehicle.make} ${vehicle.model}'.trim()),
                ),
            ],
            onChanged: (value) => setState(() => _vehicleId = value),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final size in _vehicleSizes)
                _VehicleSizeChip(
                  label: size,
                  active: _vehicleSize == size,
                  onTap: () => setState(() => _vehicleSize = size),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _SoftDivider(),
          const SizedBox(height: 22),
          const _PanelTitle(
            icon: Icons.receipt_long_outlined,
            label: 'Services',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _descriptionController,
            style: TextStyle(color: colors.textStrong),
            decoration: _fieldDecoration(context, 'DESCRIPTION'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textStrong),
                  decoration: _fieldDecoration(context, 'QTE'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textStrong),
                  decoration: _fieldDecoration(context, 'PRIX'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                width: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.focus,
                    foregroundColor: colors.onFocus,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _addLine,
                  child: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            style: TextStyle(color: colors.textStrong),
            decoration: _fieldDecoration(context, 'NOTES'),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _showVatNumber,
            activeThumbColor: colors.focus,
            activeTrackColor: colors.focus.withValues(alpha: 0.32),
            title: Text(
              'Afficher les numeros TVA',
              style: TextStyle(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              'Desactive par defaut comme dans le document cache.',
              style: TextStyle(color: colors.mutedStrong, fontSize: 12),
            ),
            onChanged: (value) => setState(() => _showVatNumber = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final colors = ClcThemeColors.of(context);

    return _DarkPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(icon: Icons.fact_check_outlined, label: 'Resume'),
          const SizedBox(height: 18),
          _InfoBlock(
            label: 'CLIENT',
            value: _selectedClient.name,
            detail: _selectedClient.email,
          ),
          const SizedBox(height: 12),
          _InfoBlock(
            label: 'VEHICULE',
            value: '${_selectedVehicle.make} ${_selectedVehicle.model}'.trim(),
            detail: _selectedVehicle.licensePlate,
          ),
          const SizedBox(height: 18),
          const _SoftDivider(),
          const SizedBox(height: 18),
          for (var index = 0; index < _lines.length; index += 1) ...[
            _SecretLineRow(
              line: _lines[index],
              onRemove: () => _removeLine(index),
              canRemove: _lines.length > 1,
            ),
            if (index < _lines.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 18),
          const _SoftDivider(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'TOTAL',
                  style: TextStyle(
                    color: colors.focus,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
              Text(
                formatMoney(_total),
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecretLineDraft {
  const _SecretLineDraft({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  final String description;
  final int quantity;
  final int unitPrice;
}

const _vehicleSizes = [
  'Taille S',
  'Taille M',
  'Taille L',
  'Sportive',
  'Pick-up',
  'Camionnette',
];

final _fallbackClient = Client(
  id: 'fallback-client',
  name: 'CLIENT',
  email: '',
  phone: '',
  address: '',
  language: 'FR',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  archived: false,
);

final _fallbackVehicle = Vehicle(
  id: 'fallback-vehicle',
  clientId: 'fallback-client',
  make: 'VEHICULE',
  model: '',
  year: '',
  licensePlate: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DocumentParty _partyFromClient(Client client) {
  return DocumentParty(
    name: client.name,
    email: client.email,
    phone: client.phone,
    address: client.address,
    companyName: client.companyName ?? '',
    vatNumber: client.vatNumber ?? '',
  );
}

DocumentVehicle _vehicleFromVehicle(Vehicle vehicle) {
  return DocumentVehicle(
    make: vehicle.make,
    model: vehicle.model,
    licensePlate: vehicle.licensePlate,
    vin: vehicle.vin ?? '',
    year: vehicle.year,
    color: vehicle.color ?? '',
  );
}

InputDecoration _fieldDecoration(BuildContext context, String label) {
  final colors = ClcThemeColors.of(context);

  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: colors.mutedStrong,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.2,
    ),
    filled: true,
    fillColor: colors.surfaceRaised,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.focus),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  );
}

class _DarkPanel extends StatelessWidget {
  const _DarkPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return AppCard(
      color: colors.field,
      borderColor: colors.border,
      padding: const EdgeInsets.all(22),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Row(
      children: [
        Icon(icon, color: colors.focus, size: 18),
        const SizedBox(width: 10),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}

class _VehicleSizeChip extends StatelessWidget {
  const _VehicleSizeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: active ? colors.focus : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? colors.focus : colors.border),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: active ? colors.onFocus : colors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.mutedStrong,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (detail.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(
                color: colors.mutedStrong,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecretLineRow extends StatelessWidget {
  const _SecretLineRow({
    required this.line,
    required this.onRemove,
    required this.canRemove,
  });

  final _SecretLineDraft line;
  final VoidCallback onRemove;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.description,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${line.quantity} x ${formatMoney(line.unitPrice)}',
                style: TextStyle(
                  color: colors.mutedStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          formatMoney(line.quantity * line.unitPrice),
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        IconButton(
          tooltip: 'Supprimer',
          onPressed: canRemove ? onRemove : null,
          icon: Icon(Icons.close_rounded, color: colors.mutedStrong),
        ),
      ],
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            colors.border,
            colors.border,
            Colors.transparent,
          ],
          stops: [0, 0.1, 0.9, 1],
        ),
      ),
    );
  }
}
