import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'geo_country.dart';

/// Sélectionne les parties d'un pays qui composent sa silhouette principale.
///
/// La même sélection est utilisée par le quiz Silhouettes et par la carte de
/// révélation. Cela évite, par exemple, d'afficher la France entière avec ses
/// territoires éloignés ou de ne colorer qu'une île de la Nouvelle-Zélande.
abstract final class CountryDisplayGeometry {
  static const Map<String, _DisplayRegion> _preferredRegions =
      <String, _DisplayRegion>{
    // Territoire européen et Corse, sans les territoires ultramarins.
    'FR': _DisplayRegion(40.5, 52.0, -6.5, 10.5),

    // États contigus, sans l'Alaska, Hawaï et les territoires océaniens.
    'US': _DisplayRegion(23.0, 51.5, -125.5, -60.0),

    // Territoires européens principaux.
    'NL': _DisplayRegion(50.0, 54.5, 2.5, 8.5),
    'PT': _DisplayRegion(36.0, 43.0, -10.5, -6.0),
    'ES': _DisplayRegion(35.0, 44.5, -10.5, 5.5),
    'DK': _DisplayRegion(54.0, 58.5, 7.0, 16.0),
    'NO': _DisplayRegion(57.0, 72.5, 3.0, 33.5),
    'GB': _DisplayRegion(49.0, 61.5, -9.0, 3.0),

    // Territoire continental et grandes îles proches.
    'AU': _DisplayRegion(-44.5, -9.0, 111.0, 155.0),
    'NZ': _DisplayRegion(-48.5, -33.0, 165.0, 180.0),
    'JP': _DisplayRegion(30.0, 46.5, 128.0, 146.5),
    'CL': _DisplayRegion(-56.5, -17.0, -76.5, -66.0),
    'EC': _DisplayRegion(-6.0, 2.5, -82.5, -74.0),
  };

  /// Ces pays sont des archipels : leurs différentes îles forment la réponse.
  /// Les cas possédant des territoires très éloignés sont traités auparavant
  /// par [_preferredRegions].
  static const Set<String> _archipelagoIsoA2 = <String>{
    'BS',
    'CV',
    'FM',
    'FJ',
    'ID',
    'KI',
    'KM',
    'MH',
    'MV',
    'PG',
    'PH',
    'PW',
    'SB',
    'SC',
    'TO',
    'TV',
    'VU',
    'WS',
  };

  static List<List<LatLng>> selectPolygons(GeoCountry country) {
    final List<List<LatLng>> polygons = country.polygons
        .where((List<LatLng> polygon) => polygon.length >= 3)
        .toList(growable: false);

    if (polygons.isEmpty) {
      return const <List<LatLng>>[];
    }

    final String isoA2 = country.isoA2.trim().toUpperCase();
    final _DisplayRegion? preferredRegion = _preferredRegions[isoA2];

    if (preferredRegion != null) {
      final List<List<LatLng>> regionalPolygons = polygons
          .where(preferredRegion.intersectsPolygon)
          .toList(growable: false);

      if (regionalPolygons.isNotEmpty) {
        return regionalPolygons;
      }
    }

    if (_archipelagoIsoA2.contains(isoA2)) {
      return polygons;
    }

    final List<_PolygonInfo> polygonInfos = polygons
        .map(_PolygonInfo.fromPolygon)
        .toList(growable: false)
      ..sort((_PolygonInfo first, _PolygonInfo second) {
        return second.area.compareTo(first.area);
      });

    final _PolygonInfo mainPolygon = polygonInfos.first;
    final double mainSpan = math.max(mainPolygon.metricSpan, 0.25);

    final List<List<LatLng>> selected = <List<LatLng>>[
      mainPolygon.polygon,
    ];

    for (final _PolygonInfo info in polygonInfos.skip(1)) {
      final double relativeArea = mainPolygon.area <= 0
          ? 0
          : info.area / mainPolygon.area;

      final double distance = _metricDistance(
        mainPolygon.center,
        info.center,
      );
      final double relativeDistance = distance / mainSpan;

      final bool isSecondMajorPart = relativeArea >= 0.08;
      final bool isCloseToMainTerritory = relativeDistance <= 1.20;
      final bool isVisibleAndReasonablyClose =
          relativeArea >= 0.012 && relativeDistance <= 1.85;

      if (isSecondMajorPart ||
          isCloseToMainTerritory ||
          isVisibleAndReasonablyClose) {
        selected.add(info.polygon);
      }
    }

    return selected;
  }

