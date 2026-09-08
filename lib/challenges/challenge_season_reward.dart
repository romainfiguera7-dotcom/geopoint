import 'challenge_definition.dart';
import 'challenge_player_state.dart';
import 'challenge_storage.dart';
import 'challenge_wallet.dart';

class ChallengeSeasonRewardTier {
  const ChallengeSeasonRewardTier({
    required this.id,
    required this.label,
    required this.coins,
    required this.diamonds,
    this.maximumRank,
  });

  final String id;
  final String label;
  final int? maximumRank;
  final int coins;
  final int diamonds;

  factory ChallengeSeasonRewardTier.fromJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString().trim() ?? '';
    final String label = json['label']?.toString().trim() ?? '';
    final int coins = _nonNegativeInt(json['coins']);
    final int diamonds = _nonNegativeInt(json['diamonds']);
    final int? maximumRank = json['maximumRank'] == null
        ? null
        : _positiveInt(json['maximumRank']);
    if (id.isEmpty || label.isEmpty || diamonds > 5) {
      throw const FormatException('Palier de saison invalide.');
    }
    return ChallengeSeasonRewardTier(
      id: id,
      label: label,
      maximumRank: maximumRank,
      coins: coins,
      diamonds: diamonds,
    );
  }

  static const List<ChallengeSeasonRewardTier> defaults =
      <ChallengeSeasonRewardTier>[
    ChallengeSeasonRewardTier(
      id: 'champion',
      label: 'Champion',
      maximumRank: 1,
      coins: 600,
      diamonds: 5,
    ),
    ChallengeSeasonRewardTier(
      id: 'podium',
      label: 'Podium',
      maximumRank: 3,
      coins: 400,
      diamonds: 3,
    ),
    ChallengeSeasonRewardTier(
      id: 'top_10',
      label: 'Top 10',
      maximumRank: 10,
      coins: 250,
      diamonds: 2,
    ),
    ChallengeSeasonRewardTier(
      id: 'top_25',
      label: 'Top 25',
      maximumRank: 25,
      coins: 150,
      diamonds: 1,
    ),
    ChallengeSeasonRewardTier(
      id: 'participant',
      label: 'Explorateur',
      coins: 75,
      diamonds: 0,
    ),
  ];

  static ChallengeSeasonRewardTier forRank(int rank) {
    if (rank < 1) {
      throw ArgumentError.value(rank, 'rank', 'Le rang doit être positif.');
    }
    return defaults.firstWhere(
      (ChallengeSeasonRewardTier tier) =>
          tier.maximumRank == null || rank <= tier.maximumRank!,
    );
  }
}

enum ChallengeSeasonRewardServerStatus {
  claimed,
  pending,
  notQualified,
}

class ChallengeSeasonRewardResponse {
  const ChallengeSeasonRewardResponse({
    required this.status,
    required this.serverNowUtc,
    required this.seasonKey,
    this.claimId,
    this.rank,
    this.challengeCount,
    this.tierId,
    this.reward,
    this.claimedAtUtc,
    this.claimOpensAtUtc,
    this.alreadyClaimed = false,
  });

  final ChallengeSeasonRewardServerStatus status;
  final DateTime serverNowUtc;
  final String seasonKey;
  final String? claimId;
  final int? rank;
  final int? challengeCount;
  final String? tierId;
  final ChallengeReward? reward;
  final DateTime? claimedAtUtc;
  final DateTime? claimOpensAtUtc;
  final bool alreadyClaimed;

