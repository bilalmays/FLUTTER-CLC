import 'package:car_luxe_cleaning_flutter/features/clients/domain/client_vehicle_bundle.dart';
import 'package:car_luxe_cleaning_flutter/features/subscriptions/data/subscription_seed_data.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/client.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/vehicle.dart';

List<ClientVehicleBundle> buildSeedClientVehicleBundles() {
  final now = DateTime(2026, 7);
  final bundlesByClientName = <String, ClientVehicleBundle>{};

  for (final subscriptionBundle in buildSeedSubscriptionBundles()) {
    final key = subscriptionBundle.client.name.trim().toUpperCase();
    final existing = bundlesByClientName[key];
    if (existing == null) {
      bundlesByClientName[key] = ClientVehicleBundle(
        client: subscriptionBundle.client,
        vehicles: [subscriptionBundle.vehicle],
      );
    } else {
      bundlesByClientName[key] = ClientVehicleBundle(
        client: existing.client,
        vehicles: [...existing.vehicles, subscriptionBundle.vehicle],
      );
    }
  }

  final manualBundles = [
    ClientVehicleBundle(
      client: Client(
        id: 'test-client-bilal-de-boeck',
        name: 'BILAL DE BOECK',
        email: 'bilal.deboeck@example.test',
        phone: '+32 470 00 00 01',
        address: 'Bruxelles',
        language: 'FR',
        createdAt: now,
        updatedAt: now,
        archived: false,
      ),
      vehicles: [
        Vehicle(
          id: 'test-vehicle-bilal-de-boeck-serie-3',
          clientId: 'test-client-bilal-de-boeck',
          make: 'BMW',
          model: 'SERIE 3',
          year: '2021',
          licensePlate: '1-BIL-001',
          color: 'NOIR',
          createdAt: now,
          updatedAt: now,
        ),
        Vehicle(
          id: 'test-vehicle-bilal-de-boeck-200',
          clientId: 'test-client-bilal-de-boeck',
          make: 'BMW',
          model: '200',
          year: '',
          licensePlate: 'DD',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    ),
    ClientVehicleBundle(
      client: Client(
        id: 'test-client-mays-altaef',
        name: 'MAYS ALTAEF',
        email: 'mays.altaef@example.test',
        phone: '+32 470 00 00 02',
        address: 'Bruxelles',
        language: 'FR',
        createdAt: now,
        updatedAt: now,
        archived: false,
      ),
      vehicles: [
        Vehicle(
          id: 'test-vehicle-mays-altaef',
          clientId: 'test-client-mays-altaef',
          make: 'AUDI',
          model: 'A4',
          year: '2020',
          licensePlate: '1-MAY-002',
          color: 'BLANC',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    ),
  ];

  for (final bundle in manualBundles) {
    bundlesByClientName[bundle.client.name.toUpperCase()] = bundle;
  }

  return bundlesByClientName.values.toList()
    ..sort((a, b) => a.client.name.compareTo(b.client.name));
}
