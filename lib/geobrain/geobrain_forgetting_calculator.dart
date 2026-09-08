import 'dart:math' as math;

import 'geobrain_attempt.dart';

enum GeoBrainRetentionState {
  unknown('Non découvert'),
  stable('Bien retenu'),
  reviewDue('À réviser'),
  repeatedForgetting('À réviser');

  const GeoBrainRetentionState(this.playerLabel);

  /// Formulation volontairement positive affichable au joueur.
  final String playerLabel;
}

class GeoBrainForgettingEvaluation {
  const GeoBrainForgettingEvaluation({
    required this.retainedScore,
    required this.passiveDecay,
    required this.state,
    required this.daysSinceConfirmation,
    required this.overdueDays,
    required this.recentErrorCount,
    required this.consecutiveErrorCount,
    required this.wasPreviouslyAcquired,
  });

  final double retainedScore;
  final double passiveDecay;
  final GeoBrainRetentionState state;
  final int daysSinceConfirmation;
  final int overdueDays;
  final int recentErrorCount;
  final int consecutiveErrorCount;
  final bool wasPreviouslyAcquired;

  bool get needsReview =>
      state == GeoBrainRetentionState.reviewDue ||
      state == GeoBrainRetentionState.repeatedForgetting;

  bool get isRepeatedForgetting =>
      state == GeoBrainRetentionState.repeatedForgetting;

  bool get isOccasionalError =>
      wasPreviouslyAcquired &&
      recentErrorCount == 1 &&
      consecutiveErrorCount == 1;

  String get playerLabel => state.playerLabel;
}

class GeoBrainForgettingCalculator {
  const GeoBrainForgettingCalculator();

  /// Évalue la conservation d'une connaissance sans modifier le score stocké.
  ///
  /// La baisse ne commence que pour une connaissance autrefois acquise :
  /// - 21 jours de grâce après une acquisition ;
  /// - 45 jours après une maîtrise ;
  /// - puis 0,35 point par jour de retard ;
  /// - avec un plancher à 65 % du score enregistré.
  GeoBrainForgettingEvaluation evaluate({
    required double score,
    required double highestScore,
    required int totalAttempts,
    required DateTime now,
    required DateTime? lastReviewedAt,
    required DateTime? lastConfirmedAt,
    List<GeoBrainAttempt> attempts = const <GeoBrainAttempt>[],
  }) {
    final double normalizedScore = score.clamp(0.0, 100.0);
    final double normalizedHighestScore = math.max(
      normalizedScore,
      highestScore.clamp(0.0, 100.0),
    );
    if (totalAttempts <= 0) {
      return const GeoBrainForgettingEvaluation(
        retainedScore: 0,
        passiveDecay: 0,
        state: GeoBrainRetentionState.unknown,
        daysSinceConfirmation: 0,
        overdueDays: 0,
        recentErrorCount: 0,
        consecutiveErrorCount: 0,
        wasPreviouslyAcquired: false,
      );
    }

    final List<GeoBrainAttempt> ordered = attempts
        .map<GeoBrainAttempt>((GeoBrainAttempt attempt) => attempt.normalized())
        .toList(growable: false)
      ..sort(
        (GeoBrainAttempt a, GeoBrainAttempt b) =>
            a.answeredAt.compareTo(b.answeredAt),
      );
    final List<GeoBrainAttempt> recent = ordered.length <= 5
        ? ordered
        : ordered.sublist(ordered.length - 5);
    final int recentErrorCount = recent
        .where((GeoBrainAttempt attempt) => !attempt.isCorrect)
        .length;
    int consecutiveErrorCount = 0;
    for (final GeoBrainAttempt attempt in ordered.reversed) {
      if (attempt.isCorrect) {
        break;
      }
      consecutiveErrorCount++;
    }

    final bool wasAcquired = normalizedHighestScore >= 65;
    final bool repeatedForgetting = wasAcquired &&
        (consecutiveErrorCount >= 2 || recentErrorCount >= 3);
    final DateTime? confirmationDate = lastConfirmedAt ?? lastReviewedAt;
    final int daysSinceConfirmation = confirmationDate == null
        ? 0
        : math.max(0, now.difference(confirmationDate).inDays);
    final int graceDays = normalizedHighestScore >= 80 ? 45 : 21;
    final int overdueDays = wasAcquired
        ? math.max(0, daysSinceConfirmation - graceDays)
        : 0;
    final double maximumDecay = normalizedScore * 0.35;
    final double passiveDecay = math.min(overdueDays * 0.35, maximumDecay);
    final double retainedScore = math.max(
      normalizedScore - passiveDecay,
      normalizedScore * 0.65,
    ).clamp(0.0, 100.0);

    final GeoBrainRetentionState state;
    if (repeatedForgetting) {
      state = GeoBrainRetentionState.repeatedForgetting;
    } else if (overdueDays > 0) {
      state = GeoBrainRetentionState.reviewDue;
    } else {
      state = GeoBrainRetentionState.stable;
    }

    return GeoBrainForgettingEvaluation(
      retainedScore: retainedScore,
      passiveDecay: passiveDecay,
      state: state,
      daysSinceConfirmation: daysSinceConfirmation,
      overdueDays: overdueDays,
      recentErrorCount: recentErrorCount,
      consecutiveErrorCount: consecutiveErrorCount,
      wasPreviouslyAcquired: wasAcquired,
    );
  }
}
