import '../../player/player_level.dart';
import '../../player/player_profile.dart';
import '../collections/passport_collection_catalog.dart';
import '../collections/passport_collection_item.dart';
import 'passport_level_goal.dart';

class PassportMajorLevelUp {
  const PassportMajorLevelUp({
    required this.previousLevel,
    required this.newLevel,
    required this.rewards,
    required this.nextGoal,
  });

  final PlayerLevel previousLevel;
  final PlayerLevel newLevel;
  final List<PassportCollectionItem> rewards;
  final PassportLevelGoal nextGoal;

  String get nextObjective {
    if (nextGoal.isMaximumLevel) {
      return 'Tous les niveaux et récompenses sont débloqués.';
    }
    return '${nextGoal.xpRemaining} XP avant ${nextGoal.nextLevelLabel}';
  }

  static PassportMajorLevelUp? between({
    required PlayerProfile beforeProfile,
    required PlayerProfile afterProfile,
  }) {
    if (afterProfile.majorLevel <= beforeProfile.majorLevel) {
      return null;
    }

    return PassportMajorLevelUp(
      previousLevel: beforeProfile.level,
      newLevel: afterProfile.level,
      rewards: List<PassportCollectionItem>.unmodifiable(
        PassportCollectionCatalog.levelRewardsUnlockedBetween(
          previousLevel: beforeProfile.currentLevel,
          newLevel: afterProfile.currentLevel,
        ),
      ),
      nextGoal: PassportLevelGoal.forProfile(afterProfile),
    );
  }
}
