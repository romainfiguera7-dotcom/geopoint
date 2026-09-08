import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_player_state.dart';
import 'package:geopoint/challenges/challenge_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la progression des défis est sauvegardée et rechargée', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final DateTime playedAt = DateTime.utc(2026, 9, 4, 12);
    final ChallengePlayerState source = ChallengePlayerState.initial()
        .registerAttempt(
          challengeId: 'daily_2026_09_04',
          score: 410,
          correctAnswers: 5,
          succeeded: true,
          playedAt: playedAt,
        );

    expect(await ChallengeStorage.save(source), isTrue);
    final ChallengePlayerState? restored = await ChallengeStorage.load();

    expect(restored, isNotNull);
    expect(
      restored!.progressFor('daily_2026_09_04').completedAtUtc,
      playedAt,
    );
  });

  test('une sauvegarde illisible ne fait pas planter le jeu', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ChallengeStorage.storageKey: '{json cassé',
    });

    expect(await ChallengeStorage.load(), isNull);
  });
}