  static double _metricDistance(LatLng first, LatLng second) {
    final double averageLatitude =
        (first.latitude + second.latitude) * math.pi / 360;
    final double latitudeDistance = second.latitude - first.latitude;
    final double longitudeDistance =
        _shortestLongitudeDifference(first.longitude, second.longitude) *
            math.cos(averageLatitude);

    return math.sqrt(
      latitudeDistance * latitudeDistance +
          longitudeDistance * longitudeDistance,
    );
  }

  static double _shortestLongitudeDifference(double first, double second) {
    double difference = second - first;

    while (difference > 180) {
      difference -= 360;
    }

    while (difference < -180) {
      difference += 360;
    }

    return difference;
  }
}

class _PolygonInfo {
  const _PolygonInfo({
    required this.polygon,
    required this.center,
    required this.area,
    required this.metricSpan,
  });

  factory _PolygonInfo.fromPolygon(List<LatLng> polygon) {
    double minLatitude = double.infinity;
    double maxLatitude = double.negativeInfinity;
    double minLongitude = double.infinity;
    double maxLongitude = double.negativeInfinity;
    double latitudeTotal = 0;
    double longitudeSinTotal = 0;
    double longitudeCosTotal = 0;

    for (final LatLng point in polygon) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
      latitudeTotal += point.latitude;

      final double longitudeRadians = point.longitude * math.pi / 180;
      longitudeSinTotal += math.sin(longitudeRadians);
      longitudeCosTotal += math.cos(longitudeRadians);
    }

    final double centerLatitude = latitudeTotal / polygon.length;
    final double centerLongitude = math.atan2(
          longitudeSinTotal,
          longitudeCosTotal,
        ) *
        180 /
        math.pi;

    final double latitudeSpan = maxLatitude - minLatitude;
    final double rawLongitudeSpan = maxLongitude - minLongitude;
    final double longitudeSpan = rawLongitudeSpan > 180
        ? 360 - rawLongitudeSpan
        : rawLongitudeSpan;
    final double metricLongitudeSpan =
        longitudeSpan * math.cos(centerLatitude * math.pi / 180).abs();

    return _PolygonInfo(
      polygon: polygon,
      center: LatLng(centerLatitude, centerLongitude),
      area: _approximateArea(polygon, centerLatitude),
      metricSpan: math.max(latitudeSpan, metricLongitudeSpan),
    );
  }

  final List<LatLng> polygon;
  final LatLng center;
  final double area;
  final double metricSpan;

  static double _approximateArea(
    List<LatLng> polygon,
    double centerLatitude,
  ) {
    double doubledArea = 0;
    double previousLongitude = polygon.first.longitude;

    for (int index = 0; index < polygon.length; index++) {
      final LatLng current = polygon[index];
      final LatLng next = polygon[(index + 1) % polygon.length];
      final double currentLongitude = _unwrapLongitude(
        current.longitude,
        previousLongitude,
      );
      final double nextLongitude = _unwrapLongitude(
        next.longitude,
        currentLongitude,
      );

      doubledArea += currentLongitude * next.latitude -
          nextLongitude * current.latitude;
      previousLongitude = currentLongitude;
    }

    return doubledArea.abs() *
        math.cos(centerLatitude * math.pi / 180).abs() /
        2;
  }

  static double _unwrapLongitude(double longitude, double reference) {
    double result = longitude;

    while (result - reference > 180) {
      result -= 360;
    }

    while (result - reference < -180) {
      result += 360;
    }

    return result;
  }
}

class _DisplayRegion {
  const _DisplayRegion(
    this.minLatitude,
    this.maxLatitude,
    this.minLongitude,
    this.maxLongitude,
  );

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  bool intersectsPolygon(List<LatLng> polygon) {
    double polygonMinLatitude = double.infinity;
    double polygonMaxLatitude = double.negativeInfinity;
    double polygonMinLongitude = double.infinity;
    double polygonMaxLongitude = double.negativeInfinity;

    for (final LatLng point in polygon) {
      polygonMinLatitude = math.min(polygonMinLatitude, point.latitude);
      polygonMaxLatitude = math.max(polygonMaxLatitude, point.latitude);
      polygonMinLongitude = math.min(polygonMinLongitude, point.longitude);
      polygonMaxLongitude = math.max(polygonMaxLongitude, point.longitude);
    }

    return polygonMaxLatitude >= minLatitude &&
        polygonMinLatitude <= maxLatitude &&
        polygonMaxLongitude >= minLongitude &&
        polygonMinLongitude <= maxLongitude;
  }
}
