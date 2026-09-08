enum ChallengePeriod {
  daily,
  weekly,
  monthly,
  permanent,
}

extension ChallengePeriodRules on ChallengePeriod {
  String get id {
    switch (this) {
      case ChallengePeriod.daily:
        return 'daily';
      case ChallengePeriod.weekly:
        return 'weekly';
      case ChallengePeriod.monthly:
        return 'monthly';
      case ChallengePeriod.permanent:
        return 'permanent';
    }
  }

  String get label {
    switch (this) {
      case ChallengePeriod.daily:
        return 'Quotidien';
      case ChallengePeriod.weekly:
        return 'Hebdomadaire';
      case ChallengePeriod.monthly:
        return 'Mensuel';
      case ChallengePeriod.permanent:
        return 'Permanent';
    }
  }
}

class ChallengePeriodCodec {
  const ChallengePeriodCodec._();

  static ChallengePeriod fromId(Object? value) {
    final String id = value?.toString().trim().toLowerCase() ?? '';
    for (final ChallengePeriod period in ChallengePeriod.values) {
      if (period.id == id) {
        return period;
      }
    }
    throw FormatException('Période de défi inconnue : $id.');
  }
}

enum ChallengeAudience {
  standard,
  beginner,
  child,
}

extension ChallengeAudienceRules on ChallengeAudience {
  String get id {
    switch (this) {
      case ChallengeAudience.standard:
        return 'standard';
      case ChallengeAudience.beginner:
        return 'beginner';
      case ChallengeAudience.child:
        return 'child';
    }
  }
}

class ChallengeAudienceCodec {
  const ChallengeAudienceCodec._();

  static ChallengeAudience fromId(Object? value) {
    final String id = value?.toString().trim().toLowerCase() ?? 'standard';
    for (final ChallengeAudience audience in ChallengeAudience.values) {
      if (audience.id == id) {
        return audience;
      }
    }
    throw FormatException('Public de défi inconnu : $id.');
  }
}

class ChallengeSuccessCondition {
  const ChallengeSuccessCondition({
    required this.minimumCorrectAnswers,
    this.minimumScore = 0,
    this.maximumAverageDistanceKilometers,
  });

  final int minimumCorrectAnswers;
  final int minimumScore;
  final double? maximumAverageDistanceKilometers;

  factory ChallengeSuccessCondition.fromJson(Map<String, dynamic> json) {
    return ChallengeSuccessCondition(
      minimumCorrectAnswers: _readInt(
        json['minimumCorrectAnswers'],
        field: 'minimumCorrectAnswers',
      ),
      minimumScore: _readOptionalInt(
        json['minimumScore'],
        field: 'minimumScore',
      ) ?? 0,
      maximumAverageDistanceKilometers: _readOptionalDouble(
        json['maximumAverageDistanceKilometers'],
        field: 'maximumAverageDistanceKilometers',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'minimumCorrectAnswers': minimumCorrectAnswers,
      'minimumScore': minimumScore,
      if (maximumAverageDistanceKilometers != null)
        'maximumAverageDistanceKilometers':
            maximumAverageDistanceKilometers,
    };
  }

  String get competitiveSignature {
    return '$minimumCorrectAnswers|$minimumScore|'
        '${maximumAverageDistanceKilometers ?? '-'}';
  }
}

class ChallengeRetryPolicy {
  const ChallengeRetryPolicy({
    required this.maximumAttempts,
    this.unlimitedFreeAttempts = false,
    this.diamondRetryCost = 0,
    this.maximumDiamondRetries = 0,
    this.rewardedAdvertisementAllowed = false,
    this.maximumRewardedAdvertisementRetries = 0,
    this.unlimitedRewardedAdvertisementRetries = false,
    this.childAdvertisementsAllowed = false,
  });

