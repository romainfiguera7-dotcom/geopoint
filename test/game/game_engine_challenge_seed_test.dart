import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/game/game_engine.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:latlong2/latlong.dart';

void main() {
  GeoCountry country(int index) {
    return GeoCountry(
      id: 'C$index',
      isoA2: 'FR',
      name: 'Pays $index',
      continent: 'Europe',
      polygons: <List<LatLng>>[
        const <LatLng>[
          LatLng(0, 0),
          LatLng(0, 1),
          LatLng(1, 0),
        ],
      ],
    );
  }

  test('la même graine reproduit les mêmes questions classées', () {
    final GameEngine engine = GameEngine();
    final List<GeoCountry> countries = List<GeoCountry>.generate(
      8,
      country,
    );

    engine.reset(randomSeed: 2804);
    final List<String> first = List<String>.generate(
      6,
      (_) => engine.createNextQuestion(countries, modeId: 'mixed')!.countryId,
    );
    engine.reset(randomSeed: 2804);
    final List<String> second = List<String>.generate(
      6,
      (_) => engine.createNextQuestion(countries, modeId: 'mixed')!.countryId,
    );

    expect(second, first);
  });
}
