import 'continent_expedition.dart';

class ContinentProgress {
  const ContinentProgress({
    required this.starsByExpedition,
    required this.bestScoresByExpedition,
  });

  final Map<String, Map<String, int>> starsByExpedition;
  final Map<String, Map<String, int>> bestScoresByExpedition;

  factory ContinentProgress.initial() {
    return const ContinentProgress(
      starsByExpedition: <String, Map<String, int>>{},
      bestScoresByExpedition: <String, Map<String, int>>{},
    );
  }

  int starsFor({
    required String expeditionId,
    required String levelId,
  }) {
    return starsByExpedition[expeditionId]?[levelId] ?? 0;
  }

  int bestScoreFor({
    required String expeditionId,
    required String levelId,
  }) {
    return bestScoresByExpedition[expeditionId]?[levelId] ?? 0;
  }

  int totalStarsFor(ContinentExpedition expedition) {
    return expedition.levels.fold<int>(
      0,
      (int total, ContinentLevel level) {
        return total + starsFor(
          expeditionId: expedition.id,
          levelId: level.id,
        );
      },
    );
  }

  int completedLevelsFor(ContinentExpedition expedition) {
    return expedition.levels.where((ContinentLevel level) {
      return starsFor(
            expeditionId: expedition.id,
            levelId: level.id,
          ) >=
          1;
    }).length;
  }

  bool isExpeditionCompleted(ContinentExpedition expedition) {
    return expedition.levels.isNotEmpty &&
        completedLevelsFor(expedition) == expedition.levels.length;
  }

  bool isLevelUnlocked({
    required ContinentExpedition expedition,
    required int levelIndex,
  }) {
    if (levelIndex <= 0) {
      return true;
    }

    if (levelIndex >= expedition.levels.length) {
      return false;
    }

    final ContinentLevel previousLevel =
        expedition.levels[levelIndex - 1];

    return starsFor(
          expeditionId: expedition.id,
          levelId: previousLevel.id,
        ) >=
        1;
  }

  ContinentProgress registerLevelResult({
    required String expeditionId,
    required String levelId,
    required int stars,
    required int score,
  }) {
    final int normalizedStars = stars.clamp(0, 3);
    final int normalizedScore = score < 0 ? 0 : score;

    final Map<String, Map<String, int>> updatedStars =
        _copyNestedMap(starsByExpedition);

    final Map<String, Map<String, int>> updatedScores =
        _copyNestedMap(bestScoresByExpedition);

    final Map<String, int> expeditionStars =
        updatedStars.putIfAbsent(
      expeditionId,
      () => <String, int>{},
    );

    final Map<String, int> expeditionScores =
        updatedScores.putIfAbsent(
      expeditionId,
      () => <String, int>{},
    );

    final int currentStars = expeditionStars[levelId] ?? 0;
    final int currentScore = expeditionScores[levelId] ?? 0;

    if (normalizedStars > currentStars) {
      expeditionStars[levelId] = normalizedStars;
    }

    if (normalizedScore > currentScore) {
      expeditionScores[levelId] = normalizedScore;
    }

    return ContinentProgress(
      starsByExpedition: updatedStars,
      bestScoresByExpedition: updatedScores,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'starsByExpedition': starsByExpedition,
      'bestScoresByExpedition': bestScoresByExpedition,
    };
  }

  factory ContinentProgress.fromJson(Map<String, dynamic> json) {
    return ContinentProgress(
      starsByExpedition: _readNestedIntMap(
        json['starsByExpedition'],
        maximumValue: 3,
      ),
      bestScoresByExpedition: _readNestedIntMap(
        json['bestScoresByExpedition'],
      ),
    );
  }

  static Map<String, Map<String, int>> _copyNestedMap(
    Map<String, Map<String, int>> source,
  ) {
    return source.map<String, Map<String, int>>(
      (
        String key,
        Map<String, int> value,
      ) {
        return MapEntry<String, Map<String, int>>(
          key,
          Map<String, int>.from(value),
        );
      },
    );
  }

  static Map<String, Map<String, int>> _readNestedIntMap(
    Object? raw, {
    int? maximumValue,
  }) {
    if (raw is! Map) {
      return <String, Map<String, int>>{};
    }

    final Map<String, Map<String, int>> result =
        <String, Map<String, int>>{};

    for (final MapEntry<dynamic, dynamic> expeditionEntry
        in raw.entries) {
      final String expeditionId =
          expeditionEntry.key.toString().trim();

      if (expeditionId.isEmpty || expeditionEntry.value is! Map) {
        continue;
      }

      final Map<String, int> values = <String, int>{};

      for (final MapEntry<dynamic, dynamic> levelEntry
          in (expeditionEntry.value as Map).entries) {
        final String levelId = levelEntry.key.toString().trim();
        final int? parsedValue =
            int.tryParse(levelEntry.value.toString());

        if (levelId.isEmpty || parsedValue == null) {
          continue;
        }

        values[levelId] = parsedValue < 0
            ? 0
            : maximumValue == null
                ? parsedValue
                : parsedValue.clamp(0, maximumValue);
      }

      result[expeditionId] = values;
    }

    return result;
  }
}
