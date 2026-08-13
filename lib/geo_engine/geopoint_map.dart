import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'country_spatial_index.dart';
import 'geo_country.dart';
import 'geo_hit_test.dart';
import 'geojson_loader.dart';

class GeoPointMap extends StatefulWidget {
  const GeoPointMap({
    super.key,
    this.answerPoint,
    this.answerCountry,
    this.preferProvidedAnswerCountry = false,
    this.resultRadiusInKilometers,
    this.resultPanelCollapsed = false,
    this.onTap,
    this.onCountrySelected,
    this.showInformationPanel = true,
    this.allowInteraction = true,
    this.initialCenter =
        const LatLng(20, 0),
    this.initialZoom = 2.2,
    this.maximumZoom = 12.0,
  });

  final LatLng? answerPoint;
  final GeoCountry? answerCountry;

  /// Force l'utilisation du pays fourni comme bonne réponse.
  ///
  /// Cette option est utile lorsqu'un point représentatif peut aussi tomber
  /// dans le contour d'une autre entité, par exemple pour un pays enclavé ou
  /// un territoire superposé. Le comportement historique reste inchangé par
  /// défaut pour les modes de localisation.
  final bool preferProvidedAnswerCountry;

  final double? resultRadiusInKilometers;

  /// Indique que la fiche de résultat est repliée.
  ///
  /// La caméra réserve alors moins de place en bas
  /// afin de montrer davantage la carte.
  final bool resultPanelCollapsed;

  final ValueChanged<LatLng>? onTap;
  final ValueChanged<GeoCountry?>? onCountrySelected;

  final bool showInformationPanel;

  /// Autorise la sélection d’une réponse par toucher.
  ///
  /// Le déplacement et le zoom restent disponibles
  /// lorsque cette valeur est fausse, ce qui permet
  /// d’explorer la carte après la validation.
  final bool allowInteraction;
  final LatLng initialCenter;
  final double initialZoom;

  /// Zoom maximal autorise pendant la recherche.
  ///
  /// Il depend du mode et de la difficulte afin de
  /// conserver un deplacement manuel agreable sans
  /// rendre les grands pays inutilement faciles.
  final double maximumZoom;

  @override
  State<GeoPointMap> createState() {
    return _GeoPointMapState();
  }
}

