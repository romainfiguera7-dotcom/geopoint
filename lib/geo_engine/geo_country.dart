import 'package:latlong2/latlong.dart';

class GeoCountry {
  GeoCountry({
    required this.id,
    required this.isoA2,
    required this.name,
    required this.continent,
    required this.polygons,
  }) : bounds = GeoBounds.fromPolygons(polygons);

  /// Identifiant principal du pays.
  ///
  /// Il s'agit généralement d'un code à trois lettres :
  /// FRA, ESP, PRT, etc.
  final String id;

  /// Code ISO à deux lettres utilisé notamment pour le drapeau :
  /// FR, ES, PT, etc.
  final String isoA2;

  final String name;
  final String continent;

  /// Un pays peut contenir plusieurs polygones :
  /// territoire principal, îles, territoires séparés, etc.
  final List<List<LatLng>> polygons;

  /// Rectangle englobant calculé automatiquement.
  final GeoBounds bounds;

  /// Drapeau généré à partir du code ISO à deux lettres.
  ///
  /// Exemple :
  /// FR devient 🇫🇷
  /// ES devient 🇪🇸
  String get flagEmoji {
    final String normalizedCode =
        isoA2.trim().toUpperCase();

    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalizedCode)) {
      return '';
    }

    return normalizedCode.codeUnits
        .map(
          (int character) => String.fromCharCode(
            character + 127397,
          ),
        )
        .join();
  }

  /// Nom du pays précédé de son drapeau.
  ///
  /// Exemple : 🇫🇷 France
  String get displayNameWithFlag {
    final String flag = flagEmoji;

    if (flag.isEmpty) {
      return name;
    }

    return '$flag $name';
  }
}

class GeoBounds {
  const GeoBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  bool contains(LatLng point) {
    return point.latitude >= minLatitude &&
        point.latitude <= maxLatitude &&
        point.longitude >= minLongitude &&
        point.longitude <= maxLongitude;
  }

  factory GeoBounds.fromPolygons(
    List<List<LatLng>> polygons,
  ) {
    if (polygons.isEmpty) {
      return const GeoBounds(
        minLatitude: 0,
        maxLatitude: 0,
        minLongitude: 0,
        maxLongitude: 0,
      );
    }

    double minLatitude = 90;
    double maxLatitude = -90;
    double minLongitude = 180;
    double maxLongitude = -180;

    for (final List<LatLng> polygon in polygons) {
      for (final LatLng point in polygon) {
        if (point.latitude < minLatitude) {
          minLatitude = point.latitude;
        }

        if (point.latitude > maxLatitude) {
          maxLatitude = point.latitude;
        }

        if (point.longitude < minLongitude) {
          minLongitude = point.longitude;
        }

        if (point.longitude > maxLongitude) {
          maxLongitude = point.longitude;
        }
      }
    }

    return GeoBounds(
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
    );
  }
}