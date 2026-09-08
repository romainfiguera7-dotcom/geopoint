import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_clock.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_player_state.dart';
import 'package:geopoint/challenges/challenge_reward_sync.dart';
import 'package:geopoint/challenges/challenge_wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'challenge_test_factory.dart';

class _FakeRewardGateway implements ChallengeRewardValidationGateway {
  _FakeRewardGateway({this.response, this.error});

  final ChallengeRewardValidationResponse? response;
  final Object? error;
  List<ChallengeRewardValidationRequest>? receivedRequests;
  int callCount = 0;

  @override
  Future<ChallengeRewardValidationResponse> validatePendingRewards(
    List<ChallengeRewardValidationRequest> requests,
  ) async {
    callCount += 1;
    receivedRequests = requests;
    if (error != null) {
      throw error!;
    }
    return response!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime now = DateTime.utc(2026, 9, 4, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ChallengePlayerState pendingState() {
    final ChallengeDefinition challenge = challengeFixture();
    final ChallengeClockEvaluation offlineClock = ChallengeClock.evaluate(
      deviceNow: now,
    );
    ChallengePlayerState state = ChallengePlayerState.initial()
        .registerAttempt(
          challengeId: challenge.id,
          score: 410,
          correctAnswers: 5,
          succeeded: true,
          playedAt: now,
        )
        .copyWith(clockState: offlineClock.updatedState);
    final ChallengeRewardClaimDecision claim = state.rewardLedger.claim(
      challenge: challenge,
      completedSuccessfully: true,
      clock: offlineClock,
    );
    return state.copyWith(rewardLedger: claim.updatedLedger);
  }

  ChallengeRewardValidationResponse responseFor(
    ChallengePlayerState state, {
    ChallengeRewardValidationDecision decision =
        ChallengeRewardValidationDecision.confirmed,
    ChallengeReward? reward,
  }) {
    final ChallengeRewardClaimRecord claim =
        state.rewardLedger.pendingClaims.single;
    return ChallengeRewardValidationResponse(
      serverNowUtc: now.add(const Duration(minutes: 2)),
      results: <ChallengeRewardValidationResult>[
        ChallengeRewardValidationResult(
          claimId: claim.claimId,
          decision: decision,
          confirmedReward: decision ==
                  ChallengeRewardValidationDecision.confirmed
              ? reward ?? claim.reward
              : null,
          rejectionReason: decision ==
                  ChallengeRewardValidationDecision.rejected
              ? 'Résultat non conforme au pack publié.'
              : null,
        ),
      ],
    );
  }

  test('récupère le portefeuille Firebase sans récompense en attente',
      () async {
    final _FakeRewardGateway gateway = _FakeRewardGateway(
      response: ChallengeRewardValidationResponse(
        serverNowUtc: now,
        results: const <ChallengeRewardValidationResult>[],
        authoritativeWallet: const ChallengeWallet(coins: 75, diamonds: 2),
      ),
    );
    final ChallengeRewardSyncReport report =
        await ChallengeRewardSyncService.synchronize(
      playerState: ChallengePlayerState.initial(),
      deviceNow: now,
      gateway: gateway,
    );

    expect(report.status, ChallengeRewardSyncStatus.upToDate);
    expect(report.pendingBefore, 0);
    expect(gateway.receivedRequests, isEmpty);
    expect(report.playerState.wallet.coins, 75);
    expect(report.playerState.wallet.diamonds, 2);
  });

  test('le portefeuille Firebase remplace un ancien solde local', () async {
    final ChallengePlayerState local = ChallengePlayerState.initial().copyWith(
      wallet: const ChallengeWallet(coins: 999, diamonds: 99),
    );
    final ChallengeRewardSyncReport report =
        await ChallengeRewardSyncService.synchronize(
      playerState: local,
      deviceNow: now,
      gateway: _FakeRewardGateway(
        response: ChallengeRewardValidationResponse(
          serverNowUtc: now,
          results: const <ChallengeRewardValidationResult>[],
          authoritativeWallet: const ChallengeWallet(),
        ),
      ),
    );

    expect(report.playerState.wallet.coins, 0);
    expect(report.playerState.wallet.diamonds, 0);
  });

  test('conserve les gains lorsque la connexion n’est pas branchée', () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRewardSyncReport report =
        await ChallengeRewardSyncService.synchronize(
      playerState: state,
      deviceNow: now,
    );

    expect(report.status, ChallengeRewardSyncStatus.pendingConnection);
    expect(report.pendingAfter, 1);
    expect(report.playerState.wallet.coins, 0);
  });

  test('envoie les preuves de partie et verse la récompense du serveur',
      () async {
    final ChallengePlayerState state = pendingState();
    const ChallengeReward authoritativeReward = ChallengeReward(
      xp: 90,
      coins: 40,
      diamonds: 1,
      progressionPoints: 2,
    );
    final _FakeRewardGateway gateway = _FakeRewardGateway(
      response: responseFor(state, reward: authoritativeReward),
    );
    final ChallengeRewardSyncReport report =
        await ChallengeRewardSyncService.synchronize(
      playerState: state,
      deviceNow: now,
      gateway: gateway,
    );

    expect(report.status, ChallengeRewardSyncStatus.synchronized);
    expect(report.confirmedCount, 1);
    expect(report.pendingAfter, 0);
    expect(report.clock.source, ChallengeClockSource.server);
    expect(report.playerState.wallet.coins, 40);
    expect(report.playerState.wallet.diamonds, 1);
    expect(gateway.callCount, 1);
    expect(gateway.receivedRequests!.single.bestScore, 410);
    expect(gateway.receivedRequests!.single.bestCorrectAnswers, 5);
  });

  test('un refus serveur clôt la demande sans verser de gain', () async {
    final ChallengePlayerState state = pendingState();
    final _FakeRewardGateway gateway = _FakeRewardGateway(
      response: responseFor(
        state,
        decision: ChallengeRewardValidationDecision.rejected,
      ),
    );
    final ChallengeRewardSyncReport report =
        await ChallengeRewardSyncService.synchronize(
      playerState: state,
      deviceNow: now,
      gateway: gateway,
    );
    final ChallengeRewardClaimRecord claim =
        report.playerState.rewardLedger.claims.values.single;

    expect(report.status, ChallengeRewardSyncStatus.partiallyRejected);
    expect(report.rejectedCount, 1);
    expect(report.pendingAfter, 0);
    expect(claim.status, ChallengeRewardClaimStatus.rejected);
    expect(claim.rejectionReason, isNotEmpty);
    expect(report.playerState.wallet.coins, 0);
  });

  test('une panne conserve la demande pour une prochaine synchronisation',
      () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRewardSyncReport report =
        await ChallengeRewardSyncService.synchronize(
      playerState: state,
      deviceNow: now,
      gateway: _FakeRewardGateway(error: StateError('hors ligne')),
    );

    expect(report.status, ChallengeRewardSyncStatus.serverUnavailable);
    expect(report.pendingAfter, 1);
    expect(report.playerState.wallet.deliveredClaimIds, isEmpty);
  });

