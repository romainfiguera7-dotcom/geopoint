class ExpeditionProgress {
  const ExpeditionProgress({
    required this.starsByExpedition,
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

  factory ExpeditionProgress.initial() {
    return const ExpeditionProgress(
      starsByExpedition:
          <String, Map<String, int>>{},
    );
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
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'starsByExpedition':
          starsByExpedition,
    };
  }

  factory ExpeditionProgress.fromJson(
    Map<String, dynamic> json,
  ) {
    final Object? raw =
        json['starsByExpedition'];

    if (raw is! Map) {
      return ExpeditionProgress.initial();
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

        final int? stars =
            int.tryParse(
          missionEntry.value
              .toString(),
        );

        if (missionId.isEmpty ||
            stars == null) {
          continue;
        }

        missions[missionId] =
            stars.clamp(0, 3);
      }

      result[difficultyId] =
          missions;
    }

    return ExpeditionProgress(
      starsByExpedition: result,
    );
  }
}