  factory ChallengeSeasonRewardResponse.fromJson(Map<String, dynamic> json) {
    final ChallengeSeasonRewardServerStatus status;
    switch (json['status']?.toString()) {
      case 'claimed':
        status = ChallengeSeasonRewardServerStatus.claimed;
      case 'pending':
        status = ChallengeSeasonRewardServerStatus.pending;
      case 'not_qualified':
        status = ChallengeSeasonRewardServerStatus.notQualified;
      default:
        throw const FormatException(
          'Statut de récompense de saison inconnu.',
        );
    }
    final DateTime? serverNow =
        DateTime.tryParse(json['serverNowUtc']?.toString() ?? '');
    final String seasonKey = json['seasonKey']?.toString().trim() ?? '';
    if (serverNow == null || !_isSeasonKey(seasonKey)) {
      throw const FormatException('Réponse de saison invalide.');
    }
    if (status != ChallengeSeasonRewardServerStatus.claimed) {
      return ChallengeSeasonRewardResponse(
        status: status,
        serverNowUtc: serverNow.toUtc(),
        seasonKey: seasonKey,
        claimOpensAtUtc: _optionalDate(json['claimOpensAtUtc']),
      );
    }
    final String claimId = json['claimId']?.toString().trim() ?? '';
    final int rank = _positiveInt(json['rank']);
    final int challengeCount = _positiveInt(json['challengeCount']);
    final DateTime? claimedAt = _optionalDate(json['claimedAtUtc']);
    final Map<String, dynamic> rewardJson = _map(json['reward']);
    final ChallengeReward reward = ChallengeReward.fromJson(rewardJson);
    final String tierId = rewardJson['tierId']?.toString().trim() ?? '';
    if (claimId != expectedClaimId(seasonKey) ||
        claimedAt == null ||
        tierId.isEmpty ||
        !_validReward(reward)) {
      throw const FormatException(
        'Versement de saison Firebase invalide.',
      );
    }
    return ChallengeSeasonRewardResponse(
      status: status,
      serverNowUtc: serverNow.toUtc(),
      seasonKey: seasonKey,
      claimId: claimId,
      rank: rank,
      challengeCount: challengeCount,
      tierId: tierId,
      reward: reward,
      claimedAtUtc: claimedAt,
      alreadyClaimed: json['alreadyClaimed'] == true,
    );
  }

  static String expectedClaimId(String seasonKey) {
    return 'season_reward:$seasonKey';
  }
}

abstract interface class ChallengeSeasonRewardGateway {
  Future<ChallengeSeasonRewardResponse> claimSeasonReward(String seasonKey);
}

enum ChallengeSeasonRewardClaimStatus {
  delivered,
  alreadyDelivered,
  pending,
  notQualified,
  connectionUnavailable,
  serverUnavailable,
  invalidServerResponse,
  storageFailure,
}

class ChallengeSeasonRewardClaimReport {
  const ChallengeSeasonRewardClaimReport({
    required this.status,
    required this.seasonKey,
    required this.playerState,
    this.rank,
    this.tierId,
    this.reward,
    this.claimOpensAtUtc,
    this.failureReason,
  });

  final ChallengeSeasonRewardClaimStatus status;
  final String seasonKey;
  final ChallengePlayerState playerState;
  final int? rank;
  final String? tierId;
  final ChallengeReward? reward;
  final DateTime? claimOpensAtUtc;
  final String? failureReason;

  bool get wasDelivered => status == ChallengeSeasonRewardClaimStatus.delivered;
}

typedef ChallengeSeasonRewardPersistence = Future<bool> Function(
  ChallengePlayerState state,
);

class ChallengeSeasonRewardService {
  const ChallengeSeasonRewardService._();

