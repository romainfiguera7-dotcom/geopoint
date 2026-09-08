import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/country_selector.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/geobrain/geobrain_service.dart';
import 'package:geopoint/geobrain/geobrain_storage.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';
import 'package:geopoint/geobrain/theme_mastery.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime now = DateTime.utc(2026, 8, 30, 12);

  GeoCountry country(String id, {String continent = 'Test'}) {
    return GeoCountry(
      id: id,
      isoA2: 'FR',
      name: id,
      continent: continent,
      polygons: const [],
    );
  }

  ThemeMastery themeMastery({
    required GeoBrainTheme theme,
    required double score,
    required int attempts,
    required DateTime nextReviewAt,
  }) {
    return ThemeMastery(
      theme: theme,
      score: score,
      correctAnswers: attempts,
      wrongAnswers: 0,
      totalAttempts: attempts,
      currentStreak: attempts,
      bestStreak: attempts,
      firstLearnedAt: now.subtract(const Duration(days: 10)),
      lastReviewedAt: now.subtract(const Duration(hours: 1)),
      lastConfirmedAt: now.subtract(const Duration(hours: 1)),
      highestScore: score,
      nextReviewAt: nextReviewAt,
      successfulReviewCount: attempts.clamp(0, 7),
    );
  }

  CountryMastery mastery(
    String id, {
    required Map<GeoBrainTheme, ThemeMastery> themes,
  }) {
    final int totalAttempts = themes.values.fold<int>(
      0,
      (int total, ThemeMastery value) => total + value.totalAttempts,
    );
    final int correctAnswers = themes.values.fold<int>(
      0,
      (int total, ThemeMastery value) => total + value.correctAnswers,
    );
    final double bestScore = themes.values.fold<double>(
      0,
      (double best, ThemeMastery value) => max(best, value.score),
    );
    return CountryMastery(
      countryId: id,
      masteryLevel: bestScore >= 80 ? 5 : 2,
      correctAnswers: correctAnswers,
      wrongAnswers: totalAttempts - correctAnswers,
      totalAttempts: totalAttempts,
      currentStreak: correctAnswers,
      bestStreak: correctAnswers,
      lastReviewedAt: now.subtract(const Duration(hours: 1)),
      nextReviewAt: themes.values
          .map<DateTime>((ThemeMastery value) => value.nextReviewAt!)
          .reduce((DateTime first, DateTime second) =>
              first.isBefore(second) ? first : second),
      isWishlisted: false,
      isVisited: false,
      themeMasteries: themes,
    );
  }

  Future<GeoBrainService> serviceFor(
    Map<String, CountryMastery> countries,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final GeoBrainProfile profile = GeoBrainProfile(
      schemaVersion: GeoBrainProfile.currentSchemaVersion,
      countries: countries,
      createdAt: now,
      updatedAt: now,
    );
    expect(await GeoBrainStorage.save(profile), isTrue);
    return GeoBrainService.create();
  }

  test('la sélection équilibrée mélange difficultés, acquis et nouveautés',
      () async {
    final Map<String, CountryMastery> learned = <String, CountryMastery>{
      for (final String id in <String>['AAA', 'BBB'])
        id: mastery(
          id,
          themes: <GeoBrainTheme, ThemeMastery>{
            GeoBrainTheme.location: themeMastery(
              theme: GeoBrainTheme.location,
              score: 35,
              attempts: 4,
              nextReviewAt: now.add(const Duration(days: 2)),
            ),
          },
        ),
      for (final String id in <String>['CCC', 'DDD', 'EEE', 'FFF'])
        id: mastery(
          id,
          themes: <GeoBrainTheme, ThemeMastery>{
            GeoBrainTheme.location: themeMastery(
              theme: GeoBrainTheme.location,
              score: 90,
              attempts: 8,
              nextReviewAt: now.add(const Duration(days: 30)),
            ),
          },
        ),
    };
    final GeoBrainService service = await serviceFor(learned);
    final Set<String> weakIds = <String>{'AAA', 'BBB'};
    final Set<String> masteredIds = <String>{'CCC', 'DDD', 'EEE', 'FFF'};
    final Set<String> newIds = <String>{'GGG', 'HHH', 'III', 'JJJ', 'KKK', 'LLL'};
    final List<GeoCountry> selected = CountrySelector(
      geoBrain: service,
      random: Random(4),
    ).selectCountries(
      availableCountries: <String>{...weakIds, ...masteredIds, ...newIds}
          .map<GeoCountry>(country)
          .toList(growable: false),
      questionCount: 6,
      theme: GeoBrainTheme.location,
      now: now,
    );
    final Set<String> selectedIds =
        selected.map<String>((GeoCountry value) => value.id).toSet();

    expect(selected, hasLength(6));
    expect(selectedIds.intersection(weakIds), hasLength(2));
    expect(selectedIds.intersection(masteredIds), hasLength(1));
    expect(selectedIds.intersection(newIds), hasLength(3));
  });

  test('deux joueurs aux fragilités différentes reçoivent des séances différentes',
      () async {
    Future<String> selectedFor(String weakId) async {
      final GeoBrainService service = await serviceFor(
        <String, CountryMastery>{
          weakId: mastery(
            weakId,
            themes: <GeoBrainTheme, ThemeMastery>{
              GeoBrainTheme.location: themeMastery(
                theme: GeoBrainTheme.location,
                score: 32,
                attempts: 4,
                nextReviewAt: now.add(const Duration(days: 2)),
              ),
            },
          ),
        },
      );
      return CountrySelector(
        geoBrain: service,
        random: Random(2),
      ).selectCountries(
        availableCountries: <String>['AAA', 'BBB', 'CCC', 'DDD']
            .map<GeoCountry>(country)
            .toList(growable: false),
        questionCount: 1,
        theme: GeoBrainTheme.location,
        selectionProfile: GeoBrainSelectionProfile.reviewDifficulties,
        now: now,
      ).single.id;
    }

    expect(await selectedFor('AAA'), 'AAA');
    expect(await selectedFor('BBB'), 'BBB');
  });

  test('le profil difficultés respecte le thème demandé', () async {
    final CountryMastery first = mastery(
      'AAA',
      themes: <GeoBrainTheme, ThemeMastery>{
        GeoBrainTheme.location: themeMastery(
          theme: GeoBrainTheme.location,
          score: 35,
          attempts: 4,
          nextReviewAt: now.add(const Duration(days: 2)),
        ),
        GeoBrainTheme.flag: themeMastery(
          theme: GeoBrainTheme.flag,
          score: 90,
          attempts: 8,
          nextReviewAt: now.add(const Duration(days: 30)),
        ),
      },
    );
    final CountryMastery second = mastery(
      'BBB',
      themes: <GeoBrainTheme, ThemeMastery>{
        GeoBrainTheme.location: themeMastery(
          theme: GeoBrainTheme.location,
          score: 90,
          attempts: 8,
          nextReviewAt: now.add(const Duration(days: 30)),
        ),
        GeoBrainTheme.flag: themeMastery(
          theme: GeoBrainTheme.flag,
          score: 35,
          attempts: 4,
          nextReviewAt: now.add(const Duration(days: 2)),
        ),
      },
    );
    final GeoBrainService service = await serviceFor(
      <String, CountryMastery>{'AAA': first, 'BBB': second},
    );

    expect(
      CountrySelector(geoBrain: service, random: Random(1))
          .selectCountries(
            availableCountries: <GeoCountry>[country('AAA'), country('BBB')],
            questionCount: 1,
            theme: GeoBrainTheme.location,
            selectionProfile: GeoBrainSelectionProfile.reviewDifficulties,
            now: now,
          )
          .single
          .id,
      'AAA',
    );
    expect(
      CountrySelector(geoBrain: service, random: Random(1))
          .selectCountries(
            availableCountries: <GeoCountry>[country('AAA'), country('BBB')],
            questionCount: 1,
            theme: GeoBrainTheme.flag,
            selectionProfile: GeoBrainSelectionProfile.reviewDifficulties,
            now: now,
          )
          .single
          .id,
      'BBB',
    );
  });

  test('deux missions proches évitent de répéter les mêmes pays', () async {
    final GeoBrainService service = await serviceFor(<String, CountryMastery>{});
    final List<GeoCountry> countries = <String>[
      'AAA', 'BBB', 'CCC', 'DDD', 'EEE', 'FFF', 'GGG', 'HHH', 'III', 'JJJ',
      'KKK', 'LLL', 'MMM', 'NNN', 'OOO', 'PPP', 'QQQ', 'RRR', 'SSS', 'TTT',
    ].map<GeoCountry>(country).toList(growable: false);
    final CountrySelector selector = CountrySelector(
      geoBrain: service,
      random: Random(11),
    );
    final Set<String> first = selector
        .selectCountries(
          availableCountries: countries,
          questionCount: 5,
          theme: GeoBrainTheme.location,
          now: now,
        )
        .map<String>((GeoCountry value) => value.id)
        .toSet();
    final Set<String> second = selector
        .selectCountries(
          availableCountries: countries,
          questionCount: 5,
          theme: GeoBrainTheme.location,
          now: now,
        )
        .map<String>((GeoCountry value) => value.id)
        .toSet();

    expect(first.intersection(second), isEmpty);
  });

  test('le sélecteur respecte le catalogue filtré et la durée demandée',
      () async {
    final GeoBrainService service = await serviceFor(<String, CountryMastery>{});
    final List<GeoCountry> europe = <GeoCountry>[
      country('FRA', continent: 'Europe'),
      country('ESP', continent: 'Europe'),
      country('ITA', continent: 'Europe'),
      country('PRT', continent: 'Europe'),
    ];
    final List<GeoCountry> selected = CountrySelector(
      geoBrain: service,
      random: Random(6),
    ).selectCountries(
      availableCountries: europe,
      questionCount: 3,
      theme: GeoBrainTheme.capital,
      now: now,
    );

    expect(selected, hasLength(3));
    expect(selected.every((GeoCountry value) => value.continent == 'Europe'),
        isTrue);
  });
}
