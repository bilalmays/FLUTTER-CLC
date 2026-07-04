import 'dart:typed_data';

import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/utils/date_money_formatters.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_button.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_card.dart';
import 'package:car_luxe_cleaning_flutter/features/basket/data/service_catalog.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/data/client_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/domain/client_vehicle_bundle.dart';
import 'package:car_luxe_cleaning_flutter/features/pdf/services/pdf_service.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/client.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';

class DevisDocumentBuilder extends ConsumerStatefulWidget {
  const DevisDocumentBuilder({super.key});

  @override
  ConsumerState<DevisDocumentBuilder> createState() =>
      _DevisDocumentBuilderState();
}

class _DevisDocumentBuilderState extends ConsumerState<DevisDocumentBuilder> {
  int _step = 1;
  CatalogVehicleSize _size = CatalogVehicleSize.m;
  String _language = 'FR';
  String _categoryId = officialServiceCategories.first.id;
  final Map<String, int> _selected = {};
  String? _clientId;
  String? _vehicleId;
  bool _applyVat = true;
  bool _includePackDetails = true;
  bool _showQrCode = true;
  List<ClientVehicleBundle> _bundles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
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

  List<DocumentLineItem> get _items {
    final items = <DocumentLineItem>[];
    for (final category in officialServiceCategories) {
      for (final service in category.services) {
        final quantity = _selected[service.id] ?? 0;
        if (quantity <= 0) continue;
        items.add(
          DocumentLineItem(
            description: service.label,
            quantity: quantity,
            unitPrice: service.price.resolve(_size),
            vatRate: _applyVat ? 21 : 0,
          ),
        );
      }
    }
    return items;
  }

  int get _totalHtva =>
      _items.fold(0, (sum, item) => sum + item.quantity * item.unitPrice);

  Future<void> _export({required bool print}) async {
    if (_items.isEmpty) return;
    final client = _selectedClient ?? _fallbackClient;
    final vehicle = _selectedVehicle ?? _fallbackVehicle;
    final bytes = await ref
        .read(pdfServiceProvider)
        .buildQuotePdf(
          QuotePdfInput(
            reference: _reference('DEV'),
            date: DateTime.now(),
            language: _language,
            client: _partyFromClient(client),
            vehicle: _vehicleFromVehicle(vehicle),
            items: _items,
            applyVat: _applyVat,
            vehicleSize: _vehicleSizeLabel(_size),
            includePackDetails: _includePackDetails,
            showQrCode: _showQrCode,
          ),
        );
    await _handlePdf(bytes, filename: 'devis-car-luxe.pdf', print: print);
  }

  Client? get _selectedClient => _bundles
      .where((bundle) => bundle.client.id == _clientId)
      .firstOrNull
      ?.client;

