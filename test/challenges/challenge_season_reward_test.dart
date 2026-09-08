import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_player_state.dart';
import 'package:geopoint/challenges/challenge_season_reward.dart';

class _FakeSeasonRewardGateway implements ChallengeSeasonRewardGateway {
  _FakeSeasonRewardGateway(this.response);

  final ChallengeSeasonRewardResponse response;
  int calls = 0;

  @override
  Future<ChallengeSeasonRewardResponse> claimSeasonReward(
    String seasonKey,
  ) async {
    calls += 1;
    return response;
  }
}

void main() {
  final DateTime now = DateTime.utc(2026, 10, 1, 2);

  ChallengeSeasonRewardResponse claimedResponse({
    int rank = 4,
    ChallengeReward reward = const ChallengeReward(
      coins: 250,
      diamonds: 2,
    ),
  }) {
    return ChallengeSeasonRewardResponse(
      status: ChallengeSeasonRewardServerStatus.claimed,
      serverNowUtc: now,
      seasonKey: '2026-09',
      claimId: 'season_reward:2026-09',
      rank: rank,
      challengeCount: 8,
      reward: reward,
      claimedAtUtc: now,
    );
  }

  test('calcule correctement la saison précédente en janvier', () {
    expect(
      ChallengeSeasonRewardService.previousSeasonKey('2027-01'),
      '2026-12',
    );
  });

  test('crédite une récompense serveur dans le portefeuille', () async {
    final _FakeSeasonRewardGateway gateway =
        _FakeSeasonRewardGateway(claimedResponse());

    final ChallengeSeasonRewardClaimReport report =
        await ChallengeSeasonRewardService.claimPreviousSeason(
      currentSeasonKey: '2026-10',
      playerState: const ChallengePlayerState(),
      gateway: gateway,
      persistence: (ChallengePlayerState state) async => true,
    );

    expect(report.status, ChallengeSeasonRewardClaimStatus.delivered);
    expect(report.rank, 4);
    expect(report.playerState.wallet.coins, 250);
    expect(report.playerState.wallet.diamonds, 2);
    expect(
      report.playerState.wallet.deliveredClaimIds,
      contains('season_reward:2026-09'),
    );
  });

  test('ne contacte plus le serveur après un versement local', () async {
    final _FakeSeasonRewardGateway gateway =
        _FakeSeasonRewardGateway(claimedResponse());
    final ChallengePlayerState delivered = const ChallengePlayerState()
        .copyWith(
          wallet: const ChallengePlayerState().wallet.deliver(
                claimId: 'season_reward:2026-09',
                confirmed: true,
                reward: const ChallengeReward(coins: 250, diamonds: 2),
              ).updatedWallet,
        );

    final ChallengeSeasonRewardClaimReport report =
        await ChallengeSeasonRewardService.claimPreviousSeason(
      currentSeasonKey: '2026-10',
      playerState: delivered,
      gateway: gateway,
      persistence: (ChallengePlayerState state) async => true,
    );

    expect(report.status, ChallengeSeasonRewardClaimStatus.alreadyDelivered);
    expect(gateway.calls, 0);
    expect(report.playerState.wallet.coins, 250);
  });

  test('ne crédite rien si le joueur ne participait pas', () async {
    final _FakeSeasonRewardGateway gateway = _FakeSeasonRewardGateway(
      ChallengeSeasonRewardResponse(
        status: ChallengeSeasonRewardServerStatus.notQualified,
        serverNowUtc: now,
        seasonKey: '2026-09',
      ),
    );

    final ChallengeSeasonRewardClaimReport report =
        await ChallengeSeasonRewardService.claimPreviousSeason(
      currentSeasonKey: '2026-10',
      playerState: const ChallengePlayerState(),
      gateway: gateway,
      persistence: (ChallengePlayerState state) async => true,
    );

    expect(report.status, ChallengeSeasonRewardClaimStatus.notQualified);
    expect(report.playerState.wallet.coins, 0);
    expect(
      report.playerState.wallet.deliveredClaimIds,
      contains('season_reward:2026-09'),
    );
  });

  test('valide les paliers du classement', () {
    expect(ChallengeSeasonRewardTier.forRank(1).id, 'champion');
    expect(ChallengeSeasonRewardTier.forRank(3).id, 'podium');
    expect(ChallengeSeasonRewardTier.forRank(10).id, 'top_10');
    expect(ChallengeSeasonRewardTier.forRank(25).id, 'top_25');
    expect(ChallengeSeasonRewardTier.forRank(26).id, 'participant');
  });
}
