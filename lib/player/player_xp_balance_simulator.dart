import 'player_level.dart';
import 'xp_system.dart';

class PlayerXpPaceScenario {
  const PlayerXpPaceScenario({
    required this.id,
    required this.label,
    required this.gamesPerWeek,
    required this.averageXpPerGame,
    required this.activeDaysPerWeek,
    required this.otherAverageXpPerWeek,
  });

  final String id;
  final String label;
  final int gamesPerWeek;

  /// XP moyenne d'une partie, hors première réussite du jour et hors bonus
  /// uniques de découverte, maîtrise, mission ou accomplissement.
  final int averageXpPerGame;

  final int activeDaysPerWeek;

  /// Moyenne hebdomadaire lissée des récompenses uniques réellement obtenues.
  /// Ce nombre n'est ni un plafond, ni une récompense automatique.
  final int otherAverageXpPerWeek;

  int get gameXpPerWeek => gamesPerWeek * averageXpPerGame;

  int get firstSuccessXpPerWeek =>
      activeDaysPerWeek * XpSystem.firstSuccessOfDayXp;

  int get totalXpPerWeek =>
      gameXpPerWeek + firstSuccessXpPerWeek + otherAverageXpPerWeek;

  bool get isValid =>
      id.trim().isNotEmpty &&
      label.trim().isNotEmpty &&
      gamesPerWeek > 0 &&
      averageXpPerGame > 0 &&
      activeDaysPerWeek >= 1 &&
      activeDaysPerWeek <= 7 &&
      otherAverageXpPerWeek >= 0;
}

class PlayerXpBalanceMilestone {
  const PlayerXpBalanceMilestone({
    required this.level,
    required this.targetXp,
    required this.estimatedWeeks,
  });

  final PlayerLevel level;
  final int targetXp;
  final int estimatedWeeks;

  double get estimatedMonths => estimatedWeeks / 4.345;
}

class PlayerXpBalanceSimulation {
  const PlayerXpBalanceSimulation({
    required this.scenario,
    required this.majorLevelMilestones,
    required this.maximumLevelMilestone,
  });

  final PlayerXpPaceScenario scenario;
  final List<PlayerXpBalanceMilestone> majorLevelMilestones;
  final PlayerXpBalanceMilestone maximumLevelMilestone;
}

class PlayerXpBalanceSimulator {
  const PlayerXpBalanceSimulator._();

  static const List<PlayerXpPaceScenario> referenceScenarios =
      <PlayerXpPaceScenario>[
    PlayerXpPaceScenario(
      id: 'casual',
      label: 'Occasionnel',
      gamesPerWeek: 6,
      averageXpPerGame: 34,
      activeDaysPerWeek: 2,
      otherAverageXpPerWeek: 56,
    ),
    PlayerXpPaceScenario(
      id: 'regular',
      label: 'Régulier',
      gamesPerWeek: 20,
      averageXpPerGame: 42,
      activeDaysPerWeek: 5,
      otherAverageXpPerWeek: 210,
    ),
    PlayerXpPaceScenario(
      id: 'intensive',
      label: 'Intensif',
      gamesPerWeek: 50,
      averageXpPerGame: 52,
      activeDaysPerWeek: 7,
      otherAverageXpPerWeek: 560,
    ),
  ];

  static PlayerXpBalanceSimulation simulate(
    PlayerXpPaceScenario scenario,
  ) {
    if (!scenario.isValid) {
      throw ArgumentError.value(
        scenario,
        'scenario',
        'Le scénario de progression est invalide.',
      );
    }

    final List<PlayerXpBalanceMilestone> milestones =
        <PlayerXpBalanceMilestone>[];
    for (int majorLevel = 1;
        majorLevel <= PlayerLevelCatalog.majorLevelCount;
        majorLevel++) {
      final int internalLevel =
          PlayerLevelCatalog.firstInternalLevelForMajorLevel(majorLevel);
      final PlayerLevel level = PlayerLevelCatalog.forLevel(internalLevel);
      milestones.add(
        PlayerXpBalanceMilestone(
          level: level,
          targetXp: level.requiredTotalXp,
          estimatedWeeks: _weeksToReach(
            level.requiredTotalXp,
            scenario.totalXpPerWeek,
          ),
        ),
      );
    }

    final PlayerLevel maximumLevel = PlayerLevelCatalog.forLevel(
      PlayerLevelCatalog.maximumLevel,
    );
    return PlayerXpBalanceSimulation(
      scenario: scenario,
      majorLevelMilestones:
          List<PlayerXpBalanceMilestone>.unmodifiable(milestones),
      maximumLevelMilestone: PlayerXpBalanceMilestone(
        level: maximumLevel,
        targetXp: maximumLevel.requiredTotalXp,
        estimatedWeeks: _weeksToReach(
          maximumLevel.requiredTotalXp,
          scenario.totalXpPerWeek,
        ),
      ),
    );
  }

  static List<PlayerXpBalanceSimulation> simulateReferenceScenarios() {
    return referenceScenarios
        .map(PlayerXpBalanceSimulator.simulate)
        .toList(growable: false);
  }

  static int _weeksToReach(int targetXp, int xpPerWeek) {
    if (targetXp <= 0) {
      return 0;
    }
    return (targetXp + xpPerWeek - 1) ~/ xpPerWeek;
  }
}