  test('un résultat officiel encore absent laisse le gain en attente',
      () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRewardClaimRecord claim =
        state.rewardLedger.pendingClaims.single;
    final ChallengeRewardSyncReport report =
        await ChallengeRewardSyncService.synchronize(
      playerState: state,
      deviceNow: now,
      gateway: _FakeRewardGateway(
        response: ChallengeRewardValidationResponse(
          serverNowUtc: now,
          results: <ChallengeRewardValidationResult>[
            ChallengeRewardValidationResult(
              claimId: claim.claimId,
              decision: ChallengeRewardValidationDecision.pending,
            ),
          ],
          authoritativeWallet: const ChallengeWallet(),
        ),
      ),
    );

    expect(report.status, ChallengeRewardSyncStatus.awaitingValidation);
    expect(report.pendingAfter, 1);
    expect(report.playerState.wallet.coins, 0);
  });

  test('une réponse incomplète est ignorée intégralement', () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRewardSyncReport report =
        await ChallengeRewardSyncService.synchronize(
      playerState: state,
      deviceNow: now,
      gateway: _FakeRewardGateway(
        response: ChallengeRewardValidationResponse(
          serverNowUtc: now,
          results: const <ChallengeRewardValidationResult>[],
        ),
      ),
    );

    expect(report.status, ChallengeRewardSyncStatus.invalidServerResponse);
    expect(report.pendingAfter, 1);
    expect(report.playerState.wallet.coins, 0);
  });

  test('un montant serveur négatif est refusé sans modifier le portefeuille',
      () async {
    final ChallengePlayerState state = pendingState();
    final ChallengeRewardClaimRecord claim =
        state.rewardLedger.pendingClaims.single;
    final ChallengeRewardSyncReport report =
        await ChallengeRewardSyncService.synchronize(
      playerState: state,
      deviceNow: now,
      gateway: _FakeRewardGateway(
        response: ChallengeRewardValidationResponse(
          serverNowUtc: now,
          results: <ChallengeRewardValidationResult>[
            ChallengeRewardValidationResult(
              claimId: claim.claimId,
              decision: ChallengeRewardValidationDecision.confirmed,
              confirmedReward: const ChallengeReward(coins: -1),
            ),
          ],
        ),
      ),
    );

    expect(report.status, ChallengeRewardSyncStatus.invalidServerResponse);
    expect(report.pendingAfter, 1);
    expect(report.playerState.wallet.coins, 0);
  });

  test('une récompense déjà versée ne peut pas être appliquée deux fois',
      () async {
    final ChallengePlayerState state = pendingState();
    final _FakeRewardGateway gateway = _FakeRewardGateway(
      response: responseFor(state),
    );
    final ChallengeRewardSyncReport first =
        await ChallengeRewardSyncService.synchronize(
      playerState: state,
      deviceNow: now,
      gateway: gateway,
    );
    final _FakeRewardGateway refreshGateway = _FakeRewardGateway(
      response: ChallengeRewardValidationResponse(
        serverNowUtc: now.add(const Duration(minutes: 3)),
        results: const <ChallengeRewardValidationResult>[],
        authoritativeWallet: first.playerState.wallet,
      ),
    );
    final ChallengeRewardSyncReport second =
        await ChallengeRewardSyncService.synchronize(
      playerState: first.playerState,
      deviceNow: now.add(const Duration(minutes: 3)),
      gateway: refreshGateway,
    );

    expect(first.playerState.wallet.coins, 25);
    expect(second.status, ChallengeRewardSyncStatus.upToDate);
    expect(second.playerState.wallet.coins, 25);
    expect(gateway.callCount, 1);
    expect(refreshGateway.callCount, 1);
  });

  test('le refus serveur survit à la sérialisation', () {
    final ChallengePlayerState state = pendingState();
    final String claimId = state.rewardLedger.pendingClaims.single.claimId;
    final ChallengePlayerState rejected = state.copyWith(
      rewardLedger: state.rewardLedger.reject(
        claimId,
        reason: 'Récompense déjà obtenue sur un autre appareil.',
      ),
    );
    final ChallengePlayerState restored =
        ChallengePlayerState.fromJson(rejected.toJson());
    final ChallengeRewardClaimRecord claim =
        restored.rewardLedger.claims[claimId]!;

    expect(claim.status, ChallengeRewardClaimStatus.rejected);
    expect(claim.rejectionReason, contains('autre appareil'));
    expect(restored.rewardLedger.pendingClaims, isEmpty);
  });
}
