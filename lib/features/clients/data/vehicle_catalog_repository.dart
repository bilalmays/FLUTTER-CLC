import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehicleCatalogRepositoryProvider = Provider<VehicleCatalogRepository>(
  (ref) => VehicleCatalogRepository(),
);

class VehicleBrandOption {
  const VehicleBrandOption(this.name);

  final String name;
}

class VehicleModelOption {
  const VehicleModelOption({required this.brandName, required this.name});

  final String brandName;
  final String name;
}

class VehicleCatalogRepository {
  List<VehicleBrandOption>? _brands;
  Map<String, List<String>>? _models;

  Future<List<VehicleBrandOption>> brandSuggestions(String query) async {
    final brands = await _loadBrands();
    final normalized = _normalize(query);
    if (query.isNotEmpty && query.trim().isEmpty) return brands;
    if (normalized.isEmpty) return const [];
    return brands
        .where((brand) => _normalize(brand.name).contains(normalized))
        .take(40)
        .toList();
  }

  Future<List<VehicleModelOption>> modelSuggestions({
    required String query,
    required String brandName,
  }) async {
    final models = await _loadModels();
    final normalized = _normalize(query);
    final normalizedBrand = _normalize(brandName);
    final scoped = <VehicleModelOption>[];
    for (final entry in models.entries) {
      if (normalizedBrand.isNotEmpty &&
          _normalize(entry.key) != normalizedBrand) {
        continue;
      }
      for (final model in entry.value) {
        scoped.add(VehicleModelOption(brandName: entry.key, name: model));
      }
    }
    if (query.isNotEmpty && query.trim().isEmpty) {
      return scoped.take(80).toList();
    }
    if (normalized.isEmpty) return const [];
    return scoped
        .where(
          (model) =>
              _normalize(model.name).contains(normalized) ||
              _normalize(model.brandName).contains(normalized),
        )
        .take(50)
        .toList();
  }

  Future<List<VehicleBrandOption>> _loadBrands() async {
    if (_brands != null) return _brands!;
    final raw = await rootBundle.loadString('assets/data/vehicle-brands.json');
    final values = (jsonDecode(raw) as List).whereType<String>().toList()
      ..sort((a, b) => a.compareTo(b));
    _brands = values.map(VehicleBrandOption.new).toList();
    return _brands!;
  }

  Future<Map<String, List<String>>> _loadModels() async {
    if (_models != null) return _models!;
    final raw = await rootBundle.loadString('assets/data/vehicle-models.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _models = decoded.map(
      (key, value) =>
          MapEntry(key, (value as List).whereType<String>().toList()..sort()),
    );
    return _models!;
  }
}

String _normalize(String value) {
  final replacements = <String, String>{
    '\u00e0': 'a',
    '\u00e1': 'a',
    '\u00e2': 'a',
    '\u00e3': 'a',
    '\u00e4': 'a',
    '\u00e5': 'a',
    '\u00e7': 'c',
    '\u00e8': 'e',
    '\u00e9': 'e',
    '\u00ea': 'e',
    '\u00eb': 'e',
    '\u00ec': 'i',
    '\u00ed': 'i',
    '\u00ee': 'i',
    '\u00ef': 'i',
    '\u00f1': 'n',
    '\u00f2': 'o',
    '\u00f3': 'o',
    '\u00f4': 'o',
    '\u00f5': 'o',
    '\u00f6': 'o',
    '\u00f9': 'u',
    '\u00fa': 'u',
    '\u00fb': 'u',
    '\u00fc': 'u',
  };
  return value.trim().toLowerCase().split('').map((char) {
    return replacements[char] ?? char;
  }).join();
}
