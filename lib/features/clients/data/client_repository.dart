import 'dart:convert';

import 'package:car_luxe_cleaning_flutter/features/clients/data/client_seed_data.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/domain/client_vehicle_bundle.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/client.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/vehicle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => LocalClientRepository(),
);

abstract class ClientRepository {
  Future<List<ClientVehicleBundle>> listClients();
  Future<List<ClientVehicleBundle>> listArchivedClients();
  Future<ClientVehicleBundle> upsertClient({
    String? id,
    required String name,
    required String email,
    required String phone,
    required String address,
    required bool isProfessional,
    required String companyName,
    required String vatNumber,
  });
  Future<void> archiveClient(String clientId);
  Future<void> restoreClient(String clientId);
  Future<void> deleteClientPermanently(String clientId);
  Future<Vehicle> upsertVehicle({
    String? id,
    required String clientId,
    required String make,
    required String model,
    required String year,
    required String licensePlate,
    required String vin,
    required String color,
    required VehicleSize? size,
  });
  Future<void> deleteVehicle(String vehicleId);
}

class LocalClientRepository implements ClientRepository {
  LocalClientRepository() {
    _ready = _load();
  }

  static const _storageKey = 'car_luxe_cleaning.clients.v1';

  final List<ClientVehicleBundle> _bundles = [];
  late final Future<void> _ready;

  @override
  Future<List<ClientVehicleBundle>> listClients() async {
    await _ready;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List.unmodifiable(
      _bundles.where((bundle) => !bundle.client.archived),
    );
  }

  @override
  Future<List<ClientVehicleBundle>> listArchivedClients() async {
    await _ready;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List.unmodifiable(
      _bundles.where((bundle) => bundle.client.archived),
    );
  }

  @override
  Future<ClientVehicleBundle> upsertClient({
    String? id,
    required String name,
    required String email,
    required String phone,
    required String address,
    required bool isProfessional,
    required String companyName,
    required String vatNumber,
  }) async {
    await _ready;
    final now = DateTime.now();
    final cleanId = id?.trim();
    final index = cleanId == null || cleanId.isEmpty
        ? -1
        : _bundles.indexWhere((bundle) => bundle.client.id == cleanId);

    if (index >= 0) {
      final existing = _bundles[index];
      final updated = ClientVehicleBundle(
        client: existing.client.copyWith(
          name: name.trim().toUpperCase(),
          email: email.trim(),
          phone: phone.trim(),
          address: address.trim(),
          isProfessional: isProfessional,
          companyName: companyName.trim(),
          vatNumber: vatNumber.trim(),
          updatedAt: now,
        ),
        vehicles: existing.vehicles,
      );
      _bundles[index] = updated;
      await _persist();
      return updated;
    }

    final clientId = 'client-${now.microsecondsSinceEpoch}';
    final bundle = ClientVehicleBundle(
      client: Client(
        id: clientId,
        name: name.trim().toUpperCase(),
        email: email.trim(),
        phone: phone.trim(),
        address: address.trim(),
        language: 'FR',
        createdAt: now,
        updatedAt: now,
        archived: false,
        isProfessional: isProfessional,
        companyName: companyName.trim(),
        vatNumber: vatNumber.trim(),
      ),
      vehicles: const [],
    );
    _bundles.insert(0, bundle);
    await _persist();
    return bundle;
  }

  @override
  Future<void> archiveClient(String clientId) async {
    await _ready;
    final index = _bundles.indexWhere((bundle) => bundle.client.id == clientId);
    if (index < 0) return;
    final existing = _bundles[index];
    _bundles[index] = ClientVehicleBundle(
      client: existing.client.copyWith(
        archived: true,
        updatedAt: DateTime.now(),
      ),
      vehicles: existing.vehicles,
    );
    await _persist();
  }

  @override
  Future<void> restoreClient(String clientId) async {
    await _ready;
    final index = _bundles.indexWhere((bundle) => bundle.client.id == clientId);
    if (index < 0) return;
    final existing = _bundles[index];
    _bundles[index] = ClientVehicleBundle(
      client: existing.client.copyWith(
        archived: false,
        updatedAt: DateTime.now(),
      ),
      vehicles: existing.vehicles,
    );
    await _persist();
  }

