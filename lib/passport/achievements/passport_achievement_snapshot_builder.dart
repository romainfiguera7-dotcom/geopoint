import '../../game/continent/continent_progress.dart';
import '../../game/expedition/expedition_progress.dart';
import '../../geo_engine/geo_country.dart';
import '../../player/player_profile.dart';
import '../../player/player_statistics.dart';
import '../progress/passport_continent_snapshot.dart';
import '../progress/passport_entity_progress.dart';
import '../progress/passport_progress_rules.dart';
import '../progress/passport_progress_v2.dart';
import 'passport_achievement.dart';

class PassportAchievementSnapshotBuilder {
  PassportAchievementSnapshotBuilder._();

  static PassportAchievementSnapshot build({
    required PassportProgressV2 progress,
    required PlayerProfile profile,
    required Iterable<GeoCountry> countries,
    required ExpeditionProgress expeditionProgress,
    required ContinentProgress continentProgress,
  }) {
    final PerformanceStatistics allTime = profile.detailedStatistics.allTime;
    final Map<PassportKnowledgeTheme, int> correctByTheme =
        <PassportKnowledgeTheme, int>{};
    int bestThemeStreak = 0;

    for (final PassportEntityProgress entity in progress.entities.values) {
      for (final PassportKnowledgeTheme theme
          in PassportKnowledgeTheme.values) {
        final PassportThemeProgress themeProgress = entity.progressFor(theme);
        correctByTheme[theme] =
            (correctByTheme[theme] ?? 0) + themeProgress.correctAnswers;
        if (themeProgress.bestStreak > bestThemeStreak) {
          bestThemeStreak = themeProgress.bestStreak;
        }
      }
    }

    final int capitalAnswers = _maximum(
      correctByTheme[PassportKnowledgeTheme.capital] ?? 0,
      profile.statisticsForMode('find_capital').correctAnswers,
    );
    final int flagAnswers = _maximum(
      correctByTheme[PassportKnowledgeTheme.flag] ?? 0,
      profile.statisticsForMode('find_flag').correctAnswers,
    );
    final int silhouetteModeAnswers =
        profile.statisticsForMode('find_silhouette').correctAnswers +
            profile.statisticsForMode('ultimate').correctAnswers;
    final int silhouetteAnswers = _maximum(
      correctByTheme[PassportKnowledgeTheme.silhouette] ?? 0,
      silhouetteModeAnswers,
    );
    final int activeDays = profile.detailedStatistics.byDay.values
        .where((PerformanceStatistics statistics) {
      return statistics.gamesPlayed > 0 || statistics.questionsPlayed > 0;
    }).length;
    final int masteredContinents = PassportContinentSnapshot.buildAll(
      countries: countries,
      progress: progress,
    ).where((PassportContinentSnapshot snapshot) {
      return snapshot.totalCount > 0 &&
          snapshot.masteredCount == snapshot.totalCount;
    }).length;

    return PassportAchievementSnapshot(
      <PassportAchievementMetric, int>{
        PassportAchievementMetric.discoveredEntities:
            progress.discoveredEntityCount,
        PassportAchievementMetric.masteredEntities:
            progress.masteredEntityCount,
        PassportAchievementMetric.masteredContinents: masteredContinents,
        PassportAchievementMetric.playDays:
            activeDays > 0 ? activeDays : (profile.gamesPlayed > 0 ? 1 : 0),
        PassportAchievementMetric.bestAnswerStreak:
            _maximum(allTime.bestStreak, bestThemeStreak),
        PassportAchievementMetric.placementsUnder10Km:
            allTime.placementsUnder10Kilometers,
        PassportAchievementMetric.placementsUnder50Km:
            allTime.placementsUnder50Kilometers,
        PassportAchievementMetric.completedExpeditionLevels:
            _completedLevels(expeditionProgress, continentProgress),
        PassportAchievementMetric.expeditionStars:
            _stars(expeditionProgress, continentProgress),
        PassportAchievementMetric.capitalCorrectAnswers: capitalAnswers,
        PassportAchievementMetric.flagCorrectAnswers: flagAnswers,
        PassportAchievementMetric.silhouetteCorrectAnswers: silhouetteAnswers,
        PassportAchievementMetric.cityCorrectAnswers:
            correctByTheme[PassportKnowledgeTheme.cities] ?? 0,
        PassportAchievementMetric.currencyCorrectAnswers:
            correctByTheme[PassportKnowledgeTheme.currency] ?? 0,
        PassportAchievementMetric.languageCorrectAnswers:
            correctByTheme[PassportKnowledgeTheme.languages] ?? 0,
        PassportAchievementMetric.visitedEntities: progress.visitedEntityCount,
        PassportAchievementMetric.wishlistedEntities:
            progress.wishlistedEntityCount,
      },
    );
  }

  static int _stars(
    ExpeditionProgress expeditionProgress,
    ContinentProgress continentProgress,
  ) {
    int total = 0;
    for (final Map<String, int> values
        in expeditionProgress.starsByExpedition.values) {
      for (final int stars in values.values) {
        total += stars.clamp(0, 3);
      }
    }
    for (final Map<String, int> values
        in continentProgress.starsByExpedition.values) {
      for (final int stars in values.values) {
        total += stars.clamp(0, 3);
      }
    }
    return total;
  }

  static int _completedLevels(
    ExpeditionProgress expeditionProgress,
    ContinentProgress continentProgress,
  ) {
    int total = 0;
    for (final Map<String, int> values
        in expeditionProgress.starsByExpedition.values) {
      total += values.values.where((int stars) => stars > 0).length;
    }
    for (final Map<String, int> values
        in continentProgress.starsByExpedition.values) {
      total += values.values.where((int stars) => stars > 0).length;
    }
    return total;
  }

  static int _maximum(int first, int second) {
    return first > second ? first : second;
  }
}
