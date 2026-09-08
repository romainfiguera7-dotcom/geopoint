import '../geo_engine/geo_entity_id.dart';
import 'country_mastery.dart';
import 'geobrain_attempt.dart';
import 'geobrain_theme.dart';
import 'theme_mastery.dart';

class GeoBrainProfile {
  const GeoBrainProfile({
    required this.schemaVersion,
    required this.countries,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int currentSchemaVersion = 5;

  /// Nombre maximal d’étoiles par pays.
  static const int maximumMasteryPerCountry =
      CountryMastery.maximumMasteryLevel;

  final int schemaVersion;

  /// Progression enregistrée par identifiant de pays.
  final Map<String, CountryMastery> countries;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory GeoBrainProfile.initial({
    DateTime? createdAt,
  }) {
    final DateTime now =
        createdAt ?? DateTime.now();

    return GeoBrainProfile(
      schemaVersion: currentSchemaVersion,
      countries:
          const <String, CountryMastery>{},
      createdAt: now,
      updatedAt: now,
    );
  }

  int get trackedCountryCount {
    return countries.length;
  }

  int get seenCountryCount {
    return countries.values
        .where(
          (CountryMastery mastery) =>
              mastery.hasBeenSeen,
        )
        .length;
  }

  int get masteredCountryCount {
    return countries.values
        .where(
          (CountryMastery mastery) =>
              mastery.isMastered,
        )
        .length;
  }

  int masteredCountryCountAt(DateTime now) {
    return countries.values
        .where(
          (CountryMastery mastery) =>
              mastery.statusAt(now) == GeoBrainMasteryStatus.mastered,
        )
        .length;
  }

  int get wishlistedCountryCount {
    return countries.values
        .where(
          (CountryMastery mastery) =>
              mastery.isWishlisted,
        )
        .length;
  }

  int get visitedCountryCount {
    return countries.values
        .where(
          (CountryMastery mastery) =>
              mastery.isVisited,
        )
        .length;
  }

  int get totalAttempts {
    return countries.values.fold<int>(
      0,
      (
        int total,
        CountryMastery mastery,
      ) {
        return total +
            mastery.totalAttempts;
      },
    );
  }

  int get totalCorrectAnswers {
    return countries.values.fold<int>(
      0,
      (
        int total,
        CountryMastery mastery,
      ) {
        return total +
            mastery.correctAnswers;
      },
    );
  }

  int get totalWrongAnswers {
    return countries.values.fold<int>(
      0,
      (
        int total,
        CountryMastery mastery,
      ) {
        return total +
            mastery.wrongAnswers;
      },
    );
  }

  int get detailedAttemptCount {
    return countries.values.fold<int>(
      0,
      (int total, CountryMastery mastery) => total + mastery.attempts.length,
    );
  }

  List<GeoBrainAttempt> get attemptHistory {
    final List<GeoBrainAttempt> result = countries.values
        .expand<GeoBrainAttempt>(
          (CountryMastery mastery) => mastery.attempts,
        )
        .toList(growable: false)
      ..sort(
        (GeoBrainAttempt a, GeoBrainAttempt b) =>
            a.answeredAt.compareTo(b.answeredAt),
      );
    return List<GeoBrainAttempt>.unmodifiable(result);
  }

  double get globalAccuracy {
    if (totalAttempts <= 0) {
      return 0;
    }

    return totalCorrectAnswers /
        totalAttempts;
  }

  double get globalMasteryScore {
    final List<CountryMastery> seen = countries.values
        .where((CountryMastery mastery) => mastery.hasBeenSeen)
        .toList(growable: false);
    if (seen.isEmpty) {
      return 0;
    }
    return seen.fold<double>(
          0,
          (double total, CountryMastery mastery) =>
              total + mastery.generalScore,
        ) /
        seen.length;
  }

  double globalRetainedMasteryScoreAt(DateTime now) {
    final List<CountryMastery> seen = countries.values
        .where((CountryMastery mastery) => mastery.hasBeenSeen)
        .toList(growable: false);
    if (seen.isEmpty) {
      return 0;
    }
    return seen.fold<double>(
          0,
          (double total, CountryMastery mastery) =>
              total + mastery.retainedGeneralScoreAt(now),
        ) /
        seen.length;
  }

  double masteryScoreForTheme(GeoBrainTheme theme) {
    final List<ThemeMastery> values = countries.values
        .map<ThemeMastery>(
          (CountryMastery mastery) => mastery.masteryForTheme(theme),
        )
        .where((ThemeMastery mastery) => mastery.hasBeenSeen)
        .toList(growable: false);
    if (values.isEmpty) {
      return 0;
    }
    return values.fold<double>(
          0,
          (double total, ThemeMastery mastery) => total + mastery.score,
        ) /
        values.length;
  }

  double retainedMasteryScoreForThemeAt(
    GeoBrainTheme theme,
    DateTime now,
  ) {
    final List<CountryMastery> values = countries.values
        .where(
          (CountryMastery mastery) =>
              mastery.masteryForTheme(theme).hasBeenSeen,
        )
        .toList(growable: false);
    if (values.isEmpty) {
      return 0;
    }
    return values.fold<double>(
          0,
          (double total, CountryMastery mastery) =>
              total + mastery.retentionForTheme(theme, now).retainedScore,
        ) /
        values.length;
  }

  int reviewCountryCountAt(DateTime now) {
    return countriesDueForReviewAt(now).length;
  }

  /// Nombre total d’étoiles obtenues.
  int get totalMasteryPoints {
    return countries.values.fold<int>(
      0,
      (
        int total,
        CountryMastery mastery,
      ) {
        return total +
            mastery.masteryLevel;
      },
    );
  }

  CountryMastery masteryFor(
    String countryId,
  ) {
    final String normalizedId =
        _normalizeCountryId(
      countryId,
    );

    return countries[normalizedId] ??
        CountryMastery.initial(
          normalizedId,
        );
  }

  bool hasSeenCountry(
    String countryId,
  ) {
    return masteryFor(
      countryId,
    ).hasBeenSeen;
  }

  GeoBrainProfile registerAnswer({
    required String countryId,
    required bool isCorrect,
    DateTime? answeredAt,
  }) {
    final String normalizedId =
        _normalizeCountryId(
      countryId,
    );

    final CountryMastery currentMastery =
        masteryFor(
      normalizedId,
    );

    final CountryMastery updatedMastery =
        currentMastery.registerAnswer(
      isCorrect: isCorrect,
      answeredAt: answeredAt,
    );

    return _replaceCountry(
      updatedMastery,
      updatedAt:
          answeredAt ?? DateTime.now(),
    );
  }

  GeoBrainProfile registerAttempt(GeoBrainAttempt source) {
    final GeoBrainAttempt attempt = source.normalized();
    final CountryMastery updatedMastery =
        masteryFor(attempt.countryId).registerAttempt(attempt);
    return _replaceCountry(
      updatedMastery,
      updatedAt: attempt.answeredAt,
    );
  }

  GeoBrainProfile toggleWishlist(
    String countryId,
  ) {
    final CountryMastery updatedMastery =
        masteryFor(
      countryId,
    ).toggleWishlist();

    return _replaceCountry(
      updatedMastery,
    );
  }

  GeoBrainProfile markVisited({
    required String countryId,
    required bool visited,
  }) {
    final CountryMastery updatedMastery =
        masteryFor(
      countryId,
    ).markVisited(
      visited,
    );

    return _replaceCountry(
      updatedMastery,
    );
  }

  List<CountryMastery> countriesDueForReviewAt(DateTime now) {
    final List<CountryMastery> result =
        countries.values
            .where(
              (CountryMastery mastery) =>
                  mastery.hasBeenSeen &&
                  mastery.needsReviewAt(now),
            )
            .toList();

    result.sort(
      (
        CountryMastery a,
        CountryMastery b,
      ) {
        final int repeatedComparison =
            (b.hasRepeatedForgettingAt(now) ? 1 : 0).compareTo(
          a.hasRepeatedForgettingAt(now) ? 1 : 0,
        );
        if (repeatedComparison != 0) {
          return repeatedComparison;
        }

        final int scoreComparison = a
            .retainedGeneralScoreAt(now)
            .compareTo(b.retainedGeneralScoreAt(now));
        if (scoreComparison != 0) {
          return scoreComparison;
        }

        final DateTime? aDate =
            a.nextReviewAt;

        final DateTime? bDate =
            b.nextReviewAt;

        if (aDate == null &&
            bDate == null) {
          return a.masteryLevel.compareTo(
            b.masteryLevel,
          );
        }

        if (aDate == null) {
          return -1;
        }

        if (bDate == null) {
          return 1;
        }

        final int dateComparison =
            aDate.compareTo(
          bDate,
        );

        if (dateComparison != 0) {
          return dateComparison;
        }

        return a.masteryLevel.compareTo(
          b.masteryLevel,
        );
      },
    );

    return List<CountryMastery>.unmodifiable(
      result,
    );
  }

  List<CountryMastery> get countriesDueForReview {
    return countriesDueForReviewAt(DateTime.now());
  }

  List<CountryMastery> get weakestCountries {
    final List<CountryMastery> result =
        countries.values
            .where(
              (CountryMastery mastery) =>
                  mastery.hasBeenSeen,
            )
            .toList();

    result.sort(
      (
        CountryMastery a,
        CountryMastery b,
      ) {
        final int masteryComparison =
            a.masteryLevel.compareTo(
          b.masteryLevel,
        );

        if (masteryComparison != 0) {
          return masteryComparison;
        }

        final int accuracyComparison =
            a.accuracy.compareTo(
          b.accuracy,
        );

        if (accuracyComparison != 0) {
          return accuracyComparison;
        }

        return b.totalAttempts.compareTo(
          a.totalAttempts,
        );
      },
    );

    return List<CountryMastery>.unmodifiable(
      result,
    );
  }

  List<CountryMastery> get strongestCountries {
    final List<CountryMastery> result =
        countries.values
            .where(
              (CountryMastery mastery) =>
                  mastery.hasBeenSeen,
            )
            .toList();

    result.sort(
      (
        CountryMastery a,
        CountryMastery b,
      ) {
        final int masteryComparison =
            b.masteryLevel.compareTo(
          a.masteryLevel,
        );

        if (masteryComparison != 0) {
          return masteryComparison;
        }

        final int accuracyComparison =
            b.accuracy.compareTo(
          a.accuracy,
        );

        if (accuracyComparison != 0) {
          return accuracyComparison;
        }

        return b.totalAttempts.compareTo(
          a.totalAttempts,
        );
      },
    );

    return List<CountryMastery>.unmodifiable(
      result,
    );
  }

  List<CountryMastery> get wishlistedCountries {
    final List<CountryMastery> result =
        countries.values
            .where(
              (CountryMastery mastery) =>
                  mastery.isWishlisted,
            )
            .toList();

    result.sort(
      (
        CountryMastery a,
        CountryMastery b,
      ) {
        return a.countryId.compareTo(
          b.countryId,
        );
      },
    );

    return List<CountryMastery>.unmodifiable(
      result,
    );
  }

  List<CountryMastery> get visitedCountries {
    final List<CountryMastery> result =
        countries.values
            .where(
              (CountryMastery mastery) =>
                  mastery.isVisited,
            )
            .toList();

    result.sort(
      (
        CountryMastery a,
        CountryMastery b,
      ) {
        return a.countryId.compareTo(
          b.countryId,
        );
      },
    );

    return List<CountryMastery>.unmodifiable(
      result,
    );
  }

  int masteryPointsForCountryIds(
    Iterable<String> countryIds,
  ) {
    int points = 0;

    for (final String countryId
        in countryIds) {
      points +=
          masteryFor(
        countryId,
      ).masteryLevel;
    }

    return points;
  }

  double masteryPercentageForCountryIds(
    Iterable<String> countryIds,
  ) {
    final Set<String> normalizedIds =
        countryIds
            .map<String>(
              _normalizeCountryId,
            )
            .toSet();

    if (normalizedIds.isEmpty) {
      return 0;
    }

    final int earnedPoints =
        masteryPointsForCountryIds(
      normalizedIds,
    );

    final int maximumPoints =
        normalizedIds.length *
            maximumMasteryPerCountry;

    if (maximumPoints <= 0) {
      return 0;
    }

    return (
      earnedPoints / maximumPoints
    ).clamp(
      0,
      1,
    );
  }

  double worldMasteryPercentage({
    required int totalCountryCount,
  }) {
    if (totalCountryCount <= 0) {
      return 0;
    }

    final int maximumPoints =
        totalCountryCount *
            maximumMasteryPerCountry;

    return (
      totalMasteryPoints /
      maximumPoints
    ).clamp(
      0,
      1,
    );
  }

  int countCountriesAtMasteryLevel(
    int masteryLevel,
  ) {
    final int normalizedLevel =
        masteryLevel.clamp(
      CountryMastery.minimumMasteryLevel,
      CountryMastery.maximumMasteryLevel,
    );

    return countries.values
        .where(
          (CountryMastery mastery) =>
              mastery.masteryLevel ==
                  normalizedLevel,
        )
        .length;
  }

  GeoBrainProfile _replaceCountry(
    CountryMastery mastery, {
    DateTime? updatedAt,
  }) {
    final Map<String, CountryMastery>
        updatedCountries =
        Map<String, CountryMastery>.from(
      countries,
    );

    updatedCountries[mastery.countryId] =
        mastery;

    return GeoBrainProfile(
      schemaVersion:
          currentSchemaVersion,
      countries:
          Map<String, CountryMastery>.unmodifiable(
        updatedCountries,
      ),
      createdAt: createdAt,
      updatedAt:
          updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic>
        serializedCountries =
        <String, dynamic>{};

    for (final MapEntry<
        String,
        CountryMastery> entry
        in countries.entries) {
      serializedCountries[entry.key] =
          entry.value.toJson();
    }

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'countries': serializedCountries,
      'createdAt':
          createdAt.toIso8601String(),
      'updatedAt':
          updatedAt.toIso8601String(),
    };
  }

  factory GeoBrainProfile.fromJson(
    Map<String, dynamic> json,
  ) {
    final DateTime now =
        DateTime.now();

    final Map<String, CountryMastery>
        countries =
        <String, CountryMastery>{};

    final Object? rawCountries =
        json['countries'];

    if (rawCountries is Map) {
      for (final MapEntry<dynamic, dynamic>
          entry in rawCountries.entries) {
        if (entry.value is! Map) {
          continue;
        }

        final Map<String, dynamic>
            countryJson =
            (entry.value as Map)
                .map<String, dynamic>(
          (
            dynamic key,
            dynamic value,
          ) {
            return MapEntry<String, dynamic>(
              key.toString(),
              value,
            );
          },
        );

        try {
          final CountryMastery mastery =
              CountryMastery.fromJson(
            countryJson,
          );

          countries[mastery.countryId] =
              mastery;
        } on FormatException {
          continue;
        }
      }
    }

    return GeoBrainProfile(
      schemaVersion: currentSchemaVersion,
      countries:
          Map<String, CountryMastery>.unmodifiable(
        countries,
      ),
      createdAt: _readDateTime(
        json['createdAt'],
        fallback: now,
      ),
      updatedAt: _readDateTime(
        json['updatedAt'],
        fallback: now,
      ),
    );
  }

  static String _normalizeCountryId(
    String countryId,
  ) {
    return GeoEntityId.require(countryId);
  }

  static DateTime _readDateTime(
    Object? value, {
    required DateTime fallback,
  }) {
    final String text =
        value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return fallback;
    }

    return DateTime.tryParse(
          text,
        ) ??
        fallback;
  }

  @override
  String toString() {
    return 'GeoBrainProfile('
        'trackedCountryCount: '
        '$trackedCountryCount, '
        'seenCountryCount: '
        '$seenCountryCount, '
        'masteredCountryCount: '
        '$masteredCountryCount, '
        'worldAttempts: '
        '$totalAttempts, '
        'detailedAttempts: '
        '$detailedAttemptCount'
        ')';
  }
}
