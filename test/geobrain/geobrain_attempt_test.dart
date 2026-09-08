import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';

void main() {
  test('une tentative conserve toutes les informations pédagogiques', () {
    final DateTime answeredAt = DateTime.utc(2026, 8, 29, 20, 15);
    final GeoBrainAttempt source = GeoBrainAttempt(
      countryId: ' fra ',
      theme: GeoBrainTheme.capital,
      answeredAt: answeredAt,
      modeId: ' FIND_CAPITAL ',
      difficultyId: ' HARD ',
      isCorrect: false,
      distanceInKilometers: 182.5,
      responseTimeMilliseconds: 7420,
      helpId: ' Continent_Hint ',
      proposedAnswerId: 'Lyon',
      context: GeoBrainAttemptContext.training,
    );

    final GeoBrainAttempt restored = GeoBrainAttempt.fromJson(
      source.toJson(),
    );

    expect(restored.countryId, 'FRA');
    expect(restored.theme, GeoBrainTheme.capital);
    expect(restored.answeredAt, answeredAt);
    expect(restored.modeId, 'find_capital');
    expect(restored.difficultyId, 'hard');
    expect(restored.isCorrect, isFalse);
    expect(restored.distanceInKilometers, 182.5);
    expect(restored.responseTime, const Duration(milliseconds: 7420));
    expect(restored.helpId, 'continent_hint');
    expect(restored.usedHelp, isTrue);
    expect(restored.proposedAnswerId, 'Lyon');
    expect(restored.context, GeoBrainAttemptContext.training);
  });

  test('les valeurs facultatives invalides ne polluent pas la sauvegarde', () {
    final GeoBrainAttempt restored = GeoBrainAttempt.fromJson(
      <String, dynamic>{
        'countryId': 'ESP',
        'theme': 'flag',
        'answeredAt': DateTime.utc(2026, 8, 29).toIso8601String(),
        'modeId': 'find_flag',
        'difficultyId': 'easy',
        'isCorrect': true,
        'distanceInKilometers': -25,
        'responseTimeMilliseconds': -100,
        'helpId': ' ',
        'proposedAnswerId': '',
        'context': 'game',
      },
    );

    expect(restored.distanceInKilometers, isNull);
    expect(restored.responseTimeMilliseconds, 0);
    expect(restored.usedHelp, isFalse);
    expect(restored.proposedAnswerId, isNull);
  });
}
