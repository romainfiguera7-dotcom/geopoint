import 'package:latlong2/latlong.dart';

import 'geo_country.dart';

class CountrySpatialIndex {
  CountrySpatialIndex({
    required List<GeoCountry> countries,
    this.cellSize = 10,
  }) {
    _build(countries);
  }

  final double cellSize;

  final Map<String, List<GeoCountry>> _cells =
      <String, List<GeoCountry>>{};

  void _build(List<GeoCountry> countries) {
    for (final GeoCountry country in countries) {
      final int minLatitudeCell =
          (country.bounds.minLatitude / cellSize).floor();

      final int maxLatitudeCell =
          (country.bounds.maxLatitude / cellSize).floor();

      final int minLongitudeCell =
          (country.bounds.minLongitude / cellSize).floor();

      final int maxLongitudeCell =
          (country.bounds.maxLongitude / cellSize).floor();

      for (
        int latitudeCell = minLatitudeCell;
        latitudeCell <= maxLatitudeCell;
        latitudeCell++
      ) {
        for (
          int longitudeCell = minLongitudeCell;
          longitudeCell <= maxLongitudeCell;
          longitudeCell++
        ) {
          final String key = _cellKeyFromIndexes(
            latitudeCell,
            longitudeCell,
          );

          final List<GeoCountry> cellCountries =
              _cells.putIfAbsent(
            key,
            () => <GeoCountry>[],
          );

          if (!cellCountries.contains(country)) {
            cellCountries.add(country);
          }
        }
      }
    }
  }

  List<GeoCountry> candidatesAt(LatLng point) {
    final int latitudeCell =
        (point.latitude / cellSize).floor();

    final int longitudeCell =
        (point.longitude / cellSize).floor();

    final String key = _cellKeyFromIndexes(
      latitudeCell,
      longitudeCell,
    );

    return _cells[key] ?? const <GeoCountry>[];
  }

  int candidateCountAt(LatLng point) {
    return candidatesAt(point).length;
  }

  String _cellKeyFromIndexes(
    int latitudeCell,
    int longitudeCell,
  ) {
    return '$latitudeCell:$longitudeCell';
  }
}