import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../geo_engine/geo_country.dart';

class CountrySilhouette extends StatelessWidget {
  const CountrySilhouette({
    required this.country,
    this.fillColor = const Color(0xFF53D8FF),
    this.borderColor = Colors.white,
    this.backgroundColor =
        const Color(0xFF0B2345),
    this.padding = 24,
    super.key,
  });

  final GeoCountry country;

  final Color fillColor;
  final Color borderColor;
  final Color backgroundColor;

  final double padding;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius:
              BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.16,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            padding,
          ),
          child: CustomPaint(
            painter: _CountrySilhouettePainter(
              country: country,
              fillColor: fillColor,
              borderColor: borderColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _CountrySilhouettePainter
    extends CustomPainter {
  const _CountrySilhouettePainter({
    required this.country,
    required this.fillColor,
    required this.borderColor,
  });

  final GeoCountry country;

  final Color fillColor;
  final Color borderColor;

  /*
   * Ces pays sont de véritables archipels.
   *
   * Pour eux, conserver uniquement le plus grand
   * polygone donnerait une silhouette trompeuse.
   */
  static const Set<String> _archipelagoIsoA2 =
      <String>{
    'BS',
    'CV',
    'FM',
    'FJ',
    'ID',
    'JP',
    'KI',
    'KM',
    'MH',
    'MV',
    'NZ',
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

  /*
   * Certaines entités possèdent des territoires
   * très éloignés du territoire principal.
   *
   * Ces zones de cadrage permettent d'afficher
   * une silhouette immédiatement reconnaissable.
   */
  static const Map<String, _PreferredRegion>
      _preferredRegions =
      <String, _PreferredRegion>{
    'FR': _PreferredRegion(
      minLatitude: 40.5,
      maxLatitude: 52.0,
      minLongitude: -6.5,
      maxLongitude: 10.5,
    ),
    'US': _PreferredRegion(
      minLatitude: 23.0,
      maxLatitude: 51.5,
      minLongitude: -130.0,
      maxLongitude: -60.0,
    ),
    'NL': _PreferredRegion(
      minLatitude: 50.0,
      maxLatitude: 54.5,
      minLongitude: 2.5,
      maxLongitude: 8.5,
    ),
    'PT': _PreferredRegion(
      minLatitude: 36.0,
      maxLatitude: 43.0,
      minLongitude: -10.5,
      maxLongitude: -6.0,
    ),
    'ES': _PreferredRegion(
      minLatitude: 35.0,
      maxLatitude: 44.5,
      minLongitude: -10.5,
      maxLongitude: 5.5,
    ),
    'DK': _PreferredRegion(
      minLatitude: 54.0,
      maxLatitude: 58.5,
      minLongitude: 7.0,
      maxLongitude: 16.0,
    ),
    'NO': _PreferredRegion(
      minLatitude: 57.0,
      maxLatitude: 72.5,
      minLongitude: 3.0,
      maxLongitude: 33.5,
    ),
  };

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        country.polygons.isEmpty) {
      return;
    }

    final List<List<LatLng>> sourcePolygons =
        country.polygons
            .where(
              (List<LatLng> polygon) {
                return polygon.length >= 3;
              },
            )
            .toList(
              growable: false,
            );

    if (sourcePolygons.isEmpty) {
      return;
    }

    final List<List<LatLng>> polygons =
        _selectDisplayPolygons(
      sourcePolygons,
    );

    if (polygons.isEmpty) {
      return;
    }

    final _SilhouetteBounds bounds =
        _calculateBounds(
      polygons,
    );

    if (!bounds.isValid) {
      return;
    }

    final double longitudeSpan =
        math.max(
      bounds.maxLongitude -
          bounds.minLongitude,
      0.000001,
    );

    final double latitudeSpan =
        math.max(
      bounds.maxLatitude -
          bounds.minLatitude,
      0.000001,
    );

    final double scaleX =
        size.width / longitudeSpan;

    final double scaleY =
        size.height / latitudeSpan;

    final double scale =
        math.min(
      scaleX,
      scaleY,
    );

    final double renderedWidth =
        longitudeSpan * scale;

    final double renderedHeight =
        latitudeSpan * scale;

    final double horizontalOffset =
        (
          size.width -
          renderedWidth
        ) /
        2;

    final double verticalOffset =
        (
          size.height -
          renderedHeight
        ) /
        2;

    final Paint fillPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = fillColor;

    final Paint borderPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = borderColor.withValues(
            alpha: 0.90,
          );

    for (final List<LatLng> polygon
        in polygons) {
      final ui.Path path =
          ui.Path();

      for (
        int index = 0;
        index < polygon.length;
        index++
      ) {
        final LatLng point =
            polygon[index];

        final double x =
            horizontalOffset +
                (
                  point.longitude -
                  bounds.minLongitude
                ) *
                    scale;

        final double y =
            verticalOffset +
                (
                  bounds.maxLatitude -
                  point.latitude
                ) *
                    scale;

        if (index == 0) {
          path.moveTo(
            x,
            y,
          );
        } else {
          path.lineTo(
            x,
            y,
          );
        }
      }

      path.close();

      canvas.drawPath(
        path,
        fillPaint,
      );

      canvas.drawPath(
        path,
        borderPaint,
      );
    }
  }

  List<List<LatLng>> _selectDisplayPolygons(
    List<List<LatLng>> polygons,
  ) {
    final String isoA2 =
        country.isoA2
            .trim()
            .toUpperCase();

    final _PreferredRegion? preferredRegion =
        _preferredRegions[isoA2];

    if (preferredRegion != null) {
      final List<List<LatLng>> regionalPolygons =
          polygons.where(
        (List<LatLng> polygon) {
          final LatLng center =
              _calculatePolygonCenter(
            polygon,
          );

          return preferredRegion.contains(
            center,
          );
        },
      ).toList(
        growable: false,
      );

      if (regionalPolygons.isNotEmpty) {
        return regionalPolygons;
      }
    }

    if (_archipelagoIsoA2.contains(
      isoA2,
    )) {
      return polygons;
    }

    final List<_PolygonInfo> polygonInfos =
        polygons
            .map<_PolygonInfo>(
              (List<LatLng> polygon) {
                return _PolygonInfo(
                  polygon: polygon,
                  bounds:
                      _calculateBounds(
                    <List<LatLng>>[
                      polygon,
                    ],
                  ),
                  center:
                      _calculatePolygonCenter(
                    polygon,
                  ),
                  area:
                      _calculatePolygonArea(
                    polygon,
                  ),
                );
              },
            )
            .toList();

    polygonInfos.sort(
      (
        _PolygonInfo first,
        _PolygonInfo second,
      ) {
        return second.area.compareTo(
          first.area,
        );
      },
    );

    final _PolygonInfo mainPolygon =
        polygonInfos.first;

    final double mainSpan =
        math.max(
      mainPolygon.bounds.maxLongitude -
          mainPolygon.bounds.minLongitude,
      mainPolygon.bounds.maxLatitude -
          mainPolygon.bounds.minLatitude,
    );

    final double safeMainSpan =
        math.max(
      mainSpan,
      1,
    );

    final List<List<LatLng>> selected =
        <List<LatLng>>[
      mainPolygon.polygon,
    ];

    for (final _PolygonInfo info
        in polygonInfos.skip(1)) {
      final double latitudeDifference =
          info.center.latitude -
              mainPolygon.center.latitude;

      final double longitudeDifference =
          info.center.longitude -
              mainPolygon.center.longitude;

      final double centerDistance =
          math.sqrt(
        latitudeDifference *
                latitudeDifference +
            longitudeDifference *
                longitudeDifference,
      );

      final double relativeDistance =
          centerDistance /
              safeMainSpan;

      final double relativeArea =
          mainPolygon.area <= 0
              ? 0
              : info.area /
                  mainPolygon.area;

      /*
       * On conserve :
       * - les grandes parties du pays ;
       * - les îles et territoires proches ;
       * - les polygones moyens, même légèrement
       *   éloignés, lorsqu'ils font réellement
       *   partie de la silhouette principale.
       */
      final bool isLargePart =
          relativeArea >= 0.12;

      final bool isNearbyPart =
          relativeDistance <= 1.15;

      final bool isMediumAndReasonablyClose =
          relativeArea >= 0.025 &&
              relativeDistance <= 1.80;

      if (isLargePart ||
          isNearbyPart ||
          isMediumAndReasonablyClose) {
        selected.add(
          info.polygon,
        );
      }
    }

    return selected;
  }

  double _calculatePolygonArea(
    List<LatLng> polygon,
  ) {
    if (polygon.length < 3) {
      return 0;
    }

    double twiceArea = 0;

    for (
      int index = 0;
      index < polygon.length;
      index++
    ) {
      final LatLng current =
          polygon[index];

      final LatLng next =
          polygon[
            (
              index + 1
            ) %
                polygon.length
          ];

      twiceArea +=
          current.longitude *
                  next.latitude -
              next.longitude *
                  current.latitude;
    }

    return twiceArea.abs() / 2;
  }

  LatLng _calculatePolygonCenter(
    List<LatLng> polygon,
  ) {
    double latitudeSum = 0;
    double longitudeSum = 0;

    for (final LatLng point
        in polygon) {
      latitudeSum +=
          point.latitude;

      longitudeSum +=
          point.longitude;
    }

    return LatLng(
      latitudeSum /
          polygon.length,
      longitudeSum /
          polygon.length,
    );
  }

  _SilhouetteBounds _calculateBounds(
    List<List<LatLng>> polygons,
  ) {
    double minLatitude =
        double.infinity;

    double maxLatitude =
        -double.infinity;

    double minLongitude =
        double.infinity;

    double maxLongitude =
        -double.infinity;

    for (final List<LatLng> polygon
        in polygons) {
      for (final LatLng point
          in polygon) {
        minLatitude =
            math.min(
          minLatitude,
          point.latitude,
        );

        maxLatitude =
            math.max(
          maxLatitude,
          point.latitude,
        );

        minLongitude =
            math.min(
          minLongitude,
          point.longitude,
        );

        maxLongitude =
            math.max(
          maxLongitude,
          point.longitude,
        );
      }
    }

    return _SilhouetteBounds(
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
    );
  }

  @override
  bool shouldRepaint(
    covariant _CountrySilhouettePainter
        oldDelegate,
  ) {
    return oldDelegate.country.id !=
            country.id ||
        oldDelegate.fillColor !=
            fillColor ||
        oldDelegate.borderColor !=
            borderColor;
  }
}

class _PolygonInfo {
  const _PolygonInfo({
    required this.polygon,
    required this.bounds,
    required this.center,
    required this.area,
  });

  final List<LatLng> polygon;
  final _SilhouetteBounds bounds;
  final LatLng center;
  final double area;
}

class _PreferredRegion {
  const _PreferredRegion({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  bool contains(
    LatLng point,
  ) {
    return point.latitude >=
            minLatitude &&
        point.latitude <=
            maxLatitude &&
        point.longitude >=
            minLongitude &&
        point.longitude <=
            maxLongitude;
  }
}

class _SilhouetteBounds {
  const _SilhouetteBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;

  final double minLongitude;
  final double maxLongitude;

  bool get isValid {
    return minLatitude.isFinite &&
        maxLatitude.isFinite &&
        minLongitude.isFinite &&
        maxLongitude.isFinite &&
        maxLatitude > minLatitude &&
        maxLongitude > minLongitude;
  }
}
