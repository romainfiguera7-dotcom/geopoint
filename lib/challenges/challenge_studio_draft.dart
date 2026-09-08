import 'dart:math' as math;

import 'challenge_definition.dart';

class ChallengeStudioDraft {
  const ChallengeStudioDraft({
    required this.id,
    required this.period,
    required this.title,
    required this.description,
    required this.validFromUtc,
    required this.validUntilUtc,
    required this.modeId,
    required this.difficultyId,
    required this.continentId,
    required this.countryIds,
    required this.questionCount,
    required this.minimumCorrectAnswers,
    required this.minimumScore,
    required this.rewardXp,
    required this.rewardCoins,
    required this.rewardDiamonds,
    required this.progressionPoints,
    required this.ranked,
    required this.geoBrainPersonalizationAllowed,
    this.minimumPlayerLevel = 1,
    this.disabled = false,
  });

  static const int schemaVersion = 3;

  final String id;
  final ChallengePeriod period;
  final String title;
  final String description;
  final DateTime validFromUtc;
  final DateTime validUntilUtc;
  final String modeId;
  final String difficultyId;
  final String? continentId;
  final List<String> countryIds;
  final int questionCount;
  final int minimumCorrectAnswers;
  final int minimumScore;
  final int rewardXp;
  final int rewardCoins;
  final int rewardDiamonds;
  final int progressionPoints;
  final bool ranked;
  final bool geoBrainPersonalizationAllowed;
  final int minimumPlayerLevel;
  final bool disabled;

  factory ChallengeStudioDraft.fresh({
    required ChallengePeriod period,
    DateTime? now,
  }) {
    final DateTime localNow = (now ?? DateTime.now()).toLocal();
    late DateTime localStart;
    late DateTime localEnd;
    switch (period) {
      case ChallengePeriod.daily:
        localStart = DateTime(localNow.year, localNow.month, localNow.day);
        localEnd = localStart.add(const Duration(days: 1));
        break;
      case ChallengePeriod.weekly:
        localStart = DateTime(localNow.year, localNow.month, localNow.day)
            .subtract(Duration(days: localNow.weekday - DateTime.monday));
        localEnd = localStart.add(const Duration(days: 7));
        break;
      case ChallengePeriod.monthly:
        localStart = DateTime(localNow.year, localNow.month);
        localEnd = DateTime(localNow.year, localNow.month + 1);
        break;
      case ChallengePeriod.permanent:
        localStart = DateTime(localNow.year, localNow.month);
        localEnd = DateTime(localNow.year, localNow.month + 1);
        break;
    }
    final String dateKey = _dateKey(localStart);
    return ChallengeStudioDraft(
      id: '${period.id}_$dateKey',
      period: period,
      title: period == ChallengePeriod.daily
          ? 'Le défi du jour'
          : period == ChallengePeriod.weekly
              ? 'Le défi de la semaine'
              : period == ChallengePeriod.monthly
                  ? 'Le défi du mois'
                  : 'Défi permanent',
      description: 'Relève cette nouvelle mission PointGeo.',
      validFromUtc: localStart.toUtc(),
      validUntilUtc: localEnd.toUtc(),
      modeId: 'find_country',
      difficultyId: 'easy',
      continentId: 'world',
      countryIds: const <String>[],
      questionCount: period == ChallengePeriod.daily ? 5 : 10,
      minimumCorrectAnswers: period == ChallengePeriod.daily ? 3 : 7,
      minimumScore: 0,
      rewardXp: period == ChallengePeriod.daily ? 100 : 250,
      rewardCoins: period == ChallengePeriod.monthly ? 200 : 50,
      rewardDiamonds: period == ChallengePeriod.monthly ? 1 : 0,
      progressionPoints: period == ChallengePeriod.daily ? 1 : 3,
      ranked: true,
      geoBrainPersonalizationAllowed: false,
      minimumPlayerLevel: 1,
    );
  }

  ChallengeStudioDraft copyWith({
    String? id,
    ChallengePeriod? period,
    String? title,
    String? description,
    DateTime? validFromUtc,
    DateTime? validUntilUtc,
    String? modeId,
    String? difficultyId,
    String? continentId,
    bool clearContinent = false,
    List<String>? countryIds,
    int? questionCount,
    int? minimumCorrectAnswers,
    int? minimumScore,
    int? rewardXp,
    int? rewardCoins,
    int? rewardDiamonds,
    int? progressionPoints,
    bool? ranked,
    bool? geoBrainPersonalizationAllowed,
    int? minimumPlayerLevel,
    bool? disabled,
  }) {
    return ChallengeStudioDraft(
      id: id ?? this.id,
      period: period ?? this.period,
      title: title ?? this.title,
      description: description ?? this.description,
      validFromUtc: validFromUtc ?? this.validFromUtc,
      validUntilUtc: validUntilUtc ?? this.validUntilUtc,
      modeId: modeId ?? this.modeId,
      difficultyId: difficultyId ?? this.difficultyId,
      continentId: clearContinent ? null : continentId ?? this.continentId,
      countryIds: List<String>.unmodifiable(countryIds ?? this.countryIds),
      questionCount: questionCount ?? this.questionCount,
      minimumCorrectAnswers:
          minimumCorrectAnswers ?? this.minimumCorrectAnswers,
      minimumScore: minimumScore ?? this.minimumScore,
      rewardXp: rewardXp ?? this.rewardXp,
      rewardCoins: rewardCoins ?? this.rewardCoins,
      rewardDiamonds: rewardDiamonds ?? this.rewardDiamonds,
      progressionPoints: progressionPoints ?? this.progressionPoints,
      ranked: ranked ?? this.ranked,
      geoBrainPersonalizationAllowed: geoBrainPersonalizationAllowed ??
          this.geoBrainPersonalizationAllowed,
      minimumPlayerLevel: minimumPlayerLevel ?? this.minimumPlayerLevel,
      disabled: disabled ?? this.disabled,
    );
  }

