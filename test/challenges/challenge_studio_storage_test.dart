import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_studio_draft.dart';
import 'package:geopoint/challenges/challenge_studio_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('sauvegarde et recharge les brouillons Studio', () async {
    final ChallengeStudioDraft draft = ChallengeStudioDraft(
      id: 'monthly_storage_test',
      period: ChallengePeriod.monthly,
      title: 'Défi du mois',
      description: 'Brouillon persistant.',
      validFromUtc: DateTime.utc(2026, 9),
      validUntilUtc: DateTime.utc(2026, 10),
      modeId: 'ultimate',
      difficultyId: 'hard',
      continentId: 'world',
      countryIds: const <String>[],
      questionCount: 20,
      minimumCorrectAnswers: 15,
      minimumScore: 0,
      rewardXp: 500,
      rewardCoins: 200,
      rewardDiamonds: 1,
      progressionPoints: 5,
      ranked: false,
      geoBrainPersonalizationAllowed: true,
    );

    expect(await ChallengeStudioStorage.save(<ChallengeStudioDraft>[draft]),
        isTrue);
    final List<ChallengeStudioDraft> restored =
        await ChallengeStudioStorage.load();

    expect(restored, hasLength(1));
    expect(restored.single.id, draft.id);
    expect(restored.single.rewardDiamonds, 1);
    expect(restored.single.period, ChallengePeriod.monthly);
  });
}
