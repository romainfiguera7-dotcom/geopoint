import '../geo_engine/country_info.dart';
import '../geo_engine/country_info_loader.dart';
import '../player/player_online_identity.dart';
import 'challenge_clock.dart';
import 'challenge_definition.dart';
import 'challenge_eligibility.dart';
import 'challenge_pack.dart';
import 'challenge_pack_repository.dart';
import 'challenge_pack_validator.dart';
import 'challenge_player_state.dart';
import 'challenge_ranking_sync.dart';
import 'challenge_remote_pack.dart';
import 'challenge_reward_sync.dart';
import 'challenge_server_connection.dart';
import 'challenge_season_reward.dart';
import 'challenge_storage.dart';

class ChallengeHubException implements Exception {
  const ChallengeHubException(this.issues);

  final List<ChallengeValidationIssue> issues;

  @override
  String toString() {
    if (issues.isEmpty) {
      return 'Le pack de défis ne peut pas être chargé.';
    }
    return issues
        .map((ChallengeValidationIssue issue) => issue.message)
        .join('\n');
  }
}

class ChallengeHubSnapshot {
  const ChallengeHubSnapshot({
    required this.pack,
    required this.playerState,
    required this.clock,
    required this.activeChallenges,
    required this.validationIssues,
    this.isChildProfile = false,
    this.packOrigin = ChallengePackOrigin.bundled,
    this.packRevision = 0,
    this.packFallbackReason,
    this.rewardSync,
    this.rankingSync,
    this.seasonRewardClaim,
  });

  final ChallengePack pack;
  final ChallengePlayerState playerState;
  final ChallengeClockEvaluation clock;
  final List<ChallengeDefinition> activeChallenges;
  final List<ChallengeValidationIssue> validationIssues;
  final bool isChildProfile;
  final ChallengePackOrigin packOrigin;
  final int packRevision;
  final String? packFallbackReason;
  final ChallengeRewardSyncReport? rewardSync;
  final ChallengeRankingSyncReport? rankingSync;
  final ChallengeSeasonRewardClaimReport? seasonRewardClaim;

  List<ChallengeDefinition> challengesFor(ChallengePeriod period) {
    return activeChallenges
        .where((ChallengeDefinition item) => item.period == period)
        .toList(growable: false);
  }

  ChallengeDefinition? get dailyChallenge {
    final List<ChallengeDefinition> daily =
        challengesFor(ChallengePeriod.daily);
    return daily.isEmpty ? null : daily.first;
  }

  List<ChallengeDefinition> get recentlyCompletedChallenges {
    final List<ChallengeDefinition> completed = pack.challenges
        .where(
          (ChallengeDefinition challenge) =>
              (isChildProfile
                  ? challenge.audience == ChallengeAudience.child
                  : challenge.audience != ChallengeAudience.child) &&
              playerState.progressFor(challenge.id).isCompleted,
        )
        .toList(growable: false);
    completed.sort(
      (ChallengeDefinition left, ChallengeDefinition right) {
        final DateTime leftDate =
            playerState.progressFor(left.id).completedAtUtc ?? left.validFromUtc;
        final DateTime rightDate =
            playerState.progressFor(right.id).completedAtUtc ?? right.validFromUtc;
        return rightDate.compareTo(leftDate);
      },
    );
    return completed.take(5).toList(growable: false);
  }
}

class ChallengeHubService {
  const ChallengeHubService._();

  static Future<ChallengeHubSnapshot> load({
    required int playerLevel,
    bool isChildProfile = false,
    DateTime? deviceNow,
    DateTime? serverNow,
    ChallengePackRepository? packRepository,
    ChallengeRewardValidationGateway? rewardValidationGateway,
    ChallengeRankingGateway? rankingGateway,
    ChallengeSeasonRewardGateway? seasonRewardGateway,
    PlayerOnlineIdentity? playerIdentity,
  }) async {
    final DateTime currentDeviceTime = deviceNow ?? DateTime.now();
    final Future<Map<String, CountryInfo>> countryInfosFuture =
        CountryInfoLoader.loadCountryInfos();
    final Future<ChallengePlayerState?> stateFuture = ChallengeStorage.load();

    final Map<String, CountryInfo> countryInfos = await countryInfosFuture;
    final ChallengePackResolution packResolution = await (packRepository ??
            ChallengePackRepository(
              remoteGateway: ChallengeServerConnection.packGateway,
            ))
        .load(
      countryIds: countryInfos.keys.toSet(),
    );
    final ChallengePack pack = packResolution.pack;
    final ChallengePlayerState playerState =
        await stateFuture ?? ChallengePlayerState.initial();
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      pack,
      context: ChallengePackValidationContext(
        countryIds: countryInfos.keys.toSet(),
      ),
    );
    final List<ChallengeValidationIssue> errors = issues
        .where((ChallengeValidationIssue issue) => issue.isError)
        .toList(growable: false);
    if (errors.isNotEmpty) {
      throw ChallengeHubException(errors);
    }

    final ChallengeClockEvaluation initialClock = ChallengeClock.evaluate(
      deviceNow: currentDeviceTime,
      serverNow: serverNow ?? packResolution.serverNowUtc,
      previousState: playerState.clockState,
    );
    final ChallengeRankingSyncReport? rankingSync = isChildProfile
        ? null
        : await ChallengeRankingSyncService.synchronize(
            playerState: playerState,
            clock: initialClock,
            deviceNow: currentDeviceTime,
            gateway: rankingGateway ?? ChallengeServerConnection.rankingGateway,
            playerIdentity: playerIdentity,
          );
    final ChallengeRewardSyncReport rewardSync =
        await ChallengeRewardSyncService.synchronize(
      playerState: rankingSync?.playerState ?? playerState,
      deviceNow: currentDeviceTime,
      trustedServerNow: rankingSync?.clock.effectiveNowUtc ??
          serverNow ??
          packResolution.serverNowUtc,
      gateway: rewardValidationGateway ??
          ChallengeServerConnection.rewardValidationGateway,
    );
    final ChallengeClockEvaluation clock = rewardSync.clock;
    final ChallengeSeasonRewardClaimReport? seasonRewardClaim = isChildProfile
        ? null
        : await ChallengeSeasonRewardService.claimPreviousSeason(
            currentSeasonKey: pack.monthKey,
            playerState: rewardSync.playerState,
            gateway: seasonRewardGateway ??
                ChallengeServerConnection.seasonRewardGateway,
          );
    final ChallengePlayerState updatedState =
        seasonRewardClaim?.playerState ??
            rewardSync.playerState;

    final List<ChallengeDefinition> active = clock.canStartChallenge
        ? ChallengeEligibility.activeForPlayer(
            pack: pack,
            now: clock.effectiveNowUtc,
            player: ChallengePlayerContext(
              playerLevel: playerLevel,
              isChildProfile: isChildProfile,
            ),
          )
        : const <ChallengeDefinition>[];

    return ChallengeHubSnapshot(
      pack: pack,
      playerState: updatedState,
      clock: clock,
      activeChallenges: active,
      validationIssues: issues,
      isChildProfile: isChildProfile,
      packOrigin: packResolution.origin,
      packRevision: packResolution.revision,
      packFallbackReason: packResolution.fallbackReason,
      rewardSync: rewardSync,
      rankingSync: rankingSync,
      seasonRewardClaim: seasonRewardClaim,
    );
  }
}
