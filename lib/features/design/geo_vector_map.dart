import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class GeoVectorBounds {
  const GeoVectorBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;
}

class GeoVectorShape {
  const GeoVectorShape({
    required this.id,
    required this.polygons,
    required this.fillColor,
    required this.borderColor,
    this.borderWidth = 0.8,
  });

  final String id;
  final List<List<LatLng>> polygons;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
}

class GeoVectorLine {
  const GeoVectorLine({
    required this.points,
    required this.color,
    this.width = 3,
  });

  final List<LatLng> points;
  final Color color;
  final double width;
}

class GeoVectorPoint {
  const GeoVectorPoint({
    required this.position,
    required this.color,
    this.radius = 7,
    this.label,
  });

  final LatLng position;
  final Color color;
  final double radius;
  final String? label;
}

/// Carte vectorielle autonome destinée aux quiz tactiles.
///
/// Elle ne possède ni contrôleur externe, ni animation différée, ni couche de
/// rendu appartenant à `flutter_map`. Le déplacement et le zoom sont calculés
/// directement à partir du geste, ce qui la rend indépendante des cartes du
/// jeu et de l’Atlas.
class GeoVectorMap extends StatefulWidget {
  const GeoVectorMap({
    required this.viewId,
    required this.initialBounds,
    required this.shapes,
    required this.backgroundColor,
    this.lines = const <GeoVectorLine>[],
    this.points = const <GeoVectorPoint>[],
    this.onShapeTap,
    this.onPositionTap,
    this.interactive = true,
    this.maximumZoom = 12,
    super.key,
  });

  final String viewId;
  final GeoVectorBounds initialBounds;
  final List<GeoVectorShape> shapes;
  final List<GeoVectorLine> lines;
  final List<GeoVectorPoint> points;
  final Color backgroundColor;
  final ValueChanged<String?>? onShapeTap;
  final ValueChanged<LatLng>? onPositionTap;
  final bool interactive;
  final double maximumZoom;

  @override
  State<GeoVectorMap> createState() => _GeoVectorMapState();
}

class _GeoVectorMapState extends State<GeoVectorMap> {
  late double _centerLatitude;
  late double _centerLongitude;
  double _zoom = 1;

