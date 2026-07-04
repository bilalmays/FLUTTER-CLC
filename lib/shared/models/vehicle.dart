enum VehicleSize { s, m, l }

class Vehicle {
  const Vehicle({
    required this.id,
    required this.clientId,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.createdAt,
    required this.updatedAt,
    this.size,
    this.vin,
    this.color,
  });

  final String id;
  final String clientId;
  final String make;
  final String model;
  final VehicleSize? size;
  final String year;
  final String licensePlate;
  final String? vin;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => '$make $model';
  String get displayPlate =>
      licensePlate.isEmpty ? 'Sans plaque' : licensePlate;

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      size: _vehicleSizeFromJson(json['size']),
      year: json['year'] as String? ?? '',
      licensePlate: json['licensePlate'] as String? ?? '',
      vin: json['vin'] as String?,
      color: json['color'] as String?,
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'make': make,
    'model': model,
    'size': size?.name.toUpperCase(),
    'year': year,
    'licensePlate': licensePlate,
    'vin': vin,
    'color': color,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Vehicle copyWith({
    String? id,
    String? clientId,
    String? make,
    String? model,
    VehicleSize? size,
    String? year,
    String? licensePlate,
    String? vin,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      make: make ?? this.make,
      model: model ?? this.model,
      size: size ?? this.size,
      year: year ?? this.year,
      licensePlate: licensePlate ?? this.licensePlate,
      vin: vin ?? this.vin,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

VehicleSize? _vehicleSizeFromJson(Object? value) {
  if (value == 'S') return VehicleSize.s;
  if (value == 'M') return VehicleSize.m;
  if (value == 'L') return VehicleSize.l;
  return null;
}

DateTime _dateFromJson(Object? value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
