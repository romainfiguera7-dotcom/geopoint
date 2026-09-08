import 'dart:math';

import 'geobrain_attempt.dart';
import 'geobrain_theme.dart';

enum GeoBrainAdaptiveReason {
  newPlayer,
  steady,
  strongResults,
  recentStruggles,
}

class GeoBrainDifficultyRecommendation {
  const GeoBrainDifficultyRecommendation({
    required this.difficultyId,
    required this.reason,
    required this.analyzedAttemptCount,
    required this.weightedAccuracy,
  });

  final String difficultyId;
  final GeoBrainAdaptiveReason reason;
  final int analyzedAttemptCount;
  final double weightedAccuracy;

  String get difficultyLabel {
    switch (difficultyId) {
      case 'easy':
        return 'Facile';
      case 'intermediate':
        return 'Normal';
      case 'hard':
        return 'Difficile';
      case 'expert':
        return 'Expert';
      default:
        return 'Facile';
    }
  }

  bool get usesContinentalTargeting => difficultyId == 'easy';

  int get questionDurationSeconds {
    switch (difficultyId) {
      case 'intermediate':
        return 17;
      case 'hard':
        return 14;
      case 'expert':
        return 10;
      case 'easy':
      default:
        return 20;
    }
  }

  double get initialZoom => difficultyId == 'easy' ? 2.1 : 2.0;

  double get capitalPrecisionInKilometers {
    switch (difficultyId) {
      case 'intermediate':
        return 150;
      case 'hard':
        return 90;
      case 'expert':
        return 50;
      case 'easy':
      default:
        return 220;
    }
  }

  String get reasonLabel {
    switch (reason) {
      case GeoBrainAdaptiveReason.newPlayer:
        return 'GeoBrain commence avec des repères accessibles.';
      case GeoBrainAdaptiveReason.strongResults:
        return 'Tes résultats récents permettent de réduire les aides.';
      case GeoBrainAdaptiveReason.recentStruggles:
        return 'Après plusieurs erreurs, GeoBrain rapproche temporairement les repères.';
      case GeoBrainAdaptiveReason.steady:
        return 'Ce niveau correspond à tes résultats récents.';
    }
  }

  String rulesSummary({
    required GeoBrainTheme? theme,
    bool standardMapMode = true,
  }) {
    if (!standardMapMode) {
      return '$difficultyLabel • contenu et précision adaptés au niveau';
    }
    final String mapRule = usesContinentalTargeting
        ? 'repère continental'
        : 'vue mondiale sans ciblage';
    final String capitalRule = theme == GeoBrainTheme.capital
        ? ' • précision ${capitalPrecisionInKilometers.round()} km'
        : '';
    return '$difficultyLabel • $mapRule • $questionDurationSeconds s$capitalRule';
  }
}

class GeoBrainDifficultyAdapter {
  const GeoBrainDifficultyAdapter();

  static const List<String> difficultyOrder = <String>[
    'easy',
    'intermediate',
    'hard',
    'expert',
  ];

  static const int maximumRecentAttempts = 12;
  static const int minimumAttemptsBeforeIncrease = 6;

  GeoBrainDifficultyRecommendation recommend({
    required Iterable<GeoBrainAttempt> attempts,
  }) {
    final List<GeoBrainAttempt> ordered = attempts
        .where(_isUsefulAttempt)
        .map<GeoBrainAttempt>((GeoBrainAttempt attempt) => attempt.normalized())
        .toList()
      ..sort(
        (GeoBrainAttempt first, GeoBrainAttempt second) =>
            first.answeredAt.compareTo(second.answeredAt),
      );
    final List<GeoBrainAttempt> recent = ordered.length <= maximumRecentAttempts
        ? ordered
        : ordered.sublist(ordered.length - maximumRecentAttempts);

    if (recent.length < minimumAttemptsBeforeIncrease) {
      return GeoBrainDifficultyRecommendation(
        difficultyId: 'easy',
        reason: GeoBrainAdaptiveReason.newPlayer,
        analyzedAttemptCount: recent.length,
        weightedAccuracy: _weightedAccuracy(recent),
      );
    }

    final int baseIndex = _baseDifficultyIndex(recent);
    final int consecutiveErrors = _consecutiveErrors(recent);
    final double weightedAccuracy = _weightedAccuracy(recent);
    final double lastFourAccuracy = _plainAccuracy(
      recent.length <= 4 ? recent : recent.sublist(recent.length - 4),
    );
    final int unassistedSuccesses = recent
        .where(
          (GeoBrainAttempt attempt) => attempt.isCorrect && !attempt.usedHelp,
        )
        .length;

    final int resolvedIndex;
    final GeoBrainAdaptiveReason reason;
    if (consecutiveErrors >= 3) {
      resolvedIndex = max(0, baseIndex - 1);
      reason = GeoBrainAdaptiveReason.recentStruggles;
    } else if (weightedAccuracy < 0.50 || lastFourAccuracy <= 0.25) {
      resolvedIndex = max(0, baseIndex - 1);
      reason = GeoBrainAdaptiveReason.recentStruggles;
    } else if (weightedAccuracy >= 0.85 &&
        lastFourAccuracy >= 0.75 &&
        unassistedSuccesses >= 5) {
      resolvedIndex = min(difficultyOrder.length - 1, baseIndex + 1);
      reason = resolvedIndex > baseIndex
          ? GeoBrainAdaptiveReason.strongResults
          : GeoBrainAdaptiveReason.steady;
    } else {
      resolvedIndex = baseIndex;
      reason = GeoBrainAdaptiveReason.steady;
    }

    return GeoBrainDifficultyRecommendation(
      difficultyId: difficultyOrder[resolvedIndex],
      reason: reason,
      analyzedAttemptCount: recent.length,
      weightedAccuracy: weightedAccuracy,
    );
  }

  bool _isUsefulAttempt(GeoBrainAttempt attempt) {
    return attempt.context != GeoBrainAttemptContext.tutorial &&
        attempt.context != GeoBrainAttemptContext.childMode &&
        difficultyOrder.contains(attempt.difficultyId.trim().toLowerCase());
  }

  int _baseDifficultyIndex(List<GeoBrainAttempt> attempts) {
    final double average = attempts.fold<double>(
          0,
          (double total, GeoBrainAttempt attempt) =>
              total + difficultyOrder.indexOf(attempt.difficultyId),
        ) /
        attempts.length;
    return average.round().clamp(0, difficultyOrder.length - 1);
  }

  int _consecutiveErrors(List<GeoBrainAttempt> attempts) {
    int result = 0;
    for (final GeoBrainAttempt attempt in attempts.reversed) {
      if (attempt.isCorrect) {
        break;
      }
      result++;
    }
    return result;
  }

  double _weightedAccuracy(List<GeoBrainAttempt> attempts) {
    if (attempts.isEmpty) {
      return 0;
    }
    final double successes = attempts.fold<double>(
      0,
      (double total, GeoBrainAttempt attempt) {
        if (!attempt.isCorrect) {
          return total;
        }
        return total + (attempt.usedHelp ? 0.45 : 1.0);
      },
    );
    return successes / attempts.length;
  }

  double _plainAccuracy(List<GeoBrainAttempt> attempts) {
    if (attempts.isEmpty) {
      return 0;
    }
    return attempts.where((GeoBrainAttempt attempt) => attempt.isCorrect).length /
        attempts.length;
  }
}
