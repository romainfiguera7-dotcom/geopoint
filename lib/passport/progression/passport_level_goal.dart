import '../../player/player_level.dart';
import '../../player/player_profile.dart';
import '../collections/passport_collection_catalog.dart';
import '../collections/passport_collection_item.dart';

class PassportLevelGoal {
  const PassportLevelGoal({
    required this.currentLevel,
    required this.nextLevel,
    required this.xpRemaining,
    required this.xpTarget,
    required this.progress,
    required this.rewards,
  });

  final PlayerLevel currentLevel;
  final PlayerLevel? nextLevel;
  final int xpRemaining;
  final int xpTarget;
  final double progress;
  final List<PassportCollectionItem> rewards;

  bool get isMaximumLevel => nextLevel == null;

  String get nextLevelLabel {
    return nextLevel?.displayTitle ?? 'Maître du monde IV';
  }

  String get rewardSummary {
    if (rewards.isEmpty) {
      return isMaximumLevel
          ? 'Toutes les récompenses de niveau sont débloquées.'
          : 'Récompense de progression';
    }
    if (rewards.length == 1) {
      return rewards.single.name;
    }
    return '${rewards.first.name} + ${rewards.length - 1} autre'
        '${rewards.length > 2 ? 's' : ''}';
  }

  String get rewardCategoryLabel {
    if (rewards.isEmpty) {
      return isMaximumLevel ? 'COLLECTION TERMINÉE' : 'RÉCOMPENSE';
    }
    if (rewards.length > 1) {
      return '${rewards.length} RÉCOMPENSES';
    }
    return rewards.single.category.label.toUpperCase();
  }

  factory PassportLevelGoal.forProfile(PlayerProfile profile) {
    final PlayerLevel current = profile.level;
    if (profile.isMaximumLevel) {
      return PassportLevelGoal(
        currentLevel: current,
        nextLevel: null,
        xpRemaining: 0,
        xpTarget: 0,
        progress: 1,
        rewards: const <PassportCollectionItem>[],
      );
    }

    final PlayerLevel next = PlayerLevelCatalog.forLevel(current.level + 1);
    return PassportLevelGoal(
      currentLevel: current,
      nextLevel: next,
      xpRemaining: profile.xpRemainingForNextLevel,
      xpTarget: profile.xpForNextLevel,
      progress: profile.levelProgress,
      rewards: List<PassportCollectionItem>.unmodifiable(
        PassportCollectionCatalog.levelRewardsForLevel(next.level),
      ),
    );
  }
}
