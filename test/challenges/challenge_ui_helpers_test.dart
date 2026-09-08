import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/features/challenges/challenge_ui_helpers.dart';

void main() {
  test('traduit les niveaux techniques pour le joueur', () {
    expect(challengeDifficultyLabel('discovery'), 'Découverte');
    expect(challengeDifficultyLabel('intermediate'), 'Intermédiaire');
    expect(challengeDifficultyLabel('expert'), 'Expert');
  });

  test('affiche un temps restant lisible', () {
    expect(challengeTimeRemaining(const Duration(days: 4)), 'Encore 4 j');
    expect(challengeTimeRemaining(const Duration(hours: 5)), 'Encore 5 h');
    expect(challengeTimeRemaining(const Duration(minutes: 12)), 'Encore 12 min');
    expect(challengeTimeRemaining(Duration.zero), 'Terminé');
  });

  test('traduit la clé du pack en mois lisible', () {
    expect(challengeMonthLabel('2026-09'), 'Septembre');
    expect(challengeMonthLabel('inconnu'), 'inconnu');
  });
}
