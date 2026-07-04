import 'package:car_luxe_cleaning_flutter/shared/models/client.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/vehicle.dart';

class ClientVehicleBundle {
  const ClientVehicleBundle({required this.client, required this.vehicles});

  final Client client;
  final List<Vehicle> vehicles;

  bool get hasVehicle => vehicles.isNotEmpty;

  String get searchIndex {
    return [
      client.name,
      client.email,
      client.phone,
      client.address,
      client.companyName,
      client.vatNumber,
      for (final vehicle in vehicles) ...[
        vehicle.make,
        vehicle.model,
        vehicle.licensePlate,
        vehicle.vin,
        vehicle.color,
      ],
    ].whereType<String>().join(' ').toLowerCase();
  }
}
