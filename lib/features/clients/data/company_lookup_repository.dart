import 'package:car_luxe_cleaning_flutter/core/api/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final companyLookupRepositoryProvider = Provider<CompanyLookupRepository>(
  (ref) => CompanyLookupRepository(ref.read(apiClientProvider)),
);

class CompanyLookupResult {
  const CompanyLookupResult({
    this.cbeNumber = '',
    this.vatNumber = '',
    this.name = '',
    this.displayName = '',
    this.companyName = '',
    this.denomination = '',
    this.address = '',
    this.email = '',
    this.phone = '',
    this.representativeName = '',
    this.contactName = '',
    this.ownerName = '',
  });

  final String cbeNumber;
  final String vatNumber;
  final String name;
  final String displayName;
  final String companyName;
  final String denomination;
  final String address;
  final String email;
  final String phone;
  final String representativeName;
  final String contactName;
  final String ownerName;

  String get title {
    return [
      displayName,
      name,
      companyName,
      denomination,
      cbeNumber,
      vatNumber,
    ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
  }

  String get taxNumber {
    final raw = (vatNumber.isNotEmpty ? vatNumber : cbeNumber)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.isEmpty) return '';
    if (raw.startsWith('BE')) return raw;
    if (RegExp(r'^\d{9,10}$').hasMatch(raw)) {
      return 'BE${raw.padLeft(10, '0')}';
    }
    return raw;
  }

  String get contactPerson {
    return [
      representativeName,
      contactName,
      ownerName,
    ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
  }

  factory CompanyLookupResult.fromJson(Map<String, dynamic> json) {
    String read(String key) => (json[key] as String?)?.trim() ?? '';
    return CompanyLookupResult(
      cbeNumber: read('cbeNumber'),
      vatNumber: read('vatNumber'),
      name: read('name'),
      displayName: read('displayName'),
      companyName: read('companyName'),
      denomination: read('denomination'),
      address: read('address'),
      email: read('email'),
      phone: read('phone'),
      representativeName: read('representativeName'),
      contactName: read('contactName'),
      ownerName: read('ownerName'),
    );
  }

  Map<String, dynamic> toJson() => {
    'cbeNumber': cbeNumber,
    'vatNumber': vatNumber,
    'name': name,
    'displayName': displayName,
    'companyName': companyName,
    'denomination': denomination,
    'address': address,
    'email': email,
    'phone': phone,
    'representativeName': representativeName,
    'contactName': contactName,
    'ownerName': ownerName,
  };
}

class CompanyLookupRepository {
  const CompanyLookupRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CompanyLookupResult>> search(String query) async {
    final trimmed = query.trim();
    if (!_shouldSearch(trimmed)) return const [];

    final vatDigits = _vatDigits(trimmed);
    final isFullVat = RegExp(r'^\d{9,10}$').hasMatch(vatDigits);

    final response = isFullVat
        ? await _apiClient.get<Map<String, dynamic>>(
            '/api/cbe/company/${Uri.encodeComponent(vatDigits.padLeft(10, '0'))}',
          )
        : await _apiClient.get<Map<String, dynamic>>(
            '/api/cbe/search',
            query: {'name': vatDigits.length >= 5 ? vatDigits : trimmed},
          );

    final data = response.data ?? {};
    if (data['company'] is Map<String, dynamic>) {
      return [
        CompanyLookupResult.fromJson(data['company'] as Map<String, dynamic>),
      ];
    }
    if (data['companies'] is List) {
      return (data['companies'] as List)
          .whereType<Map<String, dynamic>>()
          .map(CompanyLookupResult.fromJson)
          .toList();
    }
    return const [];
  }

  Future<CompanyLookupResult?> getByTaxNumber(String taxNumber) async {
    final digits = _vatDigits(taxNumber);
    if (digits.isEmpty) return null;
    final clean = digits.padLeft(10, '0');
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/cbe/company/${Uri.encodeComponent(clean)}',
    );
    final data = response.data ?? {};
    if (data['company'] is Map<String, dynamic>) {
      return CompanyLookupResult.fromJson(
        data['company'] as Map<String, dynamic>,
      );
    }
    return null;
  }

  bool _shouldSearch(String value) {
    final digits = _vatDigits(value);
    return value.length >= 2 || digits.length >= 5;
  }

  String _vatDigits(String value) {
    return value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceFirst(RegExp(r'^BE'), '')
        .replaceAll(RegExp(r'[^0-9]'), '');
  }
}
