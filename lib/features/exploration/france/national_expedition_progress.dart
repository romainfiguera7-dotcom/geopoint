class NationalExpeditionProgress {
  const NationalExpeditionProgress({
    required this.starsByLevel,
    required this.bestScoresByLevel,
  });

  final Map<String, int> starsByLevel;
  final Map<String, int> bestScoresByLevel;

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
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'starsByLevel': starsByLevel,
        'bestScoresByLevel': bestScoresByLevel,
      };

  factory NationalExpeditionProgress.fromJson(Map<String, dynamic> json) {
    return NationalExpeditionProgress(
      starsByLevel: _readIntMap(json['starsByLevel'], maximum: 3),
      bestScoresByLevel: _readIntMap(json['bestScoresByLevel']),
    );
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
