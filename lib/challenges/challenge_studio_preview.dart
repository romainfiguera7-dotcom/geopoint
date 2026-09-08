import 'challenge_definition.dart';
import 'challenge_eligibility.dart';
import 'challenge_pack.dart';

class ChallengeStudioPreview {
  const ChallengeStudioPreview({
    required this.simulatedAtUtc,
    required this.playerLevel,
    required this.isChildProfile,
    required this.visibleChallenges,
  });

  final DateTime simulatedAtUtc;
  final int playerLevel;
  final bool isChildProfile;
  final List<ChallengeDefinition> visibleChallenges;

  factory ChallengeStudioPreview.evaluate({
    required ChallengePack pack,
    required DateTime simulatedAt,
    required int playerLevel,
    required bool isChildProfile,
  }) {
    final int safeLevel = playerLevel.clamp(1, 100).toInt();
    return ChallengeStudioPreview(
      simulatedAtUtc: simulatedAt.toUtc(),
      playerLevel: safeLevel,
      isChildProfile: isChildProfile,
      visibleChallenges: ChallengeEligibility.activeForPlayer(
        pack: pack,
        now: simulatedAt,
        player: ChallengePlayerContext(
          playerLevel: safeLevel,
          isChildProfile: isChildProfile,
        ),
      ),
    );
  }

  ChallengeDefinition? challengeFor(ChallengePeriod period) {
    final List<ChallengeDefinition> matches = challengesFor(period);
    return matches.isEmpty ? null : matches.first;
  }

  List<ChallengeDefinition> challengesFor(ChallengePeriod period) {
    return visibleChallenges
        .where(
          (ChallengeDefinition challenge) => challenge.period == period,
        )
        .toList(growable: false);
  }
}
