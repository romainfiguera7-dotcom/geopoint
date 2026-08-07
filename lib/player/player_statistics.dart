class DifficultyStatistics {
  const DifficultyStatistics({
    required this.gamesPlayed,
    required this.questionsPlayed,
    required this.correctAnswers,
    required this.totalScore,
    required this.bestScore,
  });

  final int gamesPlayed;
  final int questionsPlayed;
  final int correctAnswers;
  final int totalScore;
  final int bestScore;

  factory DifficultyStatistics.initial() {
    return const DifficultyStatistics(
      gamesPlayed: 0,
      questionsPlayed: 0,
      correctAnswers: 0,
      totalScore: 0,
      bestScore: 0,
    );
  }

  bool get hasPlayed => gamesPlayed > 0;

  double get averageScore {
    if (gamesPlayed <= 0) {
      return 0;
    }

    return totalScore / gamesPlayed;
  }

  double get accuracy {
    if (questionsPlayed <= 0) {
      return 0;
    }

    return correctAnswers / questionsPlayed;
  }

  DifficultyStatistics registerGame({
    required int score,
    required int correctAnswers,
    required int totalQuestions,
  }) {
    return DifficultyStatistics(
      gamesPlayed: gamesPlayed + 1,
      questionsPlayed: questionsPlayed + totalQuestions,
      correctAnswers: this.correctAnswers + correctAnswers,
      totalScore: totalScore + score,
      bestScore: score > bestScore ? score : bestScore,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'gamesPlayed': gamesPlayed,
      'questionsPlayed': questionsPlayed,
      'correctAnswers': correctAnswers,
      'totalScore': totalScore,
      'bestScore': bestScore,
    };
  }

  factory DifficultyStatistics.fromJson(Map<String, dynamic> json) {
    final int questions = _readNonNegativeInt(json['questionsPlayed']);
    final int correct = _readNonNegativeInt(json['correctAnswers']);

    return DifficultyStatistics(
      gamesPlayed: _readNonNegativeInt(json['gamesPlayed']),
      questionsPlayed: questions,
      correctAnswers: correct > questions ? questions : correct,
      totalScore: _readNonNegativeInt(json['totalScore']),
      bestScore: _readNonNegativeInt(json['bestScore']),
    );
  }
}

class ModeStatistics {
  const ModeStatistics({
    required this.modeId,
    required this.gamesPlayed,
    required this.questionsPlayed,
    required this.correctAnswers,
    required this.totalScore,
    required this.bestScore,
    required this.byDifficulty,
  });

  final String modeId;
  final int gamesPlayed;
  final int questionsPlayed;
  final int correctAnswers;
  final int totalScore;
  final int bestScore;
  final Map<String, DifficultyStatistics> byDifficulty;

  factory ModeStatistics.initial(String modeId) {
    return ModeStatistics(
      modeId: _normalizeId(modeId, fallback: 'find_country'),
      gamesPlayed: 0,
      questionsPlayed: 0,
      correctAnswers: 0,
      totalScore: 0,
      bestScore: 0,
      byDifficulty: const <String, DifficultyStatistics>{},
    );
  }

  bool get hasPlayed => gamesPlayed > 0;

  double get averageScore {
    if (gamesPlayed <= 0) {
      return 0;
    }

    return totalScore / gamesPlayed;
  }

  double get accuracy {
    if (questionsPlayed <= 0) {
      return 0;
    }

    return correctAnswers / questionsPlayed;
  }

  DifficultyStatistics statisticsForDifficulty(String difficultyId) {
    final String normalizedId = _normalizeId(
      difficultyId,
      fallback: 'discovery',
    );

    return byDifficulty[normalizedId] ?? DifficultyStatistics.initial();
  }

  ModeStatistics registerGame({
    required String difficultyId,
    required int score,
    required int correctAnswers,
    required int totalQuestions,
  }) {
    final String normalizedDifficultyId = _normalizeId(
      difficultyId,
      fallback: 'discovery',
    );

    final Map<String, DifficultyStatistics> updatedByDifficulty =
        Map<String, DifficultyStatistics>.from(byDifficulty);

    final DifficultyStatistics current = statisticsForDifficulty(
      normalizedDifficultyId,
    );

    updatedByDifficulty[normalizedDifficultyId] = current.registerGame(
      score: score,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
    );

    return ModeStatistics(
      modeId: modeId,
      gamesPlayed: gamesPlayed + 1,
      questionsPlayed: questionsPlayed + totalQuestions,
      correctAnswers: this.correctAnswers + correctAnswers,
      totalScore: totalScore + score,
      bestScore: score > bestScore ? score : bestScore,
      byDifficulty: Map<String, DifficultyStatistics>.unmodifiable(
        updatedByDifficulty,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'modeId': modeId,
      'gamesPlayed': gamesPlayed,
      'questionsPlayed': questionsPlayed,
      'correctAnswers': correctAnswers,
      'totalScore': totalScore,
      'bestScore': bestScore,
      'byDifficulty': <String, dynamic>{
        for (final MapEntry<String, DifficultyStatistics> entry
            in byDifficulty.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }

  factory ModeStatistics.fromJson(String modeId, Map<String, dynamic> json) {
    final String normalizedModeId = _normalizeId(
      json['modeId']?.toString() ?? modeId,
      fallback: _normalizeId(modeId, fallback: 'find_country'),
    );

    final Map<String, DifficultyStatistics> difficulties =
        <String, DifficultyStatistics>{};

    final Object? rawDifficulties = json['byDifficulty'];

    if (rawDifficulties is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawDifficulties.entries) {
        final String difficultyId = _normalizeId(
          entry.key.toString(),
          fallback: '',
        );

        if (difficultyId.isEmpty || entry.value is! Map) {
          continue;
        }

        final Map<String, dynamic> difficultyJson = (entry.value as Map)
            .map<String, dynamic>((dynamic key, dynamic value) {
              return MapEntry<String, dynamic>(key.toString(), value);
            });

        difficulties[difficultyId] = DifficultyStatistics.fromJson(
          difficultyJson,
        );
      }
    }

    final int questions = _readNonNegativeInt(json['questionsPlayed']);
    final int correct = _readNonNegativeInt(json['correctAnswers']);

    return ModeStatistics(
      modeId: normalizedModeId,
      gamesPlayed: _readNonNegativeInt(json['gamesPlayed']),
      questionsPlayed: questions,
      correctAnswers: correct > questions ? questions : correct,
      totalScore: _readNonNegativeInt(json['totalScore']),
      bestScore: _readNonNegativeInt(json['bestScore']),
      byDifficulty: Map<String, DifficultyStatistics>.unmodifiable(
        difficulties,
      ),
    );
  }
}

int _readNonNegativeInt(Object? value) {
  final int parsed;

  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else {
    parsed = int.tryParse(value?.toString() ?? '') ?? 0;
  }

  return parsed < 0 ? 0 : parsed;
}

String _normalizeId(String value, {required String fallback}) {
  final String normalized = value.trim().toLowerCase();

  return normalized.isEmpty ? fallback : normalized;
}
