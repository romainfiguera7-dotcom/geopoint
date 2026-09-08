import 'challenge_definition.dart';

enum ChallengeRewardDeliveryOutcome {
  delivered,
  rejectedPending,
  rejectedDuplicate,
}

class ChallengeRewardDeliveryDecision {
  const ChallengeRewardDeliveryDecision({
    required this.outcome,
    required this.updatedWallet,
    this.reward,
  });

  final ChallengeRewardDeliveryOutcome outcome;
  final ChallengeWallet updatedWallet;
  final ChallengeReward? reward;

  bool get wasDelivered =>
      outcome == ChallengeRewardDeliveryOutcome.delivered;
}

class ChallengeWallet {
  const ChallengeWallet({
    this.schemaVersion = currentSchemaVersion,
    this.coins = 0,
    this.diamonds = 0,
    this.progressionPoints = 0,
    this.cosmeticIds = const <String>{},
    this.stampIds = const <String>{},
    this.emblemIds = const <String>{},
    this.deliveredClaimIds = const <String>{},
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int coins;
  final int diamonds;
  final int progressionPoints;
  final Set<String> cosmeticIds;
  final Set<String> stampIds;
  final Set<String> emblemIds;

  /// Registre indépendant du solde. Il garantit qu’un versement confirmé ne
  /// peut être appliqué qu’une seule fois, même après un redémarrage.
  final Set<String> deliveredClaimIds;

  bool hasDelivered(String claimId) {
    return deliveredClaimIds.contains(claimId.trim());
  }

  ChallengeRewardDeliveryDecision deliver({
    required String claimId,
    required bool confirmed,
    required ChallengeReward reward,
  }) {
    final String normalizedClaimId = claimId.trim();
    if (!confirmed) {
      return ChallengeRewardDeliveryDecision(
        outcome: ChallengeRewardDeliveryOutcome.rejectedPending,
        updatedWallet: this,
      );
    }
    if (normalizedClaimId.isEmpty || hasDelivered(normalizedClaimId)) {
      return ChallengeRewardDeliveryDecision(
        outcome: ChallengeRewardDeliveryOutcome.rejectedDuplicate,
        updatedWallet: this,
      );
    }
    final Set<String> updatedCosmetics = <String>{
      ...cosmeticIds,
      ...reward.cosmeticIds,
    };
    final Set<String> updatedStamps = <String>{...stampIds};
    final Set<String> updatedEmblems = <String>{...emblemIds};
    if (reward.stampId != null) {
      updatedStamps.add(reward.stampId!);
    }
    if (reward.emblemId != null) {
      updatedEmblems.add(reward.emblemId!);
    }

    return ChallengeRewardDeliveryDecision(
      outcome: ChallengeRewardDeliveryOutcome.delivered,
      updatedWallet: ChallengeWallet(
        coins: coins + reward.coins,
        diamonds: diamonds + reward.diamonds,
        progressionPoints: progressionPoints + reward.progressionPoints,
        cosmeticIds: Set<String>.unmodifiable(updatedCosmetics),
        stampIds: Set<String>.unmodifiable(updatedStamps),
        emblemIds: Set<String>.unmodifiable(updatedEmblems),
        deliveredClaimIds: Set<String>.unmodifiable(
          <String>{...deliveredClaimIds, normalizedClaimId},
        ),
      ),
      reward: reward,
    );
  }

  factory ChallengeWallet.fromJson(Map<String, dynamic> json) {
    return ChallengeWallet(
      schemaVersion: _readNonNegativeInt(
        json['schemaVersion'],
        fallback: currentSchemaVersion,
      ),
      coins: _readNonNegativeInt(json['coins']),
      diamonds: _readNonNegativeInt(json['diamonds']),
      progressionPoints: _readNonNegativeInt(json['progressionPoints']),
      cosmeticIds: Set<String>.unmodifiable(
        _readStringSet(json['cosmeticIds']),
      ),
      stampIds: Set<String>.unmodifiable(_readStringSet(json['stampIds'])),
      emblemIds: Set<String>.unmodifiable(_readStringSet(json['emblemIds'])),
      deliveredClaimIds: Set<String>.unmodifiable(
        _readStringSet(json['deliveredClaimIds']),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    List<String> sorted(Set<String> source) {
      return source.toList()..sort();
    }

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'coins': coins,
      'diamonds': diamonds,
      'progressionPoints': progressionPoints,
      'cosmeticIds': sorted(cosmeticIds),
      'stampIds': sorted(stampIds),
      'emblemIds': sorted(emblemIds),
      'deliveredClaimIds': sorted(deliveredClaimIds),
    };
  }
}

int _readNonNegativeInt(Object? value, {int fallback = 0}) {
  final int result = value is int
      ? value
      : int.tryParse(value?.toString() ?? '') ?? fallback;
  return result < 0 ? fallback : result;
}

Set<String> _readStringSet(Object? value) {
  if (value is! List) {
    return <String>{};
  }
  return value
      .map((Object? item) => item?.toString().trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .toSet();
}