  ChallengeStudioDraft duplicate(String newId) {
    return copyWith(id: newId, title: '$title — copie');
  }

  List<ChallengeDefinition> toDefinitions() {
    final String childId = '${id}__child';
    final ChallengeDefinition standard = ChallengeDefinition(
      id: id,
      period: period,
      title: title,
      description: description,
      illustrationAsset: 'builtin:challenge_studio',
      validFromUtc: validFromUtc.toUtc(),
      validUntilUtc: validUntilUtc.toUtc(),
      modeId: modeId,
      difficultyId: difficultyId,
      continentId: continentId,
      countryIds: List<String>.unmodifiable(countryIds),
      questionCount: questionCount,
      successCondition: ChallengeSuccessCondition(
        minimumCorrectAnswers: minimumCorrectAnswers,
        minimumScore: minimumScore,
      ),
      retryPolicy: const ChallengeRetryPolicy(
        maximumAttempts: 1,
        rewardedAdvertisementAllowed: true,
        unlimitedRewardedAdvertisementRetries: true,
      ),
      reward: ChallengeReward(
        xp: rewardXp,
        coins: rewardCoins,
        diamonds: rewardDiamonds,
        progressionPoints: progressionPoints,
      ),
      minimumPlayerLevel: 1,
      childVariantId: childId,
      rankingGroupId: id,
      geoBrainPersonalizationAllowed: false,
      disabled: disabled,
    );
    final int childMinimum = math.min(
      minimumCorrectAnswers,
      math.max(1, (questionCount * 0.6).ceil()),
    );
    final List<ChallengeDefinition> definitions =
        <ChallengeDefinition>[standard];
    final ChallengeDefinition child = ChallengeDefinition(
      id: childId,
      period: period,
      title: '$title — Junior',
      description: description,
      illustrationAsset: 'builtin:challenge_studio',
      validFromUtc: validFromUtc.toUtc(),
      validUntilUtc: validUntilUtc.toUtc(),
      modeId: modeId,
      difficultyId: difficultyId == 'discovery' ? 'discovery' : 'easy',
      continentId: continentId,
      countryIds: List<String>.unmodifiable(countryIds),
      questionCount: questionCount,
      successCondition: ChallengeSuccessCondition(
        minimumCorrectAnswers: childMinimum,
        minimumScore: minimumScore == 0 ? 0 : minimumScore ~/ 2,
      ),
      retryPolicy: const ChallengeRetryPolicy(
        maximumAttempts: 1,
        unlimitedFreeAttempts: true,
      ),
      reward: ChallengeReward(
        xp: rewardXp,
        coins: rewardCoins,
        diamonds: rewardDiamonds,
        progressionPoints: progressionPoints,
      ),
      audience: ChallengeAudience.child,
      geoBrainPersonalizationAllowed: geoBrainPersonalizationAllowed,
      disabled: disabled,
    );
    definitions.add(child);
    return definitions;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'id': id,
      'period': period.id,
      'title': title,
      'description': description,
      'validFromUtc': validFromUtc.toUtc().toIso8601String(),
      'validUntilUtc': validUntilUtc.toUtc().toIso8601String(),
      'modeId': modeId,
      'difficultyId': difficultyId,
      if (continentId != null) 'continentId': continentId,
      'countryIds': countryIds,
      'questionCount': questionCount,
      'minimumCorrectAnswers': minimumCorrectAnswers,
      'minimumScore': minimumScore,
      'rewardXp': rewardXp,
      'rewardCoins': rewardCoins,
      'rewardDiamonds': rewardDiamonds,
      'progressionPoints': progressionPoints,
      'ranked': true,
      'geoBrainPersonalizationAllowed': false,
      'minimumPlayerLevel': 1,
      'disabled': disabled,
    };
  }

  factory ChallengeStudioDraft.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final Object? value = json[key];
      final int? result = value is int ? value : int.tryParse('$value');
      if (result == null) {
        throw FormatException('Le champ $key doit être un entier.');
      }
      return result;
    }

    final Object? rawCountryIds = json['countryIds'];
    if (rawCountryIds is! List) {
      throw const FormatException('countryIds doit être une liste.');
    }
    return ChallengeStudioDraft(
      id: json['id']?.toString().trim() ?? '',
      period: ChallengePeriodCodec.fromId(json['period']),
      title: json['title']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      validFromUtc: DateTime.parse('${json['validFromUtc']}').toUtc(),
      validUntilUtc: DateTime.parse('${json['validUntilUtc']}').toUtc(),
      modeId: json['modeId']?.toString().trim() ?? '',
      difficultyId: json['difficultyId']?.toString().trim() ?? '',
      continentId: json['continentId']?.toString().trim().isEmpty == false
          ? json['continentId'].toString().trim()
          : null,
      countryIds: List<String>.unmodifiable(
        rawCountryIds.map((Object? value) => value.toString().trim()),
      ),
      questionCount: readInt('questionCount'),
      minimumCorrectAnswers: readInt('minimumCorrectAnswers'),
      minimumScore: readInt('minimumScore'),
      rewardXp: readInt('rewardXp'),
      rewardCoins: readInt('rewardCoins'),
      rewardDiamonds: readInt('rewardDiamonds'),
      progressionPoints: readInt('progressionPoints'),
      ranked: true,
      geoBrainPersonalizationAllowed: false,
      minimumPlayerLevel: 1,
      disabled: json['disabled'] == true,
    );
  }

  static String _dateKey(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}${two(date.month)}${two(date.day)}';
  }
}
