import '../../geo_engine/geo_country.dart';
import 'passport_continent.dart';
import 'passport_entity_progress.dart';
import 'passport_progress_rules.dart';
import 'passport_progress_v2.dart';

class PassportContinentSnapshot {
  const PassportContinentSnapshot._({
    required this.continent,
    required this.countries,
    required this.discoveredCount,
    required this.learningCount,
    required this.masteredCount,
    required this.stampCount,
  });

  final PassportContinent continent;
  final List<GeoCountry> countries;
  final int discoveredCount;
  final int learningCount;
  final int masteredCount;
  final int stampCount;

  int get totalCount => countries.length;

  double get discoveryProgress => _ratio(discoveredCount, totalCount);

  double get masteryProgress => _ratio(masteredCount, totalCount);

  int get discoveryPercentage => (discoveryProgress * 100).round();

  int get masteryPercentage => (masteryProgress * 100).round();

  static PassportContinentSnapshot build({
    required PassportContinent continent,
    required Iterable<GeoCountry> countries,
    required PassportProgressV2 progress,
  }) {
    final List<GeoCountry> continentCountries = countries
        .where(
          (GeoCountry country) =>
              PassportContinent.forEntity(
                entityId: country.id,
                geoContinent: country.continent,
              ) ==
              continent,
        )
        .toList(growable: false)
      ..sort(
        (GeoCountry first, GeoCountry second) =>
            first.name.compareTo(second.name),
      );
    int discovered = 0;
    int learning = 0;
    int mastered = 0;
    int stamps = 0;

    for (final GeoCountry country in continentCountries) {
      final PassportEntityProgress entity = progress.progressFor(country.id);

      if (entity.hasBeenDiscovered) {
        discovered++;
      }

      if (entity.learningState == PassportLearningState.learning) {
        learning++;
      }

      if (entity.isMastered) {
        mastered++;
      }

      if (entity.stampUnlockedAt != null) {
        stamps++;
      }
    }

    return PassportContinentSnapshot._(
      continent: continent,
      countries: List<GeoCountry>.unmodifiable(continentCountries),
      discoveredCount: discovered,
      learningCount: learning,
      masteredCount: mastered,
      stampCount: stamps,
    );
  }

  static List<PassportContinentSnapshot> buildAll({
    required Iterable<GeoCountry> countries,
    required PassportProgressV2 progress,
  }) {
    return PassportContinent.values
        .map(
          (PassportContinent continent) => build(
            continent: continent,
            countries: countries,
            progress: progress,
          ),
        )
        .toList(growable: false);
  }

  static double _ratio(int value, int total) {
    if (total <= 0) {
      return 0;
    }

    return (value / total).clamp(0, 1).toDouble();
  }
}
