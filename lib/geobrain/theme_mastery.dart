import 'geobrain_attempt.dart';
import 'geobrain_forgetting_calculator.dart';
import 'geobrain_mastery_calculator.dart';
import 'geobrain_review_scheduler.dart';
import 'geobrain_theme.dart';

class ThemeMastery {
  const ThemeMastery({
    required this.theme,
    required this.score,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.totalAttempts,
    required this.currentStreak,
    required this.bestStreak,
    required this.firstLearnedAt,
    required this.lastReviewedAt,
    required this.lastConfirmedAt,
    required this.highestScore,
    required this.nextReviewAt,
    required this.successfulReviewCount,
    this.legacyBaselineScore = 0,
    this.legacyAttemptCount = 0,
  });

  final GeoBrainTheme theme;

  /// Score de confiance compris entre 0 et 100, calculé par le moteur 26.3.
  final double score;
  final int correctAnswers;
  final int wrongAnswers;
  final int totalAttempts;
  final int currentStreak;
  final int bestStreak;
  final DateTime? firstLearnedAt;
  final DateTime? lastReviewedAt;
  final DateTime? lastConfirmedAt;
  final double highestScore;
  final DateTime? nextReviewAt;
  final int successfulReviewCount;
  final double legacyBaselineScore;
  final int legacyAttemptCount;

  factory ThemeMastery.initial(GeoBrainTheme theme) {
    return ThemeMastery(
      theme: theme,
      score: 0,
      correctAnswers: 0,
      wrongAnswers: 0,
      totalAttempts: 0,
      currentStreak: 0,
      bestStreak: 0,
      firstLearnedAt: null,
      lastReviewedAt: null,
      lastConfirmedAt: null,
      highestScore: 0,
      nextReviewAt: null,
      successfulReviewCount: 0,
    );
  }

  factory ThemeMastery.fromLegacy({
    required GeoBrainTheme theme,
    required int masteryLevel,
    required int correctAnswers,
    required int wrongAnswers,
    required int totalAttempts,
    required int currentStreak,
    required int bestStreak,
    required DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
  }) {
    final double legacyScore =
        (masteryLevel.clamp(0, 5) * 20).toDouble();
    final int reviewCount = _legacyReviewCount(
      masteryLevel: masteryLevel,
      currentStreak: currentStreak,
      wrongAnswers: wrongAnswers,
    );
    final DateTime? inferredNextReviewAt = nextReviewAt ??
        lastReviewedAt?.add(
          currentStreak <= 0 && wrongAnswers > 0
              ? const Duration(hours: 6)
              : GeoBrainReviewScheduler.intervalForSuccessfulReviewCount(
                  reviewCount,
                ),
        );
    return ThemeMastery(
      theme: theme,
      score: legacyScore,
      correctAnswers: correctAnswers.clamp(0, totalAttempts),
      wrongAnswers: wrongAnswers.clamp(0, totalAttempts),
      totalAttempts: totalAttempts.clamp(0, 1 << 31),
      currentStreak: currentStreak.clamp(0, 1 << 31),
      bestStreak: bestStreak.clamp(0, 1 << 31),
      firstLearnedAt: totalAttempts > 0 ? lastReviewedAt : null,
      lastReviewedAt: lastReviewedAt,
      lastConfirmedAt: correctAnswers > 0 ? lastReviewedAt : null,
      highestScore: legacyScore,
      nextReviewAt: inferredNextReviewAt,
      successfulReviewCount: reviewCount,
      legacyBaselineScore: legacyScore,
      legacyAttemptCount: totalAttempts.clamp(0, 1 << 31),
    );
  }

  bool get hasBeenSeen => totalAttempts > 0;

  double get accuracy =>
      totalAttempts == 0 ? 0 : correctAnswers / totalAttempts;

  GeoBrainMasteryStatus get status {
    return statusFor(score: score, totalAttempts: totalAttempts);
  }

  bool get isMastered => status == GeoBrainMasteryStatus.mastered;

  bool isDueForReviewAt(DateTime now) {
    final DateTime? reviewDate = nextReviewAt;
    return hasBeenSeen &&
        (reviewDate == null || !reviewDate.isAfter(now));
  }

