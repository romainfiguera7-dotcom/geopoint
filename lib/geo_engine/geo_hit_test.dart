import 'package:latlong2/latlong.dart';

import 'country_spatial_index.dart';
import 'geo_country.dart';

class GeoHitTest {
  static GeoCountry? findCountry(
    LatLng point,
    CountrySpatialIndex spatialIndex,
  ) {
    final List<GeoCountry> candidates =
        spatialIndex.candidatesAt(point);

    for (final GeoCountry country in candidates) {
      if (!country.bounds.contains(point)) {
        continue;
      }

      for (final List<LatLng> polygon in country.polygons) {
        if (_pointInPolygon(point, polygon)) {
          return country;
        }
      }
    }

    return null;
  }

  static bool _pointInPolygon(
    LatLng point,
    List<LatLng> polygon,
  ) {
    if (polygon.length < 3) {
      return false;
    }

    bool inside = false;
    int previousIndex = polygon.length - 1;

    for (int currentIndex = 0;
        currentIndex < polygon.length;
        currentIndex++) {
      final LatLng currentPoint = polygon[currentIndex];
      final LatLng previousPoint = polygon[previousIndex];

      final bool crossesLatitude =
          (currentPoint.latitude > point.latitude) !=
              (previousPoint.latitude > point.latitude);

      if (crossesLatitude) {
        final double longitudeIntersection =
            (previousPoint.longitude - currentPoint.longitude) *
                    (point.latitude - currentPoint.latitude) /
                    (previousPoint.latitude -
                        currentPoint.latitude) +
                currentPoint.longitude;

        if (point.longitude < longitudeIntersection) {
          inside = !inside;
        }
      }

      previousIndex = currentIndex;
    }

    return inside;
  }
}