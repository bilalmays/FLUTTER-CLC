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
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

class BasketComposerPage extends ConsumerStatefulWidget {
  const BasketComposerPage({super.key});

  @override
  ConsumerState<BasketComposerPage> createState() => _BasketComposerPageState();
}

class _BasketComposerPageState extends ConsumerState<BasketComposerPage> {
  static const _steps = 5;

  int _step = 1;
  CatalogVehicleSize _size = CatalogVehicleSize.s;
  String _categoryId = officialServiceCategories.first.id;
  final Map<String, int> _selected = {};

  bool _applyVat = false;
  bool _includePackDetails = true;
  bool _showQrCode = true;
  bool _loadingClients = false;
  bool _savingClient = false;

  List<ClientVehicleBundle> _bundles = const [];
  String? _selectedClientId;
  String? _selectedVehicleId;
  String _clientMode = 'existing';
  String _clientQuery = '';
  bool _newClientIsProfessional = false;
  bool _showVehicleForm = false;

  final _scrollController = ScrollController();
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _clientAddressController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _vatNumberController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleVinController = TextEditingController();
  final _vehicleColorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _clientNameController,
      _clientPhoneController,
      _vehicleMakeController,
      _vehicleModelController,
    ]) {
      controller.addListener(_refreshStepState);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _clientNameController,
      _clientPhoneController,
      _vehicleMakeController,
      _vehicleModelController,
    ]) {
      controller.removeListener(_refreshStepState);
    }
    _scrollController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _clientEmailController.dispose();
    _clientAddressController.dispose();
    _companyNameController.dispose();
    _vatNumberController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehiclePlateController.dispose();
    _vehicleVinController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  ServiceCategory get _activeCategory => officialServiceCategories.firstWhere(
    (category) => category.id == _categoryId,
  );

  List<_BasketLine> get _lines {
    final lines = <_BasketLine>[];
    for (final category in officialServiceCategories) {
      for (final service in category.services) {
        final quantity = _selected[service.id] ?? 0;
        if (quantity <= 0) continue;
        lines.add(
          _BasketLine(
            category: category,
            service: service,
            quantity: quantity,
            unitPrice: service.price.resolve(_size),
          ),
        );
      }
    }
    return lines;
  }

  int get _totalHtva => _lines.fold(0, (total, line) => total + line.subtotal);

  double get _vatTotal => _applyVat ? _totalHtva * 0.21 : 0;

  double get _totalWithVat => _totalHtva + _vatTotal;

  ClientVehicleBundle? get _selectedBundle => _bundles
      .where((bundle) => bundle.client.id == _selectedClientId)
      .firstOrNull;

  Client? get _selectedClient => _selectedBundle?.client;

  Vehicle? get _selectedVehicle {
    for (final bundle in _bundles) {
      for (final vehicle in bundle.vehicles) {
        if (vehicle.id == _selectedVehicleId) return vehicle;
      }
    }
    return null;
  }

  bool get _hasVehicleDraft =>
      _vehicleMakeController.text.trim().isNotEmpty &&
      _vehicleModelController.text.trim().isNotEmpty;

  bool get _canCreateClient =>
      _clientNameController.text.trim().isNotEmpty &&
      _clientPhoneController.text.trim().isNotEmpty;

  bool get _canGoNext {
    return switch (_step) {
      1 => true,
      2 => true,
      3 => _lines.isNotEmpty,
      4 =>
        _clientMode == 'new'
            ? _canCreateClient && _hasVehicleDraft
            : _selectedClient != null &&
                  (_selectedVehicle != null || _hasVehicleDraft),
      _ =>
        _lines.isNotEmpty &&
            _selectedClient != null &&
            _selectedVehicle != null,
    };
  }

  List<ClientVehicleBundle> get _filteredBundles {
    final query = _clientQuery.trim().toLowerCase();
    if (query.isEmpty) return _bundles;
    return _bundles
        .where((bundle) => bundle.searchIndex.contains(query))
        .toList();
  }

  Future<void> _loadClients() async {
    if (_loadingClients) return;
    setState(() => _loadingClients = true);
    final repository = ref.read(clientRepositoryProvider);
    final bundles = await repository.listClients();
    if (!mounted) return;
    setState(() {
      _bundles = bundles;
      _loadingClients = false;
      if (_selectedClientId != null &&
          bundles.every((bundle) => bundle.client.id != _selectedClientId)) {
        _selectedClientId = null;
        _selectedVehicleId = null;
      }
      if (_selectedVehicleId != null && _selectedVehicle == null) {
        _selectedVehicleId = null;
      }
    });
  }

  void _setQuantity(String id, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _selected.remove(id);
      } else {
        _selected[id] = quantity;
      }
    });
  }

  void _refreshStepState() {
    if (!mounted || _step != 4) return;
    setState(() {});
  }

  Future<void> _goNext() async {
    if (!_canGoNext || _step >= _steps) return;
    if (_step == 4) {
      final ready = await _ensureClientAndVehicle();
      if (!ready || !mounted) return;
    }
    final nextStep = _step + 1;
    setState(() => _step = nextStep);
    _scrollToTop();
    if (nextStep == 4 && _bundles.isEmpty) {
      await _loadClients();
    }
  }

  void _goBack() {
    if (_step <= 1) return;
    setState(() => _step -= 1);
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<bool> _ensureClientAndVehicle() async {
    if (_clientMode == 'new') return _createClientAndVehicle();
    final client = _selectedClient;
    if (client == null) {
      _showSnack('Selectionne un client avant de continuer.');
      return false;
    }
    if (_selectedVehicle != null) return true;
    if (_hasVehicleDraft) return _createVehicleFor(client.id);
    _showSnack('Selectionne ou cree une voiture pour ce devis.');
    return false;
  }

  Future<bool> _createClientAndVehicle() async {
    if (!_canCreateClient) {
      _showSnack('Nom et telephone client obligatoires.');
      return false;
    }
    if (!_hasVehicleDraft) {
      _showSnack('Marque et modele voiture obligatoires.');
      return false;
    }

    setState(() => _savingClient = true);
    try {
      final repository = ref.read(clientRepositoryProvider);
      final bundle = await repository.upsertClient(
        name: _clientNameController.text,
        email: _clientEmailController.text,
        phone: _clientPhoneController.text,
        address: _clientAddressController.text,
        isProfessional: _newClientIsProfessional,
        companyName: _companyNameController.text,
        vatNumber: _vatNumberController.text,
      );
      await repository.upsertVehicle(
        clientId: bundle.client.id,
        make: _vehicleMakeController.text,
        model: _vehicleModelController.text,
        year: _vehicleYearController.text,
        licensePlate: _vehiclePlateController.text,
        vin: _vehicleVinController.text,
        color: _vehicleColorController.text,
        size: _vehicleSizeFromCatalog(_size),
      );
      final bundles = await repository.listClients();
      if (!mounted) return false;
      final updated = bundles
          .where((item) => item.client.id == bundle.client.id)
          .firstOrNull;
      setState(() {
        _bundles = bundles;
        _selectedClientId = updated?.client.id ?? bundle.client.id;
        _selectedVehicleId = updated?.vehicles.lastOrNull?.id;
        _clientMode = 'existing';
        _clearClientForm();
        _clearVehicleForm();
      });
      return _selectedVehicleId != null;
    } catch (_) {
      _showSnack('Creation du client impossible.');
      return false;
    } finally {
      if (mounted) setState(() => _savingClient = false);
    }
  }

  Future<bool> _createVehicleFor(String clientId) async {
    if (!_hasVehicleDraft) {
      _showSnack('Marque et modele voiture obligatoires.');
      return false;
    }

    setState(() => _savingClient = true);
    try {
      final repository = ref.read(clientRepositoryProvider);
      final vehicle = await repository.upsertVehicle(
        clientId: clientId,
        make: _vehicleMakeController.text,
        model: _vehicleModelController.text,
        year: _vehicleYearController.text,
        licensePlate: _vehiclePlateController.text,
        vin: _vehicleVinController.text,
        color: _vehicleColorController.text,
        size: _vehicleSizeFromCatalog(_size),
      );
      final bundles = await repository.listClients();
      if (!mounted) return false;
      setState(() {
        _bundles = bundles;
        _selectedVehicleId = vehicle.id;
        _showVehicleForm = false;
        _clearVehicleForm();
      });
      return true;
    } catch (_) {
      _showSnack('Creation de la voiture impossible.');
      return false;
    } finally {
      if (mounted) setState(() => _savingClient = false);
    }
  }

  Future<void> _exportQuote({required bool print}) async {
    if (_lines.isEmpty) {
      _showSnack('Ajoute au moins une prestation.');
      return;
    }
    if (_selectedClient == null || _selectedVehicle == null) {
      final ready = await _ensureClientAndVehicle();
      if (!ready || _selectedClient == null || _selectedVehicle == null) return;
    }

    final client = _selectedClient!;
    final vehicle = _selectedVehicle!;
    final bytes = await ref
        .read(pdfServiceProvider)
        .buildQuotePdf(
          QuotePdfInput(
            reference: _reference('DEV'),
            date: DateTime.now(),
            language: 'FR',
            client: DocumentParty(
              name: client.name,
              email: client.email,
              phone: client.phone,
              address: client.address,
              companyName: client.companyName ?? '',
              vatNumber: client.vatNumber ?? '',
            ),
            vehicle: DocumentVehicle(
              make: vehicle.make,
              model: vehicle.model,
              licensePlate: vehicle.licensePlate,
              vin: vehicle.vin ?? '',
              year: vehicle.year,
              color: vehicle.color ?? '',
            ),
            items: [
              for (final line in _lines)
                DocumentLineItem(
                  description: line.service.label,
                  quantity: line.quantity,
                  unitPrice: line.unitPrice,
                  vatRate: _applyVat ? 21 : 0,
                ),
            ],
            applyVat: _applyVat,
            vehicleSize: _vehicleSizeLabel(_size),
            includePackDetails: _includePackDetails,
            showQrCode: _showQrCode,
          ),
        );

    final pdfBytes = Uint8List.fromList(bytes);
    if (print) {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      return;
    }
    final cleanName = client.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'devis_car_luxe_cleaning_$cleanName.pdf',
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearClientForm() {
    _clientNameController.clear();
    _clientPhoneController.clear();
    _clientEmailController.clear();
    _clientAddressController.clear();
    _companyNameController.clear();
    _vatNumberController.clear();
    _newClientIsProfessional = false;
  }

  void _clearVehicleForm() {
    _vehicleMakeController.clear();
    _vehicleModelController.clear();
    _vehicleYearController.clear();
    _vehiclePlateController.clear();
    _vehicleVinController.clear();
    _vehicleColorController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.only(top: isMobile ? 2 : 0, bottom: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BasketPageHeader(),
              const SizedBox(height: 22),
              _BasketProgress(step: _step),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    1 => _CategoryOpenStep(
                      activeCategoryId: _categoryId,
                      onSelect: (id) {
                        setState(() {
                          _categoryId = id;
                          _step = 2;
                        });
                        _scrollToTop();
                      },
                    ),
                    2 => _StepPanel(
                      accentLabel: 'Etape 2 / $_steps',
                      title: 'Gabarit du Vehicule',
                      subtitle:
                          'Selectionnez le format adapte a votre vehicule.',
                      centerHeader: true,
                      child: _SizeSelector(
                        value: _size,
                        onChanged: (value) => setState(() => _size = value),
                      ),
                    ),
                    3 => _ServicesComposerStep(
                      categoryId: _categoryId,
                      activeCategory: _activeCategory,
                      size: _size,
                      selected: _selected,
                      lines: _lines,
                      totalHtva: _totalHtva,
                      applyVat: _applyVat,
                      onCategoryChanged: (id) =>
                          setState(() => _categoryId = id),
                      onQuantityChanged: _setQuantity,
                    ),
                    4 => _ClientVehicleStep(
                      loading: _loadingClients,
                      saving: _savingClient,
                      clientMode: _clientMode,
                      onModeChanged: (value) => setState(() {
                        _clientMode = value;
                        _selectedClientId = value == 'new'
                            ? null
                            : _selectedClientId;
                        _selectedVehicleId = value == 'new'
                            ? null
                            : _selectedVehicleId;
                      }),
                      bundles: _filteredBundles,
                      allBundles: _bundles,
                      clientQuery: _clientQuery,
                      onClientQueryChanged: (value) =>
                          setState(() => _clientQuery = value),
                      selectedClientId: _selectedClientId,
                      selectedVehicleId: _selectedVehicleId,
                      onClientSelected: (bundle) => setState(() {
                        _selectedClientId = bundle.client.id;
                        _selectedVehicleId = bundle.vehicles.firstOrNull?.id;
                        _clientQuery = bundle.client.name;
                      }),
                      onVehicleSelected: (id) =>
                          setState(() => _selectedVehicleId = id),
                      selectedBundle: _selectedBundle,
                      showVehicleForm: _showVehicleForm,
                      onToggleVehicleForm: () =>
                          setState(() => _showVehicleForm = !_showVehicleForm),
                      clientNameController: _clientNameController,
                      clientPhoneController: _clientPhoneController,
                      clientEmailController: _clientEmailController,
                      clientAddressController: _clientAddressController,
                      companyNameController: _companyNameController,
                      vatNumberController: _vatNumberController,
                      isProfessional: _newClientIsProfessional,
                      onProfessionalChanged: (value) =>
                          setState(() => _newClientIsProfessional = value),
                      vehicleMakeController: _vehicleMakeController,
                      vehicleModelController: _vehicleModelController,
                      vehicleYearController: _vehicleYearController,
                      vehiclePlateController: _vehiclePlateController,
                      vehicleVinController: _vehicleVinController,
                      vehicleColorController: _vehicleColorController,
                    ),
                    _ => _FinalSynthesisStep(
                      lines: _lines,
                      size: _size,
                      activeCategory: _activeCategory,
                      selectedClient: _selectedClient,
                      selectedVehicle: _selectedVehicle,
                      totalHtva: _totalHtva,
                      vatTotal: _vatTotal,
                      totalWithVat: _totalWithVat,
                      applyVat: _applyVat,
                      onApplyVatChanged: (value) =>
                          setState(() => _applyVat = value),
                      includePackDetails: _includePackDetails,
                      onIncludePackDetailsChanged: (value) =>
                          setState(() => _includePackDetails = value),
                      showQrCode: _showQrCode,
                      onShowQrCodeChanged: (value) =>
                          setState(() => _showQrCode = value),
                      onBack: _goBack,
                      onPrint: () {
                        _exportQuote(print: true);
                      },
                      onDownload: () {
                        _exportQuote(print: false);
                      },
                    ),
                  },
                ),
              ),
              if (_step < _steps) ...[
                const SizedBox(height: 18),
                _BasketStepActions(
                  step: _step,
                  steps: _steps,
                  canNext: _canGoNext && !_savingClient,
                  onBack: _goBack,
                  onNext: () {
                    _goNext();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BasketLine {
  const _BasketLine({
    required this.category,
    required this.service,
    required this.quantity,
    required this.unitPrice,
  });

  final ServiceCategory category;
  final ServiceCatalogEntry service;
  final int quantity;
  final int unitPrice;

  int get subtotal => quantity * unitPrice;
}

class _BasketPageHeader extends StatelessWidget {
  const _BasketPageHeader();

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final isMobile = Responsive.isMobile(context);

    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PANIER',
                  style: TextStyle(
                    color: colors.mutedStrong,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'CAR ',
                    children: [
                      TextSpan(
                        text: 'LUXE',
                        style: TextStyle(color: colors.focus),
                      ),
                      const TextSpan(text: ' CLEANING'),
                    ],
                  ),
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: isMobile ? 26 : 38,
                    fontWeight: FontWeight.w300,
                    letterSpacing: isMobile ? 3.2 : 5,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.shopping_bag_outlined,
            color: colors.focus,
            size: isMobile ? 24 : 28,
          ),
        ],
      ),
    );
  }
}

