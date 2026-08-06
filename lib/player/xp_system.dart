import 'level_result.dart';
import 'player_level.dart';
import 'player_profile.dart';

class XpSystem {
  const XpSystem();

  static const int baseGameXp = 25;
  static const int correctAnswerXp = 10;
  static const int perfectGameBonus = 50;
  static const int precisionBonus = 30;

  LevelResult applyGameResult({
    required PlayerProfile profile,
    required int correctAnswers,
    required int totalQuestions,
    required double averageDistanceKm,
  }) {
    int earnedXp = baseGameXp;

    earnedXp +=
        correctAnswers * correctAnswerXp;

    if (correctAnswers ==
        totalQuestions) {
      earnedXp +=
          perfectGameBonus;
    }

    if (averageDistanceKm <= 50) {
      earnedXp +=
          precisionBonus;
    }

    final int previousXp =
        profile.totalXp;

    final int newXp =
        previousXp + earnedXp;

    final int previousLevel =
        profile.currentLevel;

    final int newLevel =
        PlayerLevelCatalog.levelForTotalXp(
      newXp,
    );

    final String previousTitle =
        PlayerLevelCatalog
            .titleForLevel(
      previousLevel,
    );

    final String newTitle =
        PlayerLevelCatalog
            .titleForLevel(
      newLevel,
    );

    return LevelResult(
      earnedXp: earnedXp,
      previousTotalXp: previousXp,
      newTotalXp: newXp,
      previousLevel: previousLevel,
      newLevel: newLevel,
      previousTitle:
          previousTitle,
      newTitle:
          newTitle,
    );
  }
}