  final int maximumAttempts;
  final bool unlimitedFreeAttempts;
  final int diamondRetryCost;
  final int maximumDiamondRetries;
  final bool rewardedAdvertisementAllowed;
  final int maximumRewardedAdvertisementRetries;
  final bool unlimitedRewardedAdvertisementRetries;

  /// Doit rester faux pour le profil enfant dans la V1.
  final bool childAdvertisementsAllowed;

  int get maximumPaidRetries {
    return maximumDiamondRetries + maximumRewardedAdvertisementRetries;
  }

  factory ChallengeRetryPolicy.fromJson(Map<String, dynamic> json) {
    return ChallengeRetryPolicy(
      maximumAttempts: _readInt(
        json['maximumAttempts'],
        field: 'maximumAttempts',
      ),
      unlimitedFreeAttempts: json['unlimitedFreeAttempts'] == true,
      diamondRetryCost: _readOptionalInt(
        json['diamondRetryCost'],
        field: 'diamondRetryCost',
      ) ?? 0,
      maximumDiamondRetries: _readOptionalInt(
        json['maximumDiamondRetries'],
        field: 'maximumDiamondRetries',
      ) ?? 0,
      rewardedAdvertisementAllowed:
          json['rewardedAdvertisementAllowed'] == true,
      maximumRewardedAdvertisementRetries: _readOptionalInt(
        json['maximumRewardedAdvertisementRetries'],
        field: 'maximumRewardedAdvertisementRetries',
      ) ?? 0,
      unlimitedRewardedAdvertisementRetries:
          json['unlimitedRewardedAdvertisementRetries'] == true,
      childAdvertisementsAllowed: json['childAdvertisementsAllowed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'maximumAttempts': maximumAttempts,
      'unlimitedFreeAttempts': unlimitedFreeAttempts,
      'diamondRetryCost': diamondRetryCost,
      'maximumDiamondRetries': maximumDiamondRetries,
      'rewardedAdvertisementAllowed': rewardedAdvertisementAllowed,
      'maximumRewardedAdvertisementRetries':
          maximumRewardedAdvertisementRetries,
      'unlimitedRewardedAdvertisementRetries':
          unlimitedRewardedAdvertisementRetries,
      'childAdvertisementsAllowed': childAdvertisementsAllowed,
    };
  }

  String get competitiveSignature {
    return '$maximumAttempts|$unlimitedFreeAttempts|'
        '$diamondRetryCost|$maximumDiamondRetries|'
        '$rewardedAdvertisementAllowed|'
        '$maximumRewardedAdvertisementRetries|'
        '$unlimitedRewardedAdvertisementRetries';
  }
}

class ChallengeReward {
  const ChallengeReward({
    this.xp = 0,
    this.coins = 0,
    this.diamonds = 0,
    this.cosmeticIds = const <String>[],
    this.stampId,
    this.emblemId,
    this.progressionPoints = 0,
  });

  final int xp;
  final int coins;
  final int diamonds;
  final List<String> cosmeticIds;
  final String? stampId;
  final String? emblemId;
  final int progressionPoints;

  bool get isEmpty {
    return xp == 0 &&
        coins == 0 &&
        diamonds == 0 &&
        cosmeticIds.isEmpty &&
        stampId == null &&
        emblemId == null &&
        progressionPoints == 0;
  }

