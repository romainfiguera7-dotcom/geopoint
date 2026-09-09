import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_definition.dart';
import 'package:geopoint/challenges/challenge_pack.dart';
import 'package:geopoint/challenges/challenge_pack_repository.dart';
import 'package:geopoint/challenges/challenge_remote_pack.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'challenge_test_factory.dart';

class _FakeRemoteGateway implements ChallengeRemoteGateway {
  _FakeRemoteGateway({this.document, this.error});

  final ChallengeRemotePackDocument? document;
  final Object? error;

  @override
  Future<ChallengeRemotePackDocument?> fetchActivePack() async {
    if (error != null) {
      throw error!;
    }
    return document;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ChallengePack pack(String id, {String modeId = 'find_country'}) {
    return ChallengePack(
      schemaVersion: ChallengePack.currentSchemaVersion,
      id: id,
      title: 'Pack $id',
      monthKey: '2026-09',
      validFromUtc: DateTime.utc(2026, 9),
      validUntilUtc: DateTime.utc(2026, 10),
      challenges: <ChallengeDefinition>[
        challengeFixture(id: '${id}_daily', modeId: modeId),
      ],
    );
  }

  ChallengeRemotePackDocument document({
    required ChallengePack pack,
    required int revision,
  }) {
    return ChallengeRemotePackDocument(
      revision: revision,
      publishedAtUtc: DateTime.utc(2026, 9, 4, 10),
      serverNowUtc: DateTime.utc(2026, 9, 4, 12),
      jsonSource: jsonEncode(pack.toJson()),
    );
  }

  ChallengePackRepository repository({
    ChallengeRemoteGateway? gateway,
    ChallengePack? bundled,
  }) {
    return ChallengePackRepository(
      remoteGateway: gateway,
      bundledLoader: () async => bundled ?? pack('bundled'),
    );
  }

  test('accepte et mémorise un pack distant valide', () async {
    final ChallengePack remotePack = pack('remote');
    final ChallengePackResolution result = await repository(
      gateway: _FakeRemoteGateway(
        document: document(pack: remotePack, revision: 4),
      ),
    ).load(countryIds: const <String>{'FRA'});

    expect(result.origin, ChallengePackOrigin.remote);
    expect(result.pack.id, 'remote');
    expect(result.revision, 4);
    expect(result.serverNowUtc, DateTime.utc(2026, 9, 4, 12));
    expect(result.usedFallback, isFalse);
  });

  test('complète un ancien pack distant avec les défis permanents inclus',
      () async {
    final ChallengePack remotePack = pack('remote_without_permanent');
    final ChallengePack bundledPack = ChallengePack(
      schemaVersion: ChallengePack.currentSchemaVersion,
      id: 'bundled_with_permanent',
      title: 'Pack inclus',
      monthKey: '2026-09',
      validFromUtc: DateTime.utc(2026, 9),
      validUntilUtc: DateTime.utc(2026, 10),
      challenges: <ChallengeDefinition>[
        challengeFixture(id: 'bundled_daily'),
        challengeFixture(
          id: 'permanent_world',
          period: ChallengePeriod.permanent,
          rankingGroupId: 'permanent_world',
        ),
      ],
    );

    final ChallengePackResolution result = await repository(
      gateway: _FakeRemoteGateway(
        document: document(pack: remotePack, revision: 4),
      ),
      bundled: bundledPack,
    ).load(countryIds: const <String>{'FRA'});

    expect(result.origin, ChallengePackOrigin.remote);
    expect(result.pack.id, 'remote_without_permanent');
    expect(result.pack.challengeById('permanent_world'), isNotNull);
  });

  test('complète un pack Studio sans supprimer semaine et mois', () async {
    final ChallengePack studioPack = ChallengePack(
      schemaVersion: ChallengePack.currentSchemaVersion,
      id: 'studio_pack_2026_09',
      title: 'Pack Studio',
      monthKey: '2026-09',
      validFromUtc: DateTime.utc(2026, 9, 4),
      validUntilUtc: DateTime.utc(2026, 9, 5),
      challenges: <ChallengeDefinition>[
        challengeFixture(id: 'studio_daily'),
      ],
    );
    final ChallengePack bundledPack = ChallengePack(
      schemaVersion: ChallengePack.currentSchemaVersion,
      id: 'bundled_calendar',
      title: 'Calendrier inclus',
      monthKey: '2026-09',
      validFromUtc: DateTime.utc(2026, 9),
      validUntilUtc: DateTime.utc(2026, 10),
      challenges: <ChallengeDefinition>[
        challengeFixture(id: 'bundled_daily'),
        challengeFixture(
          id: 'bundled_weekly',
          period: ChallengePeriod.weekly,
          validFromUtc: DateTime.utc(2026, 9, 1),
          validUntilUtc: DateTime.utc(2026, 9, 8),
        ),
        challengeFixture(
          id: 'bundled_monthly',
          period: ChallengePeriod.monthly,
          validFromUtc: DateTime.utc(2026, 9),
          validUntilUtc: DateTime.utc(2026, 10),
        ),
      ],
    );

    final ChallengePackResolution result = await repository(
      gateway: _FakeRemoteGateway(
        document: document(pack: studioPack, revision: 1),
      ),
      bundled: bundledPack,
    ).load(countryIds: const <String>{'FRA'});

    expect(result.pack.challengeById('studio_daily'), isNotNull);
    expect(result.pack.challengeById('bundled_daily'), isNotNull);
    expect(result.pack.challengeById('bundled_weekly'), isNotNull);
    expect(result.pack.challengeById('bundled_monthly'), isNotNull);
    expect(result.pack.validFromUtc, DateTime.utc(2026, 9));
    expect(result.pack.validUntilUtc, DateTime.utc(2026, 10));
  });

  test('utilise le dernier pack valide lorsque le serveur est indisponible',
      () async {
    final ChallengePack remotePack = pack('cached');
    await repository(
      gateway: _FakeRemoteGateway(
        document: document(pack: remotePack, revision: 5),
      ),
    ).load(countryIds: const <String>{'FRA'});

    final ChallengePackResolution offline = await repository(
      gateway: _FakeRemoteGateway(error: StateError('hors ligne')),
    ).load(countryIds: const <String>{'FRA'});

    expect(offline.origin, ChallengePackOrigin.cache);
    expect(offline.pack.id, 'cached');
    expect(offline.revision, 5);
    expect(offline.serverNowUtc, isNull);
    expect(offline.usedFallback, isTrue);
  });

  test('refuse une révision distante plus ancienne que le cache', () async {
    await repository(
      gateway: _FakeRemoteGateway(
        document: document(pack: pack('revisioned'), revision: 8),
      ),
    ).load(countryIds: const <String>{'FRA'});

    final ChallengePackResolution result = await repository(
      gateway: _FakeRemoteGateway(
        document: document(
          pack: pack('revisioned', modeId: 'find_capital'),
          revision: 7,
        ),
      ),
    ).load(countryIds: const <String>{'FRA'});

    expect(result.origin, ChallengePackOrigin.cache);
    expect(result.pack.id, 'revisioned');
    expect(result.revision, 8);
    expect(result.usedFallback, isTrue);
  });

  test('accepte la révision initiale d’un nouveau pack actif', () async {
    await repository(
      gateway: _FakeRemoteGateway(
        document: document(pack: pack('old_pack'), revision: 8),
      ),
    ).load(countryIds: const <String>{'FRA'});

    final ChallengePackResolution result = await repository(
      gateway: _FakeRemoteGateway(
        document: document(pack: pack('new_pack'), revision: 1),
      ),
    ).load(countryIds: const <String>{'FRA'});

    expect(result.origin, ChallengePackOrigin.remote);
    expect(result.pack.id, 'new_pack');
    expect(result.revision, 1);
    expect(result.usedFallback, isFalse);
  });

  test('refuse un pack distant invalide et revient au pack inclus', () async {
    final ChallengePack invalid = pack('invalid', modeId: 'unknown_mode');
    final ChallengePackResolution result = await repository(
      gateway: _FakeRemoteGateway(
        document: document(pack: invalid, revision: 1),
      ),
      bundled: pack('safe_bundled'),
    ).load(countryIds: const <String>{'FRA'});

    expect(result.origin, ChallengePackOrigin.bundled);
    expect(result.pack.id, 'safe_bundled');
    expect(result.revision, 0);
    expect(result.usedFallback, isTrue);
  });

  test('réutilise le cache immuable pour une révision identique', () async {
    await repository(
      gateway: _FakeRemoteGateway(
        document: document(pack: pack('same_pack'), revision: 3),
      ),
    ).load(countryIds: const <String>{'FRA'});

    final ChallengePackResolution result = await repository(
      gateway: _FakeRemoteGateway(
        document: document(
          pack: pack('same_pack', modeId: 'find_capital'),
          revision: 3,
        ),
      ),
    ).load(countryIds: const <String>{'FRA'});

    expect(result.origin, ChallengePackOrigin.remote);
    expect(result.pack.id, 'same_pack');
    expect(
      result.pack.challengeById('same_pack_daily')?.modeId,
      'find_country',
    );
    expect(result.revision, 3);
  });
}
