import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import 'geo_country.dart';

class GeoJsonLoader {
  static const String _assetPath =
      'assets/maps/world_countries.geojson';

  static Future<List<GeoCountry>>? _countriesFuture;

  static Future<List<GeoCountry>> loadCountries() async {
    final List<GeoCountry> countries =
        await (_countriesFuture ??= _readCountries());

    /*
     * Chaque appel reçoit sa propre liste afin qu'un écran puisse
     * la trier ou la mélanger sans modifier le cache partagé.
     */
    return List<GeoCountry>.of(
      countries,
      growable: false,
    );
  }

  static Future<List<GeoCountry>> _readCountries() async {
    final String source =
        await rootBundle.loadString(_assetPath);

    final Object? decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Le fichier GeoJSON ne contient pas un objet valide.',
      );
    }

    final Object? rawFeatures = decoded['features'];

    if (rawFeatures is! List) {
      throw const FormatException(
        'Le fichier GeoJSON ne contient pas de liste "features".',
      );
    }

    final Map<String, _CountryBuilder> countryBuilders =
        <String, _CountryBuilder>{};

    for (
      int featureIndex = 0;
      featureIndex < rawFeatures.length;
      featureIndex++
    ) {
      final Object? rawFeature =
          rawFeatures[featureIndex];

      if (rawFeature is! Map<String, dynamic>) {
        continue;
      }

      final Map<String, dynamic> properties =
          _asStringMap(
        rawFeature['properties'],
      );

      final Map<String, dynamic> geometry =
          _asStringMap(
        rawFeature['geometry'],
      );

      final String id = _readCountryId(
        properties,
        featureIndex,
      );

      final String isoA2 = _readIsoA2(
        properties,
      );

      final String name = _readProperty(
        properties,
        <String>[
          'NAME_FR',
          'NAME',
          'ADMIN',
          'SOVEREIGNT',
        ],
        fallback: 'Pays inconnu',
      );

      final String continent = _readProperty(
        properties,
        <String>[
          'CONTINENT',
          'REGION_UN',
          'SUBREGION',
        ],
        fallback: 'Inconnu',
      );

      final List<List<LatLng>> polygons =
          _parseGeometry(geometry);

      if (polygons.isEmpty) {
        continue;
      }

      final _CountryBuilder builder =
          countryBuilders.putIfAbsent(
        id,
        () => _CountryBuilder(
          id: id,
          isoA2: isoA2,
          name: name,
          continent: continent,
        ),
      );

      /*
       * Certains fichiers GeoJSON peuvent contenir
       * plusieurs éléments pour le même pays.
       *
       * Si le premier élément ne possède pas de code ISO A2,
       * mais qu'un élément suivant le possède, on le récupère.
       */
      if (builder.isoA2.isEmpty &&
          isoA2.isNotEmpty) {
        builder.isoA2 = isoA2;
      }

      builder.polygons.addAll(polygons);
    }

    final List<GeoCountry> countries =
        countryBuilders.values
            .map<GeoCountry>(
              (_CountryBuilder builder) => GeoCountry(
                id: builder.id,
                isoA2: builder.isoA2,
                name: builder.name,
                continent: builder.continent,
                polygons: builder.polygons,
              ),
            )
            .toList(
              growable: false,
            );

    countries.sort(
      (GeoCountry a, GeoCountry b) {
        return a.name.compareTo(b.name);
      },
    );

    return countries;
  }

  static String _readCountryId(
    Map<String, dynamic> properties,
    int featureIndex,
  ) {
    final List<String> candidateKeys = <String>[
      'ADM0_A3',
      'SOV_A3',
      'GU_A3',
      'ISO_A3',
      'ISO_A2',
    ];

    for (final String key in candidateKeys) {
      final Object? value = properties[key];

      if (value == null) {
        continue;
      }

      final String code =
          value.toString().trim().toUpperCase();

      if (_isValidCode(code)) {
        return code;
      }
    }

    final String fallbackName = _readProperty(
      properties,
      <String>[
        'NAME',
        'ADMIN',
        'SOVEREIGNT',
      ],
      fallback: 'UNKNOWN',
    );

    final String normalizedName = fallbackName
        .toUpperCase()
        .replaceAll(
          RegExp(r'[^A-Z0-9]+'),
          '_',
        )
        .replaceAll(
          RegExp(r'^_+|_+$'),
          '',
        );

    final String safeName = normalizedName.isEmpty
        ? 'COUNTRY'
        : normalizedName;

    return '${safeName}_$featureIndex';
  }

  static String _readIsoA2(
    Map<String, dynamic> properties,
  ) {
    final List<String> candidateKeys = <String>[
      'ISO_A2',
      'ISO_A2_EH',
      'WB_A2',
      'POSTAL',
    ];

    for (final String key in candidateKeys) {
      final Object? value = properties[key];

      if (value == null) {
        continue;
      }

      final String code =
          value.toString().trim().toUpperCase();

      if (_isValidIsoA2(code)) {
        return code;
      }
    }

    return '';
  }

  static bool _isValidIsoA2(
    String code,
  ) {
    if (code == '-99') {
      return false;
    }

    return RegExp(r'^[A-Z]{2}$').hasMatch(code);
  }

  static bool _isValidCode(
    String code,
  ) {
    if (code.isEmpty || code == '-99') {
      return false;
    }

    return RegExp(
      r'^[A-Za-z0-9]{2,4}$',
    ).hasMatch(code);
  }

  static String _readProperty(
    Map<String, dynamic> properties,
    List<String> keys, {
    required String fallback,
  }) {
    for (final String key in keys) {
      final Object? value = properties[key];

      if (value == null) {
        continue;
      }

      final String text =
          value.toString().trim();

      if (text.isNotEmpty && text != '-99') {
        return text;
      }
    }

    return fallback;
  }

  static List<List<LatLng>> _parseGeometry(
    Map<String, dynamic> geometry,
  ) {
    final String type =
        geometry['type']?.toString() ?? '';

    final Object? rawCoordinates =
        geometry['coordinates'];

    if (rawCoordinates is! List) {
      return const <List<LatLng>>[];
    }

    switch (type) {
      case 'Polygon':
        return _parsePolygon(
          rawCoordinates,
        );

      case 'MultiPolygon':
        return _parseMultiPolygon(
          rawCoordinates,
        );

      default:
        return const <List<LatLng>>[];
    }
  }

  static List<List<LatLng>> _parsePolygon(
    List<dynamic> coordinates,
  ) {
    if (coordinates.isEmpty) {
      return const <List<LatLng>>[];
    }

    final Object? exteriorRing =
        coordinates.first;

    if (exteriorRing is! List) {
      return const <List<LatLng>>[];
    }

    final List<LatLng> polygon =
        _parseRing(exteriorRing);

    if (polygon.length < 3) {
      return const <List<LatLng>>[];
    }

    return <List<LatLng>>[
      polygon,
    ];
  }

  static List<List<LatLng>> _parseMultiPolygon(
    List<dynamic> coordinates,
  ) {
    final List<List<LatLng>> polygons =
        <List<LatLng>>[];

    for (final Object? rawPolygon in coordinates) {
      if (rawPolygon is! List ||
          rawPolygon.isEmpty) {
        continue;
      }

      final Object? exteriorRing =
          rawPolygon.first;

      if (exteriorRing is! List) {
        continue;
      }

      final List<LatLng> polygon =
          _parseRing(exteriorRing);

      if (polygon.length >= 3) {
        polygons.add(polygon);
      }
    }

    return polygons;
  }

  static List<LatLng> _parseRing(
    List<dynamic> rawRing,
  ) {
    final List<LatLng> points =
        <LatLng>[];

    for (final Object? rawPoint in rawRing) {
      if (rawPoint is! List ||
          rawPoint.length < 2) {
        continue;
      }

      final Object? rawLongitude =
          rawPoint[0];

      final Object? rawLatitude =
          rawPoint[1];

      if (rawLongitude is! num ||
          rawLatitude is! num) {
        continue;
      }

      points.add(
        LatLng(
          rawLatitude.toDouble(),
          rawLongitude.toDouble(),
        ),
      );
    }

    return points;
  }

  static Map<String, dynamic> _asStringMap(
    Object? value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map<String, dynamic>(
        (
          Object? key,
          Object? item,
        ) {
          return MapEntry<String, dynamic>(
            key.toString(),
            item,
          );
        },
      );
    }

    return <String, dynamic>{};
  }
}

class _CountryBuilder {
  _CountryBuilder({
    required this.id,
    required this.isoA2,
    required this.name,
    required this.continent,
  });

  final String id;

  String isoA2;

  final String name;
  final String continent;

  final List<List<LatLng>> polygons =
      <List<LatLng>>[];
}