  factory ChallengeReward.fromJson(Map<String, dynamic> json) {
    return ChallengeReward(
      xp: _readOptionalInt(json['xp'], field: 'xp') ?? 0,
      coins: _readOptionalInt(json['coins'], field: 'coins') ?? 0,
      diamonds: _readOptionalInt(json['diamonds'], field: 'diamonds') ?? 0,
      cosmeticIds: _readStringList(json['cosmeticIds']),
      stampId: _readOptionalString(json['stampId']),
      emblemId: _readOptionalString(json['emblemId']),
      progressionPoints: _readOptionalInt(
        json['progressionPoints'],
        field: 'progressionPoints',
      ) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'xp': xp,
      'coins': coins,
      'diamonds': diamonds,
      'cosmeticIds': cosmeticIds,
      if (stampId != null) 'stampId': stampId,
      if (emblemId != null) 'emblemId': emblemId,
      'progressionPoints': progressionPoints,
    };
  }
}

class ChallengeDefinition {
  const ChallengeDefinition({
    required this.id,
    required this.period,
    required this.title,
    required this.description,
    required this.illustrationAsset,
    required this.validFromUtc,
    required this.validUntilUtc,
    required this.modeId,
    required this.difficultyId,
    this.continentId,
    this.countryIds = const <String>[],
    this.questionCount,
    this.durationSeconds,
    required this.successCondition,
    required this.retryPolicy,
    required this.reward,
    this.minimumPlayerLevel = 1,
    this.audience = ChallengeAudience.standard,
    this.beginnerVariantId,
    this.childVariantId,
    this.rankingGroupId,
    this.geoBrainPersonalizationAllowed = false,
    this.disabled = false,
  });

  final String id;
  final ChallengePeriod period;
  final String title;
  final String description;
  final String illustrationAsset;
  final DateTime validFromUtc;
  final DateTime validUntilUtc;
  final String modeId;
  final String difficultyId;
  final String? continentId;
  final List<String> countryIds;
  final int? questionCount;
  final int? durationSeconds;
  final ChallengeSuccessCondition successCondition;
  final ChallengeRetryPolicy retryPolicy;
  final ChallengeReward reward;
  final int minimumPlayerLevel;
  final ChallengeAudience audience;
  final String? beginnerVariantId;
  final String? childVariantId;
  final String? rankingGroupId;
  final bool geoBrainPersonalizationAllowed;
  final bool disabled;

  bool get isRanked => rankingGroupId != null;

  bool isActiveAt(DateTime now) {
    if (period == ChallengePeriod.permanent) {
      return !disabled;
    }
    final DateTime utcNow = now.toUtc();
    return !disabled &&
        !utcNow.isBefore(validFromUtc) &&
        utcNow.isBefore(validUntilUtc);
  }

  String get rewardClaimId {
    if (period == ChallengePeriod.permanent) {
      return '$id@permanent';
    }
    return '$id@${validFromUtc.toUtc().toIso8601String()}';
  }

  String get competitiveSignature {
    final List<String> sortedCountries = <String>[...countryIds]..sort();
    return <String>[
      modeId,
      difficultyId,
      continentId ?? '-',
      sortedCountries.join(','),
      questionCount?.toString() ?? '-',
      durationSeconds?.toString() ?? '-',
      successCondition.competitiveSignature,
      retryPolicy.competitiveSignature,
    ].join('|');
  }

