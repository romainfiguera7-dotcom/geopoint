import '../geo_engine/geo_country.dart';
import '../passport/progress/passport_continent.dart';
import 'country_mastery.dart';
import 'geobrain_profile.dart';
import 'geobrain_theme.dart';
import 'geobrain_training_suggestion.dart';
import 'theme_mastery.dart';

class GeoBrainThemeProgress {
  const GeoBrainThemeProgress({
    required this.theme,
    required this.retainedScore,
    required this.seenCountryCount,
    required this.reviewCountryCount,
  });

  final GeoBrainTheme theme;
  final double retainedScore;
  final int seenCountryCount;
  final int reviewCountryCount;
}

class GeoBrainContinentProgress {
  const GeoBrainContinentProgress({
    required this.continent,
    required this.retainedScore,
    required this.seenCountryCount,
    required this.totalCountryCount,
    required this.masteredCountryCount,
    required this.reviewCountryCount,
  });

  final PassportContinent continent;
  final double retainedScore;
  final int seenCountryCount;
  final int totalCountryCount;
  final int masteredCountryCount;
  final int reviewCountryCount;
}

class GeoBrainCountryThemeSnapshot {
  const GeoBrainCountryThemeSnapshot({
    required this.theme,
    required this.status,
    required this.retainedScore,
    required this.totalAttempts,
    required this.needsReview,
  });

  final GeoBrainTheme theme;
  final GeoBrainMasteryStatus status;
  final double retainedScore;
  final int totalAttempts;
  final bool needsReview;
}

class GeoBrainCountrySnapshot {
  const GeoBrainCountrySnapshot({
    required this.countryId,
    required this.countryName,
    required this.flagEmoji,
    required this.continent,
    required this.status,
    required this.retainedScore,
    required this.totalAttempts,
    required this.accuracy,
    required this.needsReview,
    required this.themeProgress,
  });

  final String countryId;
  final String countryName;
  final String flagEmoji;
  final PassportContinent? continent;
  final GeoBrainMasteryStatus status;
  final double retainedScore;
  final int totalAttempts;
  final double accuracy;
  final bool needsReview;
  final List<GeoBrainCountryThemeSnapshot> themeProgress;
}

class GeoBrainDashboardSnapshot {
  const GeoBrainDashboardSnapshot({
    required this.globalRetainedScore,
    required this.seenCountryCount,
    required this.masteredCountryCount,
    required this.reviewCountryCount,
    required this.totalAttempts,
    required this.globalAccuracy,
    required this.themes,
    required this.continents,
    required this.strengths,
    required this.reviewCountries,
    required this.countries,
    required this.nextSuggestion,
  });

  final double globalRetainedScore;
  final int seenCountryCount;
  final int masteredCountryCount;
  final int reviewCountryCount;
  final int totalAttempts;
  final double globalAccuracy;
  final List<GeoBrainThemeProgress> themes;
  final List<GeoBrainContinentProgress> continents;
  final List<GeoBrainThemeProgress> strengths;
  final List<GeoBrainCountrySnapshot> reviewCountries;
  final List<GeoBrainCountrySnapshot> countries;
  final GeoBrainTrainingSuggestion? nextSuggestion;
}

class GeoBrainDashboardBuilder {
  const GeoBrainDashboardBuilder();

  GeoBrainDashboardSnapshot build({
    required GeoBrainProfile profile,
    required List<GeoCountry> countries,
    required DateTime now,
  }) {
    final Map<String, GeoCountry> uniqueCountries = <String, GeoCountry>{
      for (final GeoCountry country in countries)
        country.id.trim().toUpperCase(): country,
    };
    uniqueCountries.removeWhere((String id, GeoCountry country) => id.isEmpty);

    final List<GeoBrainCountrySnapshot> countrySnapshots = uniqueCountries.values
        .map<GeoBrainCountrySnapshot>(
          (GeoCountry country) => _countrySnapshot(
            country: country,
            mastery: profile.masteryFor(country.id),
            now: now,
          ),
        )
        .toList(growable: false)
      ..sort(
        (GeoBrainCountrySnapshot first, GeoBrainCountrySnapshot second) =>
            first.countryName.compareTo(second.countryName),
      );

    final List<GeoBrainThemeProgress> themes = GeoBrainTheme.values
        .map<GeoBrainThemeProgress>(
          (GeoBrainTheme theme) => _themeProgress(
            profile: profile,
            theme: theme,
            now: now,
          ),
        )
        .toList(growable: false);
    final List<GeoBrainThemeProgress> strengths = themes
        .where((GeoBrainThemeProgress progress) => progress.seenCountryCount > 0)
        .toList()
      ..sort(
        (GeoBrainThemeProgress first, GeoBrainThemeProgress second) {
          final int scoreComparison =
              second.retainedScore.compareTo(first.retainedScore);
          if (scoreComparison != 0) {
            return scoreComparison;
          }
          return second.seenCountryCount.compareTo(first.seenCountryCount);
        },
      );

    final List<GeoBrainCountrySnapshot> reviewCountries = countrySnapshots
        .where((GeoBrainCountrySnapshot country) => country.needsReview)
        .toList()
      ..sort(
        (GeoBrainCountrySnapshot first, GeoBrainCountrySnapshot second) =>
            first.retainedScore.compareTo(second.retainedScore),
      );

    final List<GeoBrainTrainingSuggestion> suggestions =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: profile,
      countries: uniqueCountries.values.toList(growable: false),
      now: now,
      maximumSuggestions: 1,
    );