  static String previousSeasonKey(String currentSeasonKey) {
    if (!_isSeasonKey(currentSeasonKey)) {
      throw const FormatException('Saison courante invalide.');
    }
    final List<String> parts = currentSeasonKey.split('-');
    final DateTime previous = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]) - 1,
    );
    return '${previous.year.toString().padLeft(4, '0')}-'
        '${previous.month.toString().padLeft(2, '0')}';
  }

  static Future<ChallengeSeasonRewardClaimReport> claimPreviousSeason({
    required String currentSeasonKey,
    required ChallengePlayerState playerState,
    ChallengeSeasonRewardGateway? gateway,
    ChallengeSeasonRewardPersistence? persistence,
  }) async {
    final String seasonKey = previousSeasonKey(currentSeasonKey);
    final String expectedClaimId =
        ChallengeSeasonRewardResponse.expectedClaimId(seasonKey);
    if (playerState.wallet.hasDelivered(expectedClaimId)) {
      return ChallengeSeasonRewardClaimReport(
        status: ChallengeSeasonRewardClaimStatus.alreadyDelivered,
        seasonKey: seasonKey,
        playerState: playerState,
      );
    }
    if (gateway == null) {
      return ChallengeSeasonRewardClaimReport(
        status: ChallengeSeasonRewardClaimStatus.connectionUnavailable,
        seasonKey: seasonKey,
        playerState: playerState,
      );
    }

    final ChallengeSeasonRewardResponse response;
    try {
      response = await gateway.claimSeasonReward(seasonKey);
      if (response.seasonKey != seasonKey) {
        throw const FormatException('La saison renvoyée ne correspond pas.');
      }
    } catch (error) {
      return ChallengeSeasonRewardClaimReport(
        status: error is FormatException
            ? ChallengeSeasonRewardClaimStatus.invalidServerResponse
            : ChallengeSeasonRewardClaimStatus.serverUnavailable,
        seasonKey: seasonKey,
        playerState: playerState,
        failureReason: error.toString(),
      );
    }

    switch (response.status) {
      case ChallengeSeasonRewardServerStatus.pending:
        return ChallengeSeasonRewardClaimReport(
          status: ChallengeSeasonRewardClaimStatus.pending,
          seasonKey: seasonKey,
          playerState: playerState,
          claimOpensAtUtc: response.claimOpensAtUtc,
        );
      case ChallengeSeasonRewardServerStatus.notQualified:
        final ChallengeRewardDeliveryDecision marker =
            playerState.wallet.deliver(
          claimId: expectedClaimId,
          confirmed: true,
          reward: const ChallengeReward(),
        );
        final ChallengePlayerState checkedState = playerState.copyWith(
          wallet: marker.updatedWallet,
        );
        await (persistence ?? ChallengeStorage.save)(checkedState);
        return ChallengeSeasonRewardClaimReport(
          status: ChallengeSeasonRewardClaimStatus.notQualified,
          seasonKey: seasonKey,
          playerState: checkedState,
        );
      case ChallengeSeasonRewardServerStatus.claimed:
        final ChallengeReward reward = response.reward!;
        final ChallengeRewardDeliveryDecision delivery =
            playerState.wallet.deliver(
          claimId: response.claimId!,
          confirmed: true,
          reward: reward,
        );
        if (!delivery.wasDelivered) {
          return ChallengeSeasonRewardClaimReport(
            status: ChallengeSeasonRewardClaimStatus.alreadyDelivered,
            seasonKey: seasonKey,
            playerState: playerState,
            rank: response.rank,
            tierId: response.tierId ?? _tierId(response.rank!),
            reward: reward,
          );
        }
        final ChallengePlayerState updated = playerState.copyWith(
          wallet: delivery.updatedWallet,
        );
        final bool saved =
            await (persistence ?? ChallengeStorage.save)(updated);
        return ChallengeSeasonRewardClaimReport(
          status: saved
              ? ChallengeSeasonRewardClaimStatus.delivered
              : ChallengeSeasonRewardClaimStatus.storageFailure,
          seasonKey: seasonKey,
          playerState: updated,
          rank: response.rank,
          tierId: response.tierId ?? _tierId(response.rank!),
          reward: reward,
        );
    }
  }

  static String _tierId(int rank) {
    return ChallengeSeasonRewardTier.forRank(rank).id;
  }
}

bool _isSeasonKey(String value) {
  final RegExpMatch? match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return false;
  }
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  return year >= 2020 && year <= 2200 && month >= 1 && month <= 12;
}

DateTime? _optionalDate(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
}

int _positiveInt(Object? value) {
  final int? parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 1) {
    throw const FormatException('Nombre de saison invalide.');
  }
  return parsed;
}

int _nonNegativeInt(Object? value) {
  final int? parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 0) {
    throw const FormatException('Nombre de saison invalide.');
  }
  return parsed;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    throw const FormatException('Récompense de saison manquante.');
  }
  return value.map<String, dynamic>(
    (dynamic key, dynamic item) =>
        MapEntry<String, dynamic>(key.toString(), item),
  );
}

bool _validReward(ChallengeReward reward) {
  return reward.xp == 0 &&
      reward.coins >= 0 &&
      reward.coins <= 10000 &&
      reward.diamonds >= 0 &&
      reward.diamonds <= 5 &&
      reward.progressionPoints >= 0 &&
      reward.cosmeticIds.every((String id) => id.trim().isNotEmpty) &&
      (reward.stampId == null || reward.stampId!.trim().isNotEmpty) &&
      (reward.emblemId == null || reward.emblemId!.trim().isNotEmpty);
}