  GeoBrainForgettingEvaluation retentionAt(
    DateTime now, {
    List<GeoBrainAttempt> attempts = const <GeoBrainAttempt>[],
  }) {
    return const GeoBrainForgettingCalculator().evaluate(
      score: score,
      highestScore: highestScore,
      totalAttempts: totalAttempts,
      now: now,
      lastReviewedAt: lastReviewedAt,
      lastConfirmedAt: lastConfirmedAt,
      attempts: attempts,
    );
  }

  double retainedScoreAt(
    DateTime now, {
    List<GeoBrainAttempt> attempts = const <GeoBrainAttempt>[],
  }) {
    return retentionAt(now, attempts: attempts).retainedScore;
  }

  ThemeMastery registerAttempt(
    GeoBrainAttempt source, {
    required List<GeoBrainAttempt> previousDetailedAttempts,
  }) {
    final GeoBrainAttempt attempt = source.normalized();
    if (attempt.theme != theme) {
      throw ArgumentError.value(
        attempt.theme,
        'attempt.theme',
        'Le thème de la tentative ne correspond pas à la maîtrise.',
      );
    }

    final int updatedStreak = attempt.isCorrect ? currentStreak + 1 : 0;
    final List<GeoBrainAttempt> detailedAttempts = <GeoBrainAttempt>[
      ...previousDetailedAttempts,
      attempt,
    ];
    final GeoBrainMasteryEvaluation evaluation =
        const GeoBrainMasteryCalculator().evaluate(
      attempts: detailedAttempts,
      now: attempt.answeredAt,
      legacyBaselineScore: legacyBaselineScore,
      legacyAttemptCount: legacyAttemptCount,
    );
    final GeoBrainReviewSchedule schedule =
        const GeoBrainReviewScheduler().schedule(
      attempt: attempt,
      previousSuccessfulReviewCount: successfulReviewCount,
      previousNextReviewAt: nextReviewAt,
    );

    return ThemeMastery(
      theme: theme,
      score: evaluation.score,
      correctAnswers: correctAnswers + (attempt.isCorrect ? 1 : 0),
      wrongAnswers: wrongAnswers + (attempt.isCorrect ? 0 : 1),
      totalAttempts: totalAttempts + 1,
      currentStreak: updatedStreak,
      bestStreak: updatedStreak > bestStreak ? updatedStreak : bestStreak,
      firstLearnedAt: firstLearnedAt ?? attempt.answeredAt,
      lastReviewedAt: attempt.answeredAt,
      lastConfirmedAt: schedule.isConfirmedSuccess
          ? attempt.answeredAt
          : lastConfirmedAt,
      highestScore: evaluation.score > highestScore
          ? evaluation.score
          : highestScore,
      nextReviewAt: schedule.nextReviewAt,
      successfulReviewCount: schedule.successfulReviewCount,
      legacyBaselineScore: legacyBaselineScore,
      legacyAttemptCount: legacyAttemptCount,
    );
  }

  ThemeMastery withLegacyBaseline({
    required double score,
    required int attemptCount,
  }) {
    return ThemeMastery(
      theme: theme,
      score: this.score,
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      totalAttempts: totalAttempts,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      firstLearnedAt: firstLearnedAt,
      lastReviewedAt: lastReviewedAt,
      lastConfirmedAt: lastConfirmedAt,
      highestScore: highestScore,
      nextReviewAt: nextReviewAt,
      successfulReviewCount: successfulReviewCount,
      legacyBaselineScore: score.clamp(0.0, 100.0),
      legacyAttemptCount: attemptCount.clamp(0, totalAttempts),
    );
  }

  ThemeMastery withNextReviewAt(DateTime value) {
    return ThemeMastery(
      theme: theme,
      score: score,
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      totalAttempts: totalAttempts,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      firstLearnedAt: firstLearnedAt,
      lastReviewedAt: lastReviewedAt,
      lastConfirmedAt: lastConfirmedAt,
      highestScore: highestScore,
      nextReviewAt: value,
      successfulReviewCount: successfulReviewCount,
      legacyBaselineScore: legacyBaselineScore,
      legacyAttemptCount: legacyAttemptCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'theme': theme.id,
      'score': score,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'totalAttempts': totalAttempts,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'firstLearnedAt': firstLearnedAt?.toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'lastConfirmedAt': lastConfirmedAt?.toIso8601String(),
      'highestScore': highestScore,
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'successfulReviewCount': successfulReviewCount,
      'legacyBaselineScore': legacyBaselineScore,
      'legacyAttemptCount': legacyAttemptCount,
    };
  }

