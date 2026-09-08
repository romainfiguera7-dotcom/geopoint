import '../geo_engine/geo_entity_id.dart';
import 'geobrain_attempt.dart';
import 'geobrain_forgetting_calculator.dart';
import 'geobrain_theme.dart';
import 'theme_mastery.dart';

class CountryMastery {
  const CountryMastery({
    required this.countryId,
    required this.masteryLevel,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.totalAttempts,
    required this.currentStreak,
    required this.bestStreak,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    required this.isWishlisted,
    required this.isVisited,
    this.themeMasteries = const <GeoBrainTheme, ThemeMastery>{},
    this.attempts = const <GeoBrainAttempt>[],
  });

  static const int minimumMasteryLevel = 0;
  static const int maximumMasteryLevel = 5;

  final String countryId;

  /// Ancien niveau général conservé pour la compatibilité du Passeport.
  final int masteryLevel;
  final int correctAnswers;
  final int wrongAnswers;
  final int totalAttempts;
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final bool isWishlisted;
  final bool isVisited;

  /// Maîtrises indépendantes du point 26.1.
  final Map<GeoBrainTheme, ThemeMastery> themeMasteries;

  /// Historique détaillé des tentatives connues depuis le schéma 2.
  final List<GeoBrainAttempt> attempts;

  factory CountryMastery.initial(String countryId) {
    return CountryMastery(
      countryId: GeoEntityId.require(countryId),
      masteryLevel: minimumMasteryLevel,
      correctAnswers: 0,
      wrongAnswers: 0,
      totalAttempts: 0,
      currentStreak: 0,
      bestStreak: 0,
      lastReviewedAt: null,
      nextReviewAt: null,
      isWishlisted: false,
      isVisited: false,
    );
  }

  bool get hasBeenSeen => totalAttempts > 0;

  bool get isMastered => status == GeoBrainMasteryStatus.mastered;

  double get accuracy =>
      totalAttempts <= 0 ? 0 : correctAnswers / totalAttempts;

  double get generalScore {
    final List<ThemeMastery> available = themeMasteries.values
        .where((ThemeMastery mastery) => mastery.hasBeenSeen)
        .toList(growable: false);
    if (available.isEmpty) {
      return (masteryLevel.clamp(0, maximumMasteryLevel) * 20).toDouble();
    }
    final double total = available.fold<double>(
      0,
      (double sum, ThemeMastery mastery) => sum + mastery.score,
    );
    return total / available.length;
  }

  /// Calcule le score général sur les thèmes réellement disponibles pour
  /// l'élément. Un thème disponible mais encore inconnu compte pour zéro.
  double generalScoreFor(Iterable<GeoBrainTheme> availableThemes) {
    final Set<GeoBrainTheme> themes = availableThemes.toSet();
    if (themes.isEmpty) {
      return generalScore;
    }
    final double total = themes.fold<double>(
      0,
      (double sum, GeoBrainTheme theme) =>
          sum + masteryForTheme(theme).score,
    );
    return total / themes.length;
  }

  GeoBrainMasteryStatus get status {
    return ThemeMastery.statusFor(
      score: generalScore,
      totalAttempts: totalAttempts,
    );
  }

  GeoBrainForgettingEvaluation retentionForTheme(
    GeoBrainTheme theme,
    DateTime now,
  ) {
    return masteryForTheme(theme).retentionAt(
      now,
      attempts: attemptsForTheme(theme),
    );
  }

  double retainedGeneralScoreAt(DateTime now) {
    final List<GeoBrainTheme> available = themeMasteries.entries
        .where(
          (MapEntry<GeoBrainTheme, ThemeMastery> entry) =>
              entry.value.hasBeenSeen,
        )
        .map<GeoBrainTheme>(
          (MapEntry<GeoBrainTheme, ThemeMastery> entry) => entry.key,
        )
        .toList(growable: false);
    if (available.isEmpty) {
      return generalScore;
    }
    final double total = available.fold<double>(
      0,
      (double sum, GeoBrainTheme theme) =>
          sum + retentionForTheme(theme, now).retainedScore,
    );
    return total / available.length;
  }

  GeoBrainMasteryStatus statusAt(DateTime now) {
    return ThemeMastery.statusFor(
      score: retainedGeneralScoreAt(now),
      totalAttempts: totalAttempts,
    );
  }

  ThemeMastery masteryForTheme(GeoBrainTheme theme) {
    return themeMasteries[theme] ?? ThemeMastery.initial(theme);
  }

