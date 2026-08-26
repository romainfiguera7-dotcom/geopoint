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
    this.initialZoom = 1,
    this.showControls = true,
    this.showGrid = true,
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
  final double initialZoom;
  final bool showControls;
  final bool showGrid;

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
    _zoom = widget.initialZoom.clamp(1.0, widget.maximumZoom).toDouble();
  }

  void _zoomBy(double factor) {
    setState(() {
      _zoom = (_zoom * factor).clamp(1.0, widget.maximumZoom).toDouble();
    });
  }

  void _resetFromControl() {
    setState(_resetView);
  }

  double get _longitudeFactor {
    final double referenceLatitude =
        (widget.initialBounds.minLatitude +
                widget.initialBounds.maxLatitude) /
            2;
    return math
        .cos(referenceLatitude * math.pi / 180)
        .abs()
        .clamp(0.24, 1.0)
        .toDouble();
  }

  double _baseScale(Size size) {
    final double latitudeSpan = math.max(
      0.1,
      widget.initialBounds.maxLatitude - widget.initialBounds.minLatitude,
    );
    final double longitudeSpan = math.max(
      0.1,
      widget.initialBounds.maxLongitude - widget.initialBounds.minLongitude,
    ) *
        _longitudeFactor;
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
          (_startCenterLongitude -
                  movement.dx / (pixelsPerDegree * _longitudeFactor))
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
              (pixelsPerDegree * _longitudeFactor),
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
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onTapUp: _handleTap,
                  onDoubleTap: widget.interactive
                      ? () => _zoomBy(1.7)
                      : null,
                  child: CustomPaint(
                    size: size,
                    painter: _GeoVectorPainter(
                      centerLatitude: _centerLatitude,
                      centerLongitude: _centerLongitude,
                      pixelsPerDegree: _baseScale(size) * _zoom,
                      longitudeFactor: _longitudeFactor,
                      shapes: widget.shapes,
                      lines: widget.lines,
                      points: widget.points,
                      backgroundColor: widget.backgroundColor,
                      bounds: widget.initialBounds,
                      showGrid: widget.showGrid,
                    ),
                  ),
                ),
              ),
              if (widget.interactive && widget.showControls)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _MapControls(
                    onZoomIn: () => _zoomBy(1.5),
                    onZoomOut: () => _zoomBy(1 / 1.5),
                    onReset: _resetFromControl,
                  ),
                ),
            ],
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
    required this.longitudeFactor,
    required this.shapes,
    required this.lines,
    required this.points,
    required this.backgroundColor,
    required this.bounds,
    required this.showGrid,
  });

  final double centerLatitude;
  final double centerLongitude;
  final double pixelsPerDegree;
  final double longitudeFactor;
  final List<GeoVectorShape> shapes;
  final List<GeoVectorLine> lines;
  final List<GeoVectorPoint> points;
  final Color backgroundColor;
  final GeoVectorBounds bounds;
  final bool showGrid;

  Offset _project(LatLng point, Size size) {
    return Offset(
      size.width / 2 +
          (point.longitude - centerLongitude) *
              pixelsPerDegree *
              longitudeFactor,
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
    final Rect mapRect = Offset.zero & size;
    canvas.drawRect(
      mapRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          <Color>[
            Color.lerp(backgroundColor, const Color(0xFF031D3D), 0.48)!,
            backgroundColor,
            Color.lerp(backgroundColor, const Color(0xFF19A6C8), 0.20)!,
          ],
          const <double>[0, 0.56, 1],
        ),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (showGrid) {
      _paintGrid(canvas, size);
    }

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

  void _paintGrid(Canvas canvas, Size size) {
    final double longitudeSpan = bounds.maxLongitude - bounds.minLongitude;
    final double step = longitudeSpan > 100
        ? 30
        : longitudeSpan > 35
            ? 10
            : 2;
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final double firstLongitude = (bounds.minLongitude / step).floor() * step;
    for (double longitude = firstLongitude;
        longitude <= bounds.maxLongitude + step;
        longitude += step) {
      final Offset start = _project(LatLng(-85, longitude), size);
      final Offset end = _project(LatLng(85, longitude), size);
      canvas.drawLine(start, end, gridPaint);
    }
    final double firstLatitude = (bounds.minLatitude / step).floor() * step;
    for (double latitude = firstLatitude;
        latitude <= bounds.maxLatitude + step;
        latitude += step) {
      final Offset start = _project(LatLng(latitude, -180), size);
      final Offset end = _project(LatLng(latitude, 180), size);
      canvas.drawLine(start, end, gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GeoVectorPainter oldDelegate) => true;
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6071B3A),
      elevation: 5,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _MapControlButton(icon: Icons.add_rounded, onTap: onZoomIn),
          const SizedBox(width: 40, child: Divider(height: 1, color: Colors.white24)),
          _MapControlButton(icon: Icons.remove_rounded, onTap: onZoomOut),
          const SizedBox(width: 40, child: Divider(height: 1, color: Colors.white24)),
          _MapControlButton(icon: Icons.center_focus_strong_rounded, onTap: onReset),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
