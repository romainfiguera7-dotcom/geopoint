import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_studio_draft.dart';
import 'package:geopoint/challenges/challenge_studio_exporter.dart';
import 'package:geopoint/challenges/challenge_studio_preview.dart';

void main() {
  ChallengeStudioDraft draft({
    required String id,
    required ChallengePeriod period,
    required DateTime start,
    required DateTime end,
    bool disabled = false,
    int minimumPlayerLevel = 1,
  }) {
    return ChallengeStudioDraft(
      id: id,
      period: period,
      title: 'Défi $id',
      description: 'Prévisualisation Studio.',
      validFromUtc: start,
      validUntilUtc: end,
      modeId: 'find_country',
      difficultyId: 'intermediate',
      continentId: 'world',
      countryIds: const <String>[],
      questionCount: 10,
      minimumCorrectAnswers: 7,
      minimumScore: 0,
      rewardXp: 100,
      rewardCoins: 25,
      rewardDiamonds: 0,
      progressionPoints: 1,
      ranked: false,
      geoBrainPersonalizationAllowed: true,
      minimumPlayerLevel: minimumPlayerLevel,
      disabled: disabled,
    );
  }

  List<ChallengeStudioDraft> threePeriods({bool dailyDisabled = false}) {
    return <ChallengeStudioDraft>[
      draft(
        id: 'daily_preview',
        period: ChallengePeriod.daily,
        start: DateTime.utc(2026, 9, 4),
        end: DateTime.utc(2026, 9, 5),
        disabled: dailyDisabled,
      ),
      draft(
        id: 'weekly_preview',
        period: ChallengePeriod.weekly,
        start: DateTime.utc(2026, 9, 1),
        end: DateTime.utc(2026, 9, 8),
      ),
      draft(
        id: 'monthly_preview',
        period: ChallengePeriod.monthly,
        start: DateTime.utc(2026, 9, 1),
        end: DateTime.utc(2026, 10, 1),
      ),
    ];
  }

  ChallengeStudioPreview preview({
    required List<ChallengeStudioDraft> drafts,
    bool child = false,
    DateTime? simulatedAt,
  }) {
    final ChallengeStudioExport export = ChallengeStudioExporter.build(
      drafts: drafts,
      countryIds: const <String>{'FRA'},
    );
    return ChallengeStudioPreview.evaluate(
      pack: export.pack,
      simulatedAt: simulatedAt ?? DateTime.utc(2026, 9, 4, 12),
      playerLevel: 10,
      isChildProfile: child,
    );
  }

  test('affiche un défi de chaque rythme à la date simulée', () {
    final ChallengeStudioPreview result = preview(
      drafts: threePeriods(),
    );

    expect(result.visibleChallenges, hasLength(3));
    expect(result.challengeFor(ChallengePeriod.daily)?.id, 'daily_preview');
    expect(
      result.challengeFor(ChallengePeriod.weekly)?.id,
      'weekly_preview',
    );
    expect(
      result.challengeFor(ChallengePeriod.monthly)?.id,
      'monthly_preview',
    );
  });

  test('le profil enfant voit uniquement les variantes Junior', () {
    final ChallengeStudioPreview result = preview(
      drafts: threePeriods(),
      child: true,
    );

    expect(result.visibleChallenges, hasLength(3));
    expect(
      result.visibleChallenges.every(
        (ChallengeDefinition challenge) =>
            challenge.audience == ChallengeAudience.child &&
            !challenge.retryPolicy.rewardedAdvertisementAllowed,
      ),
      isTrue,
    );
  });

  test('un défi désactivé disparaît immédiatement de l’aperçu', () {
    final ChallengeStudioPreview result = preview(
      drafts: threePeriods(dailyDisabled: true),
    );

    expect(result.challengeFor(ChallengePeriod.daily), isNull);
    expect(result.visibleChallenges, hasLength(2));
  });

  test('une date hors du pack ne montre aucun défi', () {
    final ChallengeStudioPreview result = preview(
      drafts: threePeriods(),
      simulatedAt: DateTime.utc(2026, 10, 15),
    );

    expect(result.visibleChallenges, isEmpty);
  });

  test('un débutant voit le même défi adulte classé dès le niveau 1', () {
    final ChallengeStudioDraft source = draft(
      id: 'daily_level_10',
      period: ChallengePeriod.daily,
      start: DateTime.utc(2026, 9, 4),
      end: DateTime.utc(2026, 9, 5),
      minimumPlayerLevel: 10,
    );
    final ChallengeStudioExport export = ChallengeStudioExporter.build(
      drafts: <ChallengeStudioDraft>[source],
      countryIds: const <String>{'FRA'},
    );
    final ChallengeStudioPreview result = ChallengeStudioPreview.evaluate(
      pack: export.pack,
      simulatedAt: DateTime.utc(2026, 9, 4, 12),
      playerLevel: 2,
      isChildProfile: false,
    );

    expect(result.visibleChallenges, hasLength(1));
    expect(result.visibleChallenges.single.audience, ChallengeAudience.standard);
    expect(result.visibleChallenges.single.id, 'daily_level_10');
    expect(result.visibleChallenges.single.isRanked, isTrue);
    expect(result.visibleChallenges.single.minimumPlayerLevel, 1);
  });
}
