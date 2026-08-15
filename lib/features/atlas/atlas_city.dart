import 'package:latlong2/latlong.dart';

class AtlasCity {
  const AtlasCity({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.isCapital,
  });

  final String id;
  final String name;
  final String countryCode;
  final double latitude;
  final double longitude;
  final int population;
  final bool isCapital;

  LatLng get position => LatLng(latitude, longitude);

  String get formattedPopulation {
    if (population >= 1000000) {
      final double millions = population / 1000000;
      final int decimals = millions >= 10 ? 1 : 2;
      return '${millions.toStringAsFixed(decimals)} M hab.';
    }

    return '${(population / 1000).round()} 000 hab.';
  }

  factory AtlasCity.fromJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString().trim() ?? '';
    final String name = json['name']?.toString().trim() ?? '';
    final String countryCode =
        json['countryCode']?.toString().trim().toUpperCase() ?? '';

    final double? latitude = _readDouble(json['latitude']);
    final double? longitude = _readDouble(json['longitude']);
    final int? population = _readInt(json['population']);

    if (id.isEmpty ||
        name.isEmpty ||
        countryCode.isEmpty ||
        latitude == null ||
        longitude == null ||
        population == null ||
        population < 100000) {
      throw const FormatException('Ville invalide dans atlas_cities.json.');
    }

    return AtlasCity(
      id: id,
      name: name,
      countryCode: countryCode,
      latitude: latitude,
      longitude: longitude,
      population: population,
      isCapital: json['isCapital'] == true,
    );
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
