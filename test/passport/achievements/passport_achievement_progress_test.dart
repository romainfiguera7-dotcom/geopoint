import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/passport/achievements/passport_achievement.dart';
import 'package:geopoint/passport/achievements/passport_achievement_progress.dart';

void main() {
  test('la synchronisation enregistre les paliers atteints', () {
    final DateTime completedAt = DateTime(2026, 8, 29, 12);
    final PassportAchievementProgress progress =
        PassportAchievementProgress.initial().synchronize(
      snapshot: const PassportAchievementSnapshot(
        <PassportAchievementMetric, int>{
          PassportAchievementMetric.discoveredEntities: 55,
          PassportAchievementMetric.masteredEntities: 11,
        },
      ),
      synchronizedAt: completedAt,
    );

    expect(progress.isTierCompleted('world_discovery_10'), isTrue);
    expect(progress.isTierCompleted('world_discovery_50'), isTrue);
    expect(progress.isTierCompleted('world_discovery_100'), isFalse);
    expect(progress.isTierCompleted('country_mastery_10'), isTrue);
    expect(
      progress.completedAtByTierId['world_discovery_50'],
      completedAt,
    );
  });

  test('un palier obtenu ne peut jamais être perdu', () {
    final PassportAchievementProgress unlocked =
        PassportAchievementProgress.initial().synchronize(
      snapshot: const PassportAchievementSnapshot(
        <PassportAchievementMetric, int>{
          PassportAchievementMetric.discoveredEntities: 100,
        },
      ),
    );
    final PassportAchievementProgress afterLowerValue = unlocked.synchronize(
      snapshot: const PassportAchievementSnapshot(
        <PassportAchievementMetric, int>{
          PassportAchievementMetric.discoveredEntities: 0,
        },
      ),
    );

    expect(afterLowerValue.isTierCompleted('world_discovery_100'), isTrue);
    expect(identical(unlocked, afterLowerValue), isTrue);
  });

  test('la sauvegarde conserve les dates des accomplissements', () {
    final DateTime completedAt = DateTime.utc(2026, 8, 29, 10, 30);
    final PassportAchievementProgress original =
        PassportAchievementProgress.initial().synchronize(
      snapshot: const PassportAchievementSnapshot(
        <PassportAchievementMetric, int>{
          PassportAchievementMetric.visitedEntities: 10,
        },
      ),
      synchronizedAt: completedAt,
    );
    final PassportAchievementProgress restored =
        PassportAchievementProgress.fromJson(original.toJson());

    expect(restored.isTierCompleted('personal_visited_10'), isTrue);
    expect(
      restored.completedAtByTierId['personal_visited_10'],
      completedAt,
    );
  });
}
