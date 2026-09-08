import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/geobrain/geobrain_storage.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';
import 'package:geopoint/geobrain/theme_mastery.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le profil v5 sauvegarde et recharge tout l historique', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final DateTime answeredAt = DateTime.utc(2026, 8, 29, 20);
    final DateTime confirmedAt = answeredAt.subtract(const Duration(days: 1));
    final GeoBrainProfile source = GeoBrainProfile.initial(
      createdAt: answeredAt,
    ).registerAttempt(
      GeoBrainAttempt(
        countryId: 'ESP',
        theme: GeoBrainTheme.flag,
        answeredAt: confirmedAt,
        modeId: 'find_flag',
        difficultyId: 'intermediate',
        isCorrect: true,
        context: GeoBrainAttemptContext.training,
      ),
    ).registerAttempt(
      GeoBrainAttempt(
        countryId: 'ESP',
        theme: GeoBrainTheme.flag,
        answeredAt: answeredAt,
        modeId: 'find_flag',
        difficultyId: 'hard',
        isCorrect: false,
        responseTimeMilliseconds: 8300,
        helpId: 'flag_hint',
        proposedAnswerId: 'PRT',
        context: GeoBrainAttemptContext.expedition,
      ),
    );

    expect(await GeoBrainStorage.save(source), isTrue);
    final GeoBrainProfile? restored = await GeoBrainStorage.load();
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final Map<String, dynamic> envelope = jsonDecode(
      preferences.getString('geopoint_geobrain_profile')!,
    ) as Map<String, dynamic>;

    expect(envelope['dataSchemaVersion'], 5);
    expect(restored, isNotNull);
    expect(restored!.schemaVersion, GeoBrainProfile.currentSchemaVersion);
    expect(restored.totalAttempts, 2);
    expect(restored.detailedAttemptCount, 2);
    final GeoBrainAttempt attempt = restored.attemptHistory.last;
    expect(attempt.countryId, 'ESP');
    expect(attempt.theme, GeoBrainTheme.flag);
    expect(attempt.difficultyId, 'hard');
    expect(attempt.responseTimeMilliseconds, 8300);
    expect(attempt.helpId, 'flag_hint');
    expect(attempt.proposedAnswerId, 'PRT');
    expect(attempt.context, GeoBrainAttemptContext.expedition);
    final ThemeMastery restoredTheme = restored
        .masteryFor('ESP')
        .masteryForTheme(GeoBrainTheme.flag);
    expect(restoredTheme.highestScore, greaterThan(restoredTheme.score));
    expect(restoredTheme.lastConfirmedAt, confirmedAt);
    expect(restoredTheme.nextReviewAt, isNotNull);
    expect(restoredTheme.successfulReviewCount, 0);
  });

  test('une sauvegarde v1 est mise à niveau sans perdre sa progression',
      () async {
    final DateTime reviewedAt = DateTime.utc(2026, 6, 1);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'geopoint_geobrain_profile': jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'countries': <String, dynamic>{
          'FRA': <String, dynamic>{
            'countryId': 'FRA',
            'masteryLevel': 4,
            'correctAnswers': 7,
            'wrongAnswers': 2,
            'totalAttempts': 9,
            'currentStreak': 2,
            'bestStreak': 4,
            'lastReviewedAt': reviewedAt.toIso8601String(),
            'nextReviewAt': reviewedAt
                .add(const Duration(days: 21))
                .toIso8601String(),
            'isWishlisted': false,
            'isVisited': true,
          },
        },
        'createdAt': reviewedAt.toIso8601String(),
        'updatedAt': reviewedAt.toIso8601String(),
      }),
    });

    final GeoBrainProfile? migrated = await GeoBrainStorage.load();

    expect(migrated, isNotNull);
    expect(migrated!.schemaVersion, GeoBrainProfile.currentSchemaVersion);
    expect(migrated.totalAttempts, 9);
    expect(migrated.masteryFor('FRA').masteryLevel, 4);
    expect(migrated.masteryFor('FRA').isVisited, isTrue);
    expect(
      migrated
          .masteryFor('FRA')
          .masteryForTheme(GeoBrainTheme.location)
          .totalAttempts,
      9,
    );
    expect(migrated.detailedAttemptCount, 0);
    final ThemeMastery migratedTheme = migrated
        .masteryFor('FRA')
        .masteryForTheme(GeoBrainTheme.location);
    expect(migratedTheme.highestScore, 80);
    expect(migratedTheme.lastConfirmedAt, reviewedAt);
    expect(migratedTheme.successfulReviewCount, 5);
    expect(
      migratedTheme.nextReviewAt,
      reviewedAt.add(const Duration(days: 21)),
    );
  });

  test('le passage du schéma 2 au calcul pondéré préserve sa base acquise',
      () async {
    final DateTime first = DateTime.utc(2026, 8, 20, 12);
    final List<Map<String, dynamic>> history = <Map<String, dynamic>>[
      for (int index = 0; index < 2; index++)
        <String, dynamic>{
          'countryId': 'FRA',
          'theme': 'location',
          'answeredAt': first.add(Duration(days: index)).toIso8601String(),
          'modeId': 'find_country',
          'difficultyId': 'intermediate',
          'isCorrect': true,
          'context': 'game',
        },
    ];
    SharedPreferences.setMockInitialValues(<String, Object>{
      'geopoint_geobrain_profile': jsonEncode(<String, dynamic>{
        'schemaVersion': 2,
        'countries': <String, dynamic>{
          'FRA': <String, dynamic>{
            'countryId': 'FRA',
            'masteryLevel': 3,
            'correctAnswers': 4,
            'wrongAnswers': 1,
            'totalAttempts': 5,
            'currentStreak': 2,
            'bestStreak': 3,
            'lastReviewedAt': first.toIso8601String(),
            'isWishlisted': false,
            'isVisited': false,
            'themeMasteries': <String, dynamic>{
              'location': <String, dynamic>{
                'theme': 'location',
                'score': 60,
                'correctAnswers': 4,
                'wrongAnswers': 1,
                'totalAttempts': 5,
                'currentStreak': 2,
                'bestStreak': 3,
                'firstLearnedAt': first.toIso8601String(),
                'lastReviewedAt': first.toIso8601String(),
              },
            },
            'attempts': history,
          },
        },
        'createdAt': first.toIso8601String(),
        'updatedAt': first.toIso8601String(),
      }),
    });

    final GeoBrainProfile? migrated = await GeoBrainStorage.load();
    final ThemeMastery theme = migrated!
        .masteryFor('FRA')
        .masteryForTheme(GeoBrainTheme.location);
    final GeoBrainProfile updated = migrated.registerAttempt(
      GeoBrainAttempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: first.add(const Duration(days: 2)),
        modeId: 'find_country',
        difficultyId: 'intermediate',
        isCorrect: true,
        context: GeoBrainAttemptContext.classicGame,
      ),
    );

    expect(migrated.schemaVersion, 5);
    expect(theme.legacyAttemptCount, 3);
    expect(theme.legacyBaselineScore, 60);
    expect(updated.masteryFor('FRA').totalAttempts, 6);
    expect(updated.masteryFor('FRA').attempts, hasLength(3));
    expect(
      updated.masteryFor('FRA').masteryForTheme(GeoBrainTheme.location).score,
      greaterThan(50),
    );
  });
}
