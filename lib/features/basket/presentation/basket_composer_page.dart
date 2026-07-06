import 'dart:convert';

import 'package:car_luxe_cleaning_flutter/app/theme.dart';
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
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

const _basketLightPrestation = Color(0xFFE2E8F0);
const _basketLightPrestationBorder = Color(0xFFD8DEE8);
const _basketDarkChoice = Color(0xFF111827);
const _basketAccent = Color(0xFFAFF700);

String _basketEuro(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index += 1) {
    final remaining = rounded.length - index;
    buffer.write(rounded[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(' ');
  }
  final sign = value < 0 ? '-' : '';
  return '$sign€${buffer.toString()}';
}

String _basketEuroPlus(num value) => '+${_basketEuro(value)}';

class BasketComposerPage extends ConsumerStatefulWidget {
  const BasketComposerPage({super.key});

  @override
  ConsumerState<BasketComposerPage> createState() => _BasketComposerPageState();
}

class _BasketComposerPageState extends ConsumerState<BasketComposerPage> {
  static const _steps = 5;

  int _step = 1;
  CatalogVehicleSize _size = CatalogVehicleSize.s;
  String _categoryId = 'interior';
  String _chosenPack = 'serenite';
  String _exteriorChoice = 'lavage';
  String _polishType = 'integral';
  final Set<String> _selectedInteriorExtras = {};
  final Set<String> _selectedExteriorExtras = {};
  final Set<String> _selectedShampooExtras = {};
  final Map<String, int> _customExteriorPrices = {};
  final List<_PolishingPart> _selectedPolishingParts = [];
  bool _selectedPickup = false;
  bool _selectedCourtesyCar = false;

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

  List<_BasketLine> get _lines {
    final lines = <_BasketLine>[];
    final sizeLabel = _vehicleSizeCode(_size);
    if (_categoryId == 'interior') {
      if (_chosenPack == 'serenite') {
        lines.add(
          _BasketLine(
            categoryLabel: 'Intérieur',
            serviceLabel: 'Pack Sérénité - Intérieur • Taille [$sizeLabel]',
            quantity: 1,
            unitPrice: _packPrice('serenite'),
          ),
        );
      } else if (_chosenPack == 'purete') {
        lines.add(
          _BasketLine(
            categoryLabel: 'Intérieur',
            serviceLabel:
                'Pack Pureté Complet - Intérieur • Taille [$sizeLabel]',
            quantity: 1,
            unitPrice: _packPrice('purete'),
          ),
        );
        for (final option in interiorExtraOptions) {
          lines.add(
            _BasketLine(
              categoryLabel: 'Inclus',
              serviceLabel: 'Inclus : ${option.name} [$sizeLabel]',
              quantity: 1,
              unitPrice: 0,
            ),
          );
        }
      } else {
        lines.add(
          _BasketLine(
            categoryLabel: 'Intérieur',
            serviceLabel:
                'Composition personnalisée - Intérieur • Taille [$sizeLabel]',
            quantity: 1,
            unitPrice: 0,
          ),
        );
      }

      if (_chosenPack == 'serenite' || _chosenPack == 'composition') {
        for (final option in interiorExtraOptions) {
          if (!_selectedInteriorExtras.contains(option.id)) continue;
          lines.add(
            _BasketLine(
              categoryLabel: _chosenPack == 'composition'
                  ? 'Élément intérieur'
                  : 'Option intérieure',
              serviceLabel: '${option.name} [$sizeLabel]',
              quantity: 1,
              unitPrice: option.priceFor(_size),
            ),
          );
        }
      }
    } else {
      if (_exteriorChoice == 'polissage' && _polishType == 'partiel') {
        if (_selectedPolishingParts.isEmpty) {
          lines.add(
            _BasketLine(
              categoryLabel: 'Polissage partiel',
              serviceLabel:
                  'Diagnostic polissage partiel personnalisé • Taille [$sizeLabel]',
              quantity: 1,
              unitPrice: 0,
            ),
          );
        } else {
          lines.add(
            _BasketLine(
              categoryLabel: 'Polissage partiel',
              serviceLabel:
                  'Diagnostic polissage partiel • Taille [$sizeLabel]',
              quantity: 1,
              unitPrice: 0,
            ),
          );
          for (final part in _selectedPolishingParts) {
            lines.add(
              _BasketLine(
                categoryLabel: 'Élément à polir',
                serviceLabel: part.label,
                quantity: 1,
                unitPrice: part.price,
              ),
            );
          }
        }
      } else {
        lines.add(
          _BasketLine(
            categoryLabel: 'Extérieur',
            serviceLabel:
                '${_selectedPackLabel()} - Extérieur • Taille [$sizeLabel]',
            quantity: 1,
            unitPrice: _packPrice(_chosenPack),
          ),
        );

        for (final option in exteriorSuggestionOptions) {
          if (!_selectedExteriorExtras.contains(option.id)) continue;
          lines.add(
            _BasketLine(
              categoryLabel: 'Option extérieure',
              serviceLabel: option.name,
              quantity: 1,
              unitPrice: option.priceFor(
                size: _size,
                pack: _chosenPack,
                customPrice: _customExteriorPrices[option.id],
              ),
            ),
          );
        }
      }

      for (final option in interiorExtraOptions) {
        if (!_selectedShampooExtras.contains(option.id)) continue;
        lines.add(
          _BasketLine(
            categoryLabel: 'Shampooing intérieur optionnel',
            serviceLabel: '${option.name} [$sizeLabel]',
            quantity: 1,
            unitPrice: option.priceFor(_size),
          ),
        );
      }
    }

    if (_selectedPickup) {
      lines.add(
        const _BasketLine(
          categoryLabel: 'Service pickup',
          serviceLabel: 'Pickup aller-retour',
          quantity: 1,
          unitPrice: 50,
        ),
      );
    }
    if (_selectedCourtesyCar) {
      lines.add(
        const _BasketLine(
          categoryLabel: 'Mobilité',
          serviceLabel: 'Voiture de courtoisie',
          quantity: 1,
          unitPrice: 50,
        ),
      );
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

  void _toggleSet(Set<String> values, String id) {
    if (values.contains(id)) {
      values.remove(id);
    } else {
      values.add(id);
    }
  }

  int _packPrice(String pack) => packPrices[pack]?.priceFor(_size) ?? 0;

  String _selectedPackLabel() {
    return switch (_chosenPack) {
      'serenite' => 'Pack Sérénité',
      'purete' => 'Pack Pureté',
      'composition' => 'Composition personnalisée',
      'splendeur' => 'Pack Splendeur',
      'medium' => 'Polissage Moyen',
      'approfondi' => 'Polissage Approfondi',
      'brillance' => 'Pack Brillance',
      'renaissance' => 'Pack Renaissance',
      'signature' => 'Pack Signature',
      _ => 'Pack',
    };
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
                  description: line.serviceLabel,
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
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    1 => _CategoryOpenStep(
                      onSelect: (id) {
                        setState(() {
                          _categoryId = id;
                          if (id == 'exterior') {
                            _exteriorChoice = 'lavage';
                            _polishType = 'integral';
                            _chosenPack = 'splendeur';
                          } else {
                            _chosenPack = 'serenite';
                          }
                          _step = 2;
                        });
                        _scrollToTop();
                      },
                    ),
                    2 => _VehicleSizeAndTypeStep(
                      size: _size,
                      categoryId: _categoryId,
                      exteriorChoice: _exteriorChoice,
                      polishType: _polishType,
                      onSizeChanged: (value) => setState(() => _size = value),
                      onExteriorChoiceChanged: (value) => setState(() {
                        _exteriorChoice = value;
                        if (value == 'lavage') {
                          _polishType = 'integral';
                          _chosenPack = 'splendeur';
                        } else {
                          _polishType = 'integral';
                          _chosenPack = 'medium';
                        }
                      }),
                      onPolishTypeChanged: (value) => setState(() {
                        _polishType = value;
                        _chosenPack = value == 'partiel' ? 'medium' : 'medium';
                      }),
                    ),
                    3 => _ServicesComposerStep(
                      categoryId: _categoryId,
                      size: _size,
                      chosenPack: _chosenPack,
                      exteriorChoice: _exteriorChoice,
                      polishType: _polishType,
                      selectedInteriorExtras: _selectedInteriorExtras,
                      selectedExteriorExtras: _selectedExteriorExtras,
                      selectedShampooExtras: _selectedShampooExtras,
                      customExteriorPrices: _customExteriorPrices,
                      selectedPolishingParts: _selectedPolishingParts,
                      selectedPickup: _selectedPickup,
                      selectedCourtesyCar: _selectedCourtesyCar,
                      lines: _lines,
                      totalHtva: _totalHtva,
                      applyVat: _applyVat,
                      onPackChanged: (value) =>
                          setState(() => _chosenPack = value),
                      onInteriorExtraToggled: (id) => setState(
                        () => _toggleSet(_selectedInteriorExtras, id),
                      ),
                      onExteriorExtraToggled: (id) => setState(() {
                        final option = exteriorSuggestionOptions.firstWhere(
                          (item) => item.id == id,
                        );
                        if (option.isCeramicChoice) {
                          for (final item in exteriorSuggestionOptions) {
                            if (item.isCeramicChoice && item.id != id) {
                              _selectedExteriorExtras.remove(item.id);
                            }
                          }
                        }
                        _toggleSet(_selectedExteriorExtras, id);
                      }),
                      onShampooExtraToggled: (id) => setState(
                        () => _toggleSet(_selectedShampooExtras, id),
                      ),
                      onCustomExteriorPriceChanged: (id, value) => setState(() {
                        if (value <= 0) {
                          _customExteriorPrices.remove(id);
                        } else {
                          _customExteriorPrices[id] = value;
                        }
                      }),
                      onPolishingPartsChanged: (parts) => setState(() {
                        _selectedPolishingParts
                          ..clear()
                          ..addAll(parts);
                      }),
                      onPickupChanged: (value) =>
                          setState(() => _selectedPickup = value),
                      onCourtesyCarChanged: (value) =>
                          setState(() => _selectedCourtesyCar = value),
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
                      activeCategoryLabel: _categoryId == 'interior'
                          ? 'Intérieur'
                          : 'Extérieur',
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
              if (_step > 1 && _step < _steps) ...[
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

class _InteriorPackSelector extends StatelessWidget {
  const _InteriorPackSelector({
    required this.chosenPack,
    required this.size,
    required this.onChanged,
  });

  final String chosenPack;
  final CatalogVehicleSize size;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 760 ? 1 : 3;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        final cards = [
          _PackCardData(
            id: 'serenite',
            title: 'Pack Sérénité',
            subtitle: 'Pour un entretien régulier',
            priceLabel: _basketEuro(packPrices['serenite']!.priceFor(size)),
          ),
          _PackCardData(
            id: 'purete',
            title: 'Pack Pureté',
            subtitle: 'Remise à neuf',
            priceLabel: _basketEuro(packPrices['purete']!.priceFor(size)),
            recommended: true,
          ),
          const _PackCardData(
            id: 'composition',
            title: 'Composition personnalisée',
            subtitle: 'Choix par élément',
            priceLabel: 'À la carte',
          ),
        ];
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _PackChoiceCard(
                  data: card,
                  selected: chosenPack == card.id,
                  onTap: () => onChanged(card.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ExteriorLavageSelector extends StatelessWidget {
  const _ExteriorLavageSelector({
    required this.chosenPack,
    required this.size,
    required this.onChanged,
  });

  final String chosenPack;
  final CatalogVehicleSize size;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PackChoiceCard(
      data: _PackCardData(
        id: 'splendeur',
        title: 'Pack Splendeur',
        subtitle: 'Lavage extérieur premium',
        priceLabel: _basketEuro(packPrices['splendeur']!.priceFor(size)),
        recommended: true,
      ),
      selected: chosenPack == 'splendeur',
      onTap: () => onChanged('splendeur'),
    );
  }
}

class _PolishingIntegralSelector extends StatelessWidget {
  const _PolishingIntegralSelector({
    required this.chosenPack,
    required this.size,
    required this.onChanged,
  });

  final String chosenPack;
  final CatalogVehicleSize size;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 760 ? 1 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        final cards = [
          _PackCardData(
            id: 'medium',
            title: 'Polissage Moyen',
            subtitle: 'Correction standard',
            priceLabel: _basketEuro(packPrices['medium']!.priceFor(size)),
            description:
                'Idéal pour micro-rayures légères, voile terne et remise en brillance propre.',
          ),
          _PackCardData(
            id: 'approfondi',
            title: 'Polissage Approfondi',
            subtitle: 'Correction avancée',
            priceLabel: _basketEuro(packPrices['approfondi']!.priceFor(size)),
            description:
                'Pour défauts plus marqués, correction plus complète et finition plus poussée.',
            recommended: true,
          ),
        ];
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _PackChoiceCard(
                  data: card,
                  selected: chosenPack == card.id,
                  onTap: () => onChanged(card.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PackCardData {
  const _PackCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    this.description,
    this.recommended = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String priceLabel;
  final String? description;
  final bool recommended;
}

class _PackChoiceCard extends StatelessWidget {
  const _PackChoiceCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _PackCardData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final selectedBackground = colors.isLight
        ? const Color(0xFFF0F1F3)
        : colors.focus.withValues(alpha: 0.10);
    final idleBackground = colors.isLight
        ? Colors.white
        : colors.surfaceRaised.withValues(alpha: 0.18);
    final selectedBorder = colors.isLight ? colors.borderStrong : colors.focus;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 155),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected ? selectedBackground : idleBackground,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: selected ? selectedBorder : colors.border,
              width: selected && colors.isLight ? 1.6 : 1,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selected) _SmallBadge(label: 'Sélectionné'),
                        if (!selected) const SizedBox(height: 28),
                        const SizedBox(height: 8),
                        Text(
                          data.title.toUpperCase(),
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.subtitle,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data.recommended)
                    const _RecommendedBadge()
                  else
                    _SelectionDot(selected: selected),
                ],
              ),
              if (data.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  data.description!,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Divider(color: colors.border),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.priceLabel == 'À la carte'
                          ? 'BASE :'
                          : 'TARIF FORMAT :',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    data.priceLabel,
                    style: TextStyle(
                      color: colors.focus,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
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

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1FCA8A04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 13, color: Color(0xFFCA8A04)),
          SizedBox(width: 4),
          Text(
            'RECOMMANDÉ',
            style: TextStyle(
              color: Color(0xFFCA8A04),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteriorComparisonTable extends StatelessWidget {
  const _InteriorComparisonTable({
    required this.chosenPack,
    required this.size,
  });

  final String chosenPack;
  final CatalogVehicleSize size;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _ComparisonRowData(
        text: 'Tarif format sélectionné',
        values: {
          'Sérénité': _basketEuro(packPrices['serenite']!.priceFor(size)),
          'Pureté': _basketEuro(packPrices['purete']!.priceFor(size)),
        },
      ),
      const _ComparisonRowData(
        text: 'Usage conseillé',
        values: {'Sérénité': 'Entretien régulier', 'Pureté': 'Remise à neuf'},
      ),
      const _ComparisonRowData(
        text: 'Lavage intérieur premium',
        values: {'Sérénité': true, 'Pureté': true},
      ),
      const _ComparisonRowData(
        text: 'Shampoing des textiles et zones intérieures',
        values: {'Sérénité': 'Options', 'Pureté': true},
      ),
      const _ComparisonRowData(
        text: 'Traitement et soin des cuirs',
        values: {'Sérénité': 'Option', 'Pureté': true},
      ),
      const _ComparisonRowData(
        text: 'Reconditionnement complet habitacle',
        values: {'Sérénité': false, 'Pureté': true},
      ),
    ];
    return _ComparisonTable(
      eyebrow: 'Comparatif intérieur',
      note: "Choisis selon le niveau d'intervention attendu.",
      columns: const ['Sérénité', 'Pureté'],
      activeColumn: chosenPack == 'purete' ? 'Pureté' : 'Sérénité',
      rows: rows,
    );
  }
}

class _ExteriorComparisonTable extends StatelessWidget {
  const _ExteriorComparisonTable({
    required this.chosenPack,
    required this.size,
    required this.showSplendeur,
  });

  final String chosenPack;
  final CatalogVehicleSize size;
  final bool showSplendeur;

  @override
  Widget build(BuildContext context) {
    final columns = showSplendeur
        ? const ['Splendeur', 'Moyen', 'Approfondi']
        : const ['Moyen', 'Approfondi'];
    final rows = [
      _ComparisonRowData(
        text: 'Tarif format sélectionné',
        values: {
          if (showSplendeur)
            'Splendeur': _basketEuro(packPrices['splendeur']!.priceFor(size)),
          'Moyen': _basketEuro(packPrices['medium']!.priceFor(size)),
          'Approfondi': _basketEuro(packPrices['approfondi']!.priceFor(size)),
        },
      ),
      for (final item in exteriorComparativeItems)
        _ComparisonRowData(
          text: item.text,
          values: {
            if (showSplendeur) 'Splendeur': item.splendeur,
            'Moyen': item.medium,
            'Approfondi': item.approfondi,
          },
        ),
    ];
    final activeColumn = switch (chosenPack) {
      'splendeur' => 'Splendeur',
      'approfondi' => 'Approfondi',
      _ => 'Moyen',
    };
    return _ComparisonTable(
      eyebrow: showSplendeur ? 'Comparatif extérieur' : 'Comparatif polissage',
      note: 'Visualise clairement ce qui est inclus dans chaque niveau.',
      columns: columns,
      activeColumn: activeColumn,
      rows: rows,
    );
  }
}

class _ComparisonRowData {
  const _ComparisonRowData({required this.text, required this.values});

  final String text;
  final Map<String, Object> values;
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.eyebrow,
    required this.note,
    required this.columns,
    required this.activeColumn,
    required this.rows,
  });

  final String eyebrow;
  final String note;
  final List<String> columns;
  final String activeColumn;
  final List<_ComparisonRowData> rows;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.isLight
            ? Colors.white
            : colors.shell.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              color: colors.focus,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 620),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: {
                    0: const FlexColumnWidth(1.6),
                    for (var i = 0; i < columns.length; i += 1)
                      i + 1: const FlexColumnWidth(0.82),
                  },
                  border: TableBorder.all(color: colors.border),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: colors.surfaceRaised.withValues(
                          alpha: colors.isLight ? 1 : 0.25,
                        ),
                      ),
                      children: [
                        _ComparisonCell(
                          text: 'Comparaison',
                          header: true,
                          muted: true,
                        ),
                        for (final column in columns)
                          _ComparisonCell(
                            text: column,
                            header: true,
                            active: column == activeColumn,
                            center: true,
                          ),
                      ],
                    ),
                    for (final row in rows)
                      TableRow(
                        children: [
                          _ComparisonCell(text: row.text),
                          for (final column in columns)
                            _ComparisonValueCell(
                              value: row.values[column] ?? false,
                              active: column == activeColumn,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCell extends StatelessWidget {
  const _ComparisonCell({
    required this.text,
    this.header = false,
    this.active = false,
    this.center = false,
    this.muted = false,
  });

  final String text;
  final bool header;
  final bool active;
  final bool center;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          color: active
              ? colors.focus
              : muted
              ? colors.mutedStrong
              : colors.textStrong,
          fontSize: header ? 10 : 11,
          fontWeight: header ? FontWeight.w900 : FontWeight.w800,
          letterSpacing: header ? 1.1 : 0,
        ),
      ),
    );
  }
}

class _ComparisonValueCell extends StatelessWidget {
  const _ComparisonValueCell({required this.value, required this.active});

  final Object value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final child = switch (value) {
      true => Icon(Icons.check_rounded, color: colors.focus, size: 18),
      false => Icon(Icons.close_rounded, color: colors.danger, size: 17),
      _ => Text(
        '$value'.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.textStrong,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    };

    return Container(
      color: active ? colors.focus.withValues(alpha: 0.06) : null,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _InteriorExtrasGrid extends StatelessWidget {
  const _InteriorExtrasGrid({
    required this.chosenPack,
    required this.size,
    required this.selectedIds,
    required this.onToggle,
  });

  final String chosenPack;
  final CatalogVehicleSize size;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _OptionSection(
      title: chosenPack == 'composition'
          ? 'Composition personnalisée par élément'
          : 'Ajouter des Éléments de Reconditionnement',
      subtitle: chosenPack == 'composition'
          ? "Composez l'intérieur exactement par zones."
          : "Cochez les modules d'esthétique pour enrichir le pack Sérénité.",
      counter: '${selectedIds.length} / ${interiorExtraOptions.length} OPTIONS',
      children: [
        for (final option in interiorExtraOptions)
          _OptionToggleTile(
            selected: selectedIds.contains(option.id),
            label: option.name,
            priceLabel: _basketEuroPlus(option.priceFor(size)),
            onTap: () => onToggle(option.id),
          ),
      ],
    );
  }
}

class _InteriorShampooGrid extends StatelessWidget {
  const _InteriorShampooGrid({
    required this.size,
    required this.selectedIds,
    required this.onToggle,
  });

  final CatalogVehicleSize size;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _OptionSection(
      title: 'Shampooing Intérieur Optionnel',
      subtitle:
          'Ajoutez un nettoyage textile intérieur à votre prestation extérieure.',
      children: [
        for (final option in interiorExtraOptions)
          _OptionToggleTile(
            selected: selectedIds.contains(option.id),
            label: option.name,
            priceLabel: _basketEuroPlus(option.priceFor(size)),
            onTap: () => onToggle(option.id),
          ),
      ],
    );
  }
}

class _ExteriorSuggestionsGrid extends StatelessWidget {
  const _ExteriorSuggestionsGrid({
    required this.size,
    required this.chosenPack,
    required this.selectedIds,
    required this.customPrices,
    required this.onToggle,
    required this.onCustomPriceChanged,
  });

  final CatalogVehicleSize size;
  final String chosenPack;
  final Set<String> selectedIds;
  final Map<String, int> customPrices;
  final ValueChanged<String> onToggle;
  final void Function(String id, int value) onCustomPriceChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionSection(
      title: "Éléments optionnels & Protections d'atelier",
      subtitle: 'Enrichissez et protégez votre carrosserie externe.',
      counter: '${selectedIds.length} OPTIONS',
      children: [
        for (final option in exteriorSuggestionOptions)
          _OptionWithPriceInput(
            option: option,
            size: size,
            chosenPack: chosenPack,
            selected: selectedIds.contains(option.id),
            customPrice: customPrices[option.id] ?? 0,
            onToggle: () => onToggle(option.id),
            onPriceChanged: (value) => onCustomPriceChanged(option.id, value),
          ),
      ],
    );
  }
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({
    required this.title,
    required this.subtitle,
    required this.children,
    this.counter,
  });

  final String title;
  final String subtitle;
  final String? counter;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.isLight
            ? Colors.white
            : colors.shell.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: colors.focus,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (counter != null) ...[
                const SizedBox(width: 12),
                _SmallBadge(label: counter!),
              ],
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 620
                  ? 1
                  : constraints.maxWidth < 980
                  ? 2
                  : 3;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final child in children)
                    SizedBox(width: width, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OptionWithPriceInput extends StatelessWidget {
  const _OptionWithPriceInput({
    required this.option,
    required this.size,
    required this.chosenPack,
    required this.selected,
    required this.customPrice,
    required this.onToggle,
    required this.onPriceChanged,
  });

  final _ExteriorSuggestionOption option;
  final CatalogVehicleSize size;
  final String chosenPack;
  final bool selected;
  final int customPrice;
  final VoidCallback onToggle;
  final ValueChanged<int> onPriceChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OptionToggleTile(
          selected: selected,
          label: option.name,
          priceLabel: option.priceLabel(
            size: size,
            pack: chosenPack,
            customPrice: customPrice,
          ),
          onTap: onToggle,
        ),
        if (selected && option.isDevis) ...[
          const SizedBox(height: 6),
          _CustomPriceField(value: customPrice, onChanged: onPriceChanged),
        ],
      ],
    );
  }
}

class _CustomPriceField extends StatelessWidget {
  const _CustomPriceField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return TextFormField(
      initialValue: value > 0 ? '$value' : '',
      keyboardType: TextInputType.number,
      onChanged: (raw) => onChanged(int.tryParse(raw.trim()) ?? 0),
      style: TextStyle(
        color: colors.textStrong,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        hintText: 'Prix HTVA',
        suffixText: '€ HTVA',
        isDense: true,
        filled: true,
        fillColor: colors.surfaceRaised.withValues(
          alpha: colors.isLight ? 1 : 0.2,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _OptionToggleTile extends StatelessWidget {
  const _OptionToggleTile({
    required this.selected,
    required this.label,
    required this.priceLabel,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final String priceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final selectedBackground = colors.isLight
        ? const Color(0xFFF0F1F3)
        : colors.focus.withValues(alpha: 0.10);
    final idleBackground = colors.isLight
        ? Colors.white
        : colors.surfaceRaised.withValues(alpha: 0.18);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selectedBackground : idleBackground,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: selected ? colors.borderStrong : colors.border,
              width: selected && colors.isLight ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              _SquareCheck(selected: selected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                priceLabel,
                style: TextStyle(
                  color: colors.focus,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareCheck extends StatelessWidget {
  const _SquareCheck({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final selectedColor = colors.isLight ? _basketAccent : colors.focus;

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: selected ? selectedColor : colors.shell,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: selected ? selectedColor : colors.borderStrong,
        ),
      ),
      child: selected
          ? Icon(
              Icons.check_rounded,
              color: colors.isLight ? _basketDarkChoice : colors.onFocus,
              size: 13,
            )
          : null,
    );
  }
}

class _MobilityOptionsCard extends StatelessWidget {
  const _MobilityOptionsCard({
    required this.selectedPickup,
    required this.selectedCourtesyCar,
    required this.onPickupChanged,
    required this.onCourtesyCarChanged,
  });

  final bool selectedPickup;
  final bool selectedCourtesyCar;
  final ValueChanged<bool> onPickupChanged;
  final ValueChanged<bool> onCourtesyCarChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionSection(
      title: 'Service Pickup',
      subtitle: 'Prise en charge, retour et mobilité de courtoisie.',
      children: [
        _OptionToggleTile(
          selected: !selectedPickup,
          label: 'Aucun pickup',
          priceLabel: '0 €',
          onTap: () => onPickupChanged(false),
        ),
        _OptionToggleTile(
          selected: selectedPickup,
          label: 'Pickup aller-retour',
          priceLabel: '+50 €',
          onTap: () => onPickupChanged(true),
        ),
        _OptionToggleTile(
          selected: selectedCourtesyCar,
          label: 'Voiture de courtoisie',
          priceLabel: '+50 €',
          onTap: () => onCourtesyCarChanged(!selectedCourtesyCar),
        ),
      ],
    );
  }
}

class _BasketLine {
  const _BasketLine({
    required this.categoryLabel,
    required this.serviceLabel,
    required this.quantity,
    required this.unitPrice,
  });

  final String categoryLabel;
  final String serviceLabel;
  final int quantity;
  final int unitPrice;

  int get subtotal => quantity * unitPrice;
}

class _SizedBasketPrice {
  const _SizedBasketPrice({required this.s, required this.m, required this.l});

  final int s;
  final int m;
  final int l;

  int priceFor(CatalogVehicleSize size) {
    return switch (size) {
      CatalogVehicleSize.s => s,
      CatalogVehicleSize.m => m,
      CatalogVehicleSize.l => l,
    };
  }
}

class _InteriorExtraOption {
  const _InteriorExtraOption({
    required this.id,
    required this.name,
    required this.prices,
  });

  final String id;
  final String name;
  final _SizedBasketPrice prices;

  int priceFor(CatalogVehicleSize size) => prices.priceFor(size);
}

class _ExteriorSuggestionOption {
  const _ExteriorSuggestionOption({
    required this.id,
    required this.name,
    this.fixedPrice,
    this.isDevis = false,
    this.isCeramicChoice = false,
    this.isSereniteOption = false,
  });

  final String id;
  final String name;
  final int? fixedPrice;
  final bool isDevis;
  final bool isCeramicChoice;
  final bool isSereniteOption;

  int priceFor({
    required CatalogVehicleSize size,
    required String pack,
    int? customPrice,
  }) {
    if (isDevis) return customPrice ?? 0;
    if (isSereniteOption) {
      if (pack == 'splendeur') {
        return switch (size) {
          CatalogVehicleSize.s => 70,
          CatalogVehicleSize.m => 80,
          CatalogVehicleSize.l => 100,
        };
      }
      return 50;
    }
    return fixedPrice ?? 0;
  }

  String priceLabel({
    required CatalogVehicleSize size,
    required String pack,
    int? customPrice,
  }) {
    if (isDevis && (customPrice ?? 0) <= 0) return 'SUR DEVIS';
    return _basketEuroPlus(
      priceFor(size: size, pack: pack, customPrice: customPrice),
    );
  }
}

class _ComparativeItem {
  const _ComparativeItem({
    required this.text,
    required this.splendeur,
    required this.medium,
    required this.approfondi,
  });

  final String text;
  final Object splendeur;
  final Object medium;
  final Object approfondi;
}

class _PolishingPart {
  const _PolishingPart({
    required this.id,
    required this.label,
    required this.price,
  });

  final String id;
  final String label;
  final int price;
}

const packPrices = {
  'serenite': _SizedBasketPrice(s: 90, m: 100, l: 120),
  'purete': _SizedBasketPrice(s: 350, m: 420, l: 490),
  'composition': _SizedBasketPrice(s: 0, m: 0, l: 0),
  'splendeur': _SizedBasketPrice(s: 890, m: 990, l: 1190),
  'brillance': _SizedBasketPrice(s: 400, m: 450, l: 500),
  'renaissance': _SizedBasketPrice(s: 690, m: 790, l: 990),
  'signature': _SizedBasketPrice(s: 890, m: 990, l: 1190),
  'medium': _SizedBasketPrice(s: 400, m: 450, l: 500),
  'approfondi': _SizedBasketPrice(s: 690, m: 790, l: 990),
};

const interiorExtraOptions = [
  _InteriorExtraOption(
    id: 'ciel_toit',
    name: 'Shampoing Ciel de Toit',
    prices: _SizedBasketPrice(s: 40, m: 50, l: 60),
  ),
  _InteriorExtraOption(
    id: 'tapis',
    name: 'Shampoing des Tapis originaux',
    prices: _SizedBasketPrice(s: 25, m: 30, l: 35),
  ),
  _InteriorExtraOption(
    id: 'panneaux',
    name: 'Shampoing des Panneaux de Portes',
    prices: _SizedBasketPrice(s: 30, m: 35, l: 40),
  ),
  _InteriorExtraOption(
    id: 'tableau',
    name: 'Shampoing du Tableau de Bord',
    prices: _SizedBasketPrice(s: 20, m: 25, l: 30),
  ),
  _InteriorExtraOption(
    id: 'console_shamp',
    name: 'Shampoing de la Console Centrale',
    prices: _SizedBasketPrice(s: 15, m: 20, l: 25),
  ),
  _InteriorExtraOption(
    id: 'coffre',
    name: 'Shampoing du Compartiment Coffre',
    prices: _SizedBasketPrice(s: 30, m: 35, l: 40),
  ),
  _InteriorExtraOption(
    id: 'ceinture',
    name: 'Shampoing des Ceintures de Sécurité',
    prices: _SizedBasketPrice(s: 15, m: 20, l: 20),
  ),
  _InteriorExtraOption(
    id: 'montants',
    name: 'Shampoing des Montants Intérieurs',
    prices: _SizedBasketPrice(s: 15, m: 20, l: 25),
  ),
  _InteriorExtraOption(
    id: 'volant',
    name: 'Shampoing & Nettoyage Cuir Volant',
    prices: _SizedBasketPrice(s: 15, m: 20, l: 20),
  ),
  _InteriorExtraOption(
    id: 'nourrissant_cuir',
    name: 'Traitement Nourrissant des Cuirs',
    prices: _SizedBasketPrice(s: 35, m: 40, l: 45),
  ),
  _InteriorExtraOption(
    id: 'prelavage',
    name: 'Prélavage de Carrosserie soigné de nuit',
    prices: _SizedBasketPrice(s: 20, m: 25, l: 30),
  ),
];

const exteriorSuggestionOptions = [
  _ExteriorSuggestionOption(
    id: 'moteur_haut',
    name: 'Nettoyage Compartiment Moteur Haut',
    fixedPrice: 80,
  ),
  _ExteriorSuggestionOption(
    id: 'moteur_bas',
    name: 'Nettoyage Compartiment Moteur Bas',
    fixedPrice: 80,
  ),
  _ExteriorSuggestionOption(
    id: 'expertise_carrosserie',
    name: 'Expertise Technique de la Carrosserie',
    fixedPrice: 100,
  ),
  _ExteriorSuggestionOption(
    id: 'ceramique_vitres',
    name: 'Protection Céramique Vitres & Surfaces vitrées',
    fixedPrice: 150,
  ),
  _ExteriorSuggestionOption(
    id: 'reparation_jantes',
    name: 'Réparation & Rénovation de Jante',
    isDevis: true,
  ),
  _ExteriorSuggestionOption(
    id: 'reparation_carrosserie',
    name: 'Réparations Carrosserie (Débosselage, etc.)',
    isDevis: true,
  ),
  _ExteriorSuggestionOption(
    id: 'vitres_teintees',
    name: 'Pose de Vitres Teintées homologuées',
    isDevis: true,
  ),
  _ExteriorSuggestionOption(
    id: 'ceramique_1an',
    name: 'Céramique Carrosserie (Durabilité 1 an)',
    fixedPrice: 250,
    isCeramicChoice: true,
  ),
  _ExteriorSuggestionOption(
    id: 'ceramique_3ans',
    name: 'Céramique Carrosserie (Durabilité 3 ans)',
    fixedPrice: 500,
    isCeramicChoice: true,
  ),
  _ExteriorSuggestionOption(
    id: 'ceramique_5ans',
    name: 'Céramique Carrosserie (Durabilité 5 ans)',
    fixedPrice: 900,
    isCeramicChoice: true,
  ),
  _ExteriorSuggestionOption(
    id: 'ceramique_10ans',
    name: 'Céramique Carrosserie (Durabilité 10 ans)',
    fixedPrice: 1100,
    isCeramicChoice: true,
  ),
  _ExteriorSuggestionOption(
    id: 'dsp',
    name: 'DSP (Débosselage Sans Peinture)',
    isDevis: true,
  ),
  _ExteriorSuggestionOption(
    id: 'retouche_peinture',
    name: 'Retouche Peinture localisée',
    isDevis: true,
  ),
  _ExteriorSuggestionOption(
    id: 'serenite_sug',
    name: 'Option sérénité (Lavage Intérieur Premium)',
    isSereniteOption: true,
  ),
];

const exteriorComparativeItems = [
  _ComparativeItem(
    text: 'Prélavage de la carrosserie',
    splendeur: true,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Nettoyage et dégraissage de jantes',
    splendeur: true,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Lavage de la carrosserie à la main',
    splendeur: true,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Nettoyage des vitres',
    splendeur: true,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Nettoyage de passage de roues',
    splendeur: true,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Contour des portes, coffres & trappe à carburant',
    splendeur: true,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: "Application d'un nano-déperlant",
    splendeur: true,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Rénovateur des plastiques extérieur',
    splendeur: true,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Décontamination de la carrosserie',
    splendeur: false,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Analyse de la carrosserie',
    splendeur: false,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Masquage de tous éléments extérieurs',
    splendeur: false,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Dégraissage',
    splendeur: false,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Cire protectrice (durabilité de 2 mois)',
    splendeur: false,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Polissage en deux étapes (correction micro-rayures)',
    splendeur: false,
    medium: true,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Polissage en trois étapes (correction des défauts majeurs)',
    splendeur: false,
    medium: false,
    approfondi: true,
  ),
  _ComparativeItem(
    text: 'Ponçage carrosserie localisé',
    splendeur: false,
    medium: false,
    approfondi: 'Sur devis',
  ),
];

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

class _CategoryOpenStep extends StatelessWidget {
  const _CategoryOpenStep({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    const categories = [
      _PrestationCategory(
        id: 'interior',
        label: 'Intérieur',
        description:
            'Nettoyage intérieur, vapeur, plastiques, cuir et textile.',
      ),
      _PrestationCategory(
        id: 'exterior',
        label: 'Extérieur',
        description: 'Lavage, décontamination, brillance et polissage.',
      ),
    ];

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
                  for (final category in categories)
                    SizedBox(
                      width: width,
                      child: _CategoryLaunchCard(
                        category: category,
                        active: true,
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

class _PrestationCategory {
  const _PrestationCategory({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class _CategoryLaunchCard extends StatelessWidget {
  const _CategoryLaunchCard({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final _PrestationCategory category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final background = colors.isLight
        ? _basketLightPrestation
        : colors.surfaceRaised;
    final borderColor = colors.isLight
        ? _basketLightPrestationBorder
        : colors.surfaceRaised;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: active ? background : colors.field,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? borderColor : colors.border),
            boxShadow: colors.isLight
                ? const [
                    BoxShadow(
                      color: Color(0x12111827),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.label.toUpperCase(),
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                category.description,
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
            child: Column(
              crossAxisAlignment: centerHeader
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (accentLabel.isNotEmpty) const SizedBox.shrink(),
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
    final selectedBackground = colors.isLight
        ? _basketDarkChoice
        : colors.focus.withValues(alpha: 0.10);
    final idleBackground = colors.isLight ? Colors.white : colors.field;
    final selectedTitleColor = colors.isLight
        ? Colors.white
        : colors.textStrong;
    final selectedMutedColor = colors.isLight
        ? Colors.white.withValues(alpha: 0.68)
        : colors.muted;
    final selectedAccent = colors.isLight ? _basketAccent : colors.focus;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 145),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selected ? selectedBackground : idleBackground,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: selected ? selectedBackground : colors.borderStrong,
                width: 1,
              ),
              boxShadow: selected && colors.isLight
                  ? const [
                      BoxShadow(
                        color: Color(0x29111827),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
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
                          color: selected ? selectedAccent : colors.focus,
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
                          color: selected
                              ? selectedTitleColor
                              : colors.textStrong,
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
                          color: selected ? selectedMutedColor : colors.muted,
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

class _VehicleSizeAndTypeStep extends StatelessWidget {
  const _VehicleSizeAndTypeStep({
    required this.size,
    required this.categoryId,
    required this.exteriorChoice,
    required this.polishType,
    required this.onSizeChanged,
    required this.onExteriorChoiceChanged,
    required this.onPolishTypeChanged,
  });

  final CatalogVehicleSize size;
  final String categoryId;
  final String exteriorChoice;
  final String polishType;
  final ValueChanged<CatalogVehicleSize> onSizeChanged;
  final ValueChanged<String> onExteriorChoiceChanged;
  final ValueChanged<String> onPolishTypeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return _StepPanel(
      accentLabel: 'Etape 2 / 5',
      title: 'Gabarit du Véhicule',
      subtitle: 'Sélectionnez le format adapté à votre véhicule.',
      centerHeader: true,
      child: Column(
        children: [
          _SizeSelector(value: size, onChanged: onSizeChanged),
          if (categoryId == 'exterior') ...[
            const SizedBox(height: 28),
            Divider(color: colors.border),
            const SizedBox(height: 24),
            Text(
              'TYPE DE PRESTATION CARROSSERIE',
              textAlign: TextAlign.center,
              style: _sectionTitle(context).copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Sélectionnez le niveau d'intervention carrosserie désiré.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 760 ? 1 : 2;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 14)) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: width,
                      child: _ChoiceCard(
                        selected: exteriorChoice == 'lavage',
                        title: 'Lavage',
                        kicker: 'Pack Splendeur',
                        description:
                            'Lavage minutieux de prestige, idéal pour un entretien régulier haut de gamme.',
                        onTap: () => onExteriorChoiceChanged('lavage'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _ChoiceCard(
                        selected: exteriorChoice == 'polissage',
                        title: 'Reconditionnement',
                        kicker: 'Polissage',
                        description:
                            'Gommage des micro-rayures, brillance miroir durable et correction minutieuse du vernis.',
                        onTap: () => onExteriorChoiceChanged('polissage'),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (exteriorChoice == 'polissage') ...[
              const SizedBox(height: 28),
              Divider(color: colors.border),
              const SizedBox(height: 24),
              Text(
                'CONFIGURATION DU POLISSAGE',
                textAlign: TextAlign.center,
                style: _sectionTitle(context).copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Optez pour une correction complète ou ciblée selon l'état de votre carrosserie.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 760 ? 1 : 2;
                  final width =
                      (constraints.maxWidth - ((columns - 1) * 14)) / columns;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: [
                      SizedBox(
                        width: width,
                        child: _ChoiceCard(
                          selected: polishType == 'integral',
                          title: 'Polissage intégral',
                          kicker: 'Complet',
                          description:
                              'Traitement intégral de tous les vernis extérieurs du véhicule pour un résultat homogène.',
                          onTap: () => onPolishTypeChanged('integral'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _ChoiceCard(
                          selected: polishType == 'partiel',
                          title: 'Polissage partiel',
                          kicker: 'Par élément',
                          description:
                              'Correction localisée sur un ou plusieurs éléments précis avec tarification sur mesure.',
                          onTap: () => onPolishTypeChanged('partiel'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.kicker,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String kicker;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final selectedBackground = colors.isLight
        ? _basketDarkChoice
        : colors.focus.withValues(alpha: 0.10);
    final idleBackground = colors.isLight ? Colors.white : colors.field;
    final selectedAccent = colors.isLight ? _basketAccent : colors.focus;
    final selectedTitleColor = colors.isLight
        ? Colors.white
        : colors.textStrong;
    final selectedMutedColor = colors.isLight
        ? Colors.white.withValues(alpha: 0.70)
        : colors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected ? selectedBackground : idleBackground,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: selected ? selectedBackground : colors.borderStrong,
              width: 1,
            ),
            boxShadow: selected && colors.isLight
                ? const [
                    BoxShadow(
                      color: Color(0x16111827),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: _SelectionDot(selected: selected),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? selectedAccent : colors.focus,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kicker.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? selectedTitleColor
                              : colors.textStrong,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? selectedMutedColor : colors.muted,
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicesComposerStep extends StatelessWidget {
  const _ServicesComposerStep({
    required this.categoryId,
    required this.size,
    required this.chosenPack,
    required this.exteriorChoice,
    required this.polishType,
    required this.selectedInteriorExtras,
    required this.selectedExteriorExtras,
    required this.selectedShampooExtras,
    required this.customExteriorPrices,
    required this.selectedPolishingParts,
    required this.selectedPickup,
    required this.selectedCourtesyCar,
    required this.lines,
    required this.totalHtva,
    required this.applyVat,
    required this.onPackChanged,
    required this.onInteriorExtraToggled,
    required this.onExteriorExtraToggled,
    required this.onShampooExtraToggled,
    required this.onCustomExteriorPriceChanged,
    required this.onPolishingPartsChanged,
    required this.onPickupChanged,
    required this.onCourtesyCarChanged,
  });

  final String categoryId;
  final CatalogVehicleSize size;
  final String chosenPack;
  final String exteriorChoice;
  final String polishType;
  final Set<String> selectedInteriorExtras;
  final Set<String> selectedExteriorExtras;
  final Set<String> selectedShampooExtras;
  final Map<String, int> customExteriorPrices;
  final List<_PolishingPart> selectedPolishingParts;
  final bool selectedPickup;
  final bool selectedCourtesyCar;
  final List<_BasketLine> lines;
  final int totalHtva;
  final bool applyVat;
  final ValueChanged<String> onPackChanged;
  final ValueChanged<String> onInteriorExtraToggled;
  final ValueChanged<String> onExteriorExtraToggled;
  final ValueChanged<String> onShampooExtraToggled;
  final void Function(String id, int value) onCustomExteriorPriceChanged;
  final ValueChanged<List<_PolishingPart>> onPolishingPartsChanged;
  final ValueChanged<bool> onPickupChanged;
  final ValueChanged<bool> onCourtesyCarChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final isInterior = categoryId == 'interior';
    final isPartialPolishing =
        !isInterior && exteriorChoice == 'polissage' && polishType == 'partiel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepPanel(
          accentLabel: 'Etape 3 / 5',
          title: isPartialPolishing
              ? 'Éléments à polir'
              : !isInterior && polishType == 'integral'
              ? 'Comparer le polissage'
              : 'Personnaliser la prestation',
          subtitle: isPartialPolishing
              ? 'Sélectionnez les pièces spécifiques pour le polissage partiel.'
              : !isInterior && polishType == 'integral'
              ? 'Choisissez entre polissage moyen et approfondi, puis ajoutez les suggestions utiles.'
              : 'Ajoutez les options utiles avant de passer au devis.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isInterior) ...[
                _InteriorPackSelector(
                  chosenPack: chosenPack,
                  size: size,
                  onChanged: onPackChanged,
                ),
                const SizedBox(height: 16),
                _InteriorComparisonTable(chosenPack: chosenPack, size: size),
                if (chosenPack == 'serenite' ||
                    chosenPack == 'composition') ...[
                  const SizedBox(height: 16),
                  _InteriorExtrasGrid(
                    chosenPack: chosenPack,
                    size: size,
                    selectedIds: selectedInteriorExtras,
                    onToggle: onInteriorExtraToggled,
                  ),
                ],
              ] else ...[
                if (isPartialPolishing) ...[
                  _PolishingPartsSelector(
                    size: size,
                    selectedParts: selectedPolishingParts,
                    onChanged: onPolishingPartsChanged,
                  ),
                ] else ...[
                  if (exteriorChoice == 'lavage')
                    _ExteriorLavageSelector(
                      chosenPack: chosenPack,
                      size: size,
                      onChanged: onPackChanged,
                    )
                  else
                    _PolishingIntegralSelector(
                      chosenPack: chosenPack,
                      size: size,
                      onChanged: onPackChanged,
                    ),
                  const SizedBox(height: 16),
                  _ExteriorComparisonTable(
                    chosenPack: chosenPack,
                    size: size,
                    showSplendeur: exteriorChoice == 'lavage',
                  ),
                  const SizedBox(height: 16),
                  _ExteriorSuggestionsGrid(
                    size: size,
                    chosenPack: chosenPack,
                    selectedIds: selectedExteriorExtras,
                    customPrices: customExteriorPrices,
                    onToggle: onExteriorExtraToggled,
                    onCustomPriceChanged: onCustomExteriorPriceChanged,
                  ),
                ],
                const SizedBox(height: 16),
                _InteriorShampooGrid(
                  size: size,
                  selectedIds: selectedShampooExtras,
                  onToggle: onShampooExtraToggled,
                ),
              ],
              const SizedBox(height: 16),
              _MobilityOptionsCard(
                selectedPickup: selectedPickup,
                selectedCourtesyCar: selectedCourtesyCar,
                onPickupChanged: onPickupChanged,
                onCourtesyCarChanged: onCourtesyCarChanged,
              ),
              const SizedBox(height: 16),
              _BasketSummaryCard(
                lines: lines,
                size: size,
                totalHtva: totalHtva,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.isLight ? colors.surfaceRaised : colors.shell,
            borderRadius: BorderRadius.circular(2),
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
                          _basketEuro(totalHtva),
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (applyVat)
                          Text(
                            'HTVA (TVAC: ${_basketEuro(totalHtva * 1.21)})',
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
                      'Formule: ${isInterior ? 'Intérieur' : 'Extérieur'} [${_vehicleSizeLabel(size)}] + ${lines.length} ligne(s).',
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

class _PolishingPartsSelector extends StatefulWidget {
  const _PolishingPartsSelector({
    required this.size,
    required this.selectedParts,
    required this.onChanged,
  });

  final CatalogVehicleSize size;
  final List<_PolishingPart> selectedParts;
  final ValueChanged<List<_PolishingPart>> onChanged;

  @override
  State<_PolishingPartsSelector> createState() =>
      _PolishingPartsSelectorState();
}

class _PolishingPartsSelectorState extends State<_PolishingPartsSelector> {
  static const _svgSize = Size(1448, 1086);
  static const _views = ['front', 'top', 'rear', 'left', 'right'];
  static const _viewLabels = {
    'front': 'Avant',
    'top': 'Vue supérieure',
    'rear': 'Arrière',
    'left': 'Côté gauche',
    'right': 'Côté droit',
  };
  static final Map<String, List<_PolishingZone>> _cache = {};

  late _PolishingProfile _profile;
  late Future<List<_PolishingZone>> _zonesFuture;
  Set<String> _selectedGroups = {};

  @override
  void initState() {
    super.initState();
    _profile = _defaultProfile(widget.size);
    _zonesFuture = _loadZones(_profile);
    _selectedGroups = widget.selectedParts.map((part) => part.id).toSet();
  }

  @override
  void didUpdateWidget(covariant _PolishingPartsSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size != widget.size) {
      _profile = _defaultProfile(widget.size);
      _zonesFuture = _loadZones(_profile);
      _selectedGroups = {};
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(const []);
      });
      return;
    }
    _selectedGroups = widget.selectedParts.map((part) => part.id).toSet();
  }

  static _PolishingProfile _defaultProfile(CatalogVehicleSize size) {
    return switch (size) {
      CatalogVehicleSize.s => _polishingProfiles.firstWhere(
        (profile) => profile.key == 'S',
      ),
      CatalogVehicleSize.m => _polishingProfiles.firstWhere(
        (profile) => profile.key == 'M',
      ),
      CatalogVehicleSize.l => _polishingProfiles.firstWhere(
        (profile) => profile.key == 'Grande-Berline',
      ),
    };
  }

  List<_PolishingProfile> get _visibleProfiles {
    return _polishingProfiles
        .where((profile) => profile.size == widget.size)
        .toList();
  }

  Future<List<_PolishingZone>> _loadZones(_PolishingProfile profile) async {
    final cacheKey = profile.zoneAsset;
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(cacheKey);
    final decoded = jsonDecode(raw) as List<dynamic>;
    final zones = decoded
        .whereType<Map<String, dynamic>>()
        .map(_PolishingZone.fromJson)
        .where((zone) => zone.profile == profile.zoneProfile)
        .toList();
    _cache[cacheKey] = zones;
    return zones;
  }

  void _changeProfile(_PolishingProfile profile) {
    setState(() {
      _profile = profile;
      _zonesFuture = _loadZones(profile);
      _selectedGroups = {};
    });
    widget.onChanged(const []);
  }

  void _toggleZone(_PolishingZone zone, List<_PolishingZone> allZones) {
    final group = zone.groupKey;
    setState(() {
      if (_selectedGroups.contains(group)) {
        _selectedGroups.remove(group);
      } else {
        _selectedGroups.add(group);
      }
    });
    widget.onChanged(_selectedPartsFrom(allZones));
  }

  List<_PolishingPart> _selectedPartsFrom(List<_PolishingZone> zones) {
    final byGroup = <String, _PolishingZone>{};
    for (final zone in zones) {
      if (_selectedGroups.contains(zone.groupKey)) {
        byGroup.putIfAbsent(zone.groupKey, () => zone);
      }
    }
    return [
      for (final entry in byGroup.entries)
        _PolishingPart(
          id: entry.key,
          label: entry.value.label,
          price: entry.value.price,
        ),
    ];
  }

  void _handleTap({
    required TapDownDetails details,
    required BoxConstraints constraints,
    required String view,
    required List<_PolishingZone> zones,
  }) {
    final point = Offset(
      details.localPosition.dx / constraints.maxWidth * _svgSize.width,
      details.localPosition.dy /
          (constraints.maxWidth / _svgSize.aspectRatio) *
          _svgSize.height,
    );
    final viewZones = zones.where((zone) => zone.view == view).toList();
    for (final zone in viewZones.reversed) {
      if (zone.path.contains(point)) {
        _toggleZone(zone, zones);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const panelBackground = Color(0xFF050505);
    const panelRaised = Color(0xFF09090B);
    const panelBorder = Color(0x1AFFFFFF);
    const panelText = Colors.white;
    const panelMuted = Color(0xFF71717A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelBackground,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POLISSAGE PARTIEL — CARTOGRAPHIE INTERACTIVE',
                      style: TextStyle(
                        color: panelText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Clique sur les pièces du véhicule pour composer le polissage partiel.',
                      style: TextStyle(
                        color: panelMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _basketAccent.withValues(alpha: 0.10),
                  border: Border.all(
                    color: _basketAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _profile.label.toUpperCase(),
                  style: const TextStyle(
                    color: _basketAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panelRaised,
              border: Border.all(color: panelBorder),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final profile in _visibleProfiles)
                  _PolishingProfileButton(
                    label: profile.label,
                    selected: profile.key == _profile.key,
                    onTap: () => _changeProfile(profile),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<_PolishingZone>>(
            future: _zonesFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const _LoadingBlock();
              final zones = snapshot.data!;
              final selectedParts = _selectedPartsFrom(zones);
              final total = selectedParts.fold<int>(
                0,
                (sum, part) => sum + part.price,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 720
                          ? 1
                          : constraints.maxWidth < 900
                          ? 2
                          : 3;
                      final width =
                          (constraints.maxWidth - ((columns - 1) * 12)) /
                          columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final view in _views)
                            SizedBox(
                              width: width,
                              child: _PolishingViewCard(
                                profile: _profile,
                                view: view,
                                viewLabel: _viewLabels[view] ?? view,
                                zones: zones,
                                selectedGroups: _selectedGroups,
                                onTap: (details, constraints) => _handleTap(
                                  details: details,
                                  constraints: constraints,
                                  view: view,
                                  zones: zones,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _SelectedPolishingPartsPanel(
                    parts: selectedParts,
                    total: total,
                    onRemove: (part) {
                      setState(() => _selectedGroups.remove(part.id));
                      widget.onChanged(_selectedPartsFrom(zones));
                    },
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

class _PolishingProfileButton extends StatelessWidget {
  const _PolishingProfileButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 42, minWidth: 128),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _basketAccent : Colors.black,
            border: Border.all(
              color: selected
                  ? _basketAccent
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.left,
            style: TextStyle(
              color: selected ? _basketDarkChoice : const Color(0xFFD4D4D8),
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

class _PolishingViewCard extends StatelessWidget {
  const _PolishingViewCard({
    required this.profile,
    required this.view,
    required this.viewLabel,
    required this.zones,
    required this.selectedGroups,
    required this.onTap,
  });

  final _PolishingProfile profile;
  final String view;
  final String viewLabel;
  final List<_PolishingZone> zones;
  final Set<String> selectedGroups;
  final void Function(TapDownDetails details, BoxConstraints constraints) onTap;

  @override
  Widget build(BuildContext context) {
    final viewZones = zones.where((zone) => zone.view == view).toList();
    final selectedCount = viewZones
        .where((zone) => selectedGroups.contains(zone.groupKey))
        .length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  viewLabel.toUpperCase(),
                  style: TextStyle(
                    color: _basketDarkChoice,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Text(
                '$selectedCount sélectionné(s)',
                style: TextStyle(
                  color: const Color(0xFF52525B),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) => onTap(details, constraints),
                child: AspectRatio(
                  aspectRatio: 1448 / 1086,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/polishing/${profile.folder}/$view.png',
                        fit: BoxFit.contain,
                      ),
                      CustomPaint(
                        painter: _PolishingZonesPainter(
                          zones: viewZones,
                          selectedGroups: selectedGroups,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SelectedPolishingPartsPanel extends StatelessWidget {
  const _SelectedPolishingPartsPanel({
    required this.parts,
    required this.total,
    required this.onRemove,
  });

  final List<_PolishingPart> parts;
  final int total;
  final ValueChanged<_PolishingPart> onRemove;

  @override
  Widget build(BuildContext context) {
    const panelBorder = Color(0x1AFFFFFF);
    const panelMuted = Color(0xFF71717A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SÉLECTION POLISSAGE PARTIEL',
                  style: TextStyle(
                    color: panelMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Text(
                _basketEuro(total),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (parts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: panelBorder),
              ),
              child: const Text(
                'AUCUNE ZONE SÉLECTIONNÉE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: panelMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 700 ? 1 : 2;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 10)) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final part in parts)
                      SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: panelBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      part.label.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Polissage partiel',
                                      style: TextStyle(
                                        color: panelMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _basketEuro(part.price),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => onRemove(part),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: panelMuted,
                                  size: 16,
                                ),
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

class _PolishingZonesPainter extends CustomPainter {
  const _PolishingZonesPainter({
    required this.zones,
    required this.selectedGroups,
  });

  final List<_PolishingZone> zones;
  final Set<String> selectedGroups;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _PolishingPartsSelectorState._svgSize.width;
    final scaleY = size.height / _PolishingPartsSelectorState._svgSize.height;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    for (final zone in zones) {
      final selected = selectedGroups.contains(zone.groupKey);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = selected
            ? _basketAccent.withValues(alpha: 0.42)
            : Colors.transparent;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 5 : 2
        ..color = selected ? const Color(0xFF5F8700) : Colors.transparent;
      canvas.drawPath(zone.path, fill);
      canvas.drawPath(zone.path, stroke);
      if (selected) {
        final markerFill = Paint()..color = _basketAccent;
        canvas.drawCircle(zone.labelPoint, 22, markerFill);
        final textPainter = TextPainter(
          text: TextSpan(
            text: '✓',
            style: TextStyle(
              color: _basketDarkChoice,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          zone.labelPoint -
              Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PolishingZonesPainter oldDelegate) {
    return oldDelegate.zones != zones ||
        oldDelegate.selectedGroups != selectedGroups;
  }
}

class _PolishingProfile {
  const _PolishingProfile({
    required this.key,
    required this.label,
    required this.size,
    required this.folder,
    required this.zoneAsset,
    required this.zoneProfile,
  });

  final String key;
  final String label;
  final CatalogVehicleSize size;
  final String folder;
  final String zoneAsset;
  final String zoneProfile;
}

const _polishingProfiles = [
  _PolishingProfile(
    key: 'S',
    label: 'Citadine compacte',
    size: CatalogVehicleSize.s,
    folder: 'S',
    zoneAsset: 'assets/data/polishing/sPolishingZones.json',
    zoneProfile: 'S',
  ),
  _PolishingProfile(
    key: 'M',
    label: 'Citadine',
    size: CatalogVehicleSize.m,
    folder: 'M',
    zoneAsset: 'assets/data/polishing/tailleMPolishingZones.json',
    zoneProfile: 'M',
  ),
  _PolishingProfile(
    key: 'Berline',
    label: 'Berline',
    size: CatalogVehicleSize.m,
    folder: 'Berline',
    zoneAsset: 'assets/data/polishing/berlinePolishingZones.json',
    zoneProfile: 'Berline',
  ),
  _PolishingProfile(
    key: 'Grande-Berline',
    label: 'Grande berline',
    size: CatalogVehicleSize.l,
    folder: 'Berline',
    zoneAsset: 'assets/data/polishing/berlinePolishingZones.json',
    zoneProfile: 'Berline',
  ),
  _PolishingProfile(
    key: 'Break',
    label: 'Break',
    size: CatalogVehicleSize.l,
    folder: 'Break',
    zoneAsset: 'assets/data/polishing/breakPolishingZones.json',
    zoneProfile: 'Break',
  ),
  _PolishingProfile(
    key: 'Camionette',
    label: 'Camionnette',
    size: CatalogVehicleSize.l,
    folder: 'Camionette',
    zoneAsset: 'assets/data/polishing/camionettePolishingZones.json',
    zoneProfile: 'Camionette',
  ),
];

class _PolishingZone {
  _PolishingZone({
    required this.id,
    required this.label,
    required this.price,
    required this.profile,
    required this.view,
    required this.path,
    required this.labelPoint,
  });

  final String id;
  final String label;
  final int price;
  final String profile;
  final String view;
  final Path path;
  final Offset labelPoint;

  String get groupKey => '$profile:${_normalizeZoneLabel(label)}';

  factory _PolishingZone.fromJson(Map<String, dynamic> json) {
    return _PolishingZone(
      id: json['id'] as String,
      label: _cleanZoneLabel(json['label'] as String),
      price: (json['price'] as num).round(),
      profile: json['profile'] as String,
      view: json['view'] as String,
      path: _pointsToPath(json['points'] as String),
      labelPoint: Offset(
        (json['labelX'] as num).toDouble(),
        (json['labelY'] as num).toDouble(),
      ),
    );
  }
}

Path _pointsToPath(String raw) {
  final points = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .map((item) {
        final parts = item.split(',');
        return Offset(
          double.tryParse(parts.first) ?? 0,
          double.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        );
      })
      .toList();
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  path.close();
  return path;
}

String _cleanZoneLabel(String label) {
  return label
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+\)'), ')')
      .replaceAll(RegExp(r'\(\s+'), '(')
      .trim();
}

String _normalizeZoneLabel(String label) {
  const accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };
  final lower = _cleanZoneLabel(label).toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(accents[char] ?? char);
  }
  return buffer.toString();
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
    required this.activeCategoryLabel,
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
  final String activeCategoryLabel;
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
                        value: activeCategoryLabel,
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
  });

  final List<_BasketLine> lines;
  final CatalogVehicleSize size;
  final int totalHtva;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(2),
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
                        '${line.quantity} x ${line.serviceLabel}',
                        style: TextStyle(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _basketEuro(line.subtotal),
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
            _basketEuro(totalHtva),
            style: TextStyle(
              color: colors.focus,
              fontSize: 34,
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
                        line.serviceLabel.toUpperCase(),
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        line.categoryLabel,
                        style: TextStyle(color: colors.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${line.quantity} x ${_basketEuro(line.unitPrice)}',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _basketEuro(line.subtotal),
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
                  value: _basketEuro(totalHtva),
                ),
                const SizedBox(width: 16),
                _TotalMini(label: 'TVA 21%', value: _basketEuro(vatTotal)),
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
                _basketEuro(applyVat ? totalWithVat : totalHtva),
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

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final selectedColor = colors.isLight ? _basketAccent : colors.focus;

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: selected ? selectedColor : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? selectedColor : colors.borderStrong,
        ),
      ),
      child: selected
          ? Icon(
              Icons.check_rounded,
              size: 13,
              color: colors.isLight ? _basketDarkChoice : colors.onFocus,
            )
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

String _vehicleSizeLabel(CatalogVehicleSize size) {
  return switch (size) {
    CatalogVehicleSize.s => 'Taille S',
    CatalogVehicleSize.m => 'Taille M',
    CatalogVehicleSize.l => 'Taille L',
  };
}

String _vehicleSizeCode(CatalogVehicleSize size) {
  return switch (size) {
    CatalogVehicleSize.s => 'S',
    CatalogVehicleSize.m => 'M',
    CatalogVehicleSize.l => 'L',
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