  List<GeoBrainAttempt> attemptsForTheme(GeoBrainTheme theme) {
    return List<GeoBrainAttempt>.unmodifiable(
      attempts.where((GeoBrainAttempt attempt) => attempt.theme == theme),
    );
  }

  bool isDueForReviewAt(DateTime now) {
    final List<ThemeMastery> seenThemes = themeMasteries.values
        .where((ThemeMastery mastery) => mastery.hasBeenSeen)
        .toList(growable: false);
    if (seenThemes.isNotEmpty) {
      return seenThemes.any(
        (ThemeMastery mastery) => mastery.isDueForReviewAt(now),
      );
    }
    final DateTime? reviewDate = nextReviewAt;
    return reviewDate == null || !reviewDate.isAfter(now);
  }

  bool get isDueForReview => isDueForReviewAt(DateTime.now());

  List<GeoBrainTheme> themesToReviewAt(DateTime now) {
    final List<GeoBrainTheme> result = themeMasteries.entries
        .where(
          (MapEntry<GeoBrainTheme, ThemeMastery> entry) =>
              entry.value.hasBeenSeen &&
              (entry.value.isDueForReviewAt(now) ||
                  retentionForTheme(entry.key, now).needsReview),
        )
        .map<GeoBrainTheme>(
          (MapEntry<GeoBrainTheme, ThemeMastery> entry) => entry.key,
        )
        .toList(growable: false);
    return List<GeoBrainTheme>.unmodifiable(result);
  }

  bool hasRepeatedForgettingAt(DateTime now) {
    return themeMasteries.keys.any(
      (GeoBrainTheme theme) =>
          retentionForTheme(theme, now).isRepeatedForgetting,
    );
  }

  bool needsReviewAt(DateTime now) {
    return hasBeenSeen &&
        (isDueForReviewAt(now) || themesToReviewAt(now).isNotEmpty);
  }

  bool themeNeedsReviewAt(GeoBrainTheme theme, DateTime now) {
    final ThemeMastery mastery = masteryForTheme(theme);
    return mastery.hasBeenSeen &&
        (mastery.isDueForReviewAt(now) ||
            retentionForTheme(theme, now).needsReview);
  }

  String reviewLabelAt(DateTime now) {
    return needsReviewAt(now) ? 'À réviser' : 'À jour';
  }

  String get starsLabel {
    final int level = masteryLevel.clamp(
      minimumMasteryLevel,
      maximumMasteryLevel,
    );
    return '${'★' * level}${'☆' * (maximumMasteryLevel - level)}';
  }

  CountryMastery registerAttempt(GeoBrainAttempt source) {
    final GeoBrainAttempt attempt = source.normalized();
    if (attempt.countryId != GeoEntityId.require(countryId)) {
      throw ArgumentError.value(
        attempt.countryId,
        'attempt.countryId',
        'La tentative ne correspond pas au pays de cette fiche.',
      );
    }

    final int updatedStreak = attempt.isCorrect ? currentStreak + 1 : 0;
    final int updatedBestStreak =
        updatedStreak > bestStreak ? updatedStreak : bestStreak;
    final Map<GeoBrainTheme, ThemeMastery> updatedThemes =
        Map<GeoBrainTheme, ThemeMastery>.from(themeMasteries);
    updatedThemes[attempt.theme] = masteryForTheme(attempt.theme).registerAttempt(
      attempt,
      previousDetailedAttempts: attemptsForTheme(attempt.theme),
    );
    final List<ThemeMastery> seenThemes = updatedThemes.values
        .where((ThemeMastery mastery) => mastery.hasBeenSeen)
        .toList(growable: false);
    final double updatedGeneralScore = seenThemes.isEmpty
        ? 0
        : seenThemes.fold<double>(
              0,
              (double sum, ThemeMastery mastery) => sum + mastery.score,
            ) /
            seenThemes.length;
    final GeoBrainMasteryStatus updatedStatus = ThemeMastery.statusFor(
      score: updatedGeneralScore,
      totalAttempts: totalAttempts + 1,
    );
    final int updatedMasteryLevel = _levelForStatus(updatedStatus);

    return copyWith(
      masteryLevel: updatedMasteryLevel,
      correctAnswers: correctAnswers + (attempt.isCorrect ? 1 : 0),
      wrongAnswers: wrongAnswers + (attempt.isCorrect ? 0 : 1),
      totalAttempts: totalAttempts + 1,
      currentStreak: updatedStreak,
      bestStreak: updatedBestStreak,
      lastReviewedAt: attempt.answeredAt,
      nextReviewAt: _earliestNextReviewAt(updatedThemes.values),
      themeMasteries: Map<GeoBrainTheme, ThemeMastery>.unmodifiable(
        updatedThemes,
      ),
      attempts: List<GeoBrainAttempt>.unmodifiable(
        <GeoBrainAttempt>[...attempts, attempt],
      ),
    );
  }

  /// Compatibilité avec les anciens appels. Les nouveaux flux doivent fournir
  /// une [GeoBrainAttempt] complète via [registerAttempt].
  CountryMastery registerAnswer({
    required bool isCorrect,
    DateTime? answeredAt,
  }) {
    return registerAttempt(
      GeoBrainAttempt(
        countryId: countryId,
        theme: GeoBrainTheme.location,
        answeredAt: answeredAt ?? DateTime.now(),
        modeId: 'legacy',
        difficultyId: 'unknown',
        isCorrect: isCorrect,
        context: GeoBrainAttemptContext.unknown,
      ),
    );
  }

  static int _levelForStatus(GeoBrainMasteryStatus status) {
    switch (status) {
      case GeoBrainMasteryStatus.unknown:
        return 0;
      case GeoBrainMasteryStatus.discovered:
        return 1;
      case GeoBrainMasteryStatus.fragile:
        return 2;
      case GeoBrainMasteryStatus.progressing:
        return 3;
      case GeoBrainMasteryStatus.acquired:
        return 4;
      case GeoBrainMasteryStatus.mastered:
        return 5;
    }
  }

  static DateTime? _earliestNextReviewAt(
    Iterable<ThemeMastery> masteries,
  ) {
    DateTime? earliest;
    for (final ThemeMastery mastery in masteries) {
      final DateTime? candidate = mastery.nextReviewAt;
      if (candidate != null &&
          (earliest == null || candidate.isBefore(earliest))) {
        earliest = candidate;
      }
    }
    return earliest;
  }

  CountryMastery toggleWishlist() {
    return copyWith(isWishlisted: !isWishlisted);
  }

  CountryMastery markVisited(bool visited) {
    return copyWith(
      isVisited: visited,
      isWishlisted: visited ? false : isWishlisted,
    );
  }

  CountryMastery copyWith({
    String? countryId,
    int? masteryLevel,
    int? correctAnswers,
    int? wrongAnswers,
    int? totalAttempts,
    int? currentStreak,
    int? bestStreak,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    bool? isWishlisted,
    bool? isVisited,
    Map<GeoBrainTheme, ThemeMastery>? themeMasteries,
    List<GeoBrainAttempt>? attempts,
    bool clearLastReviewedAt = false,
    bool clearNextReviewAt = false,
  }) {
    return CountryMastery(
      countryId: countryId ?? this.countryId,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastReviewedAt: clearLastReviewedAt
          ? null
          : lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt:
          clearNextReviewAt ? null : nextReviewAt ?? this.nextReviewAt,
      isWishlisted: isWishlisted ?? this.isWishlisted,
      isVisited: isVisited ?? this.isVisited,
      themeMasteries: themeMasteries ?? this.themeMasteries,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'countryId': countryId,
      'masteryLevel': masteryLevel,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'totalAttempts': totalAttempts,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'isWishlisted': isWishlisted,
      'isVisited': isVisited,
      'themeMasteries': <String, dynamic>{
        for (final MapEntry<GeoBrainTheme, ThemeMastery> entry
            in themeMasteries.entries)
          entry.key.id: entry.value.toJson(),
      },
      'attempts': attempts
          .map<Map<String, dynamic>>(
            (GeoBrainAttempt attempt) => attempt.toJson(),
          )
          .toList(growable: false),
    };
  }

  factory CountryMastery.fromJson(Map<String, dynamic> json) {
    final String countryId = GeoEntityId.normalize(
      json['countryId']?.toString() ?? '',
    );
    if (countryId.isEmpty) {
      throw const FormatException('countryId absent dans CountryMastery.');
    }

    final int attemptsCount =
        _readInt(json['totalAttempts']).clamp(0, 1 << 31);
    final int masteryLevel = _readInt(json['masteryLevel']).clamp(
      minimumMasteryLevel,
      maximumMasteryLevel,
    );
    final int correctAnswers =
        _readInt(json['correctAnswers']).clamp(0, attemptsCount);
    final int wrongAnswers =
        _readInt(json['wrongAnswers']).clamp(0, attemptsCount);
    final int currentStreak =
        _readInt(json['currentStreak']).clamp(0, attemptsCount);
    final int bestStreak =
        _readInt(json['bestStreak']).clamp(0, attemptsCount);
    final DateTime? lastReviewedAt = _readOptionalDateTime(
      json['lastReviewedAt'],
    );
    final DateTime? countryNextReviewAt = _readOptionalDateTime(
      json['nextReviewAt'],
    );

    final Map<GeoBrainTheme, ThemeMastery> themes =
        <GeoBrainTheme, ThemeMastery>{};
    final Object? rawThemes = json['themeMasteries'];
    if (rawThemes is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawThemes.entries) {
        if (entry.value is! Map) {
          continue;
        }
        final Map<String, dynamic> themeJson =
            _asStringMap(entry.value as Map);
        themeJson.putIfAbsent('theme', () => entry.key.toString());
        try {
          ThemeMastery mastery = ThemeMastery.fromJson(themeJson);
          if (themeJson['nextReviewAt'] == null &&
              countryNextReviewAt != null) {
            mastery = mastery.withNextReviewAt(countryNextReviewAt);
          }
          themes[mastery.theme] = mastery;
        } on FormatException {
          continue;
        }
      }
    }

    // Migration non destructive du schéma 1 : l'ancien GeoBrain mélangeait
    // pays et drapeaux. Le résumé est conservé et rattaché à la localisation.
    if (themes.isEmpty && attemptsCount > 0) {
      themes[GeoBrainTheme.location] = ThemeMastery.fromLegacy(
        theme: GeoBrainTheme.location,
        masteryLevel: masteryLevel,
        correctAnswers: correctAnswers,
        wrongAnswers: wrongAnswers,
        totalAttempts: attemptsCount,
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        lastReviewedAt: lastReviewedAt,
        nextReviewAt: countryNextReviewAt,
      );
    }

    final List<GeoBrainAttempt> history = <GeoBrainAttempt>[];
    final Object? rawAttempts = json['attempts'];
    if (rawAttempts is List) {
      for (final Object? value in rawAttempts) {
        if (value is! Map) {
          continue;
        }
        try {
          final GeoBrainAttempt attempt = GeoBrainAttempt.fromJson(
            _asStringMap(value),
          );
          if (attempt.countryId == countryId) {
            history.add(attempt);
          }
        } on FormatException {
          continue;
        }
      }
    }

    // Le schéma 2 ne séparait pas encore explicitement la base héritée de
    // l'historique détaillé. On l'infère une seule fois pour préserver le
    // niveau déjà acquis lors du passage au calcul pondéré du schéma 3.
    for (final MapEntry<GeoBrainTheme, ThemeMastery> entry
        in themes.entries.toList(growable: false)) {
      final int detailedCount = history
          .where((GeoBrainAttempt attempt) => attempt.theme == entry.key)
          .length;
      final ThemeMastery mastery = entry.value;
      if (mastery.legacyAttemptCount == 0 &&
          mastery.totalAttempts > detailedCount) {
        themes[entry.key] = mastery.withLegacyBaseline(
          score: mastery.score,
          attemptCount: mastery.totalAttempts - detailedCount,
        );
      }
    }

    return CountryMastery(
      countryId: countryId,
      masteryLevel: masteryLevel,
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      totalAttempts: attemptsCount,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastReviewedAt: lastReviewedAt,
      nextReviewAt: countryNextReviewAt ??
          _earliestNextReviewAt(themes.values),
      isWishlisted: _readBool(json['isWishlisted']),
      isVisited: _readBool(json['isVisited']),
      themeMasteries: Map<GeoBrainTheme, ThemeMastery>.unmodifiable(themes),
      attempts: List<GeoBrainAttempt>.unmodifiable(history),
    );
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    return value?.toString().trim().toLowerCase() == 'true';
  }

  static DateTime? _readOptionalDateTime(Object? value) {
    return DateTime.tryParse(value?.toString().trim() ?? '');
  }

  static Map<String, dynamic> _asStringMap(Map<dynamic, dynamic> source) {
    return source.map<String, dynamic>(
      (dynamic key, dynamic value) => MapEntry<String, dynamic>(
        key.toString(),
        value,
      ),
    );
  }

  @override
  String toString() {
    return 'CountryMastery('
        'countryId: $countryId, '
        'masteryLevel: $masteryLevel, '
        'generalScore: $generalScore, '
        'status: ${status.label}, '
        'accuracy: $accuracy, '
        'attempts: ${attempts.length}'
        ')';
  }
}
