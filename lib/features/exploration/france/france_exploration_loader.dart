import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import 'france_exploration_data.dart';

class FranceExplorationLoader {
  FranceExplorationLoader._();

  static Future<FranceExplorationData>? _dataFuture;

  static Future<FranceExplorationData> load() {
    return _dataFuture ??= _load();
  }

  static Future<FranceExplorationData> _load() async {
    final List<String> sources = await Future.wait(<Future<String>>[
      rootBundle.loadString('assets/data/france_regions.geojson'),
      rootBundle.loadString('assets/data/france_departments.geojson'),
      rootBundle.loadString('assets/data/france_exploration_items.json'),
    ]);

    final Map<String, dynamic> regionJson =
        _object(jsonDecode(sources[0]), 'france_regions.geojson');
    final Map<String, dynamic> departmentJson =
        _object(jsonDecode(sources[1]), 'france_departments.geojson');
    final Map<String, dynamic> itemJson =
        _object(jsonDecode(sources[2]), 'france_exploration_items.json');

    final List<FranceRegionShape> regions = <FranceRegionShape>[];
    final Object? rawFeatures = regionJson['features'];
    if (rawFeatures is List) {
      for (final Object? rawFeature in rawFeatures) {
        if (rawFeature is! Map) {
          continue;
        }
        final Map<String, dynamic> feature = _map(rawFeature);
        final Map<String, dynamic> properties =
            _object(feature['properties'], 'propriétés de région');
        final Map<String, dynamic> geometry =
            _object(feature['geometry'], 'géométrie de région');
        final List<List<LatLng>> polygons = _readPolygons(geometry);
        if (polygons.isEmpty) {
          continue;
        }
        regions.add(
          FranceRegionShape(
            code: properties['code']?.toString() ?? '',
            name: properties['nom']?.toString() ?? '',
            polygons: List<List<LatLng>>.unmodifiable(polygons),
            center: _center(polygons),
          ),
        );
      }
    }

    final List<FranceDepartmentShape> departments =
        <FranceDepartmentShape>[];
    final Object? rawDepartments = departmentJson['features'];
    if (rawDepartments is List) {
      for (final Object? rawFeature in rawDepartments) {
        if (rawFeature is! Map) {
          continue;
        }
        final Map<String, dynamic> feature = _map(rawFeature);
        final Map<String, dynamic> properties =
            _object(feature['properties'], 'propriétés de département');
        final Map<String, dynamic> geometry =
            _object(feature['geometry'], 'géométrie de département');
        final List<List<LatLng>> polygons = _readPolygons(geometry);
        final String code = properties['code']?.toString() ?? '';
        final String name = properties['nom']?.toString() ?? '';
        final String regionCode = properties['region']?.toString() ?? '';
        if (code.isEmpty || name.isEmpty || polygons.isEmpty) {
          continue;
        }
        departments.add(
          FranceDepartmentShape(
            code: code,
            name: name,
            regionCode: regionCode,
            polygons: List<List<LatLng>>.unmodifiable(polygons),
            center: _center(polygons),
          ),
        );
      }
    }

    final List<FranceExplorationItem> items = <FranceExplorationItem>[];
    final Object? rawItems = itemJson['items'];
    if (rawItems is List) {
      for (final Object? rawItem in rawItems) {
        if (rawItem is Map) {
          items.add(FranceExplorationItem.fromJson(_map(rawItem)));
        }
      }
    }
    if (regions.isEmpty || departments.isEmpty || items.isEmpty) {
      throw const FormatException('Les données de la France sont vides.');
    }
    return FranceExplorationData(
      regions: List<FranceRegionShape>.unmodifiable(regions),
      departments: List<FranceDepartmentShape>.unmodifiable(departments),
      items: List<FranceExplorationItem>.unmodifiable(items),
    );
  }

  static List<List<LatLng>> _readPolygons(Map<String, dynamic> geometry) {
    final String type = geometry['type']?.toString() ?? '';
    final Object? rawCoordinates = geometry['coordinates'];
    if (rawCoordinates is! List) {
      return const <List<LatLng>>[];
    }
    final List<List<LatLng>> result = <List<LatLng>>[];
    if (type == 'Polygon') {
      _addOuterRing(result, rawCoordinates);
    } else if (type == 'MultiPolygon') {
      for (final Object? rawPolygon in rawCoordinates) {
        if (rawPolygon is List) {
          _addOuterRing(result, rawPolygon);
        }
      }
    }
    return result;
  }

  static void _addOuterRing(
    List<List<LatLng>> result,
    List<dynamic> rawPolygon,
  ) {
    if (rawPolygon.isEmpty || rawPolygon.first is! List) {
      return;
    }
    final List<LatLng> points = <LatLng>[];
    for (final Object? rawPoint in rawPolygon.first as List<dynamic>) {
      if (rawPoint is List && rawPoint.length >= 2) {
        final double? longitude = _double(rawPoint[0]);
        final double? latitude = _double(rawPoint[1]);
        if (latitude != null && longitude != null) {
          points.add(LatLng(latitude, longitude));
        }
      }
    }
    if (points.length >= 3) {
      result.add(List<LatLng>.unmodifiable(points));
    }
  }

  static LatLng _center(List<List<LatLng>> polygons) {
    final List<LatLng> largest = polygons.reduce(
      (List<LatLng> a, List<LatLng> b) => a.length >= b.length ? a : b,
    );
    double latitude = 0;
    double longitude = 0;
    for (final LatLng point in largest) {
      latitude += point.latitude;
      longitude += point.longitude;
    }
    return LatLng(latitude / largest.length, longitude / largest.length);
  }

  static Map<String, dynamic> _object(Object? raw, String label) {
    if (raw is! Map) {
      throw FormatException('$label doit contenir un objet.');
    }
    return _map(raw);
  }

  static Map<String, dynamic> _map(Map<dynamic, dynamic> raw) {
    return raw.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }

  static double? _double(Object? raw) {
    return raw is num ? raw.toDouble() : double.tryParse('$raw');
  }
}
