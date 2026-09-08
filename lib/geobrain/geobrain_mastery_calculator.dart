import 'dart:math' as math;

import 'geobrain_attempt.dart';

class GeoBrainMasteryEvaluation {
  const GeoBrainMasteryEvaluation({
    required this.score,
    required this.weightedAccuracy,
    required this.evidenceFactor,
    required this.regularityFactor,
    required this.recentErrorPenalty,
    required this.effectiveAttemptWeight,
    required this.distinctPracticeDays,
  });

  final double score;
  final double weightedAccuracy;
  final double evidenceFactor;
  final double regularityFactor;
  final double recentErrorPenalty;
  final double effectiveAttemptWeight;
  final int distinctPracticeDays;
}

class GeoBrainMasteryCalculator {
  const GeoBrainMasteryCalculator();

  /// Règle commune à tous les pays et territoires.
  ///
  /// Le score final combine :
  /// - la précision pondérée par la récence ;
  /// - la quantité de preuves réellement utiles ;
  /// - la régularité sur plusieurs jours ;
  /// - une pénalité uniquement après plusieurs erreurs récentes ;
  /// - une influence réduite des aides et contextes très assistés.
  GeoBrainMasteryEvaluation evaluate({
    required List<GeoBrainAttempt> attempts,
    required DateTime now,
    double legacyBaselineScore = 0,
    int legacyAttemptCount = 0,
  }) {
    final List<GeoBrainAttempt> ordered = attempts
        .map<GeoBrainAttempt>((GeoBrainAttempt attempt) => attempt.normalized())
        .toList(growable: false)
      ..sort(
        (GeoBrainAttempt a, GeoBrainAttempt b) =>
            a.answeredAt.compareTo(b.answeredAt),
      );

    final int normalizedLegacyCount = legacyAttemptCount.clamp(0, 1 << 31);
    final double normalizedLegacyScore = legacyBaselineScore.clamp(0.0, 100.0);
    final double legacyWeight = math.min(
      normalizedLegacyCount * 1.2,
      15.0,
    );

    double effectiveWeight = legacyWeight;
    double correctWeight = legacyWeight * (normalizedLegacyScore / 100);
    final Set<String> practiceDays = <String>{};

    for (final GeoBrainAttempt attempt in ordered) {
      final double weight = _attemptWeight(attempt: attempt, now: now);
      effectiveWeight += weight;
      if (attempt.isCorrect) {
        correctWeight += weight;
      }
      practiceDays.add(_dayKey(attempt.answeredAt));
    }

    if (effectiveWeight <= 0) {
      return const GeoBrainMasteryEvaluation(
        score: 0,
        weightedAccuracy: 0,
        evidenceFactor: 0,
        regularityFactor: 0,
        recentErrorPenalty: 0,
        effectiveAttemptWeight: 0,
        distinctPracticeDays: 0,
      );
    }

    final double weightedAccuracy = correctWeight / effectiveWeight;
    final double evidenceFactor = 1 - math.exp(-effectiveWeight / 5);
    final int effectivePracticeDays = normalizedLegacyCount > 0
        ? math.max(4, practiceDays.length)
        : practiceDays.length;
    final double regularityFactor = (
      0.72 + math.min(effectivePracticeDays, 4) * 0.07
    ).clamp(0.0, 1.0);
    final double recentErrorPenalty = _recentErrorPenalty(ordered);
    final double score = (
      weightedAccuracy * evidenceFactor * regularityFactor * 100 -
      recentErrorPenalty
    ).clamp(0.0, 100.0);

    return GeoBrainMasteryEvaluation(
      score: score,
      weightedAccuracy: weightedAccuracy,
      evidenceFactor: evidenceFactor,
      regularityFactor: regularityFactor,
      recentErrorPenalty: recentErrorPenalty,
      effectiveAttemptWeight: effectiveWeight,
      distinctPracticeDays: practiceDays.length,
    );
  }

  double _attemptWeight({
    required GeoBrainAttempt attempt,
    required DateTime now,
  }) {
    double weight = _recencyWeight(attempt.answeredAt, now);
    weight *= _difficultyWeight(attempt.difficultyId);
    weight *= _contextWeight(attempt.context);

    // Une réussite assistée confirme moins fortement la connaissance.
    // Une erreur reste informative même si une aide était affichée.
    if (attempt.isCorrect && attempt.usedHelp) {
      weight *= 0.45;
    }
    return weight.clamp(0.05, 1.25);
  }

  double _recencyWeight(DateTime answeredAt, DateTime now) {
    final int ageInDays = math.max(0, now.difference(answeredAt).inDays);
    if (ageInDays <= 7) {
      return 1;
    }
    if (ageInDays <= 30) {
      return 0.82;
    }
    if (ageInDays <= 90) {
      return 0.62;
    }
    return 0.35;
  }

  double _difficultyWeight(String difficultyId) {
    switch (difficultyId.trim().toLowerCase()) {
      case 'discovery':
        return 0.70;
      case 'easy':
        return 0.85;
      case 'intermediate':
        return 1;
      case 'hard':
        return 1.05;
      case 'expert':
        return 1.10;
      default:
        return 0.75;
    }
  }

  double _contextWeight(GeoBrainAttemptContext context) {
    switch (context) {
      case GeoBrainAttemptContext.classicGame:
      case GeoBrainAttemptContext.expedition:
      case GeoBrainAttemptContext.challenge:
        return 1;
      case GeoBrainAttemptContext.training:
        return 0.90;
      case GeoBrainAttemptContext.childMode:
        return 0.55;
      case GeoBrainAttemptContext.tutorial:
        return 0.35;
      case GeoBrainAttemptContext.unknown:
        return 0.65;
    }
  }

  double _recentErrorPenalty(List<GeoBrainAttempt> ordered) {
    if (ordered.isEmpty) {
      return 0;
    }
    final List<GeoBrainAttempt> recent = ordered.length <= 5
        ? ordered
        : ordered.sublist(ordered.length - 5);
    final int recentErrors = recent
        .where((GeoBrainAttempt attempt) => !attempt.isCorrect)
        .length;
    int consecutiveErrors = 0;
    for (final GeoBrainAttempt attempt in ordered.reversed) {
      if (attempt.isCorrect) {
        break;
      }
      consecutiveErrors++;
    }

    final double penalty =
        math.max(0, recentErrors - 1) * 3.0 +
        math.max(0, consecutiveErrors - 1) * 7.0;
    return math.min(penalty, 25.0);
  }

  String _dayKey(DateTime value) {
    final DateTime utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }
}
