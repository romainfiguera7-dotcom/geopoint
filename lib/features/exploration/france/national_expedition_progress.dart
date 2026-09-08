class NationalExpeditionProgress {
  const NationalExpeditionProgress({
    required this.starsByLevel,
    required this.bestScoresByLevel,
    this.gamesPlayed = 0,
    this.correctAnswers = 0,
    this.totalAnswers = 0,
  });

  final Map<String, int> starsByLevel;
  final Map<String, int> bestScoresByLevel;
  final int gamesPlayed;
  final int correctAnswers;
  final int totalAnswers;

  int get bestScore => bestScoresByLevel.values.fold<int>(
        0,
        (int best, int score) => score > best ? score : best,
      );

  int get accuracyPercent => totalAnswers == 0
      ? 0
      : ((correctAnswers / totalAnswers) * 100).round().clamp(0, 100);

  factory NationalExpeditionProgress.initial() {
    return const NationalExpeditionProgress(
      starsByLevel: <String, int>{},
      bestScoresByLevel: <String, int>{},
    );
  }

  int starsFor(String levelId) => starsByLevel[levelId] ?? 0;
  int bestScoreFor(String levelId) => bestScoresByLevel[levelId] ?? 0;

  NationalExpeditionProgress register({
    required String levelId,
    required int stars,
    required int score,
    int correctAnswers = 0,
    int totalAnswers = 0,
  }) {
    final Map<String, int> updatedStars = Map<String, int>.from(starsByLevel);
    final Map<String, int> updatedScores =
        Map<String, int>.from(bestScoresByLevel);
    updatedStars[levelId] = stars.clamp(0, 3) > starsFor(levelId)
        ? stars.clamp(0, 3)
        : starsFor(levelId);
    updatedScores[levelId] = score > bestScoreFor(levelId)
        ? score
        : bestScoreFor(levelId);
    return NationalExpeditionProgress(
      starsByLevel: updatedStars,
      bestScoresByLevel: updatedScores,
      gamesPlayed: gamesPlayed + 1,
      correctAnswers:
          this.correctAnswers + correctAnswers.clamp(0, totalAnswers),
      totalAnswers: this.totalAnswers + totalAnswers.clamp(0, 10000),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'starsByLevel': starsByLevel,
        'bestScoresByLevel': bestScoresByLevel,
        'gamesPlayed': gamesPlayed,
        'correctAnswers': correctAnswers,
        'totalAnswers': totalAnswers,
      };

  factory NationalExpeditionProgress.fromJson(Map<String, dynamic> json) {
    return NationalExpeditionProgress(
      starsByLevel: _readIntMap(json['starsByLevel'], maximum: 3),
      bestScoresByLevel: _readIntMap(json['bestScoresByLevel']),
      gamesPlayed: _readNonNegativeInt(json['gamesPlayed']),
      correctAnswers: _readNonNegativeInt(json['correctAnswers']),
      totalAnswers: _readNonNegativeInt(json['totalAnswers']),
    );
  }

  static int _readNonNegativeInt(Object? value) {
    final int parsed = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  static Map<String, int> _readIntMap(Object? raw, {int? maximum}) {
    if (raw is! Map) {
      return <String, int>{};
    }
    final Map<String, int> result = <String, int>{};
    raw.forEach((dynamic key, dynamic value) {
      final int? parsed = value is num ? value.toInt() : int.tryParse('$value');
      if (parsed != null && parsed >= 0) {
        result[key.toString()] = maximum == null ? parsed : parsed.clamp(0, maximum);
      }
    });
    return result;
  }
}
