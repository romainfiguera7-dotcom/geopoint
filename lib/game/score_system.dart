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
    final int precisionScore =
        modeId == 'find_capital'
            ? _calculateCapitalPrecisionScore(
                distanceInKilometers:
                    distanceInKilometers,
                difficultyId:
                    difficultyId,
              )
            : _calculateCountryPrecisionScore(
                isCorrectCountry:
                    isCorrectCountry,
                distanceInKilometers:
                    distanceInKilometers,
              );

    if (precisionScore == 0) {
      return 0;
    }

    final int timeBonus =
        _calculateTimeBonus(
      secondsRemaining:
          secondsRemaining,
      questionDurationSeconds:
          questionDurationSeconds,
    );

    return precisionScore + timeBonus;
  }

  int _calculateCountryPrecisionScore({
    required bool isCorrectCountry,
    required double distanceInKilometers,
  }) {
    if (isCorrectCountry) {
      return 100;
    }

    if (distanceInKilometers <= 100) {
      return 95;
    }

    if (distanceInKilometers <= 250) {
      return 90;
    }

    if (distanceInKilometers <= 500) {
      return 80;
    }

    if (distanceInKilometers <= 750) {
      return 70;
    }

    if (distanceInKilometers <= 1000) {
      return 60;
    }

    if (distanceInKilometers <= 1500) {
      return 40;
    }

    if (distanceInKilometers <= 2000) {
      return 20;
    }

    return 0;
  }

  int _calculateCapitalPrecisionScore({
    required double distanceInKilometers,
    required String difficultyId,
  }) {
    final List<double> thresholds =
        _capitalScoreThresholdsFor(
      difficultyId,
    );

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

  List<double> _capitalScoreThresholdsFor(
    String difficultyId,
  ) {
    switch (difficultyId) {
      case 'discovery':
        return const <double>[
          20,
          50,
          100,
          200,
          300,
          500,
          750,
          1000,
        ];

      case 'easy':
        return const <double>[
          15,
          40,
          80,
          150,
          250,
          400,
          650,
          900,
        ];

      case 'intermediate':
        return const <double>[
          12,
          30,
          60,
          120,
          200,
          350,
          550,
          800,
        ];

      case 'hard':
        return const <double>[
          10,
          25,
          50,
          100,
          160,
          280,
          450,
          700,
        ];

      case 'expert':
        return const <double>[
          8,
          20,
          40,
          75,
          120,
          220,
          350,
          600,
        ];

      default:
        return const <double>[
          15,
          40,
          80,
          150,
          250,
          400,
          650,
          900,
        ];
    }
  }

  int _calculateTimeBonus({
    required int secondsRemaining,
    required int questionDurationSeconds,
  }) {
    final int elapsedSeconds =
        questionDurationSeconds -
            secondsRemaining;

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
