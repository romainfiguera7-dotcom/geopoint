import 'dart:convert';

import 'package:flutter/services.dart';

import 'atlas_city.dart';

class AtlasCityLoader {
  AtlasCityLoader._();

  static const String _assetPath = 'assets/data/atlas_cities.json';

  static Future<List<AtlasCity>>? _citiesFuture;

  static Future<List<AtlasCity>> loadCities() async {
    final List<AtlasCity> cities =
        await (_citiesFuture ??= _readCities());

    return List<AtlasCity>.unmodifiable(cities);
  }

  static Future<List<AtlasCity>> _readCities() async {
    final String source = await rootBundle.loadString(_assetPath);
    final Object? decoded = jsonDecode(source);

    if (decoded is! List) {
      throw const FormatException(
        'atlas_cities.json doit contenir une liste.',
      );
    }

    final List<AtlasCity> cities = <AtlasCity>[];

    for (final Object? item in decoded) {
      if (item is! Map) {
        continue;
      }

      final Map<String, dynamic> json = item.map<String, dynamic>(
        (dynamic key, dynamic value) {
          return MapEntry<String, dynamic>(key.toString(), value);
        },
      );

      try {
        cities.add(AtlasCity.fromJson(json));
      } on FormatException {
        continue;
      }
    }

    cities.sort(
      (AtlasCity first, AtlasCity second) =>
          second.population.compareTo(first.population),
    );

    return List<AtlasCity>.unmodifiable(cities);
  }
}
