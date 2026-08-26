import 'package:latlong2/latlong.dart';

class AtlasCity {
  const AtlasCity({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.categories,
    required this.shortDescription,
  });

  final String id;
  final String name;
  final String countryCode;
  final double latitude;
  final double longitude;
  final int population;
  final List<String> categories;
  final String shortDescription;

  bool get isCapital => categories.contains('capital');

  bool get isHistoric => categories.contains('ville_historique');

  bool get isMetropolis => categories.contains('metropole');

  bool get isMajorNonCapital => categories.contains('grande_ville');

  List<String> get categoryLabels {
    return categories.map<String>((String category) {
      switch (category) {
        case 'capital':
          return 'Capitale';
        case 'ville_historique':
          return 'Ville historique';
        case 'metropole':
          return 'Métropole importante';
        case 'grande_ville':
          return 'Grande ville';
        default:
          return category;
      }
    }).toList(growable: false);
  }

  String get primaryCategoryLabel {
    if (isCapital) {
      return 'Capitale';
    }

    if (isHistoric) {
      return 'Ville historique';
    }

    if (isMetropolis) {
      return 'Métropole importante';
    }

    return 'Grande ville';
  }

  LatLng get position => LatLng(latitude, longitude);

  String get formattedPopulation {
    if (population >= 1000000) {
      final double millions = population / 1000000;
      final int decimals = millions >= 10 ? 1 : 2;
      return '${millions.toStringAsFixed(decimals)} M hab.';
    }

    if (population < 1000) {
      return '$population hab.';
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
    final List<String> categories = _readCategories(json['categories']);
    final String shortDescription =
        json['shortDescription']?.toString().trim() ?? '';

    if (id.isEmpty ||
        name.isEmpty ||
        countryCode.isEmpty ||
        latitude == null ||
        longitude == null ||
        population == null ||
        population < 0 ||
        categories.isEmpty ||
        shortDescription.isEmpty) {
      throw const FormatException(
        'Ville invalide dans major_cities.json.',
      );
    }

    return AtlasCity(
      id: id,
      name: name,
      countryCode: countryCode,
      latitude: latitude,
      longitude: longitude,
      population: population,
      categories: List<String>.unmodifiable(categories),
      shortDescription: shortDescription,
    );
  }

  static List<String> _readCategories(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    const Set<String> supported = <String>{
      'capital',
      'grande_ville',
      'ville_historique',
      'metropole',
    };

    return value
        .map((Object? item) => item?.toString().trim() ?? '')
        .where((String category) => supported.contains(category))
        .toSet()
        .toList(growable: false);
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
