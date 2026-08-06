import 'package:latlong2/latlong.dart';

class Capital {
  const Capital({
    required this.isoA2,
    required this.isoA3,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.population,
  });

  /// Code pays à deux lettres.
  ///
  /// Exemple : FR, ES, PT.
  final String isoA2;

  /// Code pays à trois lettres.
  ///
  /// Exemple : FRA, ESP, PRT.
  final String isoA3;

  /// Nom de la capitale.
  final String name;

  /// Latitude de la capitale.
  final double latitude;

  /// Longitude de la capitale.
  final double longitude;

  /// Population enregistrée dans la base GeoNames.
  final int population;

  /// Coordonnées directement utilisables sur la carte.
  LatLng get position {
    return LatLng(
      latitude,
      longitude,
    );
  }

  factory Capital.fromJson(
    Map<String, dynamic> json,
  ) {
    final String isoA2 =
        json['isoA2']?.toString().trim().toUpperCase() ?? '';

    final String isoA3 =
        json['isoA3']?.toString().trim().toUpperCase() ?? '';

    final String name =
        json['capital']?.toString().trim() ?? '';

    final double? latitude =
        _readDouble(json['latitude']);

    final double? longitude =
        _readDouble(json['longitude']);

    final int population =
        _readInt(json['population']);

    if (isoA3.isEmpty) {
      throw const FormatException(
        'Code ISO A3 manquant pour une capitale.',
      );
    }

    if (name.isEmpty) {
      throw FormatException(
        'Nom de capitale manquant pour $isoA3.',
      );
    }

    if (latitude == null ||
        longitude == null) {
      throw FormatException(
        'Coordonnées invalides pour $isoA3.',
      );
    }

    return Capital(
      isoA2: isoA2,
      isoA3: isoA3,
      name: name,
      latitude: latitude,
      longitude: longitude,
      population: population,
    );
  }

  static double? _readDouble(
    Object? value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  static int _readInt(
    Object? value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  @override
  String toString() {
    return 'Capital('
        'isoA3: $isoA3, '
        'name: $name, '
        'latitude: $latitude, '
        'longitude: $longitude'
        ')';
  }
}