  factory ThemeMastery.fromJson(Map<String, dynamic> json) {
    final GeoBrainTheme? theme = GeoBrainTheme.fromId(
      json['theme']?.toString() ?? '',
    );
    if (theme == null) {
      throw const FormatException('Thème GeoBrain inconnu.');
    }
    final int attempts = _readInt(json['totalAttempts']).clamp(0, 1 << 31);
    final int correct = _readInt(json['correctAnswers']).clamp(0, attempts);
    final int wrong = _readInt(json['wrongAnswers']).clamp(0, attempts);
    final double score = _readDouble(json['score']).clamp(0.0, 100.0);
    final double storedHighestScore = _readOptionalDouble(
          json['highestScore'],
        )?.clamp(0.0, 100.0) ??
        score;
    final DateTime? lastReviewedAt = _readDate(json['lastReviewedAt']);
    final int inferredReviewCount =
        GeoBrainReviewScheduler.inferredSuccessfulReviewCount(
      score: score,
      currentStreak: _readInt(json['currentStreak']),
      wrongAnswers: wrong,
    );
    final int reviewCount = _readOptionalInt(
          json['successfulReviewCount'],
        )?.clamp(0, GeoBrainReviewScheduler.maximumSuccessfulReviewCount) ??
        inferredReviewCount;
    final DateTime? storedNextReviewAt = _readDate(json['nextReviewAt']);
    final DateTime? inferredNextReviewAt = storedNextReviewAt ??
        (lastReviewedAt == null || attempts <= 0
            ? null
            : lastReviewedAt.add(
                _readInt(json['currentStreak']) <= 0 && wrong > 0
                    ? const Duration(hours: 6)
                    : GeoBrainReviewScheduler
                        .intervalForSuccessfulReviewCount(reviewCount),
              ));
    return ThemeMastery(
      theme: theme,
      score: score,
      correctAnswers: correct,
      wrongAnswers: wrong,
      totalAttempts: attempts,
      currentStreak: _readInt(json['currentStreak']).clamp(0, attempts),
      bestStreak: _readInt(json['bestStreak']).clamp(0, attempts),
      firstLearnedAt: _readDate(json['firstLearnedAt']),
      lastReviewedAt: lastReviewedAt,
      lastConfirmedAt: _readDate(json['lastConfirmedAt']) ??
          (correct > 0 ? lastReviewedAt : null),
      highestScore:
          storedHighestScore > score ? storedHighestScore : score,
      nextReviewAt: inferredNextReviewAt,
      successfulReviewCount: reviewCount,
      legacyBaselineScore: _readDouble(
        json['legacyBaselineScore'],
      ).clamp(0.0, 100.0),
      legacyAttemptCount: _readInt(
        json['legacyAttemptCount'],
      ).clamp(0, attempts),
    );
  }

  static GeoBrainMasteryStatus statusFor({
    required double score,
    required int totalAttempts,
  }) {
    if (totalAttempts <= 0) {
      return GeoBrainMasteryStatus.unknown;
    }
    if (score < 25) {
      return GeoBrainMasteryStatus.discovered;
    }
    if (score < 45) {
      return GeoBrainMasteryStatus.fragile;
    }
    if (score < 65) {
      return GeoBrainMasteryStatus.progressing;
    }
    if (score < 80 || totalAttempts < 8) {
      return GeoBrainMasteryStatus.acquired;
    }
    return GeoBrainMasteryStatus.mastered;
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _legacyReviewCount({
    required int masteryLevel,
    required int currentStreak,
    required int wrongAnswers,
  }) {
    final int level = masteryLevel.clamp(0, 5);
    final int baseCount;
    switch (level) {
      case 0:
        baseCount = 0;
      case 1:
        baseCount = 1;
      case 2:
        baseCount = 2;
      case 3:
        baseCount = 3;
      case 4:
        baseCount = 5;
      case 5:
        baseCount = 6;
      default:
        baseCount = 0;
    }
    if (currentStreak <= 0 && wrongAnswers > 0) {
      return (baseCount - 2).clamp(
        0,
        GeoBrainReviewScheduler.maximumSuccessfulReviewCount,
      );
    }
    return baseCount;
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _readOptionalDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static int? _readOptionalInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  static DateTime? _readDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
