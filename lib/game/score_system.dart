class ScoreSystem {
  const ScoreSystem();

  int calculateScore({
    required String modeId,
    required String difficultyId,
    required bool isCorrectCountry,
    required double distanceInKilometers,
    required int secondsRemaining,
    required int questionDurationSeconds,
  }) {
    final int precisionScore = modeId == 'find_capital'
        ? _calculateCapitalPrecisionScore(
            distanceInKilometers: distanceInKilometers,
            difficultyId: difficultyId,
          )
        : _calculateCountryPrecisionScore(
            isCorrectCountry: isCorrectCountry,
            distanceInKilometers: distanceInKilometers,
            difficultyId: difficultyId,
          );

    if (precisionScore == 0) {
      return 0;
    }

    final int timeBonus = _calculateTimeBonus(
      secondsRemaining: secondsRemaining,
      questionDurationSeconds: questionDurationSeconds,
    );

    return precisionScore + timeBonus;
  }

  int _calculateCountryPrecisionScore({
    required bool isCorrectCountry,
    required double distanceInKilometers,
    required String difficultyId,
  }) {
    if (isCorrectCountry) {
      return 100;
    }

    final List<double> thresholds = _countryScoreThresholdsFor(difficultyId);

    if (distanceInKilometers <= thresholds[0]) {
      return 95;
    }

    if (distanceInKilometers <= thresholds[1]) {
      return 90;
    }

    if (distanceInKilometers <= thresholds[2]) {
      return 80;
    }

    if (distanceInKilometers <= thresholds[3]) {
      return 70;
    }

    if (distanceInKilometers <= thresholds[4]) {
      return 60;
    }

    if (distanceInKilometers <= thresholds[5]) {
      return 40;
    }

    if (distanceInKilometers <= thresholds[6]) {
      return 20;
    }

    return 0;
  }

  List<double> _countryScoreThresholdsFor(String difficultyId) {
    switch (difficultyId) {
      case 'discovery':
        return const <double>[150, 350, 650, 950, 1300, 1800, 2500];

      case 'easy':
        return const <double>[120, 300, 550, 850, 1150, 1650, 2200];

      case 'intermediate':
        return const <double>[100, 250, 500, 750, 1000, 1500, 2000];

      case 'hard':
        return const <double>[75, 180, 350, 550, 800, 1200, 1700];

      case 'expert':
        return const <double>[50, 125, 250, 400, 600, 900, 1300];

      default:
        return const <double>[100, 250, 500, 750, 1000, 1500, 2000];
    }
  }

  int _calculateCapitalPrecisionScore({
    required double distanceInKilometers,
    required String difficultyId,
  }) {
    final List<double> thresholds = _capitalScoreThresholdsFor(difficultyId);

    if (distanceInKilometers <= thresholds[0]) {
      return 100;
    }

    if (distanceInKilometers <= thresholds[1]) {
      return 95;
    }

    if (distanceInKilometers <= thresholds[2]) {
      return 90;
    }

    if (distanceInKilometers <= thresholds[3]) {
      return 80;
    }

    if (distanceInKilometers <= thresholds[4]) {
      return 70;
    }

    if (distanceInKilometers <= thresholds[5]) {
      return 55;
    }

    if (distanceInKilometers <= thresholds[6]) {
      return 35;
    }

    if (distanceInKilometers <= thresholds[7]) {
      return 20;
    }

    return 0;
  }

  List<double> _capitalScoreThresholdsFor(String difficultyId) {
    switch (difficultyId) {
      case 'discovery':
        return const <double>[20, 50, 100, 200, 300, 500, 750, 1000];

      case 'easy':
        return const <double>[15, 40, 80, 150, 250, 400, 650, 900];

      case 'intermediate':
        return const <double>[12, 30, 60, 120, 200, 350, 550, 800];

      case 'hard':
        return const <double>[10, 25, 50, 100, 160, 280, 450, 700];

      case 'expert':
        return const <double>[8, 20, 40, 75, 120, 220, 350, 600];

      default:
        return const <double>[15, 40, 80, 150, 250, 400, 650, 900];
    }
  }

  int _calculateTimeBonus({
    required int secondsRemaining,
    required int questionDurationSeconds,
  }) {
    final int elapsedSeconds = questionDurationSeconds - secondsRemaining;

    if (elapsedSeconds <= 3) {
      return 20;
    }

    if (elapsedSeconds <= 5) {
      return 15;
    }

    if (elapsedSeconds <= 7) {
      return 10;
    }

    if (elapsedSeconds <= 10) {
      return 5;
    }

    return 0;
  }
}