  factory ChallengeDefinition.fromJson(Map<String, dynamic> json) {
    final String id = _readRequiredString(json['id'], field: 'id');
    return ChallengeDefinition(
      id: id,
      period: ChallengePeriodCodec.fromId(json['period']),
      title: _readRequiredString(json['title'], field: '$id.title'),
      description: _readRequiredString(
        json['description'],
        field: '$id.description',
      ),
      illustrationAsset: _readRequiredString(
        json['illustrationAsset'],
        field: '$id.illustrationAsset',
      ),
      validFromUtc: _readDateTime(
        json['validFromUtc'],
        field: '$id.validFromUtc',
      ),
      validUntilUtc: _readDateTime(
        json['validUntilUtc'],
        field: '$id.validUntilUtc',
      ),
      modeId: _readRequiredString(json['modeId'], field: '$id.modeId'),
      difficultyId: _readRequiredString(
        json['difficultyId'],
        field: '$id.difficultyId',
      ),
      continentId: _readOptionalString(json['continentId']),
      countryIds: _readStringList(json['countryIds']),
      questionCount: _readOptionalInt(
        json['questionCount'],
        field: '$id.questionCount',
      ),
      durationSeconds: _readOptionalInt(
        json['durationSeconds'],
        field: '$id.durationSeconds',
      ),
      successCondition: ChallengeSuccessCondition.fromJson(
        _readMap(json['successCondition'], field: '$id.successCondition'),
      ),
      retryPolicy: ChallengeRetryPolicy.fromJson(
        _readMap(json['retryPolicy'], field: '$id.retryPolicy'),
      ),
      reward: ChallengeReward.fromJson(
        _readMap(json['reward'], field: '$id.reward'),
      ),
      minimumPlayerLevel: _readOptionalInt(
        json['minimumPlayerLevel'],
        field: '$id.minimumPlayerLevel',
      ) ?? 1,
      audience: ChallengeAudienceCodec.fromId(json['audience']),
      beginnerVariantId: _readOptionalString(json['beginnerVariantId']),
      childVariantId: _readOptionalString(json['childVariantId']),
      rankingGroupId: _readOptionalString(json['rankingGroupId']),
      geoBrainPersonalizationAllowed:
          json['geoBrainPersonalizationAllowed'] == true,
      disabled: json['disabled'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'period': period.id,
      'title': title,
      'description': description,
      'illustrationAsset': illustrationAsset,
      'validFromUtc': validFromUtc.toUtc().toIso8601String(),
      'validUntilUtc': validUntilUtc.toUtc().toIso8601String(),
      'modeId': modeId,
      'difficultyId': difficultyId,
      if (continentId != null) 'continentId': continentId,
      'countryIds': countryIds,
      if (questionCount != null) 'questionCount': questionCount,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      'successCondition': successCondition.toJson(),
      'retryPolicy': retryPolicy.toJson(),
      'reward': reward.toJson(),
      'minimumPlayerLevel': minimumPlayerLevel,
      'audience': audience.id,
      if (beginnerVariantId != null)
        'beginnerVariantId': beginnerVariantId,
      if (childVariantId != null) 'childVariantId': childVariantId,
      if (rankingGroupId != null) 'rankingGroupId': rankingGroupId,
      'geoBrainPersonalizationAllowed': geoBrainPersonalizationAllowed,
      'disabled': disabled,
    };
  }
}

Map<String, dynamic> _readMap(Object? value, {required String field}) {
  if (value is! Map) {
    throw FormatException('Le champ $field doit être un objet JSON.');
  }
  return value.map<String, dynamic>(
    (dynamic key, dynamic item) => MapEntry<String, dynamic>(
      key.toString(),
      item,
    ),
  );
}

String _readRequiredString(Object? value, {required String field}) {
  final String result = value?.toString().trim() ?? '';
  if (result.isEmpty) {
    throw FormatException('Le champ $field est obligatoire.');
  }
  return result;
}

String? _readOptionalString(Object? value) {
  final String result = value?.toString().trim() ?? '';
  return result.isEmpty ? null : result;
}

int _readInt(Object? value, {required String field}) {
  final int? result = _readOptionalInt(value, field: field);
  if (result == null) {
    throw FormatException('Le champ $field doit être un entier.');
  }
  return result;
}

int? _readOptionalInt(Object? value, {required String field}) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  final int? result = int.tryParse(value.toString());
  if (result == null) {
    throw FormatException('Le champ $field doit être un entier.');
  }
  return result;
}

double? _readOptionalDouble(Object? value, {required String field}) {
  if (value == null) {
    return null;
  }
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  final double? result = double.tryParse(value.toString());
  if (result == null || !result.isFinite) {
    throw FormatException('Le champ $field doit être un nombre.');
  }
  return result;
}

DateTime _readDateTime(Object? value, {required String field}) {
  final DateTime? result = DateTime.tryParse(value?.toString() ?? '');
  if (result == null) {
    throw FormatException('Le champ $field doit être une date ISO 8601.');
  }
  return result.toUtc();
}

List<String> _readStringList(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is! List) {
    throw const FormatException('Une liste de textes était attendue.');
  }
  return List<String>.unmodifiable(
    value
        .map((Object? item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty),
  );
}
