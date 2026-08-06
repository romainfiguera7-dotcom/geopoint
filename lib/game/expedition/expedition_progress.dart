class ExpeditionProgress {
  const ExpeditionProgress({
    required this.starsByExpedition,
    this.bestScoresByExpedition =
        const <String, Map<String, int>>{},
  });

  static const List<String> primaryMissionIds =
      <String>[
    'find_country',
    'find_capital',
    'find_flag',
    'mixed',
  ];

  static const String ultimateMissionId =
      'ultimate';

  final Map<String, Map<String, int>>
      starsByExpedition;

  /// Meilleur score total obtenu pour chaque
  /// combinaison expédition + épreuve.
  ///
  /// Exemple :
  /// bestScoresByExpedition['easy']['find_country'].
  final Map<String, Map<String, int>>
      bestScoresByExpedition;

  factory ExpeditionProgress.initial() {
    return const ExpeditionProgress(
      starsByExpedition:
          <String, Map<String, int>>{},
      bestScoresByExpedition:
          <String, Map<String, int>>{},
    );
  }

  int bestScoreFor({
    required String difficultyId,
    required String missionId,
  }) {
    return bestScoresByExpedition[difficultyId]
            ?[missionId] ??
        0;
  }

  int starsFor({
    required String difficultyId,
    required String missionId,
  }) {
    return starsByExpedition[difficultyId]
            ?[missionId] ??
        0;
  }

  int totalStarsFor(
    String difficultyId,
  ) {
    final Map<String, int>? missions =
        starsByExpedition[difficultyId];

    if (missions == null) {
      return 0;
    }

    return missions.values.fold<int>(
      0,
      (
        int total,
        int stars,
      ) =>
          total + stars.clamp(0, 3),
    );
  }

  bool isUltimateUnlocked(
    String difficultyId,
  ) {
    return primaryMissionIds.every(
      (String missionId) {
        return starsFor(
              difficultyId: difficultyId,
              missionId: missionId,
            ) >=
            1;
      },
    );
  }

  bool isExpeditionUnlocked({
    required String difficultyId,
    required String? previousDifficultyId,
  }) {
    if (previousDifficultyId == null) {
      return true;
    }

    return starsFor(
          difficultyId: previousDifficultyId,
          missionId: ultimateMissionId,
        ) >=
        1;
  }

  ExpeditionProgress registerMissionStars({
    required String difficultyId,
    required String missionId,
    required int stars,
  }) {
    final int normalizedStars =
        stars.clamp(0, 3);

    final int currentStars =
        starsFor(
      difficultyId: difficultyId,
      missionId: missionId,
    );

    if (normalizedStars <= currentStars) {
      return this;
    }

    final Map<String, Map<String, int>>
        updated =
        <String, Map<String, int>>{};

    for (
      final MapEntry<
              String,
              Map<String, int>>
          entry
      in starsByExpedition.entries
    ) {
      updated[entry.key] =
          Map<String, int>.from(
        entry.value,
      );
    }

    final Map<String, int> missions =
        updated.putIfAbsent(
      difficultyId,
      () => <String, int>{},
    );

    missions[missionId] =
        normalizedStars;

    return ExpeditionProgress(
      starsByExpedition: updated,
      bestScoresByExpedition:
          bestScoresByExpedition,
    );
  }

  ExpeditionProgress registerMissionScore({
    required String difficultyId,
    required String missionId,
    required int score,
  }) {
    final int normalizedScore =
        score < 0 ? 0 : score;

    final int currentBestScore =
        bestScoreFor(
      difficultyId: difficultyId,
      missionId: missionId,
    );

    if (normalizedScore <= currentBestScore) {
      return this;
    }

    final Map<String, Map<String, int>>
        updated =
        <String, Map<String, int>>{};

    for (
      final MapEntry<
              String,
              Map<String, int>>
          entry
      in bestScoresByExpedition.entries
    ) {
      updated[entry.key] =
          Map<String, int>.from(
        entry.value,
      );
    }

    final Map<String, int> missions =
        updated.putIfAbsent(
      difficultyId,
      () => <String, int>{},
    );

    missions[missionId] =
        normalizedScore;

    return ExpeditionProgress(
      starsByExpedition:
          starsByExpedition,
      bestScoresByExpedition: updated,
    );
  }

  ExpeditionProgress registerMissionResult({
    required String difficultyId,
    required String missionId,
    required int stars,
    required int score,
  }) {
    return registerMissionStars(
      difficultyId: difficultyId,
      missionId: missionId,
      stars: stars,
    ).registerMissionScore(
      difficultyId: difficultyId,
      missionId: missionId,
      score: score,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'starsByExpedition':
          starsByExpedition,
      'bestScoresByExpedition':
          bestScoresByExpedition,
    };
  }

  factory ExpeditionProgress.fromJson(
    Map<String, dynamic> json,
  ) {
    final Object? raw =
        json['starsByExpedition'];

    final Map<String, Map<String, int>>
        result = _readNestedIntMap(
      raw,
      maximumValue: 3,
    );

    final Map<String, Map<String, int>>
        bestScores = _readNestedIntMap(
      json['bestScoresByExpedition'],
    );

    return ExpeditionProgress(
      starsByExpedition: result,
      bestScoresByExpedition:
          bestScores,
    );
  }

  static Map<String, Map<String, int>>
      _readNestedIntMap(
    Object? raw, {
    int? maximumValue,
  }) {
    if (raw is! Map) {
      return <String, Map<String, int>>{};
    }

    final Map<String, Map<String, int>>
        result =
        <String, Map<String, int>>{};

    for (
      final MapEntry<dynamic, dynamic>
          expeditionEntry
      in raw.entries
    ) {
      final String difficultyId =
          expeditionEntry.key
              .toString()
              .trim();

      final Object? rawMissions =
          expeditionEntry.value;

      if (difficultyId.isEmpty ||
          rawMissions is! Map) {
        continue;
      }

      final Map<String, int> missions =
          <String, int>{};

      for (
        final MapEntry<dynamic, dynamic>
            missionEntry
        in rawMissions.entries
      ) {
        final String missionId =
            missionEntry.key
                .toString()
                .trim();

        final int? parsedValue =
            int.tryParse(
          missionEntry.value
              .toString(),
        );

        if (missionId.isEmpty ||
            parsedValue == null) {
          continue;
        }

        final int normalizedValue =
            parsedValue < 0
                ? 0
                : maximumValue == null
                    ? parsedValue
                    : parsedValue.clamp(
                        0,
                        maximumValue,
                      );

        missions[missionId] =
            normalizedValue;
      }

      result[difficultyId] =
          missions;
    }

    return result;
  }
}
