import 'game_question.dart';

class GameSession {
  const GameSession({
    required this.questionDurationSeconds,
    required this.totalQuestions,
    required this.currentQuestion,
    required this.questionNumber,
    required this.totalScore,
    required this.lastScore,
    required this.hasAnswered,
    required this.isCorrectCountry,
    required this.secondsRemaining,
    required this.isTimeUp,
    required this.correctAnswers,
    required this.totalDistanceInKilometers,
    required this.answersWithDistance,
    required this.totalElapsedSeconds,
    required this.bestScore,
    required this.worstScore,
  });

  static const int defaultQuestionDurationSeconds = 15;
  static const int defaultTotalQuestions = 10;
  static const int maximumScorePerQuestion = 120;

  factory GameSession.initial({
    int questionDurationSeconds =
        defaultQuestionDurationSeconds,
    int totalQuestions =
        defaultTotalQuestions,
  }) {
    if (questionDurationSeconds <= 0) {
      throw ArgumentError.value(
        questionDurationSeconds,
        'questionDurationSeconds',
        'La durée doit être supérieure à zéro.',
      );
    }

    if (totalQuestions <= 0) {
      throw ArgumentError.value(
        totalQuestions,
        'totalQuestions',
        'Le nombre de questions doit être supérieur à zéro.',
      );
    }

    return GameSession(
      questionDurationSeconds: questionDurationSeconds,
      totalQuestions: totalQuestions,
      currentQuestion: null,
      questionNumber: 0,
      totalScore: 0,
      lastScore: 0,
      hasAnswered: false,
      isCorrectCountry: false,
      secondsRemaining: questionDurationSeconds,
      isTimeUp: false,
      correctAnswers: 0,
      totalDistanceInKilometers: 0,
      answersWithDistance: 0,
      totalElapsedSeconds: 0,
      bestScore: null,
      worstScore: null,
    );
  }

  final int questionDurationSeconds;
  final int totalQuestions;
  final GameQuestion? currentQuestion;
  final int questionNumber;
  final int totalScore;
  final int lastScore;
  final bool hasAnswered;

  /// Nom historique conservé pour éviter une grosse
  /// migration. Dans le mode Capitales, cette valeur
  /// signifie « réponse considérée comme correcte ».
  final bool isCorrectCountry;

  final int secondsRemaining;
  final bool isTimeUp;
  final int correctAnswers;
  final double totalDistanceInKilometers;
  final int answersWithDistance;
  final int totalElapsedSeconds;
  final int? bestScore;
  final int? worstScore;

  int get maximumGameScore =>
      totalQuestions * maximumScorePerQuestion;

  bool get isLastQuestion =>
      questionNumber == totalQuestions;

  bool get isGameOver =>
      questionNumber >= totalQuestions &&
      hasAnswered;

  bool get canStartNextQuestion =>
      questionNumber < totalQuestions;

  double get averageDistanceInKilometers {
    if (answersWithDistance == 0) {
      return 0;
    }

    return totalDistanceInKilometers /
        answersWithDistance;
  }

  double get averageElapsedSeconds {
    if (questionNumber == 0) {
      return 0;
    }

    return totalElapsedSeconds /
        questionNumber;
  }

  GameSession startQuestion(
    GameQuestion question,
  ) {
    if (!canStartNextQuestion) {
      return this;
    }

    return _copy(
      currentQuestion: question,
      questionNumber: questionNumber + 1,
      lastScore: 0,
      hasAnswered: false,
      isCorrectCountry: false,
      secondsRemaining:
          questionDurationSeconds,
      isTimeUp: false,
    );
  }

  GameSession tick() {
    if (hasAnswered ||
        isTimeUp ||
        isGameOver ||
        secondsRemaining <= 0) {
      return this;
    }

    final int newSecondsRemaining =
        secondsRemaining - 1;

    return _copy(
      secondsRemaining: newSecondsRemaining,
      isTimeUp: newSecondsRemaining <= 0,
    );
  }

  GameSession answer({
    required int score,
    required bool isCorrectCountry,
    required double distanceInKilometers,
    required int elapsedSeconds,
  }) {
    if (hasAnswered) {
      return this;
    }

    final int updatedCorrectAnswers =
        isCorrectCountry
            ? correctAnswers + 1
            : correctAnswers;

    final int updatedBestScore =
        bestScore == null ||
                score > bestScore!
            ? score
            : bestScore!;

    final int updatedWorstScore =
        worstScore == null ||
                score < worstScore!
            ? score
            : worstScore!;

    return _copy(
      totalScore: totalScore + score,
      lastScore: score,
      hasAnswered: true,
      isCorrectCountry: isCorrectCountry,
      isTimeUp: false,
      correctAnswers: updatedCorrectAnswers,
      totalDistanceInKilometers:
          totalDistanceInKilometers +
              distanceInKilometers,
      answersWithDistance:
          answersWithDistance + 1,
      totalElapsedSeconds:
          totalElapsedSeconds +
              elapsedSeconds,
      bestScore: updatedBestScore,
      worstScore: updatedWorstScore,
    );
  }

  GameSession timeout() {
    if (hasAnswered) {
      return this;
    }

    final int updatedBestScore =
        bestScore ?? 0;

    final int updatedWorstScore =
        worstScore == null ||
                0 < worstScore!
            ? 0
            : worstScore!;

    return _copy(
      lastScore: 0,
      hasAnswered: true,
      isCorrectCountry: false,
      secondsRemaining: 0,
      isTimeUp: true,
      totalElapsedSeconds:
          totalElapsedSeconds +
              questionDurationSeconds,
      bestScore: updatedBestScore,
      worstScore: updatedWorstScore,
    );
  }

  GameSession reset() {
    return GameSession.initial(
      questionDurationSeconds:
          questionDurationSeconds,
      totalQuestions: totalQuestions,
    );
  }

  GameSession _copy({
    GameQuestion? currentQuestion,
    int? questionNumber,
    int? totalScore,
    int? lastScore,
    bool? hasAnswered,
    bool? isCorrectCountry,
    int? secondsRemaining,
    bool? isTimeUp,
    int? correctAnswers,
    double? totalDistanceInKilometers,
    int? answersWithDistance,
    int? totalElapsedSeconds,
    int? bestScore,
    int? worstScore,
  }) {
    return GameSession(
      questionDurationSeconds:
          questionDurationSeconds,
      totalQuestions: totalQuestions,
      currentQuestion:
          currentQuestion ??
              this.currentQuestion,
      questionNumber:
          questionNumber ??
              this.questionNumber,
      totalScore:
          totalScore ??
              this.totalScore,
      lastScore:
          lastScore ??
              this.lastScore,
      hasAnswered:
          hasAnswered ??
              this.hasAnswered,
      isCorrectCountry:
          isCorrectCountry ??
              this.isCorrectCountry,
      secondsRemaining:
          secondsRemaining ??
              this.secondsRemaining,
      isTimeUp:
          isTimeUp ??
              this.isTimeUp,
      correctAnswers:
          correctAnswers ??
              this.correctAnswers,
      totalDistanceInKilometers:
          totalDistanceInKilometers ??
              this.totalDistanceInKilometers,
      answersWithDistance:
          answersWithDistance ??
              this.answersWithDistance,
      totalElapsedSeconds:
          totalElapsedSeconds ??
              this.totalElapsedSeconds,
      bestScore:
          bestScore ??
              this.bestScore,
      worstScore:
          worstScore ??
              this.worstScore,
    );
  }
}
