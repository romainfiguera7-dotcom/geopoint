import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../geo_engine/country_display_geometry.dart';
import '../../geo_engine/geo_country.dart';

class CountrySilhouette extends StatelessWidget {
  const CountrySilhouette({
    required this.country,
    this.fillColor = const Color(0xFFD9C2A6),
    this.borderColor = Colors.white,
    this.backgroundColor = const Color(0xFF0B2345),
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
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
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

class _CountrySilhouettePainter extends CustomPainter {
  const _CountrySilhouettePainter({
    required this.country,
    required this.fillColor,
    required this.borderColor,
  });

  static const double _maximumMercatorLatitude = 85.05112878;

  final GeoCountry country;
  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final List<List<LatLng>> sourcePolygons =
        CountryDisplayGeometry.selectPolygons(country);

    if (sourcePolygons.isEmpty) {
      return;
    }

    final List<List<_ProjectedPoint>> polygons =
        _projectPolygons(sourcePolygons);
    final _ProjectedBounds bounds = _calculateBounds(polygons);

    if (!bounds.isValid) {
      return;
    }

    final double widthSpan = math.max(bounds.maxX - bounds.minX, 0.000001);
    final double heightSpan = math.max(bounds.maxY - bounds.minY, 0.000001);
    final double scale = math.min(size.width / widthSpan, size.height / heightSpan);
    final double horizontalOffset = (size.width - widthSpan * scale) / 2;
    final double verticalOffset = (size.height - heightSpan * scale) / 2;

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = borderColor.withValues(alpha: 0.92);

    for (final List<_ProjectedPoint> polygon in polygons) {
      if (polygon.length < 3) {
        continue;
      }

      final ui.Path path = ui.Path();

      for (int index = 0; index < polygon.length; index++) {
        final _ProjectedPoint point = polygon[index];
        final double x = horizontalOffset + (point.x - bounds.minX) * scale;
        final double y = verticalOffset + (bounds.maxY - point.y) * scale;

        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    }
  }

  /// Utilise la même projection Web Mercator que flutter_map.
  ///
  /// Les pays nordiques conservent ainsi les proportions visibles sur la carte
  /// au lieu d'être aplatis par un simple dessin latitude/longitude.
  List<List<_ProjectedPoint>> _projectPolygons(
    List<List<LatLng>> polygons,
  ) {
    final double referenceLongitude = _referenceLongitude(polygons);

    return polygons.map((List<LatLng> polygon) {
      final List<double> unwrappedLongitudes = <double>[];
      double previousLongitude = referenceLongitude;

      for (final LatLng point in polygon) {
        final double longitude = _unwrapLongitude(
          point.longitude,
          previousLongitude,
        );
        unwrappedLongitudes.add(longitude);
        previousLongitude = longitude;
      }

      final double averageLongitude = unwrappedLongitudes.reduce(
            (double first, double second) => first + second,
          ) /
          unwrappedLongitudes.length;
      final double polygonShift =
          (((referenceLongitude - averageLongitude) / 360).round() * 360)
              .toDouble();

      return List<_ProjectedPoint>.generate(polygon.length, (int index) {
        final LatLng point = polygon[index];
        final double latitude = point.latitude
            .clamp(
              -_maximumMercatorLatitude,
              _maximumMercatorLatitude,
            )
            .toDouble();
        final double latitudeRadians = latitude * math.pi / 180;
        final double mercatorY =
            math.log(math.tan(math.pi / 4 + latitudeRadians / 2)) *
                180 /
                math.pi;

        return _ProjectedPoint(
          unwrappedLongitudes[index] + polygonShift,
          mercatorY,
        );
      }, growable: false);
    }).toList(growable: false);
  }

  double _referenceLongitude(List<List<LatLng>> polygons) {
    final List<LatLng> largestPolygon = polygons.reduce(
      (List<LatLng> first, List<LatLng> second) =>
          first.length >= second.length ? first : second,
    );

    double sineTotal = 0;
    double cosineTotal = 0;

    for (final LatLng point in largestPolygon) {
      final double radians = point.longitude * math.pi / 180;
      sineTotal += math.sin(radians);
      cosineTotal += math.cos(radians);
    }

    return math.atan2(sineTotal, cosineTotal) * 180 / math.pi;
  }

  double _unwrapLongitude(double longitude, double reference) {
    double result = longitude;

    while (result - reference > 180) {
      result -= 360;
    }

    while (result - reference < -180) {
      result += 360;
    }

    return result;
  }

  _ProjectedBounds _calculateBounds(
    List<List<_ProjectedPoint>> polygons,
  ) {
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final List<_ProjectedPoint> polygon in polygons) {
      for (final _ProjectedPoint point in polygon) {
        minX = math.min(minX, point.x);
        maxX = math.max(maxX, point.x);
        minY = math.min(minY, point.y);
        maxY = math.max(maxY, point.y);
      }
    }

    return _ProjectedBounds(minX, maxX, minY, maxY);
  }

  @override
  bool shouldRepaint(covariant _CountrySilhouettePainter oldDelegate) {
    return oldDelegate.country.id != country.id ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class _ProjectedPoint {
  const _ProjectedPoint(this.x, this.y);

  final double x;
  final double y;
}

class _ProjectedBounds {
  const _ProjectedBounds(this.minX, this.maxX, this.minY, this.maxY);

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  bool get isValid =>
      minX.isFinite &&
      maxX.isFinite &&
      minY.isFinite &&
      maxY.isFinite &&
      maxX > minX &&
      maxY > minY;
}
