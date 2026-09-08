import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:geopoint/geobrain/country_selector.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_dashboard.dart';
import 'package:geopoint/geobrain/geobrain_difficulty_adapter.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/geobrain/geobrain_service.dart';
import 'package:geopoint/geobrain/geobrain_storage.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';
import 'package:geopoint/geobrain/geobrain_training_suggestion.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime now = DateTime.utc(2026, 8, 31, 12);

  GeoCountry country(
    String id, {
    String? name,
    String continent = 'Europe',
  }) {
    return GeoCountry(
      id: id,
      isoA2: id.substring(0, 2),
      name: name ?? id,
      continent: continent,
      polygons: const [],
    );
  }

  GeoBrainAttempt attempt({
    required String countryId,
    required GeoBrainTheme theme,
    required DateTime answeredAt,
    required bool isCorrect,
    String difficultyId = 'intermediate',
    GeoBrainAttemptContext context = GeoBrainAttemptContext.training,
    String? helpId,
  }) {
    return GeoBrainAttempt(
      countryId: countryId,
      theme: theme,
      answeredAt: answeredAt,
      modeId: theme.id,
      difficultyId: difficultyId,
      isCorrect: isCorrect,
      context: context,
      helpId: helpId,
    );
  }

  GeoBrainProfile profileWith(
    Iterable<GeoBrainAttempt> attempts, {
    DateTime? createdAt,
  }) {
    GeoBrainProfile profile = GeoBrainProfile.initial(
      createdAt: createdAt ?? now.subtract(const Duration(days: 120)),
    );
    for (final GeoBrainAttempt value in attempts) {
      profile = profile.registerAttempt(value);
    }
    return profile;
  }

  List<GeoBrainAttempt> regularSuccesses(
    String countryId, {
    GeoBrainTheme theme = GeoBrainTheme.location,
    int count = 10,
  }) {
    return List<GeoBrainAttempt>.generate(
      count,
      (int index) => attempt(
        countryId: countryId,
        theme: theme,
        answeredAt: now.subtract(Duration(days: count - 1 - index)),
        isCorrect: true,
      ),
    );
  }

  final List<GeoCountry> oceania = <GeoCountry>[
    country('AUS', name: 'Australie', continent: 'Oceania'),
    country('NZL', name: 'Nouvelle-Zélande', continent: 'Oceania'),
    country('PNG', name: 'Papouasie-Nouvelle-Guinée', continent: 'Oceania'),
    country('FJI', name: 'Fidji', continent: 'Oceania'),
    country('SLB', name: 'Îles Salomon', continent: 'Oceania'),
  ];

  test('simulation nouveau joueur : départ facile et nouveautés', () {
    final GeoBrainProfile profile = profileWith(const <GeoBrainAttempt>[]);
    final GeoBrainDifficultyRecommendation difficulty =
        const GeoBrainDifficultyAdapter().recommend(
      attempts: profile.attemptHistory,
    );
    final GeoBrainDashboardSnapshot dashboard =
        const GeoBrainDashboardBuilder().build(
      profile: profile,
      countries: oceania,
      now: now,
    );

    expect(difficulty.difficultyId, 'easy');
    expect(difficulty.reason, GeoBrainAdaptiveReason.newPlayer);
    expect(dashboard.globalRetainedScore, 0);
    expect(dashboard.reviewCountryCount, 0);
    expect(dashboard.nextSuggestion?.id, 'discover_oceania_five');
  });

  test('simulation joueur régulier : acquis stable et difficulté relevée', () {
    final GeoBrainProfile profile = profileWith(regularSuccesses('FRA'));
    final GeoBrainDifficultyRecommendation difficulty =
        const GeoBrainDifficultyAdapter().recommend(
      attempts: profile.attemptHistory,
    );
    final GeoBrainDashboardSnapshot dashboard =
        const GeoBrainDashboardBuilder().build(
      profile: profile,
      countries: <GeoCountry>[
        country('FRA', name: 'France'),
      ],
      now: now,
    );

    expect(difficulty.difficultyId, 'hard');
    expect(difficulty.reason, GeoBrainAdaptiveReason.strongResults);
    expect(dashboard.masteredCountryCount, 1);
    expect(dashboard.reviewCountryCount, 0);
    expect(dashboard.globalRetainedScore, greaterThanOrEqualTo(80));
  });

  test('simulation retour après plusieurs semaines : progrès conservé et révision',
      () {
    final GeoBrainProfile profile = profileWith(regularSuccesses('FRA'));
    final DateTime returnDate = now.add(const Duration(days: 90));
    final GeoBrainDashboardSnapshot dashboard =
        const GeoBrainDashboardBuilder().build(
      profile: profile,
      countries: <GeoCountry>[
        country('FRA', name: 'France'),
      ],
      now: returnDate,
    );

    expect(dashboard.reviewCountryCount, 1);
    expect(dashboard.reviewCountries.single.countryId, 'FRA');
    expect(dashboard.reviewCountries.single.retainedScore, greaterThan(0));
    expect(dashboard.reviewCountries.single.status,
        isNot(GeoBrainMasteryStatus.unknown));
    expect(dashboard.nextSuggestion?.id, 'review_priorities');
    expect(
      profile.masteryFor('FRA').reviewLabelAt(returnDate),
      'À réviser',
    );
  });

  test('deux joueurs avec des difficultés différentes ont des suggestions différentes',
      () {
    final List<GeoCountry> catalog = <GeoCountry>[
      country('ALB', continent: 'Europe'),
      country('BIH', continent: 'Europe'),
      country('EGY', continent: 'Africa'),
      country('NGA', continent: 'Africa'),
      ...oceania,
    ];
    final GeoBrainProfile balkansPlayer = profileWith(<GeoBrainAttempt>[
      attempt(
        countryId: 'ALB',
        theme: GeoBrainTheme.location,
        answeredAt: now.subtract(const Duration(days: 2)),
        isCorrect: false,
      ),
      attempt(
        countryId: 'BIH',
        theme: GeoBrainTheme.location,
        answeredAt: now.subtract(const Duration(days: 2)),
        isCorrect: false,
      ),
    ]);
    final GeoBrainProfile flagsPlayer = profileWith(<GeoBrainAttempt>[
      attempt(
        countryId: 'EGY',
        theme: GeoBrainTheme.flag,
        answeredAt: now.subtract(const Duration(days: 2)),
        isCorrect: false,
      ),
      attempt(
        countryId: 'NGA',
        theme: GeoBrainTheme.flag,
        answeredAt: now.subtract(const Duration(days: 2)),
        isCorrect: false,
      ),
    ]);

    final GeoBrainTrainingSuggestion first =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: balkansPlayer,
      countries: catalog,
      now: now,
    ).first;
    final GeoBrainTrainingSuggestion second =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: flagsPlayer,
      countries: catalog,
      now: now,
    ).first;

    expect(first.id, 'review_balkans');
    expect(second.id, 'review_africa_flags');
    expect(first.countryIds, <String>{'ALB', 'BIH'});
    expect(second.countryIds, <String>{'EGY', 'NGA'});
  });

  test('les pays d’une suggestion de révision correspondent à l’historique réel',
      () {
    final GeoBrainProfile profile = profileWith(<GeoBrainAttempt>[
      attempt(
        countryId: 'EGY',
        theme: GeoBrainTheme.flag,
        answeredAt: now.subtract(const Duration(days: 1)),
        isCorrect: false,
      ),
      attempt(
        countryId: 'NGA',
        theme: GeoBrainTheme.flag,
        answeredAt: now.subtract(const Duration(days: 1)),
        isCorrect: false,
      ),
      attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.capital,
        answeredAt: now.subtract(const Duration(days: 1)),
        isCorrect: true,
      ),
    ]);
    final GeoBrainTrainingSuggestion suggestion =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: profile,
      countries: <GeoCountry>[
        country('EGY', continent: 'Africa'),
        country('NGA', continent: 'Africa'),
        country('FRA'),
      ],
      now: now,
    ).first;
    final Set<String> attemptedIds = profile.attemptHistory
        .map<String>((GeoBrainAttempt value) => value.countryId)
        .toSet();
    final Set<String> wrongFlagIds = profile.attemptHistory
        .where(
          (GeoBrainAttempt value) =>
              value.theme == GeoBrainTheme.flag && !value.isCorrect,
        )
        .map<String>((GeoBrainAttempt value) => value.countryId)
        .toSet();

    expect(suggestion.id, 'review_africa_flags');
    expect(attemptedIds.containsAll(suggestion.countryIds), isTrue);
    expect(suggestion.countryIds, wrongFlagIds);
  });

  test('une connaissance maîtrisée ne revient pas dans deux parties consécutives',
      () async {
    final GeoBrainProfile profile = profileWith(regularSuccesses('FRA'));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect(await GeoBrainStorage.save(profile), isTrue);
    final GeoBrainService service = await GeoBrainService.create();
    final List<String> ids = <String>[
      'FRA',
      'ESP',
      'ITA',
      'PRT',
      'DEU',
      'BEL',
      'NLD',
      'CHE',
      'AUT',
      'POL',
      'CZE',
      'SVK',
      'HUN',
      'ROU',
      'BGR',
      'GRC',
      'HRV',
      'SRB',
      'ALB',
      'BIH',
    ];
    final CountrySelector selector = CountrySelector(
      geoBrain: service,
      random: Random(26),
    );
    final List<GeoCountry> catalog =
        ids.map<GeoCountry>((String id) => country(id)).toList();
    final Set<String> first = selector
        .selectCountries(
          availableCountries: catalog,
          questionCount: 6,
          theme: GeoBrainTheme.location,
          now: now,
        )
        .map<String>((GeoCountry value) => value.id)
        .toSet();
    final Set<String> second = selector
        .selectCountries(
          availableCountries: catalog,
          questionCount: 6,
          theme: GeoBrainTheme.location,
          now: now,
        )
        .map<String>((GeoCountry value) => value.id)
        .toSet();

    expect(first, contains('FRA'));
    expect(second, isNot(contains('FRA')));
    expect(first.intersection(second), isEmpty);
  });
}