class _BasketProgress extends StatelessWidget {
  const _BasketProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    const labels = ['Prestation', 'Gabarit', 'Services', 'Client', 'Devis'];

    return AppCard(
      padding: const EdgeInsets.all(10),
      color: colors.isLight ? colors.surfaceRaised : colors.field,
      borderColor: colors.border,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < labels.length; index += 1)
                SizedBox(
                  width: compact
                      ? (constraints.maxWidth - 8) / 2
                      : (constraints.maxWidth - 32) / labels.length,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index + 1 == step ? colors.focus : colors.field,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: index + 1 == step ? colors.focus : colors.border,
                      ),
                    ),
                    child: Text(
                      labels[index].toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: index + 1 == step
                            ? colors.onFocus
                            : colors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryOpenStep extends StatelessWidget {
  const _CategoryOpenStep({
    required this.activeCategoryId,
    required this.onSelect,
  });

  final String activeCategoryId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return AppCard(
      color: colors.isLight ? colors.surfaceRaised : colors.shell,
      borderColor: colors.border,
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CATEGORIE DE PRESTATION', style: _sectionTitle(context)),
                const SizedBox(height: 8),
                Text(
                  'Selectionnez la categorie de travaux pour continuer.',
                  style: AppTextStyles.body.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 720 ? 1 : 2;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 16)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final category in officialServiceCategories)
                    SizedBox(
                      width: width,
                      child: _CategoryLaunchCard(
                        category: category,
                        active: category.id == activeCategoryId,
                        onTap: () => onSelect(category.id),
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

class _CategoryLaunchCard extends StatelessWidget {
  const _CategoryLaunchCard({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final ServiceCategory category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

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
            color: active
                ? colors.focus.withValues(alpha: colors.isLight ? 0.08 : 0.10)
                : colors.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? colors.focus : colors.border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: _SmallBadge(label: '${category.services.length} lignes'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 86),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label.toUpperCase(),
                      style: TextStyle(
                        color: active ? colors.focus : colors.textStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _categoryDescription(category.id),
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Text(
                          'LANCER',
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: colors.muted,
                          size: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPanel extends StatelessWidget {
  const _StepPanel({
    required this.accentLabel,
    required this.title,
    required this.subtitle,
    required this.child,
    this.centerHeader = false,
  });

  final String accentLabel;
  final String title;
  final String subtitle;
  final Widget child;
  final bool centerHeader;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return AppCard(
      color: colors.isLight ? colors.surfaceRaised : colors.field,
      borderColor: colors.border,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: centerHeader
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: colors.focus, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: centerHeader
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  accentLabel.toUpperCase(),
                  textAlign: centerHeader ? TextAlign.center : TextAlign.left,
                  style: TextStyle(
                    color: colors.focus,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title.toUpperCase(),
                  textAlign: centerHeader ? TextAlign.center : TextAlign.left,
                  style: _sectionTitle(context).copyWith(fontSize: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: centerHeader ? TextAlign.center : TextAlign.left,
                  style: AppTextStyles.body.copyWith(color: colors.muted),
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
            _SizeChoiceCard(
              width: width,
              value: CatalogVehicleSize.s,
              selected: value == CatalogVehicleSize.s,
              title: 'Petites citadines',
              description: 'Citadines standard et compactes legeres',
              onTap: () => onChanged(CatalogVehicleSize.s),
            ),
            _SizeChoiceCard(
              width: width,
              value: CatalogVehicleSize.m,
              selected: value == CatalogVehicleSize.m,
              title: 'Berline',
              description: 'Familiales, routieres, crossovers et breaks',
              onTap: () => onChanged(CatalogVehicleSize.m),
            ),
            _SizeChoiceCard(
              width: width,
              value: CatalogVehicleSize.l,
              selected: value == CatalogVehicleSize.l,
              title: 'Grand',
              description:
                  'SUV prestigieux, monospaces, pick-ups et utilitaires',
              onTap: () => onChanged(CatalogVehicleSize.l),
            ),
          ],
        );
      },
    );
  }
}

class _SizeChoiceCard extends StatelessWidget {
  const _SizeChoiceCard({
    required this.width,
    required this.value,
    required this.selected,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final double width;
  final CatalogVehicleSize value;
  final bool selected;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final letter = value.name.toUpperCase();

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 145),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selected
                  ? colors.focus.withValues(alpha: colors.isLight ? 0.08 : 0.10)
                  : colors.field,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? colors.focus : colors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: _SelectionDot(selected: selected),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        letter,
                        style: TextStyle(
                          color: colors.focus,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _ServicesComposerStep extends StatelessWidget {
  const _ServicesComposerStep({
    required this.categoryId,
    required this.activeCategory,
    required this.size,
    required this.selected,
    required this.lines,
    required this.totalHtva,
    required this.applyVat,
    required this.onCategoryChanged,
    required this.onQuantityChanged,
  });

  final String categoryId;
  final ServiceCategory activeCategory;
  final CatalogVehicleSize size;
  final Map<String, int> selected;
  final List<_BasketLine> lines;
  final int totalHtva;
  final bool applyVat;
  final ValueChanged<String> onCategoryChanged;
  final void Function(String id, int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepPanel(
          accentLabel: 'Etape 3 / 5',
          title: 'Personnaliser la prestation',
          subtitle: 'Ajoutez les options utiles avant de passer au devis.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryTabs(value: categoryId, onChanged: onCategoryChanged),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 1040;
                  final serviceGrid = _ServicePackGrid(
                    category: activeCategory,
                    size: size,
                    selected: selected,
                    onQuantityChanged: onQuantityChanged,
                  );
                  final summary = _BasketSummaryCard(
                    lines: lines,
                    size: size,
                    totalHtva: totalHtva,
                    compact: twoColumns,
                  );
                  if (!twoColumns) {
                    return Column(
                      children: [
                        serviceGrid,
                        const SizedBox(height: 16),
                        summary,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: serviceGrid),
                      const SizedBox(width: 18),
                      Expanded(flex: 3, child: summary),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.isLight ? colors.surfaceRaised : colors.shell,
            borderRadius: BorderRadius.circular(8),
            border: Border(top: BorderSide(color: colors.focus, width: 4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL PANIER :',
                      style: TextStyle(
                        color: colors.mutedStrong,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatMoney(totalHtva),
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (applyVat)
                          Text(
                            'HTVA (TVAC: ${formatMoney(totalHtva * 1.21)})',
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Formule: ${activeCategory.label} [${size.name.toUpperCase()}] + ${lines.length} ligne(s).',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.receipt_long_outlined, color: colors.focus),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final category in officialServiceCategories)
          _MiniChoiceButton(
            label: category.label,
            selected: category.id == value,
            onTap: () => onChanged(category.id),
          ),
      ],
    );
  }
}

class _ServicePackGrid extends StatelessWidget {
  const _ServicePackGrid({
    required this.category,
    required this.size,
    required this.selected,
    required this.onQuantityChanged,
  });

  final ServiceCategory category;
  final CatalogVehicleSize size;
  final Map<String, int> selected;
  final void Function(String id, int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650
            ? 1
            : constraints.maxWidth < 1000
            ? 2
            : 3;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final service in category.services)
              SizedBox(
                width: width,
                child: _ServicePackCard(
                  service: service,
                  price: service.price.resolve(size),
                  sizeLabel: size.name.toUpperCase(),
                  quantity: selected[service.id] ?? 0,
                  onQuantityChanged: (quantity) =>
                      onQuantityChanged(service.id, quantity),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ServicePackCard extends StatelessWidget {
  const _ServicePackCard({
    required this.service,
    required this.price,
    required this.sizeLabel,
    required this.quantity,
    required this.onQuantityChanged,
  });

  final ServiceCatalogEntry service;
  final int price;
  final String sizeLabel;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final selected = quantity > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onQuantityChanged(selected ? 0 : 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 168),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? colors.focus.withValues(alpha: colors.isLight ? 0.08 : 0.10)
                : colors.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colors.focus : colors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 24,
                child: selected
                    ? _SmallBadge(label: 'Selectionne')
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              Text(
                service.label.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      service.price.isFixed
                          ? 'TARIF FIXE :'
                          : 'TARIF FORMAT $sizeLabel :',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    formatMoney(price),
                    style: TextStyle(
                      color: colors.focus,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _QuantityButton(
                    icon: Icons.remove_rounded,
                    enabled: quantity > 0,
                    onTap: () => onQuantityChanged(quantity - 1),
                  ),
                  Container(
                    width: 42,
                    alignment: Alignment.center,
                    child: Text(
                      '$quantity',
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _QuantityButton(
                    icon: Icons.add_rounded,
                    enabled: true,
                    onTap: () => onQuantityChanged(quantity + 1),
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

class _ClientVehicleStep extends StatelessWidget {
  const _ClientVehicleStep({
    required this.loading,
    required this.saving,
    required this.clientMode,
    required this.onModeChanged,
    required this.bundles,
    required this.allBundles,
    required this.clientQuery,
    required this.onClientQueryChanged,
    required this.selectedClientId,
    required this.selectedVehicleId,
    required this.onClientSelected,
    required this.onVehicleSelected,
    required this.selectedBundle,
    required this.showVehicleForm,
    required this.onToggleVehicleForm,
    required this.clientNameController,
    required this.clientPhoneController,
    required this.clientEmailController,
    required this.clientAddressController,
    required this.companyNameController,
    required this.vatNumberController,
    required this.isProfessional,
    required this.onProfessionalChanged,
    required this.vehicleMakeController,
    required this.vehicleModelController,
    required this.vehicleYearController,
    required this.vehiclePlateController,
    required this.vehicleVinController,
    required this.vehicleColorController,
  });

  final bool loading;
  final bool saving;
  final String clientMode;
  final ValueChanged<String> onModeChanged;
  final List<ClientVehicleBundle> bundles;
  final List<ClientVehicleBundle> allBundles;
  final String clientQuery;
  final ValueChanged<String> onClientQueryChanged;
  final String? selectedClientId;
  final String? selectedVehicleId;
  final ValueChanged<ClientVehicleBundle> onClientSelected;
  final ValueChanged<String> onVehicleSelected;
  final ClientVehicleBundle? selectedBundle;
  final bool showVehicleForm;
  final VoidCallback onToggleVehicleForm;
  final TextEditingController clientNameController;
  final TextEditingController clientPhoneController;
  final TextEditingController clientEmailController;
  final TextEditingController clientAddressController;
  final TextEditingController companyNameController;
  final TextEditingController vatNumberController;
  final bool isProfessional;
  final ValueChanged<bool> onProfessionalChanged;
  final TextEditingController vehicleMakeController;
  final TextEditingController vehicleModelController;
  final TextEditingController vehicleYearController;
  final TextEditingController vehiclePlateController;
  final TextEditingController vehicleVinController;
  final TextEditingController vehicleColorController;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return _StepPanel(
      accentLabel: 'Etape 4 / 5',
      title: 'Client & vehicule',
      subtitle:
          'Le devis peut etre genere uniquement lorsqu un client et une voiture sont lies au panier.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Client existant',
                  selected: clientMode == 'existing',
                  onTap: () => onModeChanged('existing'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeButton(
                  label: 'Nouveau client',
                  selected: clientMode == 'new',
                  onTap: () => onModeChanged('new'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (loading)
            const _LoadingBlock()
          else if (clientMode == 'existing')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BasketTextField(
                  controller: null,
                  initialValue: clientQuery,
                  label: 'Selectionner un client existant',
                  hint: 'Rechercher...',
                  prefixIcon: Icons.search_rounded,
                  onChanged: onClientQueryChanged,
                ),
                const SizedBox(height: 14),
                if (allBundles.isEmpty)
                  _EmptyHint(
                    title: 'Aucun client enregistre',
                    subtitle: 'Cree une fiche client depuis ce panier.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 720 ? 1 : 2;
                      final width =
                          (constraints.maxWidth - ((columns - 1) * 12)) /
                          columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final bundle in bundles.take(6))
                            SizedBox(
                              width: width,
                              child: _ClientChoiceCard(
                                bundle: bundle,
                                selected: bundle.client.id == selectedClientId,
                                onTap: () => onClientSelected(bundle),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if (bundles.isEmpty && allBundles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _EmptyHint(
                    title: 'Aucun profil trouve',
                    subtitle: 'Modifie la recherche ou cree un nouveau client.',
                  ),
                ],
                const SizedBox(height: 22),
                _VehiclePicker(
                  selectedBundle: selectedBundle,
                  selectedVehicleId: selectedVehicleId,
                  onVehicleSelected: onVehicleSelected,
                  showVehicleForm: showVehicleForm,
                  onToggleVehicleForm: onToggleVehicleForm,
                  vehicleMakeController: vehicleMakeController,
                  vehicleModelController: vehicleModelController,
                  vehicleYearController: vehicleYearController,
                  vehiclePlateController: vehiclePlateController,
                  vehicleVinController: vehicleVinController,
                  vehicleColorController: vehicleColorController,
                ),
              ],
            )
          else
            _NewClientForm(
              saving: saving,
              clientNameController: clientNameController,
              clientPhoneController: clientPhoneController,
              clientEmailController: clientEmailController,
              clientAddressController: clientAddressController,
              companyNameController: companyNameController,
              vatNumberController: vatNumberController,
              isProfessional: isProfessional,
              onProfessionalChanged: onProfessionalChanged,
              vehicleMakeController: vehicleMakeController,
              vehicleModelController: vehicleModelController,
              vehicleYearController: vehicleYearController,
              vehiclePlateController: vehiclePlateController,
              vehicleVinController: vehicleVinController,
              vehicleColorController: vehicleColorController,
            ),
          if (saving) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              color: colors.focus,
              backgroundColor: colors.border,
            ),
          ],
        ],
      ),
    );
  }
}

class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({
    required this.selectedBundle,
    required this.selectedVehicleId,
    required this.onVehicleSelected,
    required this.showVehicleForm,
    required this.onToggleVehicleForm,
    required this.vehicleMakeController,
    required this.vehicleModelController,
    required this.vehicleYearController,
    required this.vehiclePlateController,
    required this.vehicleVinController,
    required this.vehicleColorController,
  });

  final ClientVehicleBundle? selectedBundle;
  final String? selectedVehicleId;
  final ValueChanged<String> onVehicleSelected;
  final bool showVehicleForm;
  final VoidCallback onToggleVehicleForm;
  final TextEditingController vehicleMakeController;
  final TextEditingController vehicleModelController;
  final TextEditingController vehicleYearController;
  final TextEditingController vehiclePlateController;
  final TextEditingController vehicleVinController;
  final TextEditingController vehicleColorController;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final vehicles = selectedBundle?.vehicles ?? const <Vehicle>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VOITURE LIEE AU DEVIS',
                      style: TextStyle(
                        color: colors.mutedStrong,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Choisis un seul vehicule pour ce document.',
                      style: TextStyle(color: colors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (selectedBundle != null)
                TextButton.icon(
                  onPressed: onToggleVehicleForm,
                  icon: Icon(
                    showVehicleForm ? Icons.close_rounded : Icons.add_rounded,
                    size: 15,
                  ),
                  label: Text(
                    showVehicleForm ? 'Fermer' : 'Ajouter',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (selectedBundle == null)
            _EmptyHint(
              title: 'Aucun client selectionne',
              subtitle: 'Selectionne un client avant d ajouter la voiture.',
            )
          else if (vehicles.isEmpty)
            _EmptyHint(
              title: 'Aucune voiture liee',
              subtitle: 'Ajoute la voiture du client pour finaliser.',
            )
          else
            Column(
              children: [
                for (final vehicle in vehicles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VehicleChoiceCard(
                      vehicle: vehicle,
                      selected: vehicle.id == selectedVehicleId,
                      onTap: () => onVehicleSelected(vehicle.id),
                    ),
                  ),
              ],
            ),
          if (selectedBundle != null && (showVehicleForm || vehicles.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _VehicleForm(
                vehicleMakeController: vehicleMakeController,
                vehicleModelController: vehicleModelController,
                vehicleYearController: vehicleYearController,
                vehiclePlateController: vehiclePlateController,
                vehicleVinController: vehicleVinController,
                vehicleColorController: vehicleColorController,
              ),
            ),
        ],
      ),
    );
  }
}

class _NewClientForm extends StatelessWidget {
  const _NewClientForm({
    required this.saving,
    required this.clientNameController,
    required this.clientPhoneController,
    required this.clientEmailController,
    required this.clientAddressController,
    required this.companyNameController,
    required this.vatNumberController,
    required this.isProfessional,
    required this.onProfessionalChanged,
    required this.vehicleMakeController,
    required this.vehicleModelController,
    required this.vehicleYearController,
    required this.vehiclePlateController,
    required this.vehicleVinController,
    required this.vehicleColorController,
  });

  final bool saving;
  final TextEditingController clientNameController;
  final TextEditingController clientPhoneController;
  final TextEditingController clientEmailController;
  final TextEditingController clientAddressController;
  final TextEditingController companyNameController;
  final TextEditingController vatNumberController;
  final bool isProfessional;
  final ValueChanged<bool> onProfessionalChanged;
  final TextEditingController vehicleMakeController;
  final TextEditingController vehicleModelController;
  final TextEditingController vehicleYearController;
  final TextEditingController vehiclePlateController;
  final TextEditingController vehicleVinController;
  final TextEditingController vehicleColorController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormSectionTitle(
          title: 'Creer client',
          subtitle: 'Le client est enregistre avant la synthese finale.',
        ),
        const SizedBox(height: 12),
        _ResponsiveFields(
          children: [
            _BasketTextField(
              controller: clientNameController,
              label: 'Nom du client *',
              hint: 'Nom du client',
              textCapitalization: TextCapitalization.characters,
            ),
            _BasketTextField(
              controller: clientPhoneController,
              label: 'Telephone *',
              hint: '+32 ...',
              keyboardType: TextInputType.phone,
            ),
            _BasketTextField(
              controller: clientEmailController,
              label: 'Email',
              hint: 'client@email.be',
              keyboardType: TextInputType.emailAddress,
            ),
            _BasketTextField(
              controller: clientAddressController,
              label: 'Adresse',
              hint: 'Rue, ville',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SwitchLine(
          label: 'Client professionnel',
          value: isProfessional,
          onChanged: onProfessionalChanged,
        ),
        if (isProfessional) ...[
          const SizedBox(height: 12),
          _ResponsiveFields(
            children: [
              _BasketTextField(
                controller: companyNameController,
                label: 'Societe',
                hint: 'Nom societe',
                textCapitalization: TextCapitalization.characters,
              ),
              _BasketTextField(
                controller: vatNumberController,
                label: 'Numero TVA',
                hint: 'BE...',
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        _FormSectionTitle(
          title: 'Completer la voiture',
          subtitle: 'Marque et modele sont obligatoires.',
        ),
        const SizedBox(height: 12),
        _VehicleForm(
          vehicleMakeController: vehicleMakeController,
          vehicleModelController: vehicleModelController,
          vehicleYearController: vehicleYearController,
          vehiclePlateController: vehiclePlateController,
          vehicleVinController: vehicleVinController,
          vehicleColorController: vehicleColorController,
        ),
      ],
    );
  }
}

class _VehicleForm extends StatelessWidget {
  const _VehicleForm({
    required this.vehicleMakeController,
    required this.vehicleModelController,
    required this.vehicleYearController,
    required this.vehiclePlateController,
    required this.vehicleVinController,
    required this.vehicleColorController,
  });

  final TextEditingController vehicleMakeController;
  final TextEditingController vehicleModelController;
  final TextEditingController vehicleYearController;
  final TextEditingController vehiclePlateController;
  final TextEditingController vehicleVinController;
  final TextEditingController vehicleColorController;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveFields(
      children: [
        _BasketTextField(
          controller: vehicleMakeController,
          label: 'Marque *',
          hint: 'BMW',
          textCapitalization: TextCapitalization.characters,
        ),
        _BasketTextField(
          controller: vehicleModelController,
          label: 'Modele *',
          hint: 'Serie 3',
          textCapitalization: TextCapitalization.characters,
        ),
        _BasketTextField(
          controller: vehicleColorController,
          label: 'Couleur',
          hint: 'Noir',
        ),
        _BasketTextField(
          controller: vehicleYearController,
          label: 'Annee',
          hint: '2024',
          keyboardType: TextInputType.number,
        ),
        _BasketTextField(
          controller: vehiclePlateController,
          label: 'Plaque',
          hint: '1-ABC-123',
          textCapitalization: TextCapitalization.characters,
        ),
        _BasketTextField(
          controller: vehicleVinController,
          label: 'VIN',
          hint: 'VIN',
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }
}

class _FinalSynthesisStep extends StatelessWidget {
  const _FinalSynthesisStep({
    required this.lines,
    required this.size,
    required this.activeCategory,
    required this.selectedClient,
    required this.selectedVehicle,
    required this.totalHtva,
    required this.vatTotal,
    required this.totalWithVat,
    required this.applyVat,
    required this.onApplyVatChanged,
    required this.includePackDetails,
    required this.onIncludePackDetailsChanged,
    required this.showQrCode,
    required this.onShowQrCodeChanged,
    required this.onBack,
    required this.onPrint,
    required this.onDownload,
  });

  final List<_BasketLine> lines;
  final CatalogVehicleSize size;
  final ServiceCategory activeCategory;
  final Client? selectedClient;
  final Vehicle? selectedVehicle;
  final int totalHtva;
  final double vatTotal;
  final double totalWithVat;
  final bool applyVat;
  final ValueChanged<bool> onApplyVatChanged;
  final bool includePackDetails;
  final ValueChanged<bool> onIncludePackDetailsChanged;
  final bool showQrCode;
  final ValueChanged<bool> onShowQrCodeChanged;
  final VoidCallback onBack;
  final VoidCallback onPrint;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepPanel(
          accentLabel: 'Etape 5 / 5',
          title: 'Synthese finale',
          subtitle: 'Verifie le panier puis genere le devis PDF.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 640
                      ? 1
                      : constraints.maxWidth < 980
                      ? 2
                      : 5;
                  final width =
                      (constraints.maxWidth - ((columns - 1) * 12)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SummaryTile(
                        width: width,
                        label: 'Client',
                        value: selectedClient?.name ?? '-',
                      ),
                      _SummaryTile(
                        width: width,
                        label: 'Vehicule',
                        value: selectedVehicle == null
                            ? '-'
                            : '${selectedVehicle!.make} ${selectedVehicle!.model}',
                      ),
                      _SummaryTile(
                        width: width,
                        label: 'Service',
                        value: activeCategory.label,
                      ),
                      _SummaryTile(
                        width: width,
                        label: 'Gabarit',
                        value: _vehicleSizeLabel(size),
                      ),
                      _SummaryTile(
                        width: width,
                        label: 'Formule',
                        value: '${lines.length} ligne(s)',
                        accent: true,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _BasketInfoRow(
                label: 'Lignes du devis',
                value: '${lines.length}',
              ),
              const SizedBox(height: 12),
              _SelectedLinesList(lines: lines),
              const SizedBox(height: 16),
              _VatToggle(value: applyVat, onChanged: onApplyVatChanged),
              const SizedBox(height: 12),
              _SwitchLine(
                label: 'Inclure detail de pack',
                value: includePackDetails,
                onChanged: onIncludePackDetailsChanged,
              ),
              const SizedBox(height: 10),
              _SwitchLine(
                label: 'Afficher QR code',
                value: showQrCode,
                onChanged: onShowQrCodeChanged,
              ),
              const SizedBox(height: 16),
              _TotalPanel(
                totalHtva: totalHtva,
                vatTotal: vatTotal,
                totalWithVat: totalWithVat,
                applyVat: applyVat,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 740;
            final children = [
              AppButton(
                label: 'Revenir au client',
                icon: Icons.arrow_back_rounded,
                tone: AppButtonTone.secondary,
                expanded: stacked,
                onPressed: onBack,
              ),
              AppButton(
                label: 'Imprimer devis',
                icon: Icons.print_rounded,
                expanded: stacked,
                onPressed: onPrint,
              ),
              AppButton(
                label: 'Telecharger',
                icon: Icons.picture_as_pdf_rounded,
                tone: AppButtonTone.secondary,
                expanded: stacked,
                onPressed: onDownload,
              ),
            ];
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < children.length; index += 1) ...[
                    children[index],
                    if (index < children.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 12),
                Expanded(child: children[1]),
                const SizedBox(width: 12),
                Expanded(child: children[2]),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.go('/documents?module=devis'),
            icon: Icon(
              Icons.open_in_new_rounded,
              color: colors.muted,
              size: 16,
            ),
            label: Text(
              'Ouvrir le module documents',
              style: TextStyle(
                color: colors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BasketStepActions extends StatelessWidget {
  const _BasketStepActions({
    required this.step,
    required this.steps,
    required this.canNext,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final int steps;
  final bool canNext;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 620;
        final back = AppButton(
          label: step <= 1 ? 'Precedent' : 'Precedent',
          icon: Icons.arrow_back_rounded,
          tone: AppButtonTone.secondary,
          expanded: stacked,
          onPressed: step <= 1 ? null : onBack,
        );
        final next = AppButton(
          label: step >= steps
              ? 'Devis'
              : step == 4
              ? 'Synthese'
              : 'Suivant',
          icon: Icons.arrow_forward_rounded,
          expanded: stacked,
          onPressed: canNext ? onNext : null,
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [back, const SizedBox(height: 10), next],
          );
        }
        return Row(
          children: [
            Expanded(child: back),
            const SizedBox(width: 12),
            Expanded(child: next),
          ],
        );
      },
    );
  }
}

class _BasketSummaryCard extends StatelessWidget {
  const _BasketSummaryCard({
    required this.lines,
    required this.size,
    required this.totalHtva,
    this.compact = false,
  });

  final List<_BasketLine> lines;
  final CatalogVehicleSize size;
  final int totalHtva;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.focus.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PANIER ACTUEL',
            style: AppTextStyles.eyebrow.copyWith(color: colors.mutedStrong),
          ),
          const SizedBox(height: 16),
          if (lines.isEmpty)
            Text(
              'Selectionne une prestation pour preparer un devis.',
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            )
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${line.quantity} x ${line.service.label}',
                        style: TextStyle(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(line.subtotal),
                      style: TextStyle(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 18),
          Divider(color: colors.border),
          const SizedBox(height: 16),
          Text(
            'TOTAL ACTUEL',
            style: TextStyle(
              color: colors.mutedStrong,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(totalHtva),
            style: TextStyle(
              color: colors.focus,
              fontSize: compact ? 30 : 34,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _vehicleSizeLabel(size),
            style: TextStyle(
              color: colors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedLinesList extends StatelessWidget {
  const _SelectedLinesList({required this.lines});

  final List<_BasketLine> lines;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    if (lines.isEmpty) {
      return _EmptyHint(
        title: 'Panier vide',
        subtitle: 'Reviens aux services pour ajouter une prestation.',
      );
    }

    return Column(
      children: [
        for (final line in lines)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.service.label.toUpperCase(),
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        line.category.label,
                        style: TextStyle(color: colors.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${line.quantity} x ${formatMoney(line.unitPrice)}',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatMoney(line.subtotal),
                  style: TextStyle(
                    color: colors.focus,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TotalPanel extends StatelessWidget {
  const _TotalPanel({
    required this.totalHtva,
    required this.vatTotal,
    required this.totalWithVat,
    required this.applyVat,
  });

  final int totalHtva;
  final double vatTotal;
  final double totalWithVat;
  final bool applyVat;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.focus.withValues(alpha: colors.isLight ? 0.08 : 0.10),
            colors.field,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.focus.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          if (applyVat) ...[
            Row(
              children: [
                _TotalMini(
                  label: 'Sous-total HTVA',
                  value: formatMoney(totalHtva),
                ),
                const SizedBox(width: 16),
                _TotalMini(label: 'TVA 21%', value: formatMoney(vatTotal)),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: colors.border),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL ESTIME ${applyVat ? 'TTC' : 'HTVA'}',
                      style: TextStyle(
                        color: colors.focus,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Montant du devis avant validation.',
                      style: TextStyle(color: colors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Text(
                formatMoney(applyVat ? totalWithVat : totalHtva),
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalMini extends StatelessWidget {
  const _TotalMini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colors.mutedStrong,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: colors.textStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VatToggle extends StatelessWidget {
  const _VatToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: value
                ? colors.focus.withValues(alpha: colors.isLight ? 0.08 : 0.10)
                : colors.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value
                  ? colors.focus.withValues(alpha: 0.50)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              _SelectionDot(selected: value),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'APPLIQUER LA TVA (21%)',
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Text(
                value ? 'AVEC TVA' : 'SANS TVA',
                style: TextStyle(
                  color: colors.focus,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: colors.focus,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _BasketInfoRow extends StatelessWidget {
  const _BasketInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: colors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.width,
    required this.label,
    required this.value,
    this.accent = false,
  });

  final double width;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.field,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: colors.mutedStrong,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent ? colors.focus : colors.textStrong,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientChoiceCard extends StatelessWidget {
  const _ClientChoiceCard({
    required this.bundle,
    required this.selected,
    required this.onTap,
  });

  final ClientVehicleBundle bundle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? colors.focus.withValues(alpha: colors.isLight ? 0.08 : 0.10)
                : colors.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? colors.focus : colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.client.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        bundle.client.phone,
                        if ((bundle.client.companyName ?? '').isNotEmpty)
                          bundle.client.companyName!,
                      ].where((value) => value.trim().isNotEmpty).join('  -  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 10),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${bundle.vehicles.length} voiture(s)',
                      style: TextStyle(
                        color: colors.focus,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _SelectionDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleChoiceCard extends StatelessWidget {
  const _VehicleChoiceCard({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? colors.focus.withValues(alpha: colors.isLight ? 0.08 : 0.10)
                : colors.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? colors.focus : colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.make} ${vehicle.model}'.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Plaque : ${vehicle.displayPlate}',
                      style: TextStyle(color: colors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              _SelectionDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? colors.focus : colors.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? colors.focus : colors.border),
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? colors.onFocus : colors.textStrong,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChoiceButton extends StatelessWidget {
  const _MiniChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? colors.focus : colors.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? colors.focus : colors.border),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: selected ? colors.onFocus : colors.textStrong,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        color: colors.focus,
        disabledColor: colors.muted.withValues(alpha: 0.35),
        style: IconButton.styleFrom(
          backgroundColor: colors.field,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.border),
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
    final colors = ClcThemeColors.of(context);

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: selected ? colors.focus : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.focus : colors.borderStrong,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 13, color: colors.onFocus)
          : null,
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.focus.withValues(alpha: colors.isLight ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.focus.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: colors.focus,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _BasketTextField extends StatelessWidget {
  const _BasketTextField({
    required this.label,
    required this.hint,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: colors.mutedStrong,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          onChanged: onChanged,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: colors.muted, size: 18),
            hintText: hint,
            hintStyle: TextStyle(color: colors.muted.withValues(alpha: 0.6)),
            filled: true,
            fillColor: colors.field,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.focus),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720 ? 1 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: colors.focus,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: TextStyle(color: colors.muted, fontSize: 12)),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: colors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.focus,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Chargement...',
            style: TextStyle(color: colors.muted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

TextStyle _sectionTitle(BuildContext context) {
  final colors = ClcThemeColors.of(context);
  return TextStyle(
    color: colors.textStrong,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.6,
    height: 1.08,
  );
}

String _categoryDescription(String id) {
  return switch (id) {
    'lavage' => 'Lavage, decontamination et brillance exterieure.',
    'reconditionnement' => 'Remise a neuf interieur et exterieur premium.',
    'polissage' => 'Correction et renovation de carrosserie.',
    'ceramique' => 'Protection durable des surfaces et finitions.',
    'supplements' => 'Modules additionnels, pickup et extras atelier.',
    _ => 'Composition personnalisee.',
  };
}

String _vehicleSizeLabel(CatalogVehicleSize size) {
  return switch (size) {
    CatalogVehicleSize.s => 'Taille S',
    CatalogVehicleSize.m => 'Taille M',
    CatalogVehicleSize.l => 'Taille L',
  };
}

VehicleSize _vehicleSizeFromCatalog(CatalogVehicleSize size) {
  return switch (size) {
    CatalogVehicleSize.s => VehicleSize.s,
    CatalogVehicleSize.m => VehicleSize.m,
    CatalogVehicleSize.l => VehicleSize.l,
  };
}

String _reference(String prefix) {
  final now = DateTime.now();
  final day = now.day.toString().padLeft(2, '0');
  final month = now.month.toString().padLeft(2, '0');
  final short = now.millisecondsSinceEpoch.toString().substring(7);
  return '$prefix-$day$month-${now.year}-$short';
}
