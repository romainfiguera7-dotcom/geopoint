import 'geobrain_attempt.dart';

class GeoBrainReviewSchedule {
  const GeoBrainReviewSchedule({
    required this.successfulReviewCount,
    required this.nextReviewAt,
    required this.interval,
    required this.isConfirmedSuccess,
  });

  final int successfulReviewCount;
  final DateTime nextReviewAt;
  final Duration interval;
  final bool isConfirmedSuccess;
}

class GeoBrainReviewScheduler {
  const GeoBrainReviewScheduler();

  static const int maximumSuccessfulReviewCount = 7;

  /// Programme la prochaine présentation d'un thème.
  ///
  /// Une réussite autonome arrivée à échéance allonge la séquence :
  /// 1, 3, 7, 14, 30, 60 puis 120 jours. Une réponse donnée avant son
  /// échéance ne repousse pas artificiellement la révision. Une erreur ramène
  /// la question six heures plus tard et réduit de deux niveaux l'espacement.
  GeoBrainReviewSchedule schedule({
    required GeoBrainAttempt attempt,
    required int previousSuccessfulReviewCount,
    required DateTime? previousNextReviewAt,
  }) {
    final GeoBrainAttempt normalized = attempt.normalized();
    final int previousCount = previousSuccessfulReviewCount.clamp(
      0,
      maximumSuccessfulReviewCount,
    );

    if (!normalized.isCorrect) {
      final int reducedCount = (previousCount - 2).clamp(
        0,
        maximumSuccessfulReviewCount,
      );
      const Duration interval = Duration(hours: 6);
      return GeoBrainReviewSchedule(
        successfulReviewCount: reducedCount,
        nextReviewAt: normalized.answeredAt.add(interval),
        interval: interval,
        isConfirmedSuccess: false,
      );
    }

    final bool confirmedSuccess = _isConfirmedSuccess(normalized);
    final bool reviewWasDue = previousNextReviewAt == null ||
        !previousNextReviewAt.isAfter(normalized.answeredAt);

    // Répondre plusieurs fois juste après l'apprentissage ne permet pas de
    // gonfler l'intervalle. La date déjà programmée reste inchangée.
    if (!reviewWasDue) {
      return GeoBrainReviewSchedule(
        successfulReviewCount: previousCount,
        nextReviewAt: previousNextReviewAt,
        interval: previousNextReviewAt.difference(normalized.answeredAt),
        isConfirmedSuccess: confirmedSuccess,
      );
    }

    final int updatedCount = confirmedSuccess
        ? (previousCount + 1).clamp(
            1,
            maximumSuccessfulReviewCount,
          )
        : previousCount;
    final Duration interval = confirmedSuccess
        ? intervalForSuccessfulReviewCount(updatedCount)
        : const Duration(days: 1);
    return GeoBrainReviewSchedule(
      successfulReviewCount: updatedCount,
      nextReviewAt: normalized.answeredAt.add(interval),
      interval: interval,
      isConfirmedSuccess: confirmedSuccess,
    );
  }

  static Duration intervalForSuccessfulReviewCount(int count) {
    switch (count.clamp(0, maximumSuccessfulReviewCount)) {
      case 0:
      case 1:
        return const Duration(days: 1);
      case 2:
        return const Duration(days: 3);
      case 3:
        return const Duration(days: 7);
      case 4:
        return const Duration(days: 14);
      case 5:
        return const Duration(days: 30);
      case 6:
        return const Duration(days: 60);
      case 7:
        return const Duration(days: 120);
      default:
        return const Duration(days: 1);
    }
  }

  static int inferredSuccessfulReviewCount({
    required double score,
    required int currentStreak,
    required int wrongAnswers,
  }) {
    if (currentStreak <= 0 && wrongAnswers > 0) {
      return 0;
    }
    if (score >= 80) {
      return 6;
    }
    if (score >= 65) {
      return 5;
    }
    if (score >= 45) {
      return 4;
    }
    if (score >= 25) {
      return 2;
    }
    return score > 0 ? 1 : 0;
  }

  bool _isConfirmedSuccess(GeoBrainAttempt attempt) {
    return attempt.isCorrect &&
        !attempt.usedHelp &&
        attempt.context != GeoBrainAttemptContext.tutorial &&
        attempt.context != GeoBrainAttemptContext.unknown;
  }
}
