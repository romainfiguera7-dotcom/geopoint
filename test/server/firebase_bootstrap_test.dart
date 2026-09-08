import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_server_connection.dart';
import 'package:geopoint/server/firebase_bootstrap.dart';
import 'package:geopoint/server/firebase_callable_gateway.dart';

class _UnusedTransport implements GeoPointCallableTransport {
  @override
  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) {
    throw UnimplementedError();
  }
}

void main() {
  setUp(ChallengeServerConnection.clear);
  tearDown(ChallengeServerConnection.clear);

  test('branche Firebase après les trois étapes de démarrage', () async {
    final List<String> steps = <String>[];

    final GeoPointFirebaseBootstrapReport report =
        await GeoPointFirebaseBootstrap.initialize(
      initializeCore: () async {
        steps.add('core');
      },
      activateAppCheck: () async {
        steps.add('app_check');
      },
      authenticate: () async {
        steps.add('auth');
        return 'firebase_uid_test';
      },
      transportFactory: _UnusedTransport.new,
    );

    expect(report.status, GeoPointFirebaseBootstrapStatus.ready);
    expect(report.authenticatedPlayerId, 'firebase_uid_test');
    expect(steps, <String>['core', 'app_check', 'auth']);
    expect(ChallengeServerConnection.coreGateway, isNotNull);
    expect(ChallengeServerConnection.packGateway, isNotNull);
    expect(ChallengeServerConnection.rewardValidationGateway, isNotNull);
    expect(ChallengeServerConnection.rankingGateway, isNotNull);
    expect(ChallengeServerConnection.leaderboardGateway, isNotNull);
    expect(ChallengeServerConnection.seasonRewardGateway, isNotNull);
    expect(ChallengeServerConnection.friendGateway, isNotNull);
    expect(ChallengeServerConnection.adminGateway, isNotNull);
    expect(ChallengeServerConnection.monetizationGateway, isNotNull);
  });

  test('conserve le jeu local si Firebase Core est indisponible', () async {
    final GeoPointFirebaseBootstrapReport report =
        await GeoPointFirebaseBootstrap.initialize(
      initializeCore: () async => throw StateError('core indisponible'),
      activateAppCheck: () async {},
      authenticate: () async => 'firebase_uid_test',
      transportFactory: _UnusedTransport.new,
    );

    expect(
      report.status,
      GeoPointFirebaseBootstrapStatus.coreUnavailable,
    );
    expect(ChallengeServerConnection.isConfigured, isFalse);
  });

  test('refuse la connexion distante sans App Check', () async {
    final GeoPointFirebaseBootstrapReport report =
        await GeoPointFirebaseBootstrap.initialize(
      initializeCore: () async {},
      activateAppCheck: () async => throw StateError('App Check indisponible'),
      authenticate: () async => 'firebase_uid_test',
      transportFactory: _UnusedTransport.new,
    );

    expect(
      report.status,
      GeoPointFirebaseBootstrapStatus.appCheckUnavailable,
    );
    expect(ChallengeServerConnection.isConfigured, isFalse);
  });

  test('refuse la connexion distante sans joueur authentifié', () async {
    final GeoPointFirebaseBootstrapReport report =
        await GeoPointFirebaseBootstrap.initialize(
      initializeCore: () async {},
      activateAppCheck: () async {},
      authenticate: () async => '',
      transportFactory: _UnusedTransport.new,
    );

    expect(
      report.status,
      GeoPointFirebaseBootstrapStatus.authenticationUnavailable,
    );
    expect(ChallengeServerConnection.isConfigured, isFalse);
  });
}
