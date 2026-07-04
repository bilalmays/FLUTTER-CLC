import 'package:car_luxe_cleaning_flutter/shared/models/client.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/subscription.dart';
import 'package:car_luxe_cleaning_flutter/shared/models/vehicle.dart';

class ImportedSubscriptionRow {
  const ImportedSubscriptionRow({
    required this.sourceId,
    required this.clientName,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.plan,
    required this.termMonths,
    required this.visitDates,
    this.amountHtva,
    this.notes = const [],
  });

  final String sourceId;
  final String clientName;
  final String vehicleMake;
  final String vehicleModel;
  final SubscriptionPlan plan;
  final int termMonths;
  final int? amountHtva;
  final List<String> visitDates;
  final List<String> notes;
}

const importedSubscriptions = [
  ImportedSubscriptionRow(
    sourceId: 'resa-shinikar-x5',
    clientName: 'Resa / Shinikar',
    vehicleMake: 'BMW',
    vehicleModel: 'X5',
    plan: SubscriptionPlan.gold,
    amountHtva: 1824,
    termMonths: 12,
    visitDates: [
      '2025-07-22',
      '2025-08-25',
      '2025-09-29',
      '2025-10-22',
      '2025-11-17',
      '2025-12-15',
      '2026-01-31',
      '2026-02-17',
      '2026-03-23',
      '2026-05-23',
      '2026-06-27',
    ],
  ),
  ImportedSubscriptionRow(
    sourceId: 'accardo-330e-break',
    clientName: 'Accardo',
    vehicleMake: 'BMW',
    vehicleModel: '330 E Break',
    plan: SubscriptionPlan.gold,
    amountHtva: 1980,
    termMonths: 12,
    visitDates: [
      '2025-08-25',
      '2025-10-03',
      '2025-11-18',
      '2025-12-13',
      '2026-01-09',
      '2026-02-26',
      '2026-03-23',
      '2026-04-30',
      '2026-06-05',
    ],
    notes: ['Relance notee dans le fichier Excel: 24/02/2026.'],
  ),
  ImportedSubscriptionRow(
    sourceId: 'arturas-audi-q5',
    clientName: 'Arturas',
    vehicleMake: 'Audi',
    vehicleModel: 'Q5',
    plan: SubscriptionPlan.gold,
    amountHtva: 1860,
    termMonths: 12,
    visitDates: [
      '2025-09-24',
      '2025-10-24',
      '2025-11-27',
      '2026-01-23',
      '2026-02-24',
      '2026-03-26',
      '2026-04-29',
      '2026-05-19',
    ],
  ),
  ImportedSubscriptionRow(
    sourceId: 'najib-samir-glc',
    clientName: 'Najib Samir',
    vehicleMake: 'Mercedes-Benz',
    vehicleModel: 'GLC',
    plan: SubscriptionPlan.gold,
    amountHtva: 1860,
    termMonths: 12,
    visitDates: [
      '2025-10-01',
      '2025-11-06',
      '2025-12-09',
      '2026-01-27',
      '2026-03-03',
      '2026-05-25',
    ],
  ),
  ImportedSubscriptionRow(
    sourceId: 'azarkane-classe-e-break',
    clientName: 'Azarkane / AZ Consulting',
    vehicleMake: 'Mercedes-Benz',
    vehicleModel: 'Classe E Break',
    plan: SubscriptionPlan.gold,
    amountHtva: 1860,
    termMonths: 12,
    visitDates: [
      '2025-10-08',
      '2025-11-12',
      '2025-12-08',
      '2026-01-09',
      '2026-02-09',
      '2026-04-01',
      '2026-05-26',
      '2026-06-15',
      '2026-07-02',
    ],
  ),
  ImportedSubscriptionRow(
    sourceId: 'el-yakoubi-range-rover-sport',
    clientName: 'El Yakoubi',
    vehicleMake: 'Land Rover',
    vehicleModel: 'Range Rover Sport',
    plan: SubscriptionPlan.gold,
    amountHtva: 1860,
    termMonths: 12,
    visitDates: [
      '2025-11-10',
      '2025-12-06',
      '2026-01-21',
      '2026-02-26',
      '2026-03-27',
      '2026-04-29',
      '2026-06-02',
      '2026-06-03',
    ],
  ),
  ImportedSubscriptionRow(
    sourceId: 'davide-ferarri-audi-sq5',
    clientName: 'Davide Ferarri',
    vehicleMake: 'Audi',
    vehicleModel: 'SQ5',
    plan: SubscriptionPlan.carbone,
    termMonths: 6,
    visitDates: ['2025-12-15', '2026-02-24', '2026-03-30'],
    notes: [
      'Montant HTVA renseigne par un point d interrogation dans le fichier.',
    ],
  ),
  ImportedSubscriptionRow(
    sourceId: 'abdorrahman-ouedan-audi-q7',
    clientName: 'Abdorrahman Ouedan',
    vehicleMake: 'Audi',
    vehicleModel: 'Q7',
    plan: SubscriptionPlan.gold,
    amountHtva: 1800,
    termMonths: 12,
    visitDates: ['2026-04-29', '2026-05-26', '2026-06-30'],
  ),
  ImportedSubscriptionRow(
    sourceId: 'abdorrahman-ouedan-audi-q3',
    clientName: 'Abdorrahman Ouedan',
    vehicleMake: 'Audi',
    vehicleModel: 'Q3',
    plan: SubscriptionPlan.gold,
    amountHtva: 1800,
    termMonths: 12,
    visitDates: ['2026-04-29', '2026-05-26'],
  ),
];

List<SubscriptionBundle> buildSeedSubscriptionBundles() {
  return importedSubscriptions.map((row) {
      final start = DateTime.parse(row.visitDates.first);
      final end = DateTime(start.year, start.month + row.termMonths, start.day);
      final created = DateTime(2026, 7);
      final clientId = 'client-${row.sourceId}';
      final vehicleId = 'vehicle-${row.sourceId}';

      final client = Client(
        id: clientId,
        name: row.clientName.toUpperCase(),
        email: '',
        phone: '',
        address: '',
        language: 'FR',
        createdAt: created,
        updatedAt: created,
        archived: false,
      );

      final vehicle = Vehicle(
        id: vehicleId,
        clientId: clientId,
        make: row.vehicleMake,
        model: row.vehicleModel,
        year: '',
        licensePlate: '',
        createdAt: created,
        updatedAt: created,
      );

      final subscription = Subscription(
        id: 'subscription-${row.sourceId}',
        clientId: clientId,
        vehicleId: vehicleId,
        plan: row.plan,
        startDate: start,
        endDate: end,
        amountPaid: row.amountHtva,
        totalWash: row.visitDates.length,
        monthlyAllowance: row.plan == SubscriptionPlan.carbone ? 3 : 2,
        paymentType: PaymentType.full,
        status: SubscriptionStatus.active,
        notes: row.notes.join('\n'),
        createdAt: created,
        updatedAt: created,
      );

      final visits =
          row.visitDates
              .map(
                (date) => SubscriptionVisit(
                  id: 'visit-${row.sourceId}-$date',
                  subscriptionId: subscription.id,
                  clientId: clientId,
                  vehicleId: vehicleId,
                  visitDate: DateTime.parse(date),
                  createdAt: created,
                ),
              )
              .toList()
            ..sort((a, b) => a.visitDate.compareTo(b.visitDate));

      return SubscriptionBundle(
        subscription: subscription,
        client: client,
        vehicle: vehicle,
        visits: visits,
      );
    }).toList()
    ..sort((a, b) => a.subscription.endDate.compareTo(b.subscription.endDate));
}
