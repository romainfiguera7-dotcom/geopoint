import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/passport/progress/passport_progress_rules.dart';
import 'package:geopoint/passport/progress/passport_progress_storage.dart';
import 'package:geopoint/passport/progress/passport_progress_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fermeture et redémarrage conservent toute la progression', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final DateTime now = DateTime.utc(2026, 8, 29, 20);
    final PassportProgressV2 source = PassportProgressV2.initial(
      createdAt: now,
    ).registerAnswer(
      entityId: 'FRA',
      theme: PassportKnowledgeTheme.flag,
      isCorrect: true,
      source: PassportDiscoverySource.game,
      answeredAt: now,
    ).unlockCollectionItem(
      'emblem_world_scout',
      unlockedAt: now,
    ).recordAchievementTiers(
      <String, DateTime>{'world_discovery_50': now},
      recordedAt: now,
    );

    expect(await PassportProgressStorage.save(source), isTrue);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final Map<String, dynamic> envelope = jsonDecode(
      preferences.getString('geopoint_passport_progress_v2')!,
    ) as Map<String, dynamic>;
    final PassportProgressV2? restarted =
        await PassportProgressStorage.load();

    expect(envelope['schemaVersion'], 2);
    expect(envelope['dataSchemaVersion'], 4);
    expect(envelope['revision'], 1);
    expect(restarted, isNotNull);
    expect(restarted!.schemaVersion, PassportProgressV2.currentSchemaVersion);
    expect(restarted.progressFor('FRA').stampUnlockedAt, now);
    expect(restarted.unlockedCollectionItemIds, contains('emblem_world_scout'));
    expect(
      restarted.completedAchievementTierDates['world_discovery_50'],
      now,
    );
  });

  test('une écriture corrompue recharge la dernière copie valide', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final DateTime now = DateTime.utc(2026, 8, 29, 21);
    final PassportProgressV2 first = PassportProgressV2.initial(
      createdAt: now,
    ).markDiscovered(
      entityId: 'ESP',
      source: PassportDiscoverySource.atlas,
      discoveredAt: now,
    );
    final PassportProgressV2 second = first.markDiscovered(
      entityId: 'PRT',
      source: PassportDiscoverySource.atlas,
      discoveredAt: now.add(const Duration(minutes: 1)),
    );

    await PassportProgressStorage.save(first);
    await PassportProgressStorage.save(second);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'geopoint_passport_progress_v2',
      '{sauvegarde interrompue',
    );

    final PassportProgressV2? recovered =
        await PassportProgressStorage.load();

    expect(recovered, isNotNull);
    expect(recovered!.progressFor('ESP').hasBeenDiscovered, isTrue);
    expect(recovered.progressFor('PRT').hasBeenDiscovered, isFalse);
  });

  test('une ancienne version est mise à niveau sans perdre ses champs', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final DateTime now = DateTime.utc(2026, 8, 29, 22);
    final Map<String, dynamic> oldData = PassportProgressV2.initial(
      createdAt: now,
    ).markDiscovered(
      entityId: 'CAN',
      source: PassportDiscoverySource.game,
      discoveredAt: now,
    ).toJson()
      ..['schemaVersion'] = 2
      ..remove('unlockedCollectionItemIds')
      ..remove('completedAchievementTierDates');
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'geopoint_passport_progress_v2',
      jsonEncode(oldData),
    );

    final PassportProgressV2? migrated =
        await PassportProgressStorage.load();

    expect(migrated, isNotNull);
    expect(migrated!.schemaVersion, PassportProgressV2.currentSchemaVersion);
    expect(migrated.progressFor('CAN').hasBeenDiscovered, isTrue);
    expect(migrated.unlockedCollectionItemIds, isEmpty);
    expect(migrated.completedAchievementTierDates, isEmpty);
  });
}
