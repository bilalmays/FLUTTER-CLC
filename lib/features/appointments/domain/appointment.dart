class Appointment {
  const Appointment({
    required this.id,
    required this.clientId,
    required this.vehicleId,
    required this.date,
    required this.status,
  });

  final String id;
  final String clientId;
  final String vehicleId;
  final DateTime date;
  final String status;
}
