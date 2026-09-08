import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/features/atlas/atlas_geometry_lod.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:geopoint/geo_engine/geojson_loader.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('les niveaux Atlas allègent la carte sans supprimer de pays',
      () async {
    final List<GeoCountry> countries = await GeoJsonLoader.loadCountries();
    final AtlasGeometryLod geometryLod = await AtlasGeometryLod.load();

    int overviewPointCount = 0;
    int continentPointCount = 0;
    int regionalPointCount = 0;
    int fullPointCount = 0;

    for (final GeoCountry country in countries) {
      final List<List<LatLng>> overview = geometryLod.polygonsFor(
        country,
        AtlasGeometryDetail.overview,
      );
      final List<List<LatLng>> regional = geometryLod.polygonsFor(
        country,
        AtlasGeometryDetail.regional,
      );
      final List<List<LatLng>> continent = geometryLod.polygonsFor(
        country,
        AtlasGeometryDetail.continent,
      );
      final List<List<LatLng>> full = geometryLod.polygonsFor(
        country,
        AtlasGeometryDetail.full,
      );

      expect(overview, isNotEmpty);
      expect(continent, isNotEmpty);
      expect(regional, isNotEmpty);
      expect(identical(full, country.polygons), isTrue);

      overviewPointCount += _pointCount(overview);
      continentPointCount += _pointCount(continent);
      regionalPointCount += _pointCount(regional);
      fullPointCount += _pointCount(full);
    }

    expect(overviewPointCount, lessThan(continentPointCount));
    expect(continentPointCount, lessThan(regionalPointCount));
    expect(regionalPointCount, lessThan(fullPointCount));
  });

  test('le détail complet revient automatiquement en zoom rapproché',
      () async {
    final AtlasGeometryLod geometryLod = await AtlasGeometryLod.load();

    expect(
      geometryLod.detailForZoom(2),
      AtlasGeometryDetail.overview,
    );
    expect(
      geometryLod.detailForZoom(4),
      AtlasGeometryDetail.continent,
    );
    expect(
      geometryLod.detailForZoom(5),
      AtlasGeometryDetail.regional,
    );
    expect(
      geometryLod.detailForZoom(7),
      AtlasGeometryDetail.full,
    );
  });
}

int _pointCount(List<List<LatLng>> polygons) {
  return polygons.fold<int>(
    0,
    (int total, List<LatLng> polygon) => total + polygon.length,
  );
}
