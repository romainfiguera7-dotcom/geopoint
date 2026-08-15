import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../geo_engine/country_info.dart';
import '../../geo_engine/country_spatial_index.dart';
import '../../geo_engine/geo_country.dart';
import '../../geo_engine/geo_hit_test.dart';
import 'atlas_city.dart';

class AtlasMap extends StatefulWidget {
  const AtlasMap({
    required this.countries,
    required this.selectedCountryCities,
    required this.countryInfos,
    required this.selectedContinent,
    required this.selectedCountry,
    required this.onCountrySelected,
    required this.onCitySelected,
    super.key,
  });

  final List<GeoCountry> countries;
  final List<AtlasCity> selectedCountryCities;
  final Map<String, CountryInfo> countryInfos;
  final String selectedContinent;
  final GeoCountry? selectedCountry;
  final ValueChanged<GeoCountry> onCountrySelected;
  final ValueChanged<AtlasCity> onCitySelected;

  @override
  State<AtlasMap> createState() => AtlasMapState();
}

class AtlasMapState extends State<AtlasMap> {
  static const Color _oceanColor = Color(0xFF67B7D1);
  static const double _maximumLatitude = 85.05112878;
  static const CameraConstraint _worldConstraint =
      CameraConstraint.containLatitude(
    -_maximumLatitude,
    _maximumLatitude,
  );

  final MapController _mapController = MapController();

  late CountrySpatialIndex _spatialIndex;
  late Map<String, LatLng> _countryLabelPoints;
  late List<Polygon<Object>> _polygons;

  Timer? _cameraTimer;
  bool _mapReady = false;
  double _zoom = 2.0;
  LatLngBounds? _visibleBounds;

  @override
  void initState() {
    super.initState();
    _prepareCountryCaches();
  }

