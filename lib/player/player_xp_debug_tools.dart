import 'player_level.dart';
import 'player_profile.dart';
import 'player_xp_ledger.dart';

enum PlayerXpDebugAction {
  addXp,
  prepareNextTier,
  prepareNextMajorLevel,
  reachMaximumLevel,
  resetXp,
}

class PlayerXpDebugTools {
  const PlayerXpDebugTools._();

  static int get maximumTotalXp =>
      PlayerLevelCatalog.requiredTotalXpForLevel(
        PlayerLevelCatalog.maximumLevel,
      );

  static PlayerProfile apply({
    required PlayerProfile profile,
    required PlayerXpDebugAction action,
    int amount = 0,
  }) {
    switch (action) {
      case PlayerXpDebugAction.addXp:
        if (amount <= 0) {
          throw ArgumentError.value(
            amount,
            'amount',
            'La quantité d’XP doit être strictement positive.',
          );
        }
        return _withTotalXp(
          profile,
          profile.totalXp + amount,
        );
      case PlayerXpDebugAction.prepareNextTier:
        if (profile.isMaximumLevel) {
          return profile;
        }
        final int nextThreshold = PlayerLevelCatalog.requiredTotalXpForLevel(
          profile.currentLevel + 1,
        );
        return _withTotalXp(profile, nextThreshold - 1);
      case PlayerXpDebugAction.prepareNextMajorLevel:
        if (profile.majorLevel >= PlayerLevelCatalog.majorLevelCount) {
          return profile;
        }
        final int nextMajorInternalLevel =
            PlayerLevelCatalog.firstInternalLevelForMajorLevel(
          profile.majorLevel + 1,
        );
        final int nextMajorThreshold =
            PlayerLevelCatalog.requiredTotalXpForLevel(
          nextMajorInternalLevel,
        );
        return _withTotalXp(profile, nextMajorThreshold - 1);
      case PlayerXpDebugAction.reachMaximumLevel:
        return _withTotalXp(profile, maximumTotalXp);
      case PlayerXpDebugAction.resetXp:
        return profile.copyWith(
          totalXp: 0,
          xpLedger: PlayerXpLedger.initial(),
        );
    }
  }

  static PlayerProfile _withTotalXp(
    PlayerProfile profile,
    int totalXp,
  ) {
    return profile.copyWith(
      totalXp: totalXp.clamp(0, maximumTotalXp),
    );
  }
}
