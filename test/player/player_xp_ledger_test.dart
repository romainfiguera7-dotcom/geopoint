import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/player/player_profile.dart';
import 'package:geopoint/player/player_xp_ledger.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 2, 12);

  PlayerXpGrantRequest request({
    required String id,
    required PlayerXpSource source,
    required int baseXp,
    int bonusXp = 0,
    DateTime? occurredAt,
  }) {
    return PlayerXpGrantRequest(
      grantId: id,
      source: source,
      baseXp: baseXp,
      bonusXp: bonusXp,
      occurredAt: occurredAt ?? now,
    );
  }

  test('enregistre la valeur brute, le bonus et la valeur accordée', () {
    final PlayerXpGrantDecision decision = const PlayerXpLedger().apply(
      request(
        id: 'game-001',
        source: PlayerXpSource.gameCompleted,
        baseXp: 80,
        bonusXp: 20,
      ),
    );

    expect(decision.outcome, PlayerXpGrantOutcome.granted);
    expect(decision.requestedXp, 100);
    expect(decision.awardedXp, 100);
    expect(decision.record, isNotNull);
    expect(decision.record!.baseXp, 80);
    expect(decision.record!.bonusXp, 20);
    expect(decision.record!.awardedXp, 100);
  });

  test('empêche le même gain d’être accordé deux fois', () {
    final PlayerXpGrantRequest grant = request(
      id: 'country-FRA-discovered',
      source: PlayerXpSource.countryDiscovered,
      baseXp: 10,
    );
    final PlayerXpGrantDecision first = const PlayerXpLedger().apply(grant);
    final PlayerXpGrantDecision duplicate = first.updatedLedger.apply(grant);

    expect(first.awardedXp, 10);
    expect(duplicate.outcome, PlayerXpGrantOutcome.rejectedDuplicate);
    expect(duplicate.awardedXp, 0);
    expect(
      duplicate.updatedLedger.permanentGrantIds,
      contains('country-FRA-discovered'),
    );
  });

  test('accorde toutes les parties de la journée sans plafond', () {
    final PlayerXpGrantDecision first = const PlayerXpLedger().apply(
      request(
        id: 'game-001',
        source: PlayerXpSource.gameCompleted,
        baseXp: 150,
      ),
    );
    final PlayerXpGrantDecision second = first.updatedLedger.apply(
      request(
        id: 'game-002',
        source: PlayerXpSource.gameCompleted,
        baseXp: 100,
      ),
    );
    final PlayerXpGrantDecision third = second.updatedLedger.apply(
      request(
        id: 'game-003',
        source: PlayerXpSource.gameCompleted,
        baseXp: 25,
      ),
    );

    expect(first.awardedXp, 150);
    expect(second.outcome, PlayerXpGrantOutcome.granted);
    expect(second.awardedXp, 100);
    expect(third.outcome, PlayerXpGrantOutcome.granted);
    expect(third.awardedXp, 25);
    expect(third.updatedLedger.recentGrants, hasLength(3));
  });

  test('ignore les anciens totaux journaliers lors du chargement', () {
    final PlayerXpLedger legacyLedger = PlayerXpLedger.fromJson(
      <String, dynamic>{
        'schemaVersion': 1,
        'repeatableXpByUtcDay': <String, int>{'2026-09-02': 200},
      },
    );
    final PlayerXpGrantDecision game = legacyLedger.apply(
      request(
        id: 'game-001',
        source: PlayerXpSource.gameCompleted,
        baseXp: 100,
      ),
    );

    expect(game.outcome, PlayerXpGrantOutcome.granted);
    expect(game.awardedXp, 100);
    expect(game.updatedLedger.toJson(), isNot(contains('repeatableXpByUtcDay')));
  });

  test('refuse publicité, achat, relance, tutoriel et entraînement', () {
    const List<PlayerXpSource> forbiddenSources = <PlayerXpSource>[
      PlayerXpSource.advertisement,
      PlayerXpSource.purchase,
      PlayerXpSource.paidRetry,
      PlayerXpSource.tutorialCompleted,
      PlayerXpSource.trainingCompleted,
    ];

    for (final PlayerXpSource source in forbiddenSources) {
      final PlayerXpGrantDecision decision = const PlayerXpLedger().apply(
        request(
          id: 'forbidden-${source.id}',
          source: source,
          baseXp: 100,
        ),
      );

      expect(
        decision.outcome,
        PlayerXpGrantOutcome.rejectedForbiddenSource,
        reason: source.id,
      );
      expect(decision.awardedXp, 0);
      expect(decision.updatedLedger.recentGrants, isEmpty);
    }
  });

  test('le profil applique un gain accepté sans modifier ses statistiques', () {
    final PlayerProfile before = PlayerProfile.initial(createdAt: now).copyWith(
      gamesPlayed: 12,
      totalAnswers: 120,
    );
    final PlayerXpProfileUpdate update = before.applyXpGrant(
      request(
        id: 'achievement-world-10',
        source: PlayerXpSource.achievementCompleted,
        baseXp: 50,
      ),
    );

    expect(update.decision.awardedXp, 50);
    expect(update.profile.totalXp, 50);
    expect(update.profile.gamesPlayed, 12);
    expect(update.profile.totalAnswers, 120);
    expect(
      update.profile.xpLedger.permanentGrantIds,
      contains('achievement-world-10'),
    );
  });

  test('la récompense XP d’un défi reste unique définitivement', () {
    final PlayerXpGrantRequest grant = request(
      id: 'challenge-reward:daily_2026_09_04',
      source: PlayerXpSource.challengeCompleted,
      baseXp: 85,
    );
    final PlayerXpGrantDecision first = const PlayerXpLedger().apply(grant);
    final PlayerXpGrantDecision duplicate = first.updatedLedger.apply(grant);

    expect(first.awardedXp, 85);
    expect(duplicate.outcome, PlayerXpGrantOutcome.rejectedDuplicate);
    expect(
      first.updatedLedger.permanentGrantIds,
      contains('challenge-reward:daily_2026_09_04'),
    );
  });

  test('le registre survit à la sauvegarde du profil', () {
    final PlayerProfile source = PlayerProfile.initial(createdAt: now)
        .applyXpGrant(
          request(
            id: 'mission-europe-01',
            source: PlayerXpSource.expeditionMissionCompleted,
            baseXp: 80,
          ),
        )
        .profile;
    final PlayerProfile restored = PlayerProfile.fromJson(source.toJson());

    expect(restored.totalXp, 80);
    expect(restored.xpLedger.containsGrant('mission-europe-01'), isTrue);
    expect(restored.xpLedger.recentGrants, hasLength(1));
    expect(
      restored.xpLedger.recentGrants.single.source,
      PlayerXpSource.expeditionMissionCompleted,
    );
  });
}
