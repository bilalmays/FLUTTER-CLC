class Client {
  const Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    required this.archived,
    this.isProfessional = false,
    this.companyName,
    this.vatNumber,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final bool isProfessional;
  final String? companyName;
  final String? vatNumber;

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      language: json['language'] as String? ?? 'FR',
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
      archived: json['archived'] as bool? ?? false,
      isProfessional: json['isProfessional'] as bool? ?? false,
      companyName: json['companyName'] as String?,
      vatNumber: json['vatNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'language': language,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'archived': archived,
    'isProfessional': isProfessional,
    'companyName': companyName,
    'vatNumber': vatNumber,
  };

  Client copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? language,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? archived,
    bool? isProfessional,
    String? companyName,
    String? vatNumber,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
      isProfessional: isProfessional ?? this.isProfessional,
      companyName: companyName ?? this.companyName,
      vatNumber: vatNumber ?? this.vatNumber,
    );
  }
}

DateTime _dateFromJson(Object? value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