  @override
  Future<void> deleteClientPermanently(String clientId) async {
    await _ready;
    _bundles.removeWhere((bundle) => bundle.client.id == clientId);
    await _persist();
  }

  @override
  Future<Vehicle> upsertVehicle({
    String? id,
    required String clientId,
    required String make,
    required String model,
    required String year,
    required String licensePlate,
    required String vin,
    required String color,
    required VehicleSize? size,
  }) async {
    await _ready;
    final bundleIndex = _bundles.indexWhere(
      (bundle) => bundle.client.id == clientId,
    );
    if (bundleIndex < 0) throw StateError('Client introuvable.');

    final bundle = _bundles[bundleIndex];
    final now = DateTime.now();
    final vehicleIndex = id == null || id.trim().isEmpty
        ? -1
        : bundle.vehicles.indexWhere((vehicle) => vehicle.id == id);

    final vehicle = vehicleIndex >= 0
        ? bundle.vehicles[vehicleIndex].copyWith(
            make: make.trim().toUpperCase(),
            model: model.trim().toUpperCase(),
            year: year.trim(),
            licensePlate: licensePlate.trim().toUpperCase(),
            vin: vin.trim().toUpperCase(),
            color: color.trim().toUpperCase(),
            size: size,
            updatedAt: now,
          )
        : Vehicle(
            id: 'vehicle-${now.microsecondsSinceEpoch}',
            clientId: clientId,
            make: make.trim().toUpperCase(),
            model: model.trim().toUpperCase(),
            year: year.trim(),
            licensePlate: licensePlate.trim().toUpperCase(),
            vin: vin.trim().toUpperCase(),
            color: color.trim().toUpperCase(),
            size: size,
            createdAt: now,
            updatedAt: now,
          );

    final vehicles = [...bundle.vehicles];
    if (vehicleIndex >= 0) {
      vehicles[vehicleIndex] = vehicle;
    } else {
      vehicles.add(vehicle);
    }
    _bundles[bundleIndex] = ClientVehicleBundle(
      client: bundle.client.copyWith(updatedAt: now),
      vehicles: vehicles,
    );
    await _persist();
    return vehicle;
  }

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    await _ready;
    for (var index = 0; index < _bundles.length; index += 1) {
      final bundle = _bundles[index];
      final vehicles = bundle.vehicles
          .where((vehicle) => vehicle.id != vehicleId)
          .toList();
      if (vehicles.length == bundle.vehicles.length) continue;
      _bundles[index] = ClientVehicleBundle(
        client: bundle.client.copyWith(updatedAt: DateTime.now()),
        vehicles: vehicles,
      );
      await _persist();
      return;
    }
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      _bundles.addAll(buildSeedClientVehicleBundles());
      await _persist();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Invalid client data');
      _bundles
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(_bundleFromJson)
              .whereType<ClientVehicleBundle>(),
        );
      if (_bundles.isEmpty) {
        _bundles.addAll(buildSeedClientVehicleBundles());
      }
    } catch (_) {
      _bundles
        ..clear()
        ..addAll(buildSeedClientVehicleBundles());
      await _persist();
    }
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_bundles.map(_bundleToJson).toList()),
    );
  }

  Map<String, dynamic> _bundleToJson(ClientVehicleBundle bundle) {
    return {
      'client': bundle.client.toJson(),
      'vehicles': bundle.vehicles.map((vehicle) => vehicle.toJson()).toList(),
    };
  }

  ClientVehicleBundle? _bundleFromJson(Map<String, dynamic> json) {
    final clientJson = json['client'];
    if (clientJson is! Map<String, dynamic>) return null;
    final vehiclesJson = json['vehicles'];
    return ClientVehicleBundle(
      client: Client.fromJson(clientJson),
      vehicles: vehiclesJson is List
          ? vehiclesJson
                .whereType<Map<String, dynamic>>()
                .map(Vehicle.fromJson)
                .toList()
          : const [],
    );
  }
}