  Vehicle? get _selectedVehicle {
    for (final bundle in _bundles) {
      for (final vehicle in bundle.vehicles) {
        if (vehicle.id == _vehicleId) return vehicle;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activeCategory = officialServiceCategories.firstWhere(
      (category) => category.id == _categoryId,
    );

    return _BuilderShell(
      eyebrow: 'Devis',
      title: 'Création devis',
      subtitle: 'Taille, langue, services, client et finalisation PDF.',
      step: _step,
      steps: const ['Taille', 'Langue', 'Services', 'Client', 'Final'],
      onPrevious: _step > 1 ? () => setState(() => _step -= 1) : null,
      onNext: _step < 5 ? () => setState(() => _step += 1) : null,
      canNext: _step != 3 || _items.isNotEmpty,
      child: switch (_step) {
        1 => _SizeStep(
          value: _size,
          onChanged: (value) => setState(() => _size = value),
        ),
        2 => _LanguageStep(
          value: _language,
          onChanged: (value) => setState(() => _language = value),
        ),
        3 => _ServicesStep(
          categoryId: _categoryId,
          activeCategory: activeCategory,
          size: _size,
          selected: _selected,
          onCategoryChanged: (value) => setState(() => _categoryId = value),
          onQuantityChanged: (id, quantity) {
            setState(() {
              if (quantity <= 0) {
                _selected.remove(id);
              } else {
                _selected[id] = quantity;
              }
            });
          },
        ),
        4 =>
          _loading
              ? const _LoadingBlock()
              : _ClientVehicleStep(
                  bundles: _bundles,
                  selectedClientId: _clientId,
                  selectedVehicleId: _vehicleId,
                  onChanged: (clientId, vehicleId) {
                    setState(() {
                      _clientId = clientId;
                      _vehicleId = vehicleId;
                    });
                  },
                ),
        _ => _FinalStep(
          totalHtva: _totalHtva,
          applyVat: _applyVat,
          onApplyVatChanged: (value) => setState(() => _applyVat = value),
          options: [
            _SwitchRow(
              label: 'Afficher QR code',
              value: _showQrCode,
              onChanged: (value) => setState(() => _showQrCode = value),
            ),
            _SwitchRow(
              label: 'Inclure detail de pack',
              value: _includePackDetails,
              onChanged: (value) => setState(() => _includePackDetails = value),
            ),
          ],
          onPrint: _items.isEmpty ? null : () => _export(print: true),
          onDownload: _items.isEmpty ? null : () => _export(print: false),
        ),
      },
    );
  }
}

class CarnetDocumentBuilder extends ConsumerStatefulWidget {
  const CarnetDocumentBuilder({super.key});

  @override
  ConsumerState<CarnetDocumentBuilder> createState() =>
      _CarnetDocumentBuilderState();
}

class _CarnetDocumentBuilderState extends ConsumerState<CarnetDocumentBuilder> {
  int _step = 1;
  String? _clientId;
  String? _vehicleId;
  DateTime _visitDate = DateTime.now();
  String _category = 'Intérieur';
  String _pack = 'Pureté';
  final _remarkController = TextEditingController();
  final List<_CarnetVisitDraft> _entries = [];
  List<ClientVehicleBundle> _bundles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final bundles = await ref.read(clientRepositoryProvider).listClients();
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

  Future<void> _export({required bool print}) async {
    final client = _selectedClient ?? _fallbackClient;
    final vehicle = _selectedVehicle ?? _fallbackVehicle;
    final entries = _entries.isEmpty
        ? [_currentCarnetEntry(1)]
        : [
            for (var index = 0; index < _entries.length; index += 1)
              _entries[index].toPdf(index + 1),
          ];
    final bytes = await ref
        .read(pdfServiceProvider)
        .buildMaintenanceBookPdf(
          CarnetPdfInput(
            reference: _reference('CLC'),
            createdDate: _visitDate,
            client: _partyFromClient(client),
            vehicle: _vehicleFromVehicle(vehicle),
            entries: entries,
          ),
        );
    await _handlePdf(bytes, filename: 'carnet-car-luxe.pdf', print: print);
  }

  CarnetEntryPdf _currentCarnetEntry(int index) {
    return CarnetEntryPdf(
      visitNumber: index.toString().padLeft(2, '0'),
      date: _visitDate,
      category: _category,
      pack: _pack,
      remark: _remarkController.text.trim(),
    );
  }

  void _addCarnetEntry() {
    if (_entries.length >= 55) return;
    setState(() {
      _entries.add(
        _CarnetVisitDraft(
          date: _visitDate,
          category: _category,
          pack: _pack,
          remark: _remarkController.text.trim(),
        ),
      );
      _remarkController.clear();
    });
  }

  void _removeCarnetEntry(int index) {
    setState(() => _entries.removeAt(index));
  }

  Client? get _selectedClient => _bundles
      .where((bundle) => bundle.client.id == _clientId)
      .firstOrNull
      ?.client;

  Vehicle? get _selectedVehicle {
    for (final bundle in _bundles) {
      for (final vehicle in bundle.vehicles) {
        if (vehicle.id == _vehicleId) return vehicle;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _BuilderShell(
      eyebrow: "Carnet d'entretien",
      title: 'Creation carnet',
      subtitle: 'Client, véhicule, service realise et PDF carnet.',
      step: _step,
      steps: const ['Client', 'Vehicule', 'Service', 'Finalisation'],
      onPrevious: _step > 1 ? () => setState(() => _step -= 1) : null,
      onNext: _step < 4 ? () => setState(() => _step += 1) : null,
      child: switch (_step) {
        1 =>
          _loading
              ? const _LoadingBlock()
              : _ClientVehicleStep(
                  bundles: _bundles,
                  selectedClientId: _clientId,
                  selectedVehicleId: _vehicleId,
                  clientOnly: true,
                  onChanged: (clientId, vehicleId) {
                    setState(() {
                      _clientId = clientId;
                      _vehicleId = vehicleId;
                    });
                  },
                ),
        2 =>
          _loading
              ? const _LoadingBlock()
              : Column(
                  children: [
                    _ClientVehicleStep(
                      bundles: _bundles,
                      selectedClientId: _clientId,
                      selectedVehicleId: _vehicleId,
                      vehicleOnly: true,
                      onChanged: (clientId, vehicleId) {
                        setState(() {
                          _clientId = clientId;
                          _vehicleId = vehicleId;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _DateField(
                      label: 'Date de la visite',
                      value: _visitDate,
                      onChanged: (date) => setState(() => _visitDate = date),
                    ),
                  ],
                ),
        3 => _CarnetServiceStep(
          category: _category,
          pack: _pack,
          visitDate: _visitDate,
          entries: _entries,
          remarkController: _remarkController,
          onCategoryChanged: (value) => setState(() => _category = value),
          onPackChanged: (value) => setState(() => _pack = value),
          onAddEntry: _addCarnetEntry,
          onRemoveEntry: _removeCarnetEntry,
        ),
        _ => _DocumentActions(
          title:
              'Carnet prêt - ${_entries.isEmpty ? 1 : _entries.length} visite(s)',
          description:
              'Le PDF utilise les fonds officiels du carnet TypeScript et reprend tout l historique de visites.',
          onPrint: () => _export(print: true),
          onDownload: () => _export(print: false),
        ),
      },
    );
  }
}

class _CarnetVisitDraft {
  const _CarnetVisitDraft({
    required this.date,
    required this.category,
    required this.pack,
    required this.remark,
  });

  final DateTime date;
  final String category;
  final String pack;
  final String remark;

  CarnetEntryPdf toPdf(int index) {
    return CarnetEntryPdf(
      visitNumber: index.toString().padLeft(2, '0'),
      date: date,
      category: category,
      pack: pack,
      remark: remark,
    );
  }
}

class DepositDocumentBuilder extends ConsumerStatefulWidget {
  const DepositDocumentBuilder({super.key});

  @override
  ConsumerState<DepositDocumentBuilder> createState() =>
      _DepositDocumentBuilderState();
}

class _DepositDocumentBuilderState
    extends ConsumerState<DepositDocumentBuilder> {
  String _language = 'FR';
  String? _clientId;
  String? _vehicleId;
  final _amountController = TextEditingController(text: '100');
  final _reasonController = TextEditingController(text: 'Acompte prestation');
  String _paymentMethod = 'Bancontact';
  List<ClientVehicleBundle> _bundles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final bundles = await ref.read(clientRepositoryProvider).listClients();
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

  Future<void> _export({required bool print}) async {
    final client = _selectedClient ?? _fallbackClient;
    final vehicle = _selectedVehicle ?? _fallbackVehicle;
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final bytes = await ref
        .read(pdfServiceProvider)
        .buildDepositPdf(
          DepositPdfInput(
            reference: _reference('ACP'),
            date: DateTime.now(),
            language: _language,
            client: _partyFromClient(client),
            vehicle: _vehicleFromVehicle(vehicle),
            amount: amount,
            paymentMethod: _paymentMethod,
            reason: _reasonController.text,
          ),
        );
    await _handlePdf(bytes, filename: 'acompte-car-luxe.pdf', print: print);
  }

  Client? get _selectedClient => _bundles
      .where((bundle) => bundle.client.id == _clientId)
      .firstOrNull
      ?.client;

  Vehicle? get _selectedVehicle {
    for (final bundle in _bundles) {
      for (final vehicle in bundle.vehicles) {
        if (vehicle.id == _vehicleId) return vehicle;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniTitle(
            eyebrow: 'Acompte',
            title: "Recu d'acompte",
            subtitle: 'Client, véhicule, montant, langue et paiement.',
          ),
          const SizedBox(height: 24),
          _LanguageStep(
            value: _language,
            onChanged: (value) => setState(() => _language = value),
          ),
          const SizedBox(height: 18),
          _loading
              ? const _LoadingBlock()
              : _ClientVehicleStep(
                  bundles: _bundles,
                  selectedClientId: _clientId,
                  selectedVehicleId: _vehicleId,
                  onChanged: (clientId, vehicleId) {
                    setState(() {
                      _clientId = clientId;
                      _vehicleId = vehicleId;
                    });
                  },
                ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 720;
              final fields = [
                _TextInput(
                  label: 'Montant reçu',
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                ),
                _TextInput(label: 'Motif', controller: _reasonController),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(labelText: 'PAIEMENT'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Bancontact',
                      child: Text('Bancontact'),
                    ),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'Virement',
                      child: Text('Virement'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _paymentMethod = value ?? 'Bancontact'),
                ),
              ];
              if (mobile) {
                return Column(
                  children: fields
                      .map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: field,
                        ),
                      )
                      .toList(),
                );
              }
              return Row(
                children: fields
                    .map(
                      (field) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: field,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          _DocumentActions(
            title: 'Acompte prêt',
            description: 'Le reçu peut etre imprime ou téléchargé en PDF.',
            onPrint: () => _export(print: true),
            onDownload: () => _export(print: false),
          ),
        ],
      ),
    );
  }
}

class PickupDocumentBuilder extends ConsumerStatefulWidget {
  const PickupDocumentBuilder({super.key});

  @override
  ConsumerState<PickupDocumentBuilder> createState() =>
      _PickupDocumentBuilderState();
}

class _PickupDocumentBuilderState extends ConsumerState<PickupDocumentBuilder> {
  String? _clientId;
  String? _vehicleId;
  final _addressController = TextEditingController();
  final _distancesController = TextEditingController(text: '3.0 / 3.05 / 3.1');
  final _notesController = TextEditingController();
  final _clientSignatureController = SignatureController(
    penStrokeWidth: 2.6,
    penColor: AppColors.text,
  );
  final _companySignatureController = SignatureController(
    penStrokeWidth: 2.4,
    penColor: AppColors.text,
  );
  String _condition = 'Moyen';
  bool _companySignatureRequired = false;
  List<ClientVehicleBundle> _bundles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _distancesController.dispose();
    _notesController.dispose();
    _clientSignatureController.dispose();
    _companySignatureController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final bundles = await ref.read(clientRepositoryProvider).listClients();
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

  PickupDistanceResult get _distanceResult =>
      calculatePickupDistance(_distancesController.text);

  int get _price => _distanceResult.distanceKm <= 3.1 ? 50 : 70;

  Future<void> _export({required bool print}) async {
    final client = _selectedClient ?? _fallbackClient;
    final vehicle = _selectedVehicle ?? _fallbackVehicle;
    final clientSignatureBytes = _clientSignatureController.isNotEmpty
        ? await _clientSignatureController.toPngBytes()
        : null;
    final companySignatureBytes = _companySignatureController.isNotEmpty
        ? await _companySignatureController.toPngBytes()
        : null;
    final bytes = await ref
        .read(pdfServiceProvider)
        .buildPickupPdf(
          PickupPdfInput(
            reference: _reference('PU'),
            date: DateTime.now(),
            client: _partyFromClient(client),
            vehicle: _vehicleFromVehicle(vehicle),
            pickupAddress: _addressController.text,
            distanceKm: _distanceResult.distanceKm,
            price: _price,
            condition: _condition,
            notes: _notesController.text,
            clientSignatureRequired: clientSignatureBytes == null,
            companySignatureRequired:
                _companySignatureRequired && companySignatureBytes == null,
            clientSignatureBytes: clientSignatureBytes,
            companySignatureBytes: companySignatureBytes,
          ),
        );
    await _handlePdf(bytes, filename: 'pickup-car-luxe.pdf', print: print);
  }

  Client? get _selectedClient => _bundles
      .where((bundle) => bundle.client.id == _clientId)
      .firstOrNull
      ?.client;

  Vehicle? get _selectedVehicle {
    for (final bundle in _bundles) {
      for (final vehicle in bundle.vehicles) {
        if (vehicle.id == _vehicleId) return vehicle;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniTitle(
            eyebrow: 'Service pick-up',
            title: 'Prise en charge',
            subtitle:
                'Client, véhicule, distance avec moyenne/médiane, signatures et PDF.',
          ),
          const SizedBox(height: 24),
          _loading
              ? const _LoadingBlock()
              : _ClientVehicleStep(
                  bundles: _bundles,
                  selectedClientId: _clientId,
                  selectedVehicleId: _vehicleId,
                  onChanged: (clientId, vehicleId) {
                    setState(() {
                      _clientId = clientId;
                      _vehicleId = vehicleId;
                    });
                  },
                ),
          const SizedBox(height: 18),
          _TextInput(label: 'Adresse pick-up', controller: _addressController),
          const SizedBox(height: 12),
          _TextInput(
            label: 'Distances Maps',
            controller: _distancesController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _DistancePanel(result: _distanceResult, price: _price),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _condition,
            decoration: const InputDecoration(labelText: 'ÉTAT VÉHICULE'),
            items: const [
              DropdownMenuItem(value: 'Propre', child: Text('Propre')),
              DropdownMenuItem(value: 'Moyen', child: Text('Moyen')),
              DropdownMenuItem(value: 'Sale', child: Text('Sale')),
            ],
            onChanged: (value) => setState(() => _condition = value ?? 'Moyen'),
          ),
          const SizedBox(height: 12),
          _TextInput(
            label: 'Remarques',
            controller: _notesController,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _SwitchRow(
            label: 'Signature Car Luxe obligatoire',
            value: _companySignatureRequired,
            onChanged: (value) =>
                setState(() => _companySignatureRequired = value),
          ),
          const SizedBox(height: 18),
          _SignatureSection(controller: _clientSignatureController),
          const SizedBox(height: 18),
          _SignatureSection(controller: _companySignatureController),
          const SizedBox(height: 20),
          _DocumentActions(
            title: 'Pick-up prêt',
            description:
                'Signature client obligatoire. Signature Car Luxe facultative sauf option activée.',
            onPrint: () => _export(print: true),
            onDownload: () => _export(print: false),
          ),
        ],
      ),
    );
  }
}

class DocumentsHistoryBuilder extends StatelessWidget {
  const DocumentsHistoryBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Devis', 'Génération PDF Flutter active', "Aujourd'hui"),
      ('Carnet', 'Client + véhicule + service', "Aujourd'hui"),
      ('Acompte', 'Reçu multilingue', "Aujourd'hui"),
      ('Pick-up', 'Distance et signatures', "Aujourd'hui"),
    ];

    return AppCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MiniTitle(
            eyebrow: 'Historique',
            title: 'Registre documents',
            subtitle:
                'La structure est prête pour persister les PDF générés. Les lignes ci-dessous montrent les modules Flutter actifs.',
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i += 1)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : const Border(
                              top: BorderSide(color: AppColors.border),
                            ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            rows[i].$1,
                            style: AppTextStyles.cardTitle,
                          ),
                        ),
                        Expanded(
                          child: Text(rows[i].$2, style: AppTextStyles.body),
                        ),
                        Text(rows[i].$3, style: AppTextStyles.body),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EtatDocumentBuilder extends ConsumerStatefulWidget {
  const EtatDocumentBuilder({super.key});

  @override
  ConsumerState<EtatDocumentBuilder> createState() =>
      _EtatDocumentBuilderState();
}

class _EtatDocumentBuilderState extends ConsumerState<EtatDocumentBuilder> {
  final _imagePicker = ImagePicker();
  final _notesController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 2.6,
    penColor: AppColors.text,
  );
  final Map<String, bool> _checklist = {
    'Carrosserie contrôlée': true,
    'Jantes contrôlées': true,
    'Vitres contrôlées': true,
    'Habitacle contrôlé': true,
    'Objets personnels signalés': true,
    'Kilométrage / état général confirmé': true,
  };
  final List<XFile> _photos = [];
  String? _clientId;
  String? _vehicleId;
  List<ClientVehicleBundle> _bundles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final bundles = await ref.read(clientRepositoryProvider).listClients();
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

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;
    setState(() => _photos.add(file));
  }

  Future<void> _export({required bool print}) async {
    final client = _selectedClient ?? _fallbackClient;
    final vehicle = _selectedVehicle ?? _fallbackVehicle;
    final pdfPhotos = <DocumentPhoto>[];
    for (final photo in _photos.take(8)) {
      pdfPhotos.add(
        DocumentPhoto(fileName: photo.name, bytes: await photo.readAsBytes()),
      );
    }
    final signatureBytes = _signatureController.isNotEmpty
        ? await _signatureController.toPngBytes()
        : null;
    final bytes = await ref
        .read(pdfServiceProvider)
        .buildInspectionPdf(
          InspectionPdfInput(
            reference: _reference('EDL'),
            date: DateTime.now(),
            client: _partyFromClient(client),
            vehicle: _vehicleFromVehicle(vehicle),
            checklist: _checklist,
            photoNames: _photos.map((photo) => photo.name).toList(),
            notes: _notesController.text,
            clientSignatureCaptured: signatureBytes != null,
            photos: pdfPhotos,
            clientSignatureBytes: signatureBytes,
          ),
        );
    await _handlePdf(
      bytes,
      filename: 'état-des-lieux-car-luxe.pdf',
      print: print,
    );
  }

  Client? get _selectedClient => _bundles
      .where((bundle) => bundle.client.id == _clientId)
      .firstOrNull
      ?.client;

  Vehicle? get _selectedVehicle {
    for (final bundle in _bundles) {
      for (final vehicle in bundle.vehicles) {
        if (vehicle.id == _vehicleId) return vehicle;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MiniTitle(
            eyebrow: 'État des lieux',
            title: 'Inspection véhicule',
            subtitle:
                'Checklist, photos, notes, signature client et PDF inspection.',
          ),
          const SizedBox(height: 24),
          _loading
              ? const _LoadingBlock()
              : _ClientVehicleStep(
                  bundles: _bundles,
                  selectedClientId: _clientId,
                  selectedVehicleId: _vehicleId,
                  onChanged: (clientId, vehicleId) {
                    setState(() {
                      _clientId = clientId;
                      _vehicleId = vehicleId;
                    });
                  },
                ),
          const SizedBox(height: 20),
          _InspectionChecklist(
            values: _checklist,
            onChanged: (key, value) => setState(() => _checklist[key] = value),
          ),
          const SizedBox(height: 18),
          _PhotoSection(
            photos: _photos,
            onCamera: () => _pickPhoto(ImageSource.camera),
            onGallery: () => _pickPhoto(ImageSource.gallery),
            onRemove: (photo) => setState(() => _photos.remove(photo)),
          ),
          const SizedBox(height: 18),
          _TextInput(
            label: 'Remarques inspection',
            controller: _notesController,
            maxLines: 4,
          ),
          const SizedBox(height: 18),
          _SignatureSection(controller: _signatureController),
          const SizedBox(height: 20),
          _DocumentActions(
            title: 'Inspection prête',
            description:
                'La signature client est obligatoire dans le flux métier; le PDF indique si elle est capturée.',
            onPrint: () => _export(print: true),
            onDownload: () => _export(print: false),
          ),
        ],
      ),
    );
  }
}

class _InspectionChecklist extends StatelessWidget {
  const _InspectionChecklist({required this.values, required this.onChanged});

  final Map<String, bool> values;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Checklist'.toUpperCase(), style: AppTextStyles.eyebrow),
          const SizedBox(height: 12),
          for (final entry in values.entries)
            CheckboxListTile(
              value: entry.value,
              onChanged: (value) => onChanged(entry.key, value ?? false),
              title: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              activeColor: AppColors.navy,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photos,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final List<XFile> photos;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<XFile> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Photos'.toUpperCase(),
                  style: AppTextStyles.eyebrow,
                ),
              ),
              AppButton(
                label: 'Caméra',
                icon: Icons.photo_camera_outlined,
                tone: AppButtonTone.secondary,
                onPressed: onCamera,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Galerie',
                icon: Icons.add_photo_alternate_outlined,
                tone: AppButtonTone.secondary,
                onPressed: onGallery,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            Text('Aucune photo ajoutée.', style: AppTextStyles.body)
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final photo in photos)
                  Chip(
                    label: Text(photo.name),
                    deleteIcon: const Icon(Icons.close_rounded),
                    onDeleted: () => onRemove(photo),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SignatureSection extends StatefulWidget {
  const _SignatureSection({required this.controller});

  final SignatureController controller;

  @override
  State<_SignatureSection> createState() => _SignatureSectionState();
}

class _SignatureSectionState extends State<_SignatureSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Signature client obligatoire'.toUpperCase(),
                  style: AppTextStyles.eyebrow,
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.controller.clear();
                  setState(() {});
                },
                child: const Text('Effacer'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Signature(
              controller: widget.controller,
              height: 180,
              backgroundColor: AppColors.surfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuilderShell extends StatelessWidget {
  const _BuilderShell({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.steps,
    required this.child,
    this.onPrevious,
    this.onNext,
    this.canNext = true,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final int step;
  final List<String> steps;
  final Widget child;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool canNext;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(Responsive.isMobile(context) ? 18 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniTitle(eyebrow: eyebrow, title: title, subtitle: subtitle),
          const SizedBox(height: 22),
          _StepperBar(step: step, steps: steps),
          const SizedBox(height: 24),
          child,
          const SizedBox(height: 24),
          Row(
            children: [
              AppButton(
                label: 'Retour',
                icon: Icons.arrow_back_rounded,
                tone: AppButtonTone.ghost,
                onPressed: onPrevious,
              ),
              const Spacer(),
              if (onNext != null)
                AppButton(
                  label: 'Suivant',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: canNext ? onNext : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperBar extends StatelessWidget {
  const _StepperBar({required this.step, required this.steps});

  final int step;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 760;
        final width = mobile
            ? constraints.maxWidth
            : (constraints.maxWidth - ((steps.length - 1) * 10)) / steps.length;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < steps.length; index += 1)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: width,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: index + 1 == step
                      ? AppColors.navy
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: index + 1 == step
                        ? AppColors.navy
                        : AppColors.border,
                  ),
                  boxShadow: index + 1 == step ? AppShadows.soft : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: index + 1 == step ? Colors.white : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[index].toUpperCase(),
                        style: TextStyle(
                          color: index + 1 == step
                              ? Colors.white
                              : AppColors.text,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MiniTitle extends StatelessWidget {
  const _MiniTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(), style: AppTextStyles.eyebrow),
        const SizedBox(height: 10),
        Text(title, style: AppTextStyles.pageTitle.copyWith(fontSize: 38)),
        const SizedBox(height: 10),
        Text(subtitle, style: AppTextStyles.body),
      ],
    );
  }
}

class _SizeStep extends StatelessWidget {
  const _SizeStep({required this.value, required this.onChanged});

  final CatalogVehicleSize value;
  final ValueChanged<CatalogVehicleSize> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionGrid(
      children: [
        _ChoiceCard(
          icon: Icons.directions_car_outlined,
          title: 'Taille S',
          subtitle: 'Citadine - Fiat 500, Polo, Yaris',
          selected: value == CatalogVehicleSize.s,
          onTap: () => onChanged(CatalogVehicleSize.s),
        ),
        _ChoiceCard(
          icon: Icons.directions_car_outlined,
          title: 'Taille M',
          subtitle: 'Berline / compacte - Golf, Classe A, Serie 1',
          selected: value == CatalogVehicleSize.m,
          onTap: () => onChanged(CatalogVehicleSize.m),
        ),
        _ChoiceCard(
          icon: Icons.directions_car_outlined,
          title: 'Taille L',
          subtitle: 'SUV / grande berline / van',
          selected: value == CatalogVehicleSize.l,
          onTap: () => onChanged(CatalogVehicleSize.l),
        ),
      ],
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionGrid(
      children: [
        _ChoiceCard(
          icon: Icons.translate_rounded,
          title: 'FR',
          subtitle: 'Francais',
          selected: value == 'FR',
          onTap: () => onChanged('FR'),
        ),
        _ChoiceCard(
          icon: Icons.translate_rounded,
          title: 'NL',
          subtitle: 'Nederlands',
          selected: value == 'NL',
          onTap: () => onChanged('NL'),
        ),
        _ChoiceCard(
          icon: Icons.translate_rounded,
          title: 'EN',
          subtitle: 'English',
          selected: value == 'EN',
          onTap: () => onChanged('EN'),
        ),
      ],
    );
  }
}

class _ServicesStep extends StatelessWidget {
  const _ServicesStep({
    required this.categoryId,
    required this.activeCategory,
    required this.size,
    required this.selected,
    required this.onCategoryChanged,
    required this.onQuantityChanged,
  });

  final String categoryId;
  final ServiceCategory activeCategory;
  final CatalogVehicleSize size;
  final Map<String, int> selected;
  final ValueChanged<String> onCategoryChanged;
  final void Function(String id, int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final category in officialServiceCategories)
              ChoiceChip(
                label: Text(category.label.toUpperCase()),
                selected: category.id == categoryId,
                onSelected: (_) => onCategoryChanged(category.id),
                selectedColor: AppColors.navy,
                backgroundColor: AppColors.surfaceMuted,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: category.id == categoryId
                      ? Colors.white
                      : AppColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        for (final service in activeCategory.services)
          _ServiceQuantityRow(
            service: service,
            price: service.price.resolve(size),
            quantity: selected[service.id] ?? 0,
            onChanged: (quantity) => onQuantityChanged(service.id, quantity),
          ),
      ],
    );
  }
}

class _ServiceQuantityRow extends StatelessWidget {
  const _ServiceQuantityRow({
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: quantity > 0 ? const Color(0xFFF0F2F5) : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: quantity > 0 ? AppColors.navy : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.label, style: AppTextStyles.cardTitle),
                const SizedBox(height: 6),
                Text(formatMoney(price), style: AppTextStyles.body),
              ],
            ),
          ),
          IconButton(
            onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(
            '$quantity',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          IconButton(
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _ClientVehicleStep extends StatelessWidget {
  const _ClientVehicleStep({
    required this.bundles,
    required this.selectedClientId,
    required this.selectedVehicleId,
    required this.onChanged,
    this.clientOnly = false,
    this.vehicleOnly = false,
  });

  final List<ClientVehicleBundle> bundles;
  final String? selectedClientId;
  final String? selectedVehicleId;
  final void Function(String? clientId, String? vehicleId) onChanged;
  final bool clientOnly;
  final bool vehicleOnly;

  @override
  Widget build(BuildContext context) {
    final selectedBundle = bundles
        .where((bundle) => bundle.client.id == selectedClientId)
        .firstOrNull;
    final vehicles = selectedBundle?.vehicles ?? const <Vehicle>[];

    return Column(
      children: [
        if (!vehicleOnly)
          DropdownButtonFormField<String>(
            initialValue: selectedClientId,
            decoration: const InputDecoration(labelText: 'CLIENT'),
            items: [
              for (final bundle in bundles)
                DropdownMenuItem(
                  value: bundle.client.id,
                  child: Text(bundle.client.name),
                ),
            ],
            onChanged: (value) {
              final bundle = bundles
                  .where((item) => item.client.id == value)
                  .firstOrNull;
              onChanged(value, bundle?.vehicles.firstOrNull?.id);
            },
          ),
        if (!clientOnly) ...[
          if (!vehicleOnly) const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue:
                vehicles.any((vehicle) => vehicle.id == selectedVehicleId)
                ? selectedVehicleId
                : vehicles.firstOrNull?.id,
            decoration: const InputDecoration(labelText: 'VEHICULE'),
            items: [
              for (final vehicle in vehicles)
                DropdownMenuItem(
                  value: vehicle.id,
                  child: Text(
                    '${vehicle.make} ${vehicle.model} - ${vehicle.displayPlate}',
                  ),
                ),
            ],
            onChanged: (value) => onChanged(selectedClientId, value),
          ),
        ],
      ],
    );
  }
}

class _CarnetServiceStep extends StatelessWidget {
  const _CarnetServiceStep({
    required this.category,
    required this.pack,
    required this.visitDate,
    required this.entries,
    required this.remarkController,
    required this.onCategoryChanged,
    required this.onPackChanged,
    required this.onAddEntry,
    required this.onRemoveEntry,
  });

  final String category;
  final String pack;
  final DateTime visitDate;
  final List<_CarnetVisitDraft> entries;
  final TextEditingController remarkController;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onPackChanged;
  final VoidCallback onAddEntry;
  final ValueChanged<int> onRemoveEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'CATEGORIE DE SERVICE',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Intérieur',
                    child: Text('Intérieur'),
                  ),
                  DropdownMenuItem(
                    value: 'Exterieur',
                    child: Text('Exterieur'),
                  ),
                  DropdownMenuItem(value: 'Complet', child: Text('Complet')),
                  DropdownMenuItem(
                    value: 'Protection',
                    child: Text('Protection'),
                  ),
                ],
                onChanged: (value) => onCategoryChanged(value ?? 'Intérieur'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: pack,
                decoration: const InputDecoration(labelText: 'PACK'),
                items: const [
                  DropdownMenuItem(value: 'Pureté', child: Text('Pureté')),
                  DropdownMenuItem(value: 'Serenite', child: Text('Serenite')),
                  DropdownMenuItem(
                    value: 'Brillance',
                    child: Text('Brillance'),
                  ),
                  DropdownMenuItem(
                    value: 'Signature',
                    child: Text('Signature'),
                  ),
                ],
                onChanged: (value) => onPackChanged(value ?? 'Pureté'),
              ),
              const SizedBox(height: 14),
              _TextInput(
                label: 'Remarque / travaux realises',
                controller: remarkController,
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: entries.length >= 55
                      ? 'Limite atteinte'
                      : 'Ajouter visite',
                  icon: Icons.add_rounded,
                  onPressed: entries.length >= 55 ? null : onAddEntry,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _CarnetVisitList(
          visitDate: visitDate,
          category: category,
          pack: pack,
          entries: entries,
          onRemove: onRemoveEntry,
        ),
      ],
    );
  }
}

class _CarnetVisitList extends StatelessWidget {
  const _CarnetVisitList({
    required this.visitDate,
    required this.category,
    required this.pack,
    required this.entries,
    required this.onRemove,
  });

  final DateTime visitDate;
  final String category;
  final String pack;
  final List<_CarnetVisitDraft> entries;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final effectiveEntries = entries.isEmpty
        ? [
            _CarnetVisitDraft(
              date: visitDate,
              category: category,
              pack: pack,
              remark: 'Visite en cours - ajoute-la pour figer l historique.',
            ),
          ]
        : entries;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: AppColors.surfaceMuted,
            child: Text(
              'Historique des visites'.toUpperCase(),
              style: AppTextStyles.eyebrow.copyWith(letterSpacing: 2.4),
            ),
          ),
          for (var index = 0; index < effectiveEntries.length; index += 1) ...[
            _CarnetVisitRow(
              index: index,
              entry: effectiveEntries[index],
              draft: entries.isEmpty,
              onRemove: entries.isEmpty ? null : () => onRemove(index),
            ),
            if (index < effectiveEntries.length - 1) const _SoftDivider(),
          ],
        ],
      ),
    );
  }
}

