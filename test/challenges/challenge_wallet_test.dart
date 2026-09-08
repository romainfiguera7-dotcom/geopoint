import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_wallet.dart';

void main() {
  const ChallengeReward reward = ChallengeReward(
    xp: 80,
    coins: 25,
    diamonds: 2,
    cosmeticIds: <String>['hat_explorer'],
    stampId: 'stamp_daily',
    emblemId: 'emblem_monthly',
    progressionPoints: 3,
  );

  test('verse toutes les récompenses confirmées', () {
    final ChallengeRewardDeliveryDecision delivery =
        const ChallengeWallet().deliver(
      claimId: 'daily_1@2026-09-04',
      confirmed: true,
      reward: reward,
    );

    expect(delivery.wasDelivered, isTrue);
    expect(delivery.updatedWallet.coins, 25);
    expect(delivery.updatedWallet.diamonds, 2);
    expect(delivery.updatedWallet.progressionPoints, 3);
    expect(delivery.updatedWallet.cosmeticIds, contains('hat_explorer'));
    expect(delivery.updatedWallet.stampIds, contains('stamp_daily'));
    expect(delivery.updatedWallet.emblemIds, contains('emblem_monthly'));
  });

  test('refuse une récompense encore en attente du serveur', () {
    final ChallengeRewardDeliveryDecision delivery =
        const ChallengeWallet().deliver(
      claimId: 'pending_claim',
      confirmed: false,
      reward: reward,
    );

    expect(
      delivery.outcome,
      ChallengeRewardDeliveryOutcome.rejectedPending,
    );
    expect(delivery.updatedWallet.coins, 0);
    expect(delivery.updatedWallet.deliveredClaimIds, isEmpty);
  });

  test('ne verse jamais deux fois le même identifiant', () {
    final ChallengeRewardDeliveryDecision first =
        const ChallengeWallet().deliver(
      claimId: 'unique_claim',
      confirmed: true,
      reward: reward,
    );
    final ChallengeRewardDeliveryDecision duplicate =
        first.updatedWallet.deliver(
      claimId: 'unique_claim',
      confirmed: true,
      reward: reward,
    );

    expect(
      duplicate.outcome,
      ChallengeRewardDeliveryOutcome.rejectedDuplicate,
    );
    expect(duplicate.updatedWallet.coins, 25);
    expect(duplicate.updatedWallet.diamonds, 2);
  });

  test('le portefeuille survit à la sérialisation', () {
    final ChallengeWallet source = const ChallengeWallet().deliver(
      claimId: 'persisted_claim',
      confirmed: true,
      reward: reward,
    ).updatedWallet;
    final ChallengeWallet restored =
        ChallengeWallet.fromJson(source.toJson());

    expect(restored.coins, source.coins);
    expect(restored.diamonds, source.diamonds);
    expect(restored.progressionPoints, source.progressionPoints);
    expect(restored.deliveredClaimIds, contains('persisted_claim'));
    expect(restored.cosmeticIds, contains('hat_explorer'));
  });
}
