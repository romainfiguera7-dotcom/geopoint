import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:geopoint/passport/progress/passport_continent.dart';
import 'package:geopoint/passport/progress/passport_continent_snapshot.dart';
import 'package:geopoint/passport/progress/passport_entity_progress.dart';
import 'package:geopoint/passport/progress/passport_progress_rules.dart';
import 'package:geopoint/passport/progress/passport_progress_v2.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('PassportContinentSnapshot', () {
    final DateTime now = DateTime.utc(2026, 8, 28);
    final List<GeoCountry> countries = <GeoCountry>[
      _country('FRA', 'FR', 'France', 'Europe'),
      _country('SYC', 'SC', 'Seychelles', 'Seven seas (open ocean)'),
      _country('ATF', 'TF', 'Terres australes', 'Seven seas (open ocean)'),
      _country('USA', 'US', 'États-Unis', 'North America'),
    ];

    test('calcule les compteurs de progression d’un continent', () {
      PassportProgressV2 progress = PassportProgressV2.initial(
        createdAt: now,
      );
      final PassportEntityProgress france =
          PassportEntityProgress.initial('FRA').registerAnswer(
        theme: PassportKnowledgeTheme.location,
        isCorrect: true,
        masteryLevelAfterAnswer: 5,
        source: PassportDiscoverySource.game,
        answeredAt: now,
      );
      final PassportEntityProgress seychelles =
          PassportEntityProgress.initial('SYC').markDiscovered(
        source: PassportDiscoverySource.atlas,
        discoveredAt: now,
      );

      progress = progress.replaceEntity(france, updatedAt: now);
      progress = progress.replaceEntity(seychelles, updatedAt: now);

      final PassportContinentSnapshot europe =
          PassportContinentSnapshot.build(
        continent: PassportContinent.europe,
        countries: countries,
        progress: progress,
      );
      final PassportContinentSnapshot africa =
          PassportContinentSnapshot.build(
        continent: PassportContinent.africa,
        countries: countries,
        progress: progress,
      );

      expect(europe.totalCount, 1);
      expect(europe.discoveredCount, 1);
      expect(europe.masteredCount, 1);
      expect(europe.stampCount, 1);
      expect(europe.discoveryPercentage, 100);
      expect(europe.masteryPercentage, 100);
      expect(africa.totalCount, 1);
      expect(africa.discoveredCount, 1);
      expect(africa.masteredCount, 0);
      expect(africa.stampCount, 0);
    });

    test('classe les exceptions maritimes dans la bonne zone', () {
      final List<PassportContinentSnapshot> snapshots =
          PassportContinentSnapshot.buildAll(
        countries: countries,
        progress: PassportProgressV2.initial(createdAt: now),
      );
      final Map<PassportContinent, PassportContinentSnapshot> byContinent =
          <PassportContinent, PassportContinentSnapshot>{
        for (final PassportContinentSnapshot snapshot in snapshots)
          snapshot.continent: snapshot,
      };

      expect(byContinent[PassportContinent.africa]!.totalCount, 1);
      expect(byContinent[PassportContinent.polar]!.totalCount, 1);
      expect(byContinent[PassportContinent.americas]!.totalCount, 1);
      expect(byContinent[PassportContinent.europe]!.totalCount, 1);
      expect(
        snapshots.fold<int>(
          0,
          (int total, PassportContinentSnapshot snapshot) =>
              total + snapshot.totalCount,
        ),
        countries.length,
      );
    });
  });
}

GeoCountry _country(
  String id,
  String isoA2,
  String name,
  String continent,
) {
  return GeoCountry(
    id: id,
    isoA2: isoA2,
    name: name,
    continent: continent,
    polygons: const <List<LatLng>>[],
  );
}