  double _startCenterLatitude = 0;
  double _startCenterLongitude = 0;
  double _startZoom = 1;
  Offset _startFocalPoint = Offset.zero;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _resetView();
  }

  @override
  void didUpdateWidget(covariant GeoVectorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewId != widget.viewId) {
      _resetView();
    }
  }

  void _resetView() {
    _centerLatitude =
        (widget.initialBounds.minLatitude + widget.initialBounds.maxLatitude) /
            2;
    _centerLongitude =
        (widget.initialBounds.minLongitude + widget.initialBounds.maxLongitude) /
            2;
    _zoom = 1;
  }

  double _baseScale(Size size) {
    final double latitudeSpan = math.max(
      0.1,
      widget.initialBounds.maxLatitude - widget.initialBounds.minLatitude,
    );
    final double longitudeSpan = math.max(
      0.1,
      widget.initialBounds.maxLongitude - widget.initialBounds.minLongitude,
    );
    return math.min(
          size.width / longitudeSpan,
          size.height / latitudeSpan,
        ) *
        0.92;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (!widget.interactive) {
      return;
    }
    _startCenterLatitude = _centerLatitude;
    _startCenterLongitude = _centerLongitude;
    _startZoom = _zoom;
    _startFocalPoint = details.localFocalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.interactive || _lastSize.isEmpty) {
      return;
    }
    final double nextZoom = (_startZoom * details.scale)
        .clamp(1.0, widget.maximumZoom)
        .toDouble();
    final double pixelsPerDegree = _baseScale(_lastSize) * nextZoom;
    final Offset movement = details.localFocalPoint - _startFocalPoint;
    setState(() {
      _zoom = nextZoom;
      _centerLongitude =
          (_startCenterLongitude - movement.dx / pixelsPerDegree)
              .clamp(-180.0, 180.0)
              .toDouble();
      _centerLatitude =
          (_startCenterLatitude + movement.dy / pixelsPerDegree)
              .clamp(-85.0, 85.0)
              .toDouble();
    });
  }

  void _handleTap(TapUpDetails details) {
    if (!widget.interactive || _lastSize.isEmpty) {
      return;
    }
    final double pixelsPerDegree = _baseScale(_lastSize) * _zoom;
    final LatLng position = LatLng(
      _centerLatitude -
          (details.localPosition.dy - _lastSize.height / 2) /
              pixelsPerDegree,
      _centerLongitude +
          (details.localPosition.dx - _lastSize.width / 2) /
              pixelsPerDegree,
    );
    widget.onPositionTap?.call(position);
    widget.onShapeTap?.call(_shapeAt(position));
  }

  String? _shapeAt(LatLng position) {
    String? selectedId;
    double selectedArea = double.infinity;
    for (final GeoVectorShape shape in widget.shapes) {
      for (final List<LatLng> polygon in shape.polygons) {
        if (polygon.length < 3 || !_contains(polygon, position)) {
          continue;
        }
        double minLatitude = 90;
        double maxLatitude = -90;
        double minLongitude = 180;
        double maxLongitude = -180;
        for (final LatLng point in polygon) {
          minLatitude = math.min(minLatitude, point.latitude);
          maxLatitude = math.max(maxLatitude, point.latitude);
          minLongitude = math.min(minLongitude, point.longitude);
          maxLongitude = math.max(maxLongitude, point.longitude);
        }
        final double area =
            (maxLatitude - minLatitude) * (maxLongitude - minLongitude);
        if (area < selectedArea) {
          selectedArea = area;
          selectedId = shape.id;
        }
      }
    }
    return selectedId;
  }

  bool _contains(List<LatLng> polygon, LatLng position) {
    bool inside = false;
    for (int index = 0, previous = polygon.length - 1;
        index < polygon.length;
        previous = index++) {
      final LatLng first = polygon[index];
      final LatLng second = polygon[previous];
      final bool crosses =
          (first.latitude > position.latitude) !=
                  (second.latitude > position.latitude) &&
              position.longitude <
                  (second.longitude - first.longitude) *
                              (position.latitude - first.latitude) /
                              (second.latitude - first.latitude) +
                          first.longitude;
      if (crosses) {
        inside = !inside;
      }
    }
    return inside;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size screenSize = MediaQuery.sizeOf(context);
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenSize.width;
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screenSize.height;
        final Size size = Size(
          math.max(1.0, width),
          math.max(1.0, height),
        );
        _lastSize = size;
        return RepaintBoundary(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onTapUp: _handleTap,
            onDoubleTap: widget.interactive
                ? () {
                    setState(() {
                      _zoom = (_zoom * 1.7)
                          .clamp(1.0, widget.maximumZoom)
                          .toDouble();
                    });
                  }
                : null,
            child: CustomPaint(
              size: size,
              painter: _GeoVectorPainter(
                centerLatitude: _centerLatitude,
                centerLongitude: _centerLongitude,
                pixelsPerDegree: _baseScale(size) * _zoom,
                shapes: widget.shapes,
                lines: widget.lines,
                points: widget.points,
                backgroundColor: widget.backgroundColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GeoVectorPainter extends CustomPainter {
  const _GeoVectorPainter({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.pixelsPerDegree,
    required this.shapes,
    required this.lines,
    required this.points,
    required this.backgroundColor,
  });

  final double centerLatitude;
  final double centerLongitude;
  final double pixelsPerDegree;
  final List<GeoVectorShape> shapes;
  final List<GeoVectorLine> lines;
  final List<GeoVectorPoint> points;
  final Color backgroundColor;

  Offset _project(LatLng point, Size size) {
    return Offset(
      size.width / 2 +
          (point.longitude - centerLongitude) * pixelsPerDegree,
      size.height / 2 -
          (point.latitude - centerLatitude) * pixelsPerDegree,
    );
  }

  ui.Path _path(List<LatLng> polygon, Size size) {
    final ui.Path path = ui.Path();
    if (polygon.isEmpty) {
      return path;
    }
    final int step = math.max(1, (polygon.length / 280).floor());
    path.moveTo(_project(polygon.first, size).dx, _project(polygon.first, size).dy);
    for (int index = step; index < polygon.length; index += step) {
      final Offset point = _project(polygon[index], size);
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (final GeoVectorShape shape in shapes) {
      for (final List<LatLng> polygon in shape.polygons) {
        if (polygon.length < 3) {
          continue;
        }
        final ui.Path path = _path(polygon, size);
        canvas.drawPath(path, Paint()..color = shape.fillColor);
        canvas.drawPath(
          path,
          Paint()
            ..color = shape.borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = shape.borderWidth,
        );
      }
    }

    for (final GeoVectorLine line in lines) {
      if (line.points.length < 2) {
        continue;
      }
      final ui.Path path = ui.Path();
      final Offset first = _project(line.points.first, size);
      path.moveTo(first.dx, first.dy);
      for (final LatLng coordinate in line.points.skip(1)) {
        final Offset point = _project(coordinate, size);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line.color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = line.width,
      );
    }

    for (final GeoVectorPoint point in points) {
      final Offset projected = _project(point.position, size);
      canvas.drawCircle(
        projected,
        point.radius + 2,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(projected, point.radius, Paint()..color = point.color);
      final String? label = point.label;
      if (label != null && label.isNotEmpty) {
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: 170);
        final Rect background = Rect.fromLTWH(
          projected.dx - textPainter.width / 2 - 5,
          projected.dy - point.radius - textPainter.height - 9,
          textPainter.width + 10,
          textPainter.height + 5,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(background, const Radius.circular(7)),
          Paint()..color = const Color(0xE6071B3A),
        );
        textPainter.paint(
          canvas,
          Offset(background.left + 5, background.top + 2),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GeoVectorPainter oldDelegate) => true;
}
