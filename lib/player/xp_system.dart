import 'level_result.dart';
import 'player_level.dart';
import 'player_profile.dart';

class XpSystem {
  const XpSystem();

  static const int baseGameXp = 25;
  static const int correctAnswerXp = 10;
  static const int perfectGameBonus = 50;
  static const int precisionBonus = 30;

  static const int ultimateBaseGameXp = 50;
  static const int ultimateCorrectAnswerXp = 10;
  static const int ultimatePerfectGameBonus = 75;

  LevelResult applyGameResult({
    required PlayerProfile profile,
    required int correctAnswers,
    required int totalQuestions,
    required double averageDistanceKm,
    String difficultyId = 'discovery',
  }) {
    int earnedXp = baseGameXp;

    earnedXp += correctAnswers * correctAnswerXp;

    earnedXp += difficultyBonusFor(difficultyId);

    if (totalQuestions > 0 && correctAnswers == totalQuestions) {
      earnedXp += perfectGameBonus;
    }

    if (correctAnswers > 0 && averageDistanceKm <= 50) {
      earnedXp += precisionBonus;
    }

    final int previousXp = profile.totalXp;

    final int newXp = previousXp + earnedXp;

    final int previousLevel = profile.currentLevel;

    final int newLevel = PlayerLevelCatalog.levelForTotalXp(newXp);

    final String previousTitle = PlayerLevelCatalog.titleForLevel(
      previousLevel,
    );

    final String newTitle = PlayerLevelCatalog.titleForLevel(newLevel);

    return LevelResult(
      earnedXp: earnedXp,
      previousTotalXp: previousXp,
      newTotalXp: newXp,
      previousLevel: previousLevel,
      newLevel: newLevel,
      previousTitle: previousTitle,
      newTitle: newTitle,
    );
  }

  LevelResult applyUltimateGameResult({
    required PlayerProfile profile,
    required int correctAnswers,
    required int totalQuestions,
    required String difficultyId,
  }) {
    int earnedXp = ultimateBaseGameXp;

    earnedXp += correctAnswers * ultimateCorrectAnswerXp;

    earnedXp += difficultyBonusFor(difficultyId);

    if (totalQuestions > 0 && correctAnswers == totalQuestions) {
      earnedXp += ultimatePerfectGameBonus;
    }

    return _buildLevelResult(profile: profile, earnedXp: earnedXp);
  }

  static int difficultyBonusFor(String difficultyId) {
    switch (difficultyId.trim().toLowerCase()) {
      case 'easy':
        return 15;

      case 'intermediate':
        return 30;

      case 'hard':
        return 50;

      case 'expert':
        return 75;

      case 'discovery':
      default:
        return 0;
    }
  }

  LevelResult _buildLevelResult({
    required PlayerProfile profile,
    required int earnedXp,
  }) {
    final int previousXp = profile.totalXp;

    final int newXp = previousXp + earnedXp;

    final int previousLevel = profile.currentLevel;

    final int newLevel = PlayerLevelCatalog.levelForTotalXp(newXp);

    final String previousTitle = PlayerLevelCatalog.titleForLevel(
      previousLevel,
    );

    final String newTitle = PlayerLevelCatalog.titleForLevel(newLevel);

    return LevelResult(
      earnedXp: earnedXp,
      previousTotalXp: previousXp,
      newTotalXp: newXp,
      previousLevel: previousLevel,
      newLevel: newLevel,
      previousTitle: previousTitle,
      newTitle: newTitle,
    );
  }
}