class _CarnetVisitRow extends StatelessWidget {
  const _CarnetVisitRow({
    required this.index,
    required this.entry,
    required this.draft,
    required this.onRemove,
  });

  final int index;
  final _CarnetVisitDraft entry;
  final bool draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: draft ? AppColors.surfaceMuted : AppColors.navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (index + 1).toString().padLeft(2, '0'),
              style: TextStyle(
                color: draft ? AppColors.muted : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.pack.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${entry.category} - ${formatDate(entry.date)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (entry.remark.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    entry.remark,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3F3F46),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Retirer la visite',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

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

class _FinalStep extends StatelessWidget {
  const _FinalStep({
    required this.totalHtva,
    required this.applyVat,
    required this.onApplyVatChanged,
    required this.options,
    required this.onPrint,
    required this.onDownload,
  });

  final int totalHtva;
  final bool applyVat;
  final ValueChanged<bool> onApplyVatChanged;
  final List<Widget> options;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final total = applyVat ? totalHtva * 1.21 : totalHtva.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OptionGrid(
          children: [
            _ChoiceCard(
              icon: Icons.euro_rounded,
              title: 'Oui, avec TVA',
              subtitle: 'Affiche HTVA, TVA 21% et total TVAC.',
              selected: applyVat,
              onTap: () => onApplyVatChanged(true),
            ),
            _ChoiceCard(
              icon: Icons.euro_rounded,
              title: 'Non, sans TVA',
              subtitle: 'Affiche uniquement le total sans TVA.',
              selected: !applyVat,
              onTap: () => onApplyVatChanged(false),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...options,
        const SizedBox(height: 18),
        _DocumentActions(
          title: formatMoney(total),
          description: 'Total actuel du document.',
          onPrint: onPrint,
          onDownload: onDownload,
        ),
      ],
    );
  }
}

class _DocumentActions extends StatelessWidget {
  const _DocumentActions({
    required this.title,
    required this.description,
    required this.onPrint,
    required this.onDownload,
  });

  final String title;
  final String description;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 720;
          final actions = [
            AppButton(
              label: 'Imprimer',
              icon: Icons.print_outlined,
              tone: AppButtonTone.secondary,
              onPressed: onPrint,
              expanded: mobile,
            ),
            AppButton(
              label: 'Telecharger',
              icon: Icons.download_rounded,
              onPressed: onDownload,
              expanded: mobile,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(description, style: AppTextStyles.body),
              const SizedBox(height: 18),
              mobile
                  ? Column(
                      children: actions
                          .map(
                            (action) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: action,
                            ),
                          )
                          .toList(),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        actions.first,
                        const SizedBox(width: 12),
                        actions.last,
                      ],
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720
            ? 1
            : children.length.clamp(2, 3);
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.navy : AppColors.border,
            ),
            boxShadow: selected ? AppShadows.soft : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.navy),
              const SizedBox(height: 22),
              Text(
                title,
                style: AppTextStyles.cardTitle.copyWith(
                  color: selected ? Colors.white : AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppTextStyles.body.copyWith(
                  color: selected ? Colors.white70 : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      activeThumbColor: AppColors.navy,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label.toUpperCase()),
      style: const TextStyle(fontWeight: FontWeight.w800),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label.toUpperCase()),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatDate(value),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const Icon(Icons.calendar_today_outlined),
          ],
        ),
      ),
    );
  }
}