    return GeoBrainDashboardSnapshot(
      globalRetainedScore: profile.globalRetainedMasteryScoreAt(now),
      seenCountryCount: profile.seenCountryCount,
      masteredCountryCount: profile.masteredCountryCountAt(now),
      reviewCountryCount: reviewCountries.length,
      totalAttempts: profile.totalAttempts,
      globalAccuracy: profile.globalAccuracy,
      themes: List<GeoBrainThemeProgress>.unmodifiable(themes),
      continents: List<GeoBrainContinentProgress>.unmodifiable(
        _continentProgress(countrySnapshots),
      ),
      strengths: List<GeoBrainThemeProgress>.unmodifiable(strengths.take(3)),
      reviewCountries:
          List<GeoBrainCountrySnapshot>.unmodifiable(reviewCountries),
      countries: List<GeoBrainCountrySnapshot>.unmodifiable(countrySnapshots),
      nextSuggestion: suggestions.isEmpty ? null : suggestions.first,
    );
  }

  GeoBrainThemeProgress _themeProgress({
    required GeoBrainProfile profile,
    required GeoBrainTheme theme,
    required DateTime now,
  }) {
    final List<CountryMastery> seen = profile.countries.values
        .where(
          (CountryMastery mastery) =>
              mastery.masteryForTheme(theme).hasBeenSeen,
        )
        .toList(growable: false);
    final int reviewCount = seen
        .where(
          (CountryMastery mastery) => mastery.themeNeedsReviewAt(theme, now),
        )
        .length;
    return GeoBrainThemeProgress(
      theme: theme,
      retainedScore: profile.retainedMasteryScoreForThemeAt(theme, now),
      seenCountryCount: seen.length,
      reviewCountryCount: reviewCount,
    );
  }

  List<GeoBrainContinentProgress> _continentProgress(
    List<GeoBrainCountrySnapshot> countries,
  ) {
    return PassportContinent.values.map<GeoBrainContinentProgress>(
      (PassportContinent continent) {
        final List<GeoBrainCountrySnapshot> continentCountries = countries
            .where(
              (GeoBrainCountrySnapshot country) =>
                  country.continent == continent,
            )
            .toList(growable: false);
        final List<GeoBrainCountrySnapshot> seen = continentCountries
            .where(
              (GeoBrainCountrySnapshot country) => country.totalAttempts > 0,
            )
            .toList(growable: false);
        final double score = seen.isEmpty
            ? 0
            : seen.fold<double>(
                  0,
                  (double total, GeoBrainCountrySnapshot country) =>
                      total + country.retainedScore,
                ) /
                seen.length;
        return GeoBrainContinentProgress(
          continent: continent,
          retainedScore: score,
          seenCountryCount: seen.length,
          totalCountryCount: continentCountries.length,
          masteredCountryCount: seen
              .where(
                (GeoBrainCountrySnapshot country) =>
                    country.status == GeoBrainMasteryStatus.mastered,
              )
              .length,
          reviewCountryCount: seen
              .where((GeoBrainCountrySnapshot country) => country.needsReview)
              .length,
        );
      },
    ).toList(growable: false);
  }

  GeoBrainCountrySnapshot _countrySnapshot({
    required GeoCountry country,
    required CountryMastery mastery,
    required DateTime now,
  }) {
    final List<GeoBrainCountryThemeSnapshot> themes = GeoBrainTheme.values
        .map<GeoBrainCountryThemeSnapshot>((GeoBrainTheme theme) {
      final ThemeMastery themeMastery = mastery.masteryForTheme(theme);
      final double retainedScore =
          mastery.retentionForTheme(theme, now).retainedScore;
      return GeoBrainCountryThemeSnapshot(
        theme: theme,
        status: ThemeMastery.statusFor(
          score: retainedScore,
          totalAttempts: themeMastery.totalAttempts,
        ),
        retainedScore: retainedScore,
        totalAttempts: themeMastery.totalAttempts,
        needsReview: mastery.themeNeedsReviewAt(theme, now),
      );
    }).toList(growable: false);
    return GeoBrainCountrySnapshot(
      countryId: country.id.trim().toUpperCase(),
      countryName: country.name,
      flagEmoji: country.flagEmoji,
      continent: PassportContinent.forEntity(
        entityId: country.id,
        geoContinent: country.continent,
      ),
      status: mastery.statusAt(now),
      retainedScore: mastery.retainedGeneralScoreAt(now),
      totalAttempts: mastery.totalAttempts,
      accuracy: mastery.accuracy,
      needsReview: mastery.needsReviewAt(now),
      themeProgress: List<GeoBrainCountryThemeSnapshot>.unmodifiable(themes),
    );
  }
}
