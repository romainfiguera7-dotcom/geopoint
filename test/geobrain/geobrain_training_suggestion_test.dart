import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';
import 'package:geopoint/geobrain/geobrain_training_suggestion.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 31, 12);

  GeoCountry country(String id, String continent) {
    return GeoCountry(
      id: id,
      isoA2: 'FR',
      name: id,
      continent: continent,
      polygons: const [],
    );
  }

  CountryMastery learned({
    required String id,
    required GeoBrainTheme theme,
    required bool isCorrect,
    int daysAgo = 2,
  }) {
    return CountryMastery.initial(id).registerAttempt(
      GeoBrainAttempt(
        countryId: id,
        theme: theme,
        answeredAt: now.subtract(Duration(days: daysAgo)),
        modeId: theme.id,
        difficultyId: 'intermediate',
        isCorrect: isCorrect,
        context: GeoBrainAttemptContext.training,
      ),
    );
  }

  GeoBrainProfile profile(Map<String, CountryMastery> countries) {
    return GeoBrainProfile(
      schemaVersion: GeoBrainProfile.currentSchemaVersion,
      countries: countries,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );
  }

  final List<GeoCountry> catalog = <GeoCountry>[
    country('ALB', 'Europe'),
    country('BIH', 'Europe'),
    country('EGY', 'Africa'),
    country('NGA', 'Africa'),
    country('FRA', 'Europe'),
    country('ESP', 'Europe'),
    country('AUS', 'Oceania'),
    country('NZL', 'Oceania'),
    country('PNG', 'Oceania'),
    country('FJI', 'Oceania'),
    country('SLB', 'Oceania'),
  ];

  test('GeoBrain génère les quatre suggestions pédagogiques attendues', () {
    final GeoBrainProfile value = profile(<String, CountryMastery>{
      'ALB': learned(
        id: 'ALB',
        theme: GeoBrainTheme.location,
        isCorrect: false,
      ),
      'BIH': learned(
        id: 'BIH',
        theme: GeoBrainTheme.location,
        isCorrect: false,
      ),
      'EGY': learned(
        id: 'EGY',
        theme: GeoBrainTheme.flag,
        isCorrect: false,
      ),
      'NGA': learned(
        id: 'NGA',
        theme: GeoBrainTheme.flag,
        isCorrect: false,
      ),
      'FRA': learned(
        id: 'FRA',
        theme: GeoBrainTheme.capital,
        isCorrect: true,
      ),
      'ESP': learned(
        id: 'ESP',
        theme: GeoBrainTheme.capital,
        isCorrect: true,
      ),
    });
    final List<GeoBrainTrainingSuggestion> suggestions =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: value,
      countries: catalog,
      now: now,
      maximumSuggestions: 4,
    );

    expect(
      suggestions.map<String>((GeoBrainTrainingSuggestion item) => item.id),
      <String>[
        'review_balkans',
        'review_africa_flags',
        'confirm_recent_capitals',
        'discover_oceania_five',
      ],
    );
  });

  test('chaque suggestion transporte une vraie séance préconfigurée', () {
    final GeoBrainProfile value = profile(<String, CountryMastery>{
      'ALB': learned(
        id: 'ALB',
        theme: GeoBrainTheme.location,
        isCorrect: false,
      ),
      'BIH': learned(
        id: 'BIH',
        theme: GeoBrainTheme.location,
        isCorrect: false,
      ),
    });
    final List<GeoBrainTrainingSuggestion> suggestions =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: value,
      countries: catalog,
      now: now,
      maximumSuggestions: 4,
    );
    final GeoBrainTrainingSuggestion balkans = suggestions.firstWhere(
      (GeoBrainTrainingSuggestion item) => item.id == 'review_balkans',
    );
    final GeoBrainTrainingSuggestion oceania = suggestions.firstWhere(
      (GeoBrainTrainingSuggestion item) => item.id == 'discover_oceania_five',
    );

    expect(balkans.modeId, 'mixed');
    expect(balkans.regionId, 'europe');
    expect(balkans.countryIds, <String>{'ALB', 'BIH'});
    expect(balkans.reviewDifficultiesOnly, isTrue);
    expect(oceania.modeId, 'find_country');
    expect(oceania.regionId, 'oceania');
    expect(oceania.questionCount, 5);
    expect(oceania.countryIds, <String>{'AUS', 'NZL', 'PNG', 'FJI', 'SLB'});
  });

  test('ignorer une suggestion ne modifie pas le profil GeoBrain', () {
    final GeoBrainProfile value = profile(<String, CountryMastery>{
      'ALB': learned(
        id: 'ALB',
        theme: GeoBrainTheme.location,
        isCorrect: false,
      ),
      'BIH': learned(
        id: 'BIH',
        theme: GeoBrainTheme.location,
        isCorrect: false,
      ),
    });
    final int attemptsBefore = value.totalAttempts;
    final List<GeoBrainTrainingSuggestion> suggestions =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: value,
      countries: catalog,
      now: now,
      ignoredSuggestionIds: const <String>{'review_balkans'},
      maximumSuggestions: 4,
    );

    expect(
      suggestions.any(
        (GeoBrainTrainingSuggestion item) => item.id == 'review_balkans',
      ),
      isFalse,
    );
    expect(value.totalAttempts, attemptsBefore);
  });

  test('les capitales de plus de sept jours ne sont plus dites récentes', () {
    final GeoBrainProfile value = profile(<String, CountryMastery>{
      'FRA': learned(
        id: 'FRA',
        theme: GeoBrainTheme.capital,
        isCorrect: true,
        daysAgo: 8,
      ),
      'ESP': learned(
        id: 'ESP',
        theme: GeoBrainTheme.capital,
        isCorrect: true,
        daysAgo: 8,
      ),
    });
    final List<GeoBrainTrainingSuggestion> suggestions =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: value,
      countries: catalog,
      now: now,
      maximumSuggestions: 4,
    );

    expect(
      suggestions.any(
        (GeoBrainTrainingSuggestion item) =>
            item.id == 'confirm_recent_capitals',
      ),
      isFalse,
    );
  });

  test('chaque proposition explique positivement pourquoi elle apparaît', () {
    final List<GeoBrainTrainingSuggestion> suggestions =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: profile(const <String, CountryMastery>{}),
      countries: catalog,
      now: now,
      maximumSuggestions: 4,
    );

    expect(suggestions, isNotEmpty);
    expect(
      suggestions.every(
        (GeoBrainTrainingSuggestion item) =>
            item.title.trim().isNotEmpty && item.reason.trim().isNotEmpty,
      ),
      isTrue,
    );
  });
}