class _GeoPointMapState extends State<GeoPointMap>
    with SingleTickerProviderStateMixin {
  static const Color _oceanColor =
      Color(0xFF67B7D1);

  static const Color _selectedCountryColor =
      Color(0xFFE94B3C);

  static const Color _selectedCountryBorderColor =
      Color(0xFF8F1710);

  static const Color _answerCountryColor =
      Color(0xFF63E276);

  static const Color _answerCountryBorderColor =
      Color(0xFF056F27);

  static const double _maximumLatitude =
      85.05112878;

  /*
   * À un zoom inférieur à 2, la hauteur du monde
   * devient plus petite que celle d'un écran de
   * téléphone en mode portrait. Il est alors
   * impossible d'empêcher l'affichage de vide au-delà
   * des pôles, quelle que soit la contrainte utilisée.
   */
  static const double _minimumMapZoom =
      2.0;

  static const double _absoluteMaximumMapZoom =
      12.0;

  /*
   * Le cadrage du resultat reserve beaucoup de place
   * au panneau situe en bas de l'ecran. Il peut donc
   * decaler les bords visibles au-dela des latitudes
   * du monde, meme lorsque le centre reste valide.
   *
   * Cette contrainte limite les bords nord et sud de
   * la camera, sans bloquer le defilement horizontal
   * continu autour du monde.
   */
  static const CameraConstraint
      _worldLatitudeConstraint =
      CameraConstraint.containLatitude(
    -_maximumLatitude,
    _maximumLatitude,
  );

  static const Duration _cameraAnimationDuration =
      Duration(milliseconds: 850);

  static const int _maximumCameraPolygonPoints =
      140;

  final MapController _mapController =
      MapController();

  late final AnimationController
      _cameraAnimationController;

  late final Future<List<GeoCountry>>
      _countriesFuture;

  CountrySpatialIndex? _spatialIndex;

  GeoCountry? _selectedCountry;
  GeoCountry? _resolvedAnswerCountry;

  LatLng? _selectedPoint;

  int? _candidateCount;

  bool _mapIsReady = false;
  bool _cameraFitScheduled = false;

  Animation<double>? _latitudeAnimation;
  Animation<double>? _longitudeAnimation;
  Animation<double>? _zoomAnimation;

  LatLng? _finalCameraCenter;
  double? _finalCameraZoom;
  String _cameraAnimationId =
      'geopoint-camera-animation';

  bool get _isAnswerRevealed {
    return widget.answerPoint != null;
  }

  double get _effectiveMaximumMapZoom {
    /*
     * Apres la validation, le joueur peut de nouveau
     * zoomer librement pour explorer le territoire et
     * profiter de la fiche pedagogique.
     */
    if (_isAnswerRevealed) {
      return _absoluteMaximumMapZoom;
    }

    return widget.maximumZoom.clamp(
      _minimumMapZoom,
      _absoluteMaximumMapZoom,
    ).toDouble();
  }

  double get _safeInitialZoom {
    return widget.initialZoom.clamp(
      _minimumMapZoom,
      _effectiveMaximumMapZoom,
    ).toDouble();
  }

  GeoCountry? get _effectiveAnswerCountry {
    return _resolvedAnswerCountry ??
        widget.answerCountry;
  }

  @override
  void initState() {
    super.initState();

    _cameraAnimationController =
        AnimationController(
      vsync: this,
      duration: _cameraAnimationDuration,
    );

    _cameraAnimationController.addListener(
      _handleCameraAnimation,
    );

    _cameraAnimationController.addStatusListener(
      _handleCameraAnimationStatus,
    );

    _countriesFuture = _loadCountries();
  }

  @override
  void didUpdateWidget(
    covariant GeoPointMap oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final bool answerHasJustAppeared =
        oldWidget.answerPoint == null &&
            widget.answerPoint != null;

    final bool answerHasJustDisappeared =
        oldWidget.answerPoint != null &&
            widget.answerPoint == null;

    final bool answerPointChanged =
        !_samePoint(
      oldWidget.answerPoint,
      widget.answerPoint,
    );

    final bool answerCountryChanged =
        !_sameCountry(
      oldWidget.answerCountry,
      widget.answerCountry,
    );

    final bool initialCenterChanged =
        !_samePoint(
      oldWidget.initialCenter,
      widget.initialCenter,
    );

    final bool initialZoomChanged =
        oldWidget.initialZoom !=
            widget.initialZoom;

    final bool resultPanelStateChanged =
        oldWidget.resultPanelCollapsed !=
            widget.resultPanelCollapsed;

    final bool newQuestionIsDisplayed =
        widget.answerPoint == null &&
            (
              answerHasJustDisappeared ||
                  initialCenterChanged ||
                  initialZoomChanged
            );

    if (newQuestionIsDisplayed) {
      _resetQuestionView();

      /*
       * Le retour au cadrage de depart est immediat.
       * Cela evite que la camera conserve quelques
       * instants le zoom de la reponse precedente et
       * garantit qu'elle respecte le nouveau zoom
       * maximal avant la reconstruction de FlutterMap.
       */
      if (_mapIsReady) {
        _mapController.move(
          widget.initialCenter,
          _safeInitialZoom,
          id: 'geopoint-question-reset',
        );
      }
    }

    if (widget.answerPoint != null &&
        (
          answerHasJustAppeared ||
              answerPointChanged ||
              answerCountryChanged ||
              resultPanelStateChanged
        )) {
      _resolveAnswerCountry();
      _scheduleCameraFit();
    }
  }

  void _resetQuestionView() {
    /*
     * Une nouvelle question doit repartir d'une
     * carte totalement propre. Sans cette remise à
     * zéro, le marqueur, le pays choisi et la fin de
     * l'animation précédente peuvent rester visibles
     * lorsque deux pays successifs sont proches.
     */
    _cameraAnimationController.stop();

    _cameraFitScheduled = false;

    _latitudeAnimation = null;
    _longitudeAnimation = null;
    _zoomAnimation = null;

    _finalCameraCenter = null;
    _finalCameraZoom = null;

    _selectedPoint = null;
    _selectedCountry = null;
    _resolvedAnswerCountry = null;
    _candidateCount = null;
  }

  @override
  void dispose() {
    _mapIsReady = false;

    _cameraAnimationController.removeListener(
      _handleCameraAnimation,
    );

    _cameraAnimationController
        .removeStatusListener(
      _handleCameraAnimationStatus,
    );

    _cameraAnimationController.dispose();
    _mapController.dispose();

    super.dispose();
  }

  Future<List<GeoCountry>> _loadCountries() async {
    final List<GeoCountry> countries =
        await GeoJsonLoader.loadCountries();

    _spatialIndex = CountrySpatialIndex(
      countries: countries,
    );

    _resolveAnswerCountry();

    return countries;
  }

  void _handleMapTap(
    TapPosition tapPosition,
    LatLng point,
  ) {
    if (!widget.allowInteraction) {
      return;
    }

    final CountrySpatialIndex? spatialIndex =
        _spatialIndex;

    if (spatialIndex == null) {
      return;
    }

    _cameraAnimationController.stop();

    final int candidateCount =
        spatialIndex.candidateCountAt(point);

    final GeoCountry? country =
        GeoHitTest.findCountry(
      point,
      spatialIndex,
    );

    debugPrint(
      'GeoPoint : '
      '${point.latitude.toStringAsFixed(4)}, '
      '${point.longitude.toStringAsFixed(4)} '
      '→ $candidateCount pays candidats',
    );

    setState(() {
      _selectedPoint = point;
      _selectedCountry = country;
      _candidateCount = candidateCount;
    });

    widget.onTap?.call(point);
    widget.onCountrySelected?.call(country);
  }

  void _resolveAnswerCountry() {
    final LatLng? answerPoint =
        widget.answerPoint;

    if (widget.preferProvidedAnswerCountry &&
        widget.answerCountry != null) {
      _resolvedAnswerCountry = widget.answerCountry;
      return;
    }

    final CountrySpatialIndex? spatialIndex =
        _spatialIndex;

    if (answerPoint == null ||
        spatialIndex == null) {
      _resolvedAnswerCountry = null;
      return;
    }

    final GeoCountry? countryFromPoint =
        GeoHitTest.findCountry(
      answerPoint,
      spatialIndex,
    );

    if (countryFromPoint != null) {
      _resolvedAnswerCountry =
          countryFromPoint;

      debugPrint(
        'GeoPoint : pays de réponse résolu '
        'avec la position → '
        '${countryFromPoint.name}',
      );

      return;
    }

    _resolvedAnswerCountry =
        widget.answerCountry;

    debugPrint(
      'GeoPoint : pays de réponse résolu '
      'avec les identifiants → '
      '${_resolvedAnswerCountry?.name ?? 'introuvable'}',
    );
  }

  bool _samePoint(
    LatLng? first,
    LatLng? second,
  ) {
    if (first == null && second == null) {
      return true;
    }

    if (first == null || second == null) {
      return false;
    }

    return first.latitude ==
            second.latitude &&
        first.longitude ==
            second.longitude;
  }

  bool _sameCountry(
    GeoCountry? first,
    GeoCountry? second,
  ) {
    if (first == null || second == null) {
      return false;
    }

    final String firstId =
        first.id.trim().toUpperCase();

    final String secondId =
        second.id.trim().toUpperCase();

    if (firstId.isNotEmpty &&
        secondId.isNotEmpty &&
        firstId == secondId) {
      return true;
    }

    final String firstIsoA2 =
        first.isoA2.trim().toUpperCase();

    final String secondIsoA2 =
        second.isoA2.trim().toUpperCase();

    if (firstIsoA2.isNotEmpty &&
        secondIsoA2.isNotEmpty &&
        firstIsoA2 == secondIsoA2) {
      return true;
    }

    final String firstName =
        _normalizeCountryName(
      first.name,
    );

    final String secondName =
        _normalizeCountryName(
      second.name,
    );

    return firstName.isNotEmpty &&
        firstName == secondName;
  }

  String _normalizeCountryName(
    String value,
  ) {
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
        .replaceAll('ç', 'c')
        .replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '',
        );
  }

  void _scheduleCameraFit() {
    if (_cameraFitScheduled) {
      return;
    }

    _cameraFitScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _cameraFitScheduled = false;

        if (!mounted) {
          return;
        }

        _animateCameraToResult();
      },
    );
  }

  void _animateCameraToResult() {
    if (!_mapIsReady) {
      return;
    }

    final LatLng? answerPoint =
        widget.answerPoint;

    if (answerPoint == null) {
      return;
    }

    final LatLng? selectedPoint =
        _selectedPoint;

    final List<LatLng> cameraPoints =
        <LatLng>[];

    final double? resultRadiusInKilometers =
        widget.resultRadiusInKilometers;

    final bool hasCircularResultZone =
        resultRadiusInKilometers != null &&
            resultRadiusInKilometers > 0;

    /*
     * Pays choisi :
     * on conserve uniquement le territoire entourant
     * exactement le clic du joueur.
     */
    if (!hasCircularResultZone) {
      cameraPoints.addAll(
        _cameraPointsForCountry(
          country: _selectedCountry,
          referencePoint: selectedPoint,
        ),
      );
    }

    /*
     * Bonne réponse :
     * on conserve uniquement le territoire entourant
     * la capitale ou le point de réponse.
     */
    if (!hasCircularResultZone) {
      cameraPoints.addAll(
        _cameraPointsForCountry(
          country: _effectiveAnswerCountry,
          referencePoint: answerPoint,
        ),
      );
    }

    if (selectedPoint != null) {
      cameraPoints.add(
        selectedPoint,
      );
    }

    cameraPoints.add(
      answerPoint,
    );

    if (hasCircularResultZone) {
      cameraPoints.addAll(
        _areaAroundResultRadius(
          answerPoint,
          resultRadiusInKilometers,
        ),
      );
    }

    /*
     * Clic dans l’océan ou pays introuvable :
     * les deux marqueurs restent malgré tout cadrés.
     */
    if (cameraPoints.length < 2) {
      if (selectedPoint != null) {
        cameraPoints.add(
          selectedPoint,
        );
      }

      cameraPoints.add(
        answerPoint,
      );
    }

    /*
     * Si les deux positions sont proches ou si le
     * territoire est minuscule, on crée une petite
     * zone minimale autour de la réponse.
     */
    if (selectedPoint == null ||
        _pointsAreVeryClose(
          selectedPoint,
          answerPoint,
        ) ||
        _cameraBoundsAreVerySmall(
          cameraPoints,
        )) {
      cameraPoints.addAll(
        _minimumAreaAround(
          answerPoint,
        ),
      );
    }

    final LatLngBounds bounds =
        LatLngBounds.fromPoints(
      cameraPoints,
    );

    final Size screenSize =
        MediaQuery.sizeOf(context);

    final double bottomPadding =
        widget.resultPanelCollapsed
            ? (screenSize.height * 0.18)
                .clamp(
                  125.0,
                  170.0,
                )
                .toDouble()
            : (screenSize.height * 0.42)
                .clamp(
                  260.0,
                  380.0,
                )
                .toDouble();

    final double topPadding =
        (screenSize.height * 0.10)
            .clamp(
              85.0,
              120.0,
            )
            .toDouble();

    final CameraFit cameraFit =
        CameraFit.bounds(
      bounds: bounds,
      padding: EdgeInsets.fromLTRB(
        42,
        topPadding,
        42,
        bottomPadding,
      ),
      maxZoom: 7.4,
      minZoom: _minimumMapZoom,
    );

    try {
      final MapCamera targetCamera =
          cameraFit.fit(
        _mapController.camera,
      );

      _startCameraAnimation(
        targetCenter:
            targetCamera.center,
        targetZoom:
            targetCamera.zoom,
        animationId:
            'geopoint-result-animation',
      );
    } catch (error) {
      debugPrint(
        'Impossible d’animer la caméra : '
        '$error',
      );
    }
  }

  void _startCameraAnimation({
    required LatLng targetCenter,
    required double targetZoom,
    required String animationId,
  }) {
    if (!_mapIsReady) {
      return;
    }

    final MapCamera startCamera =
        _mapController.camera;

    final double safeTargetZoom =
        targetZoom.clamp(
      _minimumMapZoom,
      _effectiveMaximumMapZoom,
    ).toDouble();

    final LatLng startCenter =
        startCamera.center;

    final double animatedTargetLongitude =
        _nearestLongitude(
      startCenter.longitude,
      targetCenter.longitude,
    );

    final Animation<double> curvedAnimation =
        _cameraAnimationController.drive(
      CurveTween(
        curve: Curves.easeInOutCubic,
      ),
    );

    _latitudeAnimation =
        Tween<double>(
      begin: startCenter.latitude,
      end: targetCenter.latitude,
    ).animate(
      curvedAnimation,
    );

    _longitudeAnimation =
        Tween<double>(
      begin: startCenter.longitude,
      end: animatedTargetLongitude,
    ).animate(
      curvedAnimation,
    );

    _zoomAnimation =
        Tween<double>(
      begin: startCamera.zoom,
      end: safeTargetZoom,
    ).animate(
      curvedAnimation,
    );

    _finalCameraCenter =
        targetCenter;

    _finalCameraZoom =
        safeTargetZoom;

    _cameraAnimationId =
        animationId;

    _cameraAnimationController
      ..stop()
      ..reset()
      ..forward();
  }

  List<LatLng> _cameraPointsForCountry({
    required GeoCountry? country,
    required LatLng? referencePoint,
  }) {
    if (country == null) {
      return const <LatLng>[];
    }

    final List<LatLng>? bestPolygon =
        _findBestPolygon(
      country.polygons,
      referencePoint,
    );

    if (bestPolygon == null ||
        bestPolygon.isEmpty) {
      return <LatLng>[
        LatLng(
          country.bounds.minLatitude,
          country.bounds.minLongitude,
        ),
        LatLng(
          country.bounds.minLatitude,
          country.bounds.maxLongitude,
        ),
        LatLng(
          country.bounds.maxLatitude,
          country.bounds.minLongitude,
        ),
        LatLng(
          country.bounds.maxLatitude,
          country.bounds.maxLongitude,
        ),
      ];
    }

    return _samplePolygonPoints(
      bestPolygon,
    );
  }

  List<LatLng>? _findBestPolygon(
    List<List<LatLng>> polygons,
    LatLng? referencePoint,
  ) {
    if (polygons.isEmpty) {
      return null;
    }

    if (referencePoint == null) {
      return _largestPolygon(
        polygons,
      );
    }

    final List<List<LatLng>>
        containingPolygons =
        <List<LatLng>>[];

    for (final List<LatLng> polygon
        in polygons) {
      if (_polygonBoundsContain(
        polygon,
        referencePoint,
      )) {
        containingPolygons.add(
          polygon,
        );
      }
    }

    if (containingPolygons.isNotEmpty) {
      containingPolygons.sort(
        (
          List<LatLng> first,
          List<LatLng> second,
        ) {
          return _polygonBoundsArea(first)
              .compareTo(
            _polygonBoundsArea(second),
          );
        },
      );

      return containingPolygons.first;
    }

    List<LatLng>? nearestPolygon;
    double? nearestDistance;

    for (final List<LatLng> polygon
        in polygons) {
      if (polygon.isEmpty) {
        continue;
      }

      final LatLng center =
          _polygonBoundsCenter(
        polygon,
      );

      final double distance =
          _simpleCoordinateDistanceSquared(
        center,
        referencePoint,
      );

      if (nearestDistance == null ||
          distance < nearestDistance) {
        nearestDistance = distance;
        nearestPolygon = polygon;
      }
    }

    return nearestPolygon ??
        _largestPolygon(polygons);
  }

  List<LatLng>? _largestPolygon(
    List<List<LatLng>> polygons,
  ) {
    List<LatLng>? largest;
    double largestArea = -1;

    for (final List<LatLng> polygon
        in polygons) {
      final double area =
          _polygonBoundsArea(
        polygon,
      );

      if (area > largestArea) {
        largestArea = area;
        largest = polygon;
      }
    }

    return largest;
  }

  bool _polygonBoundsContain(
    List<LatLng> polygon,
    LatLng point,
  ) {
    if (polygon.isEmpty) {
      return false;
    }

    double minLatitude = 90;
    double maxLatitude = -90;
    double minLongitude = 180;
    double maxLongitude = -180;

    for (final LatLng polygonPoint
        in polygon) {
      if (polygonPoint.latitude <
          minLatitude) {
        minLatitude =
            polygonPoint.latitude;
      }

      if (polygonPoint.latitude >
          maxLatitude) {
        maxLatitude =
            polygonPoint.latitude;
      }

      if (polygonPoint.longitude <
          minLongitude) {
        minLongitude =
            polygonPoint.longitude;
      }

      if (polygonPoint.longitude >
          maxLongitude) {
        maxLongitude =
            polygonPoint.longitude;
      }
    }

    return point.latitude >= minLatitude &&
        point.latitude <= maxLatitude &&
        point.longitude >= minLongitude &&
        point.longitude <= maxLongitude;
  }

  double _polygonBoundsArea(
    List<LatLng> polygon,
  ) {
    if (polygon.isEmpty) {
      return 0;
    }

    double minLatitude = 90;
    double maxLatitude = -90;
    double minLongitude = 180;
    double maxLongitude = -180;

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

    return (maxLatitude - minLatitude).abs() *
        (maxLongitude - minLongitude).abs();
  }

  LatLng _polygonBoundsCenter(
    List<LatLng> polygon,
  ) {
    if (polygon.isEmpty) {
      return const LatLng(0, 0);
    }

    double minLatitude = 90;
    double maxLatitude = -90;
    double minLongitude = 180;
    double maxLongitude = -180;

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

    return LatLng(
      (minLatitude + maxLatitude) / 2,
      (minLongitude + maxLongitude) / 2,
    );
  }

  double _simpleCoordinateDistanceSquared(
    LatLng first,
    LatLng second,
  ) {
    final double latitudeDifference =
        first.latitude -
            second.latitude;

    double longitudeDifference =
        first.longitude -
            second.longitude;

    if (longitudeDifference > 180) {
      longitudeDifference -= 360;
    } else if (longitudeDifference < -180) {
      longitudeDifference += 360;
    }

    return latitudeDifference *
            latitudeDifference +
        longitudeDifference *
            longitudeDifference;
  }

  List<LatLng> _samplePolygonPoints(
    List<LatLng> polygon,
  ) {
    if (polygon.length <=
        _maximumCameraPolygonPoints) {
      return List<LatLng>.from(
        polygon,
      );
    }

    final int step =
        (polygon.length /
                _maximumCameraPolygonPoints)
            .ceil();

    final List<LatLng> sampledPoints =
        <LatLng>[];

    for (
      int index = 0;
      index < polygon.length;
      index += step
    ) {
      sampledPoints.add(
        polygon[index],
      );
    }

    if (sampledPoints.last !=
        polygon.last) {
      sampledPoints.add(
        polygon.last,
      );
    }

    return sampledPoints;
  }

  bool _cameraBoundsAreVerySmall(
    List<LatLng> points,
  ) {
    if (points.isEmpty) {
      return true;
    }

    double minLatitude = 90;
    double maxLatitude = -90;
    double minLongitude = 180;
    double maxLongitude = -180;

    for (final LatLng point in points) {
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

    return (maxLatitude - minLatitude).abs() <
            0.7 &&
        (maxLongitude - minLongitude).abs() <
            0.7;
  }

  List<LatLng> _minimumAreaAround(
    LatLng point,
  ) {
    const double latitudeMargin = 0.42;
    const double longitudeMargin = 0.42;

    return <LatLng>[
      LatLng(
        point.latitude - latitudeMargin,
        point.longitude - longitudeMargin,
      ),
      LatLng(
        point.latitude + latitudeMargin,
        point.longitude + longitudeMargin,
      ),
    ];
  }

  List<LatLng> _areaAroundResultRadius(
    LatLng point,
    double radiusInKilometers,
  ) {
    final double latitudeMargin =
        radiusInKilometers / 110.574;

    final double latitudeInRadians =
        point.latitude * math.pi / 180;

    final double longitudeScale =
        math.cos(latitudeInRadians)
            .abs()
            .clamp(0.15, 1.0)
            .toDouble();

    final double longitudeMargin =
        radiusInKilometers /
            (111.320 * longitudeScale);

    return <LatLng>[
      LatLng(
        point.latitude - latitudeMargin,
        point.longitude,
      ),
      LatLng(
        point.latitude + latitudeMargin,
        point.longitude,
      ),
      LatLng(
        point.latitude,
        point.longitude - longitudeMargin,
      ),
      LatLng(
        point.latitude,
        point.longitude + longitudeMargin,
      ),
    ];
  }

  double _nearestLongitude(
    double startLongitude,
    double targetLongitude,
  ) {
    double difference =
        targetLongitude -
            startLongitude;

    if (difference > 180) {
      difference -= 360;
    } else if (difference < -180) {
      difference += 360;
    }

    return startLongitude +
        difference;
  }

  double _normalizeLongitude(
    double longitude,
  ) {
    double normalized =
        longitude;

    while (normalized > 180) {
      normalized -= 360;
    }

    while (normalized < -180) {
      normalized += 360;
    }

    return normalized;
  }

  void _handleCameraAnimation() {
    if (!_mapIsReady) {
      return;
    }

    final Animation<double>? latitude =
        _latitudeAnimation;

    final Animation<double>? longitude =
        _longitudeAnimation;

    final Animation<double>? zoom =
        _zoomAnimation;

    if (latitude == null ||
        longitude == null ||
        zoom == null) {
      return;
    }

    final double safeLatitude =
        latitude.value.clamp(
      -_maximumLatitude,
      _maximumLatitude,
    );

    _mapController.move(
      LatLng(
        safeLatitude,
        _normalizeLongitude(
          longitude.value,
        ),
      ),
      zoom.value,
      id: '$_cameraAnimationId-frame',
    );
  }

  void _handleCameraAnimationStatus(
    AnimationStatus status,
  ) {
    if (status !=
            AnimationStatus.completed ||
        !_mapIsReady) {
      return;
    }

    final LatLng? finalCenter =
        _finalCameraCenter;

    final double? finalZoom =
        _finalCameraZoom;

    if (finalCenter == null ||
        finalZoom == null) {
      return;
    }

    _mapController.move(
      LatLng(
        finalCenter.latitude.clamp(
          -_maximumLatitude,
          _maximumLatitude,
        ),
        _normalizeLongitude(
          finalCenter.longitude,
        ),
      ),
      finalZoom,
      id: '$_cameraAnimationId-final',
    );
  }

  bool _pointsAreVeryClose(
    LatLng first,
    LatLng second,
  ) {
    final double latitudeDifference =
        (
          first.latitude -
          second.latitude
        ).abs();

    double longitudeDifference =
        (
          first.longitude -
          second.longitude
        ).abs();

    if (longitudeDifference > 180) {
      longitudeDifference =
          360 - longitudeDifference;
    }

    return latitudeDifference < 0.08 &&
        longitudeDifference < 0.08;
  }

  Color _countryColor(
    GeoCountry country,
  ) {
    final String continent =
        country.continent
            .toLowerCase()
            .trim();

    if (continent.contains('africa')) {
      return const Color(0xFFF2C14E);
    }

    if (continent.contains('asia')) {
      return const Color(0xFFE07A5F);
    }

    if (continent.contains('europe')) {
      return const Color(0xFF81B29A);
    }

    if (continent.contains(
      'north america',
    )) {
      return const Color(0xFF8ECAE6);
    }

    if (continent.contains(
      'south america',
    )) {
      return const Color(0xFF90BE6D);
    }

    if (continent.contains('oceania')) {
      return const Color(0xFFB388EB);
    }

    if (continent.contains(
      'antarctica',
    )) {
      return const Color(0xFFEAF4F4);
    }

    return const Color(0xFFD9C2A6);
  }

  List<Polygon<Object>> _buildCountryPolygons(
    List<GeoCountry> countries,
  ) {
    final List<Polygon<Object>>
        normalPolygons =
        <Polygon<Object>>[];

    final List<Polygon<Object>>
        selectedPolygons =
        <Polygon<Object>>[];

    final List<Polygon<Object>>
        answerPolygons =
        <Polygon<Object>>[];

    final GeoCountry? effectiveAnswer =
        _effectiveAnswerCountry;

    for (final GeoCountry country
        in countries) {
      final bool isSelectedCountry =
          _sameCountry(
        country,
        _selectedCountry,
      );

      final bool isAnswerCountry =
          _sameCountry(
        country,
        effectiveAnswer,
      );

      final bool isWrongSelectedCountry =
          _isAnswerRevealed &&
              isSelectedCountry &&
              !isAnswerCountry;

      final List<LatLng>?
          selectedTerritory =
          isSelectedCountry
              ? _findBestPolygon(
                  country.polygons,
                  _selectedPoint,
                )
              : null;

      final List<LatLng>?
          answerTerritory =
          isAnswerCountry
              ? _findBestPolygon(
                  country.polygons,
                  widget.answerPoint,
                )
              : null;

      final Color normalColor =
          _countryColor(country);

      for (final List<LatLng> countryPolygon
          in country.polygons) {
        final bool isSelectedTerritory =
            identical(
          countryPolygon,
          selectedTerritory,
        );

        final bool isAnswerTerritory =
            identical(
          countryPolygon,
          answerTerritory,
        );

        final bool isCorrectSelectedTerritory =
            _isAnswerRevealed &&
                isSelectedCountry &&
                isAnswerCountry &&
                isSelectedTerritory;

        if (_isAnswerRevealed &&
            (
              isAnswerTerritory ||
                  isCorrectSelectedTerritory
            )) {
          answerPolygons.add(
            Polygon<Object>(
              points: countryPolygon,
              color:
                  _answerCountryColor
                      .withValues(
                alpha: 0.98,
              ),
              borderColor:
                  _answerCountryBorderColor,
              borderStrokeWidth: 2.8,
            ),
          );

          continue;
        }

        if (isWrongSelectedCountry &&
            isSelectedTerritory) {
          selectedPolygons.add(
            Polygon<Object>(
              points: countryPolygon,
              color:
                  _selectedCountryColor
                      .withValues(
                alpha: 0.97,
              ),
              borderColor:
                  _selectedCountryBorderColor,
              borderStrokeWidth: 2.8,
            ),
          );

          continue;
        }

        if (!_isAnswerRevealed &&
            isSelectedCountry &&
            isSelectedTerritory) {
          selectedPolygons.add(
            Polygon<Object>(
              points: countryPolygon,
              color:
                  const Color(0xFFFF8C42)
                      .withValues(
                alpha: 0.95,
              ),
              borderColor:
                  const Color(0xFFD94801),
              borderStrokeWidth: 2.8,
            ),
          );

          continue;
        }

        normalPolygons.add(
          Polygon<Object>(
            points: countryPolygon,
            color:
                normalColor.withValues(
              alpha: 0.92,
            ),
            borderColor:
                Colors.white.withValues(
              alpha: 0.78,
            ),
            borderStrokeWidth: 0.75,
          ),
        );
      }
    }

    return <Polygon<Object>>[
      ...normalPolygons,
      ...selectedPolygons,
      ...answerPolygons,
    ];
  }

  List<CircleMarker<Object>>
      _buildResultCircles() {
    final LatLng? answerPoint =
        widget.answerPoint;

    final double? radiusInKilometers =
        widget.resultRadiusInKilometers;

    if (answerPoint == null ||
        radiusInKilometers == null ||
        radiusInKilometers <= 0) {
      return const <CircleMarker<Object>>[];
    }

    return <CircleMarker<Object>>[
      CircleMarker<Object>(
        point: answerPoint,
        radius:
            radiusInKilometers * 1000,
        useRadiusInMeter: true,
        color: const Color(0xFF63E276)
            .withValues(
          alpha: 0.18,
        ),
        borderColor:
            const Color(0xFF056F27)
                .withValues(
          alpha: 0.90,
        ),
        borderStrokeWidth: 2.2,
      ),
    ];
  }

  List<Polyline<Object>> _buildAnswerLines() {
    final LatLng? selectedPoint =
        _selectedPoint;

    final LatLng? answerPoint =
        widget.answerPoint;

    if (selectedPoint == null ||
        answerPoint == null) {
      return const <Polyline<Object>>[];
    }

    return <Polyline<Object>>[
      Polyline<Object>(
        points: <LatLng>[
          selectedPoint,
          answerPoint,
        ],
        strokeWidth: 6,
        color: Colors.black.withValues(
          alpha: 0.24,
        ),
      ),
      Polyline<Object>(
        points: <LatLng>[
          selectedPoint,
          answerPoint,
        ],
        strokeWidth: 3.5,
        color: const Color(0xFFFF3B30),
      ),
    ];
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers =
        <Marker>[];

    final LatLng? selectedPoint =
        _selectedPoint;

    final LatLng? answerPoint =
        widget.answerPoint;

    if (selectedPoint != null) {
      markers.add(
        Marker(
          point: selectedPoint,
          width: 48,
          height: 52,
          alignment:
              Alignment.topCenter,
          child:
              const _SelectedPointMarker(),
        ),
      );
    }

    if (answerPoint != null) {
      markers.add(
        Marker(
          point: answerPoint,
          width: 46,
          height: 46,
          alignment:
              Alignment.center,
          child: const _AnswerGlow(),
        ),
      );

      markers.add(
        Marker(
          point: answerPoint,
          width: 46,
          height: 50,
          alignment:
              Alignment.topCenter,
          child:
              const _AnswerFlagMarker(),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GeoCountry>>(
      future: _countriesFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<GeoCountry>>
            snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const ColoredBox(
            color: _oceanColor,
            child: Center(
              child:
                  CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return ColoredBox(
            color: _oceanColor,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Text(
                  'Erreur pendant le chargement '
                  'de la carte :\n'
                  '${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        final List<GeoCountry> countries =
            snapshot.data ??
                const <GeoCountry>[];

        if (countries.isEmpty) {
          return const ColoredBox(
            color: _oceanColor,
            child: Center(
              child: Text(
                'Aucun pays trouvé dans '
                'le fichier GeoJSON.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        final List<Polyline<Object>>
            answerLines =
            _buildAnswerLines();

        final List<CircleMarker<Object>>
            resultCircles =
            _buildResultCircles();

        final List<Marker> markers =
            _buildMarkers();

        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: ColoredBox(
                color: _oceanColor,
                child: FlutterMap(
                  mapController:
                      _mapController,
                  options: MapOptions(
                    initialCenter:
                        widget.initialCenter,
                    initialZoom:
                        _safeInitialZoom,
                    minZoom:
                        _minimumMapZoom,
                    maxZoom:
                        _effectiveMaximumMapZoom,
                    backgroundColor:
                        _oceanColor,
                    cameraConstraint:
                        _worldLatitudeConstraint,
                    interactionOptions:
                        const InteractionOptions(
                      flags:
                          InteractiveFlag.drag |
                              InteractiveFlag
                                  .pinchZoom |
                              InteractiveFlag
                                  .doubleTapZoom |
                              InteractiveFlag
                                  .scrollWheelZoom,
                    ),
                    onMapReady: () {
                      _mapIsReady = true;

                      _mapController.move(
                        widget.initialCenter,
                        _safeInitialZoom,
                        id: 'geopoint-question-initial',
                      );

                      _resolveAnswerCountry();

                      if (widget.answerPoint !=
                          null) {
                        _scheduleCameraFit();
                      }
                    },
                    onTap: widget.allowInteraction
                        ? _handleMapTap
                        : null,
                  ),
                  children: <Widget>[
                    PolygonLayer<Object>(
                      polygons:
                          _buildCountryPolygons(
                        countries,
                      ),
                    ),
                    CircleLayer<Object>(
                      circles: resultCircles,
                    ),
                    PolylineLayer<Object>(
                      polylines: answerLines,
                    ),
                    MarkerLayer(
                      markers: markers,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.showInformationPanel)
              Positioned(
                top:
                    MediaQuery.paddingOf(
                              context,
                            ).top +
                        12,
                left: 12,
                right: 12,
                child: _InformationPanel(
                  selectedCountry:
                      _selectedCountry,
                  selectedPoint:
                      _selectedPoint,
                  candidateCount:
                      _candidateCount,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SelectedPointMarker
    extends StatelessWidget {
  const _SelectedPointMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        Positioned(
          top: 8,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color:
                      const Color(0xFFFF5C35)
                          .withValues(
                    alpha: 0.48,
                  ),
                  blurRadius: 13,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        const Icon(
          Icons.location_pin,
          size: 46,
          color: Color(0xFFFF5C35),
          shadows: <Shadow>[
            Shadow(
              color: Colors.black38,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnswerGlow extends StatelessWidget {
  const _AnswerGlow();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              const Color(0xFF8DFF86),
          border: Border.all(
            color: Colors.white,
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color:
                  const Color(0xFF75FF70)
                      .withValues(
                alpha: 0.78,
              ),
              blurRadius: 12,
              spreadRadius: 3,
            ),
            BoxShadow(
              color:
                  const Color(0xFF75FF70)
                      .withValues(
                alpha: 0.26,
              ),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerFlagMarker
    extends StatelessWidget {
  const _AnswerFlagMarker();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.flag,
      size: 42,
      color: Color(0xFF38C95A),
      shadows: <Shadow>[
        Shadow(
          color: Colors.black45,
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
        Shadow(
          color: Color(0xFF79FF82),
          blurRadius: 8,
        ),
      ],
    );
  }
}

class _InformationPanel
    extends StatelessWidget {
  const _InformationPanel({
    required this.selectedCountry,
    required this.selectedPoint,
    required this.candidateCount,
  });

  final GeoCountry? selectedCountry;
  final LatLng? selectedPoint;
  final int? candidateCount;

  @override
  Widget build(BuildContext context) {
    final LatLng? point =
        selectedPoint;

    if (point == null) {
      return const SizedBox.shrink();
    }

    final GeoCountry? country =
        selectedCountry;

    final String locationText =
        country == null
            ? 'Océan ou zone non reconnue'
            : country.name;

    final String coordinatesText =
        '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}';

    final String candidateText =
        candidateCount == null
            ? ''
            : '$candidateCount pays candidats testés';

    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 430,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: 0.72,
          ),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color:
                Colors.white.withValues(
              alpha: 0.32,
            ),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.20,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: <Widget>[
            Text(
              locationText,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              coordinatesText,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.white.withValues(
                  alpha: 0.82,
                ),
                fontSize: 13,
              ),
            ),
            if (candidateText.isNotEmpty)
              ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  candidateText,
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Colors.white.withValues(
                      alpha: 0.62,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
