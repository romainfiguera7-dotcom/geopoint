import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/player/player_level.dart';
import 'package:geopoint/player/player_xp_balance_simulator.dart';

void main() {
  test('les trois scénarios utilisent les rythmes hebdomadaires retenus', () {
    final List<PlayerXpPaceScenario> scenarios =
        PlayerXpBalanceSimulator.referenceScenarios;

    expect(scenarios, hasLength(3));
    expect(scenarios[0].label, 'Occasionnel');
    expect(scenarios[0].totalXpPerWeek, 300);
    expect(scenarios[1].label, 'Régulier');
    expect(scenarios[1].totalXpPerWeek, 1150);
    expect(scenarios[2].label, 'Intensif');
    expect(scenarios[2].totalXpPerWeek, 3300);
  });

  test('chaque simulation contient les 12 grands niveaux réels', () {
    for (final PlayerXpBalanceSimulation simulation
        in PlayerXpBalanceSimulator.simulateReferenceScenarios()) {
      expect(
        simulation.majorLevelMilestones,
        hasLength(PlayerLevelCatalog.majorLevelCount),
      );
      for (int index = 0;
          index < simulation.majorLevelMilestones.length;
          index++) {
        final PlayerXpBalanceMilestone milestone =
            simulation.majorLevelMilestones[index];
        expect(milestone.level.majorLevel, index + 1);
        expect(milestone.level.tier, 1);
        expect(
          milestone.targetXp,
          PlayerLevelCatalog.majorLevelXpBoundaries[index],
        );
      }
    }
  });

  test('estime le niveau maximal à 221, 58 et 21 semaines', () {
    final List<PlayerXpBalanceSimulation> simulations =
        PlayerXpBalanceSimulator.simulateReferenceScenarios();

    expect(simulations[0].maximumLevelMilestone.estimatedWeeks, 221);
    expect(simulations[1].maximumLevelMilestone.estimatedWeeks, 58);
    expect(simulations[2].maximumLevelMilestone.estimatedWeeks, 21);
    for (final PlayerXpBalanceSimulation simulation in simulations) {
      expect(simulation.maximumLevelMilestone.targetXp, 66250);
      expect(simulation.maximumLevelMilestone.level.level, 48);
    }
  });

  test('davantage de parties donne toujours toute leur XP sans plafond', () {
    const PlayerXpPaceScenario oneGame = PlayerXpPaceScenario(
      id: 'one',
      label: 'Une partie',
      gamesPerWeek: 1,
      averageXpPerGame: 40,
      activeDaysPerWeek: 1,
      otherAverageXpPerWeek: 0,
    );
    const PlayerXpPaceScenario oneHundredGames = PlayerXpPaceScenario(
      id: 'hundred',
      label: 'Cent parties',
      gamesPerWeek: 100,
      averageXpPerGame: 40,
      activeDaysPerWeek: 1,
      otherAverageXpPerWeek: 0,
    );

    expect(
      oneHundredGames.totalXpPerWeek - oneGame.totalXpPerWeek,
      99 * 40,
    );
    expect(
      PlayerXpBalanceSimulator.simulate(oneHundredGames)
          .maximumLevelMilestone
          .estimatedWeeks,
      lessThan(
        PlayerXpBalanceSimulator.simulate(oneGame)
            .maximumLevelMilestone
            .estimatedWeeks,
      ),
    );
  });

  test('refuse un scénario incohérent', () {
    const PlayerXpPaceScenario invalid = PlayerXpPaceScenario(
      id: 'invalid',
      label: 'Invalide',
      gamesPerWeek: 0,
      averageXpPerGame: 40,
      activeDaysPerWeek: 8,
      otherAverageXpPerWeek: 0,
    );

    expect(
      () => PlayerXpBalanceSimulator.simulate(invalid),
      throwsArgumentError,
    );
  });
}
