import 'challenge_definition.dart';
import 'challenge_pack.dart';

class ChallengePlayerContext {
  const ChallengePlayerContext({
    required this.playerLevel,
    this.isChildProfile = false,
  });

  final int playerLevel;
  final bool isChildProfile;
}

class ChallengeEligibility {
  const ChallengeEligibility._();

  static List<ChallengeDefinition> activeForPlayer({
    required ChallengePack pack,
    required DateTime now,
    required ChallengePlayerContext player,
  }) {
    final List<ChallengeDefinition> active = pack.activeChallengesAt(now);
    final Map<String, ChallengeDefinition> byId = <String, ChallengeDefinition>{
      for (final ChallengeDefinition challenge in active)
        challenge.id: challenge,
    };
    final List<ChallengeDefinition> result = <ChallengeDefinition>[];
    final Set<String> addedIds = <String>{};

    for (final ChallengeDefinition challenge in active) {
      if (challenge.audience != ChallengeAudience.standard) {
        continue;
      }

      ChallengeDefinition selected = challenge;
      if (player.isChildProfile && challenge.childVariantId != null) {
        final ChallengeDefinition? variant = byId[challenge.childVariantId!];
        if (variant != null &&
            variant.audience == ChallengeAudience.child &&
            player.playerLevel >= variant.minimumPlayerLevel) {
          selected = variant;
        }
      } else if (player.isChildProfile) {
        // Un contenu sans variante explicitement contrôlée n'est jamais
        // exposé à un profil enfant.
        continue;
      } else if (!player.isChildProfile &&
          player.playerLevel < challenge.minimumPlayerLevel &&
          challenge.beginnerVariantId != null) {
        final ChallengeDefinition? variant =
            byId[challenge.beginnerVariantId!];
        if (variant != null &&
            variant.audience == ChallengeAudience.beginner &&
            player.playerLevel >= variant.minimumPlayerLevel) {
          selected = variant;
        }
      }

      if (player.playerLevel < selected.minimumPlayerLevel) {
        continue;
      }

      if (addedIds.add(selected.id)) {
        result.add(selected);
      }
    }

    return List<ChallengeDefinition>.unmodifiable(result);
  }
}
