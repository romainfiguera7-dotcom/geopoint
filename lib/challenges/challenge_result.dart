import 'challenge_definition.dart';

class ChallengePerformance {
  const ChallengePerformance({
    required this.score,
    required this.correctAnswers,
    this.averageDistanceKilometers,
    this.elapsedSeconds = 0,
    this.answerEvidence = const <ChallengeAnswerEvidence>[],
  });

  final int score;
  final int correctAnswers;
  final double? averageDistanceKilometers;
  final int elapsedSeconds;
  final List<ChallengeAnswerEvidence> answerEvidence;
}

/// Preuve minimale permettant au serveur de recalculer une partie classée.
///
/// Aucun pays choisi ni aucune coordonnée précise n'est conservé : seuls les
/// éléments nécessaires au barème sont envoyés.
class ChallengeAnswerEvidence {
  const ChallengeAnswerEvidence({
    required this.modeId,
    required this.isCorrect,
    required this.elapsedSeconds,
    this.distanceInKilometers,
  });

  final String modeId;
  final bool isCorrect;
  final int elapsedSeconds;
  final double? distanceInKilometers;

  factory ChallengeAnswerEvidence.fromJson(Map<String, dynamic> json) {
    final String modeId = json['modeId']?.toString().trim() ?? '';
    final int? elapsedSeconds = json['elapsedSeconds'] is num
        ? (json['elapsedSeconds'] as num).toInt()
        : int.tryParse(json['elapsedSeconds']?.toString() ?? '');
    final Object? rawDistance = json['distanceInKilometers'];
    final double? distance = rawDistance == null
        ? null
        : double.tryParse(rawDistance.toString());
    if (modeId.isEmpty ||
        json['isCorrect'] is! bool ||
        elapsedSeconds == null ||
        elapsedSeconds < 0 ||
        (rawDistance != null && distance == null) ||
        (distance != null && (!distance.isFinite || distance < 0))) {
      throw const FormatException('Preuve de réponse classée invalide.');
    }
    return ChallengeAnswerEvidence(
      modeId: modeId,
      isCorrect: json['isCorrect'] as bool,
      elapsedSeconds: elapsedSeconds,
      distanceInKilometers: distance,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'modeId': modeId,
      'isCorrect': isCorrect,
      'elapsedSeconds': elapsedSeconds,
      if (distanceInKilometers != null)
        'distanceInKilometers': distanceInKilometers,
    };
  }
}

class ChallengeResultEvaluation {
  const ChallengeResultEvaluation({
    required this.succeeded,
    required this.correctAnswersReached,
    required this.scoreReached,
    required this.distanceReached,
  });

  final bool succeeded;
  final bool correctAnswersReached;
  final bool scoreReached;
  final bool distanceReached;
}

class ChallengeResultEvaluator {
  const ChallengeResultEvaluator._();

  static ChallengeResultEvaluation evaluate({
    required ChallengeDefinition challenge,
    required ChallengePerformance performance,
  }) {
    if (performance.score < 0 || performance.correctAnswers < 0) {
      throw ArgumentError('Le résultat du défi ne peut pas être négatif.');
    }

    final ChallengeSuccessCondition condition = challenge.successCondition;
    final bool correctAnswersReached =
        performance.correctAnswers >= condition.minimumCorrectAnswers;
    final bool scoreReached = performance.score >= condition.minimumScore;
    final double? maximumDistance =
        condition.maximumAverageDistanceKilometers;
    final bool distanceReached = maximumDistance == null ||
        (performance.averageDistanceKilometers != null &&
            performance.averageDistanceKilometers! <= maximumDistance);

    return ChallengeResultEvaluation(
      succeeded: correctAnswersReached && scoreReached && distanceReached,
      correctAnswersReached: correctAnswersReached,
      scoreReached: scoreReached,
      distanceReached: distanceReached,
    );
  }
}
