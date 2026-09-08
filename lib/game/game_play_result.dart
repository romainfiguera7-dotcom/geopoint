import '../challenges/challenge_result.dart';

class GamePlayResult {
  const GamePlayResult({
    required this.totalScore,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.averageDistanceInKilometers,
    required this.totalElapsedSeconds,
    this.answerEvidence = const <ChallengeAnswerEvidence>[],
  });

  final int totalScore;
  final int correctAnswers;
  final int totalQuestions;
  final double averageDistanceInKilometers;
  final int totalElapsedSeconds;
  final List<ChallengeAnswerEvidence> answerEvidence;
}
