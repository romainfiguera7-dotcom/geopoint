import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_eligibility.dart';
import 'package:geopoint/challenges/challenge_pack.dart';
import 'package:geopoint/challenges/challenge_pack_loader.dart';
import 'package:geopoint/challenges/challenge_pack_validator.dart';

void main() {
  late ChallengePack septemberPack;

  setUpAll(() {
    final String source = File(
      'assets/data/challenge_pack_2026_09.json',
    ).readAsStringSync();
    septemberPack = ChallengePackLoader.decode(source);
  });

  test('le pack déplie les rythmes et les six défis permanents', () {
    expect(septemberPack.challenges, hasLength(76));
    expect(
      septemberPack.challenges.where(
        (ChallengeDefinition item) =>
            item.period == ChallengePeriod.daily &&
            item.audience == ChallengeAudience.standard,
      ),
      hasLength(30),
    );
    expect(
      septemberPack.challenges.where(
        (ChallengeDefinition item) =>
            item.period == ChallengePeriod.weekly &&
            item.audience == ChallengeAudience.standard,
      ),
      hasLength(4),
    );
    expect(
      septemberPack.challenges.where(
        (ChallengeDefinition item) =>
            item.period == ChallengePeriod.monthly &&
            item.audience == ChallengeAudience.standard,
      ),
      hasLength(1),
    );
    expect(
      septemberPack.challenges.where(
        (ChallengeDefinition item) =>
            item.period == ChallengePeriod.permanent &&
            item.audience == ChallengeAudience.standard,
      ),
      hasLength(6),
    );
  });

  test('le pack réel ne contient aucune erreur de configuration', () {
    final List<dynamic> countryJson = jsonDecode(
      File('assets/data/country_infos.json').readAsStringSync(),
    ) as List<dynamic>;
    final Set<String> countryIds = countryJson
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) => item['entityId'].toString())
        .toSet();
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      septemberPack,
      context: ChallengePackValidationContext(countryIds: countryIds),
    );

    expect(
      issues.where((ChallengeValidationIssue issue) => issue.isError),
      isEmpty,
      reason: issues
          .map(
            (ChallengeValidationIssue issue) =>
                '${issue.challengeId}: ${issue.code} - ${issue.message}',
          )
          .join('\n'),
    );
  });

  test('chaque jour expose trois défis programmés et six permanents', () {
    for (int day = 1; day <= 30; day++) {
      final DateTime midday = DateTime.utc(2026, 9, day, 12);
      final List<ChallengeDefinition> active = septemberPack
          .activeChallengesAt(midday)
          .where(
            (ChallengeDefinition item) =>
                item.audience == ChallengeAudience.standard,
          )
          .toList(growable: false);
      expect(active, hasLength(9), reason: 'Jour $day');
      for (final ChallengePeriod period in ChallengePeriod.values) {
        expect(
          active.where((ChallengeDefinition item) => item.period == period),
          hasLength(period == ChallengePeriod.permanent ? 6 : 1),
          reason: 'Jour $day, période ${period.id}',
        );
      }
    }
  });

  test('les six défis permanents restent actifs après le pack mensuel', () {
    final List<ChallengeDefinition> active = septemberPack
        .activeChallengesAt(DateTime.utc(2027, 3, 15))
        .where(
          (ChallengeDefinition item) =>
              item.audience == ChallengeAudience.standard,
        )
        .toList(growable: false);

    expect(active, hasLength(6));
    expect(
      active.every(
        (ChallengeDefinition item) =>
            item.period == ChallengePeriod.permanent,
      ),
      isTrue,
    );
  });

  test('les défis quotidiens alternent six formats pendant le mois', () {
    final Set<String> modeIds = septemberPack.challenges
        .where(
          (ChallengeDefinition item) =>
              item.period == ChallengePeriod.daily &&
              item.audience == ChallengeAudience.standard,
        )
        .map((ChallengeDefinition item) => item.modeId)
        .toSet();

    expect(modeIds, hasLength(5));
    expect(
      modeIds,
      containsAll(<String>{
        'find_country',
        'find_capital',
        'find_flag',
        'ultimate',
        'mixed',
      }),
    );
  });

  test('un adulte voit les trois défis programmés et six permanents', () {
    final List<ChallengeDefinition> active =
        ChallengeEligibility.activeForPlayer(
      pack: septemberPack,
      now: DateTime.utc(2026, 9, 4, 12),
      player: const ChallengePlayerContext(playerLevel: 20),
    );

    expect(active, hasLength(9));
    expect(active.every((ChallengeDefinition item) => !item.id.endsWith('__child')), isTrue);
  });

  test('un enfant reçoit les variantes adaptées même au niveau 1', () {
    final List<ChallengeDefinition> active =
        ChallengeEligibility.activeForPlayer(
      pack: septemberPack,
      now: DateTime.utc(2026, 9, 4, 12),
      player: const ChallengePlayerContext(
        playerLevel: 1,
        isChildProfile: true,
      ),
    );

    expect(active, hasLength(3));
    expect(
      active.every(
        (ChallengeDefinition item) =>
            item.audience == ChallengeAudience.child &&
            item.id.endsWith('__child'),
      ),
      isTrue,
    );
    expect(
      active.every(
        (ChallengeDefinition item) =>
            !item.retryPolicy.rewardedAdvertisementAllowed,
      ),
      isTrue,
    );
    expect(
      active.every(
        (ChallengeDefinition item) =>
            item.retryPolicy.unlimitedFreeAttempts,
      ),
      isTrue,
    );
  });

  test('tous les défis adultes sont classés et accessibles dès le niveau 1', () {
    final List<ChallengeDefinition> active =
        ChallengeEligibility.activeForPlayer(
      pack: septemberPack,
      now: DateTime.utc(2026, 9, 4, 12),
      player: const ChallengePlayerContext(playerLevel: 1),
    );

    expect(active, hasLength(9));
    expect(
      active.every(
        (ChallengeDefinition item) =>
            item.audience == ChallengeAudience.standard,
      ),
      isTrue,
    );
    expect(
      septemberPack.challenges.where(
        (ChallengeDefinition item) =>
            item.audience == ChallengeAudience.beginner,
      ),
      isEmpty,
    );
    expect(
      active.every(
        (ChallengeDefinition item) => item.minimumPlayerLevel <= 1,
      ),
      isTrue,
    );
    expect(active.every((ChallengeDefinition item) => item.isRanked), isTrue);
    expect(
      active.every(
        (ChallengeDefinition item) =>
            item.retryPolicy.unlimitedRewardedAdvertisementRetries,
      ),
      isTrue,
    );
  });

  test('un défi désactivé dans le pack disparaît immédiatement', () {
    final ChallengeDefinition source = septemberPack.challenges.firstWhere(
      (ChallengeDefinition item) => item.id == 'daily_2026_09_04',
    );
    final ChallengePack disabledPack = ChallengePack(
      schemaVersion: septemberPack.schemaVersion,
      id: septemberPack.id,
      title: septemberPack.title,
      monthKey: septemberPack.monthKey,
      validFromUtc: septemberPack.validFromUtc,
      validUntilUtc: septemberPack.validUntilUtc,
      challenges: septemberPack.challenges,
      disabledChallengeIds: <String>{source.id},
    );

    expect(
      disabledPack.activeChallengesAt(DateTime.utc(2026, 9, 4, 12)),
      isNot(contains(source)),
    );
  });

  test('un modèle inconnu bloque le chargement du pack', () {
    const String source = '''
      {
        "schemaVersion": 1,
        "id": "bad_pack",
        "title": "Pack incorrect",
        "monthKey": "2026-09",
        "validFromUtc": "2026-09-01T00:00:00Z",
        "validUntilUtc": "2026-10-01T00:00:00Z",
        "schedule": [{
          "id": "daily_bad",
          "templateId": "missing",
          "validFromUtc": "2026-09-01T00:00:00Z",
          "validUntilUtc": "2026-09-02T00:00:00Z"
        }]
      }
    ''';

    expect(
      () => ChallengePackLoader.decode(source),
      throwsA(isA<FormatException>()),
    );
  });
}
