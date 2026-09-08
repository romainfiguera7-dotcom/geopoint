import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_dashboard.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';
import 'package:geopoint/passport/progress/passport_continent.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 31, 12);

  GeoCountry country(String id, String name, String continent) {
    return GeoCountry(
      id: id,
      isoA2: id.substring(0, 2),
      name: name,
      continent: continent,
      polygons: const [],
    );
  }

  CountryMastery withAttempts(
    String id,
    GeoBrainTheme theme,
    List<bool> answers, {
    int daysAgo = 2,
  }) {
    CountryMastery mastery = CountryMastery.initial(id);
    for (int index = 0; index < answers.length; index++) {
      mastery = mastery.registerAttempt(
        GeoBrainAttempt(
          countryId: id,
          theme: theme,
          answeredAt: now.subtract(
            Duration(days: daysAgo, minutes: answers.length - index),
          ),
          modeId: theme.id,
          difficultyId: 'intermediate',
          isCorrect: answers[index],
          context: GeoBrainAttemptContext.training,
        ),
      );
    }
    return mastery;
  }

  GeoBrainProfile profile(Map<String, CountryMastery> countries) {
    return GeoBrainProfile(
      schemaVersion: GeoBrainProfile.currentSchemaVersion,
      countries: countries,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );
  }

  test('le résumé global reste lisible pour un nouveau joueur', () {
    final GeoBrainDashboardSnapshot snapshot =
        const GeoBrainDashboardBuilder().build(
      profile: profile(const <String, CountryMastery>{}),
      countries: <GeoCountry>[
        country('FRA', 'France', 'Europe'),
      ],
      now: now,
    );

    expect(snapshot.globalRetainedScore, 0);
    expect(snapshot.seenCountryCount, 0);
    expect(snapshot.masteredCountryCount, 0);
    expect(snapshot.reviewCountryCount, 0);
    expect(snapshot.countries.single.status, GeoBrainMasteryStatus.unknown);
  });

  test('la progression par thème utilise uniquement les thèmes rencontrés', () {
    final GeoBrainDashboardSnapshot snapshot =
        const GeoBrainDashboardBuilder().build(
      profile: profile(<String, CountryMastery>{
        'FRA': withAttempts(
          'FRA',
          GeoBrainTheme.capital,
          <bool>[true, true, true],
        ),
      }),
      countries: <GeoCountry>[
        country('FRA', 'France', 'Europe'),
      ],
      now: now,
    );
    final GeoBrainThemeProgress capital = snapshot.themes.firstWhere(
      (GeoBrainThemeProgress value) => value.theme == GeoBrainTheme.capital,
    );
    final GeoBrainThemeProgress flag = snapshot.themes.firstWhere(
      (GeoBrainThemeProgress value) => value.theme == GeoBrainTheme.flag,
    );

    expect(capital.seenCountryCount, 1);
    expect(capital.retainedScore, greaterThan(0));
    expect(flag.seenCountryCount, 0);
    expect(flag.retainedScore, 0);
  });

  test('la progression continentale respecte le catalogue géographique', () {
    final GeoBrainDashboardSnapshot snapshot =
        const GeoBrainDashboardBuilder().build(
      profile: profile(<String, CountryMastery>{
        'FRA': withAttempts('FRA', GeoBrainTheme.location, <bool>[true]),
        'EGY': withAttempts('EGY', GeoBrainTheme.location, <bool>[false]),
      }),
      countries: <GeoCountry>[
        country('FRA', 'France', 'Europe'),
        country('ESP', 'Espagne', 'Europe'),
        country('EGY', 'Égypte', 'Africa'),
      ],
      now: now,
    );
    final GeoBrainContinentProgress europe = snapshot.continents.firstWhere(
      (GeoBrainContinentProgress value) =>
          value.continent == PassportContinent.europe,
    );
    final GeoBrainContinentProgress africa = snapshot.continents.firstWhere(
      (GeoBrainContinentProgress value) =>
          value.continent == PassportContinent.africa,
    );

    expect(europe.totalCountryCount, 2);
    expect(europe.seenCountryCount, 1);
    expect(africa.totalCountryCount, 1);
    expect(africa.seenCountryCount, 1);
  });

  test('les connaissances arrivées à échéance remontent dans À réviser', () {
    final GeoBrainDashboardSnapshot snapshot =
        const GeoBrainDashboardBuilder().build(
      profile: profile(<String, CountryMastery>{
        'FRA': withAttempts(
          'FRA',
          GeoBrainTheme.location,
          <bool>[false, false],
          daysAgo: 3,
        ),
      }),
      countries: <GeoCountry>[
        country('FRA', 'France', 'Europe'),
      ],
      now: now,
    );

    expect(snapshot.reviewCountryCount, 1);
    expect(snapshot.reviewCountries.single.countryId, 'FRA');
    expect(snapshot.reviewCountries.single.needsReview, isTrue);
  });

  test('le détail pays conserve les sept maîtrises indépendantes', () {
    final GeoBrainDashboardSnapshot snapshot =
        const GeoBrainDashboardBuilder().build(
      profile: profile(<String, CountryMastery>{
        'FRA': withAttempts('FRA', GeoBrainTheme.flag, <bool>[true, false]),
      }),
      countries: <GeoCountry>[
        country('FRA', 'France', 'Europe'),
      ],
      now: now,
    );
    final GeoBrainCountrySnapshot france = snapshot.countries.single;

    expect(france.themeProgress.length, GeoBrainTheme.values.length);
    expect(
      france.themeProgress
          .firstWhere(
            (GeoBrainCountryThemeSnapshot value) =>
                value.theme == GeoBrainTheme.flag,
          )
          .totalAttempts,
      2,
    );
    expect(
      france.themeProgress
          .firstWhere(
            (GeoBrainCountryThemeSnapshot value) =>
                value.theme == GeoBrainTheme.languages,
          )
          .status,
      GeoBrainMasteryStatus.unknown,
    );
  });

  test('la prochaine séance conseillée provient du moteur GeoBrain', () {
    final GeoBrainDashboardSnapshot snapshot =
        const GeoBrainDashboardBuilder().build(
      profile: profile(const <String, CountryMastery>{}),
      countries: <GeoCountry>[
        country('AUS', 'Australie', 'Oceania'),
        country('NZL', 'Nouvelle-Zélande', 'Oceania'),
        country('PNG', 'Papouasie-Nouvelle-Guinée', 'Oceania'),
        country('FJI', 'Fidji', 'Oceania'),
        country('SLB', 'Îles Salomon', 'Oceania'),
      ],
      now: now,
    );

    expect(snapshot.nextSuggestion, isNotNull);
    expect(snapshot.nextSuggestion!.id, 'discover_oceania_five');
    expect(snapshot.nextSuggestion!.questionCount, 5);
  });
}
