import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/player/player_profile.dart';

void main() {
  test('un nouveau profil commence à zéro XP', () {
    final PlayerProfile profile = PlayerProfile.initial(
      createdAt: DateTime.utc(2026, 9, 1),
    );

    expect(profile.totalXp, 0);
    expect(profile.currentLevel, 1);
    expect(profile.majorLevel, 1);
    expect(profile.levelTier, 1);
    expect(profile.displayLevelTitle, 'Premiers pas I');
  });

  test('une ancienne XP est remise à zéro sans effacer les statistiques', () {
    final PlayerProfile profile = PlayerProfile.fromJson(<String, dynamic>{
      'schemaVersion': 3,
      'playerId': 'local_player',
      'displayName': 'Voyageur',
      'avatarId': 'default',
      'totalXp': 17740,
      'gamesPlayed': 178,
      'correctAnswers': 600,
      'totalAnswers': 890,
      'totalScore': 55000,
      'totalDistanceInKilometers': 12345,
      'totalElapsedSeconds': 45678,
      'createdAt': '2026-01-01T00:00:00.000Z',
    });

    expect(profile.schemaVersion, PlayerProfile.currentSchemaVersion);
    expect(profile.totalXp, 0);
    expect(profile.gamesPlayed, 178);
    expect(profile.correctAnswers, 600);
    expect(profile.totalAnswers, 890);
    expect(profile.totalScore, 55000);
  });

  test('la nouvelle XP sauvegardée reste conservée', () {
    final PlayerProfile source = PlayerProfile.initial(
      createdAt: DateTime.utc(2026, 9, 1),
    ).copyWith(totalXp: 1250);
    final PlayerProfile restored = PlayerProfile.fromJson(source.toJson());

    expect(restored.totalXp, 1250);
    expect(restored.displayLevelTitle, 'Éclaireur I');
  });

  test('une sauvegarde 27.1 garde son XP et reçoit un registre vide', () {
    final PlayerProfile restored = PlayerProfile.fromJson(<String, dynamic>{
      'schemaVersion': 4,
      'playerId': 'local_player',
      'displayName': 'Voyageur',
      'avatarId': 'default',
      'totalXp': 1250,
      'gamesPlayed': 4,
      'correctAnswers': 20,
      'totalAnswers': 40,
      'totalScore': 3000,
      'createdAt': '2026-09-01T00:00:00.000Z',
    });

    expect(restored.totalXp, 1250);
    expect(restored.xpLedger.recentGrants, isEmpty);
    expect(restored.xpLedger.permanentGrantIds, isEmpty);
  });

  test('une ancienne sauvegarde reste un profil adulte', () {
    final PlayerProfile restored = PlayerProfile.fromJson(<String, dynamic>{
      'schemaVersion': 5,
      'playerId': 'local_player',
      'displayName': 'Voyageur',
      'avatarId': 'default',
      'totalXp': 0,
      'gamesPlayed': 0,
      'correctAnswers': 0,
      'totalAnswers': 0,
      'totalScore': 0,
      'createdAt': '2026-09-01T00:00:00.000Z',
    });

    expect(restored.isChildProfile, false);
    expect(restored.profileType, PlayerProfileType.adult);
  });

  test('la protection enfant et sa tranche d’âge sont sauvegardées', () {
    final PlayerProfile protected = PlayerProfile.initial(
      createdAt: DateTime.utc(2026, 9, 1),
    ).activateChildProtection(PlayerChildAgeGroup.ages9To11);
    final PlayerProfile restored = PlayerProfile.fromJson(protected.toJson());

    expect(restored.isChildProfile, true);
    expect(restored.childAgeGroup, PlayerChildAgeGroup.ages9To11);
    expect(restored.toJson()['profileType'], 'child');
    expect(restored.toJson()['childAgeGroup'], '9_11');
  });
}
