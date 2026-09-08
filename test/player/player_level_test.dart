import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/player/player_level.dart';

void main() {
  group('PlayerLevelCatalog', () {
    test('définit 12 grands niveaux et 4 paliers chacun', () {
      expect(PlayerLevelCatalog.majorTitles, hasLength(12));
      expect(PlayerLevelCatalog.tiersPerMajorLevel, 4);
      expect(PlayerLevelCatalog.maximumLevel, 48);

      for (int level = 1; level <= PlayerLevelCatalog.maximumLevel; level++) {
        expect(PlayerLevelCatalog.forLevel(level).isValid, isTrue);
      }
    });

    test('commence à Premiers pas I avec zéro XP', () {
      final PlayerLevel level = PlayerLevelCatalog.forLevel(
        PlayerLevelCatalog.levelForTotalXp(0),
      );

      expect(level.level, 1);
      expect(level.majorLevel, 1);
      expect(level.tier, 1);
      expect(level.displayTitle, 'Premiers pas I');
      expect(level.requiredTotalXp, 0);
    });

    test('franchit correctement les paliers puis les grands niveaux', () {
      expect(PlayerLevelCatalog.levelForTotalXp(99), 1);
      expect(PlayerLevelCatalog.levelForTotalXp(100), 2);
      expect(PlayerLevelCatalog.displayTitleForLevel(4), 'Premiers pas IV');
      expect(PlayerLevelCatalog.levelForTotalXp(399), 4);
      expect(PlayerLevelCatalog.levelForTotalXp(400), 5);
      expect(PlayerLevelCatalog.displayTitleForLevel(5), 'Curieux du monde I');
      expect(PlayerLevelCatalog.levelForTotalXp(55000), 45);
      expect(PlayerLevelCatalog.displayTitleForLevel(45), 'Maître du monde I');
      expect(PlayerLevelCatalog.levelForTotalXp(66250), 48);
      expect(PlayerLevelCatalog.displayTitleForLevel(48), 'Maître du monde IV');
    });

    test('la courbe reste strictement croissante', () {
      int previousThreshold = -1;

      for (int level = 1; level <= PlayerLevelCatalog.maximumLevel; level++) {
        final int threshold =
            PlayerLevelCatalog.requiredTotalXpForLevel(level);
        expect(threshold, greaterThan(previousThreshold));
        previousThreshold = threshold;
      }
    });

    test('les 12 grands niveaux commencent aux bornes prévues', () {
      expect(
        PlayerLevelCatalog.majorLevelXpBoundaries,
        hasLength(PlayerLevelCatalog.majorLevelCount + 1),
      );

      for (int majorLevel = 1;
          majorLevel <= PlayerLevelCatalog.majorLevelCount;
          majorLevel++) {
        final int internalLevel =
            PlayerLevelCatalog.firstInternalLevelForMajorLevel(majorLevel);
        final PlayerLevel level = PlayerLevelCatalog.forLevel(internalLevel);

        expect(level.majorLevel, majorLevel);
        expect(level.tier, 1);
        expect(
          level.title,
          PlayerLevelCatalog.majorTitles[majorLevel - 1],
        );
        expect(
          level.requiredTotalXp,
          PlayerLevelCatalog.majorLevelXpBoundaries[majorLevel - 1],
        );
      }
    });

    test('chacun des 48 seuils ouvre exactement le bon palier', () {
      for (int level = 1; level <= PlayerLevelCatalog.maximumLevel; level++) {
        final int threshold =
            PlayerLevelCatalog.requiredTotalXpForLevel(level);

        expect(PlayerLevelCatalog.levelForTotalXp(threshold), level);
        if (level > PlayerLevelCatalog.minimumLevel) {
          expect(PlayerLevelCatalog.levelForTotalXp(threshold - 1), level - 1);
        }
      }
    });

    test('calcule la progression vers le prochain palier', () {
      expect(PlayerLevelCatalog.progressToNextLevel(0), 0);
      expect(PlayerLevelCatalog.progressToNextLevel(50), 0.5);
      expect(PlayerLevelCatalog.xpNeededForNextLevel(50), 50);
      expect(PlayerLevelCatalog.progressToNextLevel(66250), 1);
    });
  });
}