class _DistancePanel extends StatelessWidget {
  const _DistancePanel({required this.result, required this.price});

  final PickupDistanceResult result;
  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distance retenue'.toUpperCase(), style: AppTextStyles.eyebrow),
          const SizedBox(height: 8),
          Text(
            '${result.distanceKm.toStringAsFixed(2)} km - ${formatMoney(price)}',
            style: AppTextStyles.cardTitle,
          ),
          const SizedBox(height: 6),
          Text(result.note, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: AppColors.navy),
      ),
    );
  }
}

class PickupDistanceResult {
  const PickupDistanceResult({required this.distanceKm, required this.note});

  final double distanceKm;
  final String note;
}

PickupDistanceResult calculatePickupDistance(String rawValue) {
  final distances =
      RegExp(r'\d+(?:[,.]\d+)?')
          .allMatches(rawValue)
          .map((match) => double.parse(match.group(0)!.replaceAll(',', '.')))
          .where((value) => value > 0)
          .toList()
        ..sort();

  if (distances.isEmpty) {
    return const PickupDistanceResult(
      distanceKm: 0,
      note: 'Ajoute une ou plusieurs distances pour calculer le prix.',
    );
  }
  if (distances.length == 1) {
    return PickupDistanceResult(
      distanceKm: distances.first,
      note: 'Une seule distance fournie.',
    );
  }

  const tolerance = 0.10;
  final closeValues = <double>[];
  for (final distance in distances) {
    final hasNeighbour = distances.any(
      (other) => other != distance && (other - distance).abs() <= tolerance,
    );
    if (hasNeighbour) closeValues.add(distance);
  }

  if (closeValues.length >= 2) {
    final average = closeValues.reduce((a, b) => a + b) / closeValues.length;
    return PickupDistanceResult(
      distanceKm: average,
      note:
          'Distances proches: moyenne retenue (${closeValues.map((v) => v.toStringAsFixed(2)).join(' / ')} km).',
    );
  }

  final median = distances[distances.length ~/ 2];
  return PickupDistanceResult(
    distanceKm: median,
    note:
        'Routes trop differentes: distance du milieu retenue (${distances.map((v) => v.toStringAsFixed(2)).join(' / ')} km).',
  );
}

Future<void> _handlePdf(
  List<int> bytes, {
  required String filename,
  required bool print,
}) async {
  final data = Uint8List.fromList(bytes);
  if (print) {
    await Printing.layoutPdf(onLayout: (_) async => data);
  } else {
    await Printing.sharePdf(bytes: data, filename: filename);
  }
}

String _reference(String prefix) {
  final now = DateTime.now();
  final date =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return '$prefix-$date-${now.millisecondsSinceEpoch.toString().substring(8)}';
}

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

String _vehicleSizeLabel(CatalogVehicleSize size) {
  return switch (size) {
    CatalogVehicleSize.s => 'S',
    CatalogVehicleSize.m => 'M',
    CatalogVehicleSize.l => 'L',
  };
}

final _fallbackClient = Client(
  id: 'manual-client',
  name: 'CLIENT',
  email: '',
  phone: '',
  address: '',
  language: 'FR',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  archived: false,
);

final _fallbackVehicle = Vehicle(
  id: 'manual-vehicle',
  clientId: 'manual-client',
  make: 'VEHICULE',
  model: '',
  year: '',
  licensePlate: '',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
