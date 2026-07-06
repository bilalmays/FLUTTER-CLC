import 'package:car_luxe_cleaning_flutter/core/api/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final autorefRepositoryProvider = Provider<AutorefRepository>(
  (ref) => AutorefRepository(ref.read(apiClientProvider)),
);

class AutorefVehicleResult {
  const AutorefVehicleResult({
    this.make = '',
    this.model = '',
    this.year = '',
    this.vin = '',
    this.licensePlate = '',
    this.color = '',
  });

  final String make;
  final String model;
  final String year;
  final String vin;
  final String licensePlate;
  final String color;

  factory AutorefVehicleResult.fromJson(Map<String, dynamic> json) {
    String read(String key) => (json[key] as String?)?.trim() ?? '';
    final vehicle = json['vehicle'] is Map<String, dynamic>
        ? json['vehicle'] as Map<String, dynamic>
        : json;
    String readVehicle(String key) => (vehicle[key] as String?)?.trim() ?? '';
    return AutorefVehicleResult(
      make: readVehicle('make').isNotEmpty ? readVehicle('make') : read('make'),
      model: readVehicle('model').isNotEmpty
          ? readVehicle('model')
          : read('model'),
      year: readVehicle('year').isNotEmpty
          ? readVehicle('year')
          : readVehicle('firstRegistrationDate').isNotEmpty
          ? readVehicle('firstRegistrationDate')
          : read('year'),
      vin: readVehicle('vin').isNotEmpty ? readVehicle('vin') : read('vin'),
      licensePlate: readVehicle('licensePlate').isNotEmpty
          ? readVehicle('licensePlate')
          : read('licensePlate'),
      color: readVehicle('color').isNotEmpty
          ? readVehicle('color')
          : read('color'),
    );
  }

  Map<String, dynamic> toJson() => {
    'make': make,
    'model': model,
    'year': year,
    'vin': vin,
    'licensePlate': licensePlate,
    'color': color,
  };
}

class AutorefRepository {
  const AutorefRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AutorefVehicleResult?> lookupVin(String vin) async {
    final clean = vin.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (clean.length < 10) return null;
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/autoref/vehicles/${Uri.encodeComponent(clean)}',
      query: {'lang': 'fr'},
    );
    return AutorefVehicleResult.fromJson(response.data ?? {});
  }

  Future<AutorefVehicleResult?> lookupPlate(String plate) async {
    final clean = plate.toUpperCase().trim();
    if (clean.isEmpty) return null;
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/autoref/plate',
      query: {'plate': clean, 'country': 'BE'},
    );
    return AutorefVehicleResult.fromJson(response.data ?? {});
  }
}