  @override
  void didUpdateWidget(covariant AtlasMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.countries, widget.countries)) {
      _prepareCountryCaches();
    } else if (oldWidget.selectedContinent != widget.selectedContinent ||
        oldWidget.selectedCountry?.id != widget.selectedCountry?.id) {
      _polygons = _buildPolygons();
    }
  }

  void _prepareCountryCaches() {
    _spatialIndex = CountrySpatialIndex(countries: widget.countries);
    _countryLabelPoints = <String, LatLng>{};

    for (final GeoCountry country in widget.countries) {
      _countryLabelPoints[country.id] = _mainPolygonCenter(country);
    }

    _polygons = _buildPolygons();
  }

  @override
  void dispose() {
    _cameraTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void resetView() {
    if (!_mapReady) {
      return;
    }

    _mapController.move(const LatLng(20, 0), 2.0);
  }

  void focusCountry(GeoCountry country) {
    if (!_mapReady) {
      return;
    }

    final _PolygonFrame frame = _mainPolygonFrame(country);
    final double span = math.max(frame.latitudeSpan, frame.longitudeSpan);

    final double targetZoom;

    if (span >= 55) {
      targetZoom = 2.3;
    } else if (span >= 25) {
      targetZoom = 3.0;
    } else if (span >= 12) {
      targetZoom = 3.7;
    } else if (span >= 5) {
      targetZoom = 4.5;
    } else if (span >= 1.5) {
      targetZoom = 5.3;
    } else {
      targetZoom = 6.1;
    }

    _mapController.move(frame.center, targetZoom);
  }

  void focusCity(AtlasCity city) {
    if (!_mapReady) {
      return;
    }

    _mapController.move(city.position, 6.0);
  }

  void _handleCameraChange(MapCamera camera, bool hasGesture) {
    _cameraTimer?.cancel();
    _cameraTimer = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _zoom = camera.zoom;
        _visibleBounds = camera.visibleBounds;
      });
    });
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    final AtlasCity? city = _findTappedCity(point);

    if (city != null) {
      widget.onCitySelected(city);
      return;
    }

    final GeoCountry? country = GeoHitTest.findCountry(
      point,
      _spatialIndex,
    );

    if (country == null || !_matchesContinent(country)) {
      return;
    }

    widget.onCountrySelected(country);
  }

  AtlasCity? _findTappedCity(LatLng point) {
    if (!_mapReady || widget.selectedCountry == null) {
      return null;
    }

    final MapCamera camera = _mapController.camera;
    final Offset tappedPixel = camera.projectAtZoom(point);
    AtlasCity? nearest;
    double nearestDistanceSquared = 24 * 24;

    for (final AtlasCity city in widget.selectedCountryCities) {
      if (city.population < _minimumVisibleCityPopulation) {
        break;
      }

      final Offset cityPixel = camera.projectAtZoom(city.position);
      final double distanceSquared =
          (cityPixel - tappedPixel).distanceSquared;

      if (distanceSquared <= nearestDistanceSquared) {
        nearest = city;
        nearestDistanceSquared = distanceSquared;
      }
    }

    return nearest;
  }

  bool _matchesContinent(GeoCountry country) {
    final String filter = _normalize(widget.selectedContinent);

    if (filter == 'tous') {
      return true;
    }

    final String continent = _normalize(country.continent);

    if (filter == 'ameriques') {
      return continent.contains('amerique du nord') ||
          continent.contains('amerique du sud') ||
          continent == 'north america' ||
          continent == 'south america';
    }

    return continent == filter;
  }

  bool _isVisible(LatLng point) {
    final LatLngBounds? bounds = _visibleBounds;
    return bounds == null || bounds.contains(point);
  }

  int get _minimumVisibleCityPopulation {
    if (_zoom < 3.0) {
      return 1000000;
    }

    if (_zoom < 3.7) {
      return 500000;
    }

    if (_zoom < 4.2) {
      return 250000;
    }

    return 100000;
  }

  bool _shouldShowCountryLabel(GeoCountry country) {
    if (widget.selectedCountry?.id == country.id) {
      return true;
    }

    final double? area =
        widget.countryInfos[country.id]?.areaSquareKilometers;

    if (_zoom < 2.7) {
      return area == null || area >= 200000;
    }

    if (_zoom < 3.4) {
      return area == null || area >= 30000;
    }

    return true;
  }

  List<Polygon<Object>> _buildPolygons() {
    final List<Polygon<Object>> polygons = <Polygon<Object>>[];

    for (final GeoCountry country in widget.countries) {
      final bool selected = widget.selectedCountry?.id == country.id;
      final bool included = _matchesContinent(country);
      final Color countryColor = selected
          ? const Color(0xFFFFD166)
          : included
              ? _colorForContinent(country.continent)
              : const Color(0xFF617084);

      for (final List<LatLng> points in country.polygons) {
        if (points.length < 3) {
          continue;
        }

        polygons.add(
          Polygon<Object>(
            points: points,
            color: countryColor.withValues(alpha: included ? 0.92 : 0.40),
            borderColor: selected
                ? const Color(0xFF7A4B00)
                : Colors.white.withValues(alpha: included ? 0.72 : 0.25),
            borderStrokeWidth: selected ? 2.3 : 0.65,
          ),
        );
      }
    }

    return polygons;
  }

  List<Marker> _buildCountryLabels() {
    final List<Marker> markers = <Marker>[];

    for (final GeoCountry country in widget.countries) {
      final LatLng? point = _countryLabelPoints[country.id];

      if (point == null ||
          !_matchesContinent(country) ||
          !_shouldShowCountryLabel(country) ||
          !_isVisible(point)) {
        continue;
      }

      final bool selected = widget.selectedCountry?.id == country.id;
      final String label =
          widget.countryInfos[country.id]?.title ?? country.name;
      final double width =
          (label.length * 7.0 + 18).clamp(48, 170).toDouble();

      markers.add(
        Marker(
          point: point,
          width: width,
          height: 28,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: selected
                    ? BoxDecoration(
                        color: const Color(0xFF071B3A)
                            .withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: selected
                        ? const Color(0xFFFFD166)
                        : const Color(0xFF071B3A),
                    fontSize: _zoom < 3 ? 9 : 10.5,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: selected
                        ? null
                        : const <Shadow>[
                            Shadow(color: Colors.white, blurRadius: 2),
                            Shadow(color: Colors.white, blurRadius: 5),
                          ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  List<CircleMarker<Object>> _buildCityDots() {
    if (widget.selectedCountry == null) {
      return const <CircleMarker<Object>>[];
    }

    final int minimumPopulation = _minimumVisibleCityPopulation;
    final List<CircleMarker<Object>> circles = <CircleMarker<Object>>[];

    for (final AtlasCity city in widget.selectedCountryCities) {
      if (city.population < minimumPopulation) {
        break;
      }

      if (!_isVisible(city.position)) {
        continue;
      }

      circles.add(
        CircleMarker<Object>(
          point: city.position,
          radius: city.isCapital ? 5 : 3.5,
          color: city.isCapital
              ? const Color(0xFFFFC857)
              : const Color(0xFF071B3A),
          borderColor: Colors.white,
          borderStrokeWidth: 1.2,
        ),
      );
    }

    return circles;
  }

  List<Marker> _buildCityLabels() {
    if (!_mapReady || widget.selectedCountry == null) {
      return const <Marker>[];
    }

    final int minimumPopulation = _minimumVisibleCityPopulation;
    final MapCamera camera = _mapController.camera;
    final List<AtlasCity> candidates = widget.selectedCountryCities
        .where((AtlasCity city) {
          return city.population >= minimumPopulation &&
              _isVisible(city.position);
        })
        .toList(growable: false);

    candidates.sort((AtlasCity first, AtlasCity second) {
      if (first.isCapital != second.isCapital) {
        return first.isCapital ? -1 : 1;
      }

      return second.population.compareTo(first.population);
    });

    final List<Rect> occupiedAreas = <Rect>[];
    final List<Marker> markers = <Marker>[];

    for (final AtlasCity city in candidates) {
      if (markers.length >= _maximumCityLabelCount) {
        break;
      }

      final double width =
          (city.name.length * 6.8 + 20).clamp(58, 155).toDouble();
      final Offset pixel = camera.projectAtZoom(city.position);
      final Rect labelArea = Rect.fromLTWH(
        pixel.dx + 7,
        pixel.dy - 13,
        width,
        26,
      ).inflate(4);

      if (occupiedAreas.any(labelArea.overlaps)) {
        continue;
      }

      occupiedAreas.add(labelArea);

      markers.add(
        Marker(
          point: city.position,
          width: width + 10,
          height: 26,
          alignment: Alignment.centerLeft,
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  city.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF071B3A),
                    fontSize: city.isCapital ? 10 : 9.5,
                    fontWeight:
                        city.isCapital ? FontWeight.w900 : FontWeight.w800,
                    shadows: const <Shadow>[
                      Shadow(color: Colors.white, blurRadius: 2),
                      Shadow(color: Colors.white, blurRadius: 5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  int get _maximumCityLabelCount {
    if (_zoom < 5) {
      return 12;
    }

    if (_zoom < 6) {
      return 20;
    }

    if (_zoom < 7) {
      return 32;
    }

    return 48;
  }

  @override
  Widget build(BuildContext context) {
    final List<Marker> countryLabels = _buildCountryLabels();
    final List<CircleMarker<Object>> cityDots = _buildCityDots();
    final List<Marker> cityLabels = _buildCityLabels();

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ColoredBox(
            color: _oceanColor,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(20, 0),
                initialZoom: 2.0,
                minZoom: 2.0,
                maxZoom: 8.0,
                backgroundColor: _oceanColor,
                cameraConstraint: _worldConstraint,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.scrollWheelZoom,
                ),
                onMapReady: () {
                  _mapReady = true;
                  setState(() {
                    _zoom = _mapController.camera.zoom;
                    _visibleBounds = _mapController.camera.visibleBounds;
                  });
                },
                onPositionChanged: _handleCameraChange,
                onTap: _handleMapTap,
              ),
              children: <Widget>[
                PolygonLayer<Object>(polygons: _polygons),
                MarkerLayer(markers: countryLabels),
                CircleLayer<Object>(circles: cityDots),
                MarkerLayer(markers: cityLabels),
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF071B3A).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              widget.selectedCountry == null
                  ? 'Touchez un pays pour afficher ses villes'
                  : '${widget.selectedCountryCities.length} villes • '
                      'touchez un point • ≥ ${_populationThresholdLabel()}',
              style: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _populationThresholdLabel() {
    final int value = _minimumVisibleCityPopulation;

    if (value >= 1000000) {
      return '${value ~/ 1000000} M';
    }

    return '${value ~/ 1000} 000 hab.';
  }

  static Color _colorForContinent(String continent) {
    final String value = _normalize(continent);

    if (value.contains('afrique') || value == 'africa') {
      return const Color(0xFFF2A65A);
    }

    if (value.contains('asie') || value == 'asia') {
      return const Color(0xFFE66A6A);
    }

    if (value.contains('amerique') || value.contains('america')) {
      return const Color(0xFF55C99A);
    }

    if (value.contains('oceanie') || value == 'oceania') {
      return const Color(0xFFA989E8);
    }

    if (value.contains('antarct')) {
      return const Color(0xFFDCEFF7);
    }

    return const Color(0xFF69A7F2);
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }

  static LatLng _mainPolygonCenter(GeoCountry country) {
    return _mainPolygonFrame(country).center;
  }

  static _PolygonFrame _mainPolygonFrame(GeoCountry country) {
    if (country.polygons.isEmpty) {
      return const _PolygonFrame(
        center: LatLng(0, 0),
        latitudeSpan: 0,
        longitudeSpan: 0,
      );
    }

    List<LatLng> mainPolygon = country.polygons.first;
    double largestArea = -1;

    for (final List<LatLng> polygon in country.polygons) {
      final double area = _polygonArea(polygon);

      if (area > largestArea) {
        largestArea = area;
        mainPolygon = polygon;
      }
    }

    double minLatitude = 90;
    double maxLatitude = -90;
    double minLongitude = 180;
    double maxLongitude = -180;

    for (final LatLng point in mainPolygon) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
    }

    return _PolygonFrame(
      center: LatLng(
        (minLatitude + maxLatitude) / 2,
        (minLongitude + maxLongitude) / 2,
      ),
      latitudeSpan: maxLatitude - minLatitude,
      longitudeSpan: maxLongitude - minLongitude,
    );
  }

  static double _polygonArea(List<LatLng> polygon) {
    if (polygon.length < 3) {
      return 0;
    }

    double area = 0;

    for (int index = 0; index < polygon.length; index++) {
      final LatLng current = polygon[index];
      final LatLng next = polygon[(index + 1) % polygon.length];
      area += current.longitude * next.latitude;
      area -= next.longitude * current.latitude;
    }

    return area.abs() / 2;
  }
}

class _PolygonFrame {
  const _PolygonFrame({
    required this.center,
    required this.latitudeSpan,
    required this.longitudeSpan,
  });

  final LatLng center;
  final double latitudeSpan;
  final double longitudeSpan;
}
