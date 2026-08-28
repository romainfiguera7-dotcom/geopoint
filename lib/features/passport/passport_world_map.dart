import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../geo_engine/geo_country.dart';
import '../../passport/progress/passport_entity_progress.dart';
import '../../passport/progress/passport_progress_rules.dart';
import '../../passport/progress/passport_progress_v2.dart';

enum PassportWorldMapMode {
  knowledge,
  travel,
}

class PassportWorldMap extends StatelessWidget {
  const PassportWorldMap({
    required this.countries,
    required this.progress,
    required this.mode,
    super.key,
  });

  static const double _maximumLatitude = 85.05112878;
  static const Color _oceanColor = Color(0xFF75C7E3);
  static const CameraConstraint _worldConstraint =
      CameraConstraint.containLatitude(
    -_maximumLatitude,
    _maximumLatitude,
  );

  final List<GeoCountry> countries;
  final PassportProgressV2 progress;
  final PassportWorldMapMode mode;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ColoredBox(
        color: _oceanColor,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double shortestSide = math.min(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final double fittedZoom =
                (math.log(shortestSide / 256) / math.ln2 - 0.08)
                    .clamp(0.05, 1.8)
                    .toDouble();
            final double minimumZoom =
                (fittedZoom - 0.20).clamp(0, fittedZoom).toDouble();

            return FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(5, 0),
                initialZoom: fittedZoom,
                minZoom: minimumZoom,
                maxZoom: 6,
                backgroundColor: _oceanColor,
                cameraConstraint: _worldConstraint,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.scrollWheelZoom,
                ),
              ),
              children: <Widget>[
                PolygonLayer<Object>(
                  polygons: _buildPolygons(),
                  useAltRendering: true,
                  polygonCulling: true,
                  polygonLabels: false,
                  drawInSingleWorld: true,
                  simplificationTolerance: 0.62,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Polygon<Object>> _buildPolygons() {
    final List<Polygon<Object>> polygons = <Polygon<Object>>[];

    for (final GeoCountry country in countries) {
      final PassportEntityProgress entityProgress =
          progress.progressFor(country.id);
      final Color color = mode == PassportWorldMapMode.knowledge
          ? _knowledgeColor(entityProgress)
          : _travelColor(entityProgress);
      final Color borderColor = _borderColor(entityProgress);
      final double borderWidth = _borderWidth(entityProgress);

      for (final List<LatLng> points in country.polygons) {
        if (points.length < 3) {
          continue;
        }

        polygons.add(
          Polygon<Object>(
            points: points,
            color: color,
            borderColor: borderColor,
            borderStrokeWidth: borderWidth,
          ),
        );
      }
    }

    return polygons;
  }

  Color _knowledgeColor(PassportEntityProgress entityProgress) {
    switch (entityProgress.learningState) {
      case PassportLearningState.undiscovered:
        return const Color(0xFFAAB8C8);
      case PassportLearningState.discovered:
        return const Color(0xFF6FC6F2);
      case PassportLearningState.learning:
        return const Color(0xFFA985F8);
      case PassportLearningState.mastered:
        return const Color(0xFF55D6A6);
    }
  }

  Color _travelColor(PassportEntityProgress entityProgress) {
    if (entityProgress.isFavorite) {
      return const Color(0xFFFFCE59);
    }

    if (entityProgress.isVisited) {
      return const Color(0xFF55D6A6);
    }

    if (entityProgress.isWishlisted) {
      return const Color(0xFFFF756B);
    }

    return const Color(0xFFD1D9E3);
  }

  Color _borderColor(PassportEntityProgress entityProgress) {
    if (mode == PassportWorldMapMode.travel && entityProgress.isFavorite) {
      return const Color(0xFF9A6A00);
    }

    if (mode == PassportWorldMapMode.travel && entityProgress.isVisited) {
      return const Color(0xFF087A59);
    }

    if (mode == PassportWorldMapMode.travel && entityProgress.isWishlisted) {
      return const Color(0xFFA82F3B);
    }

    return Colors.white.withValues(alpha: 0.72);
  }

  double _borderWidth(PassportEntityProgress entityProgress) {
    if (mode == PassportWorldMapMode.travel &&
        (entityProgress.isFavorite ||
            entityProgress.isVisited ||
            entityProgress.isWishlisted)) {
      return 1.25;
    }

    return 0.55;
  }
}
