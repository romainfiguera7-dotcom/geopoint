import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../challenges/challenge_server_connection.dart';
import '../firebase_options.dart';
import 'firebase_callable_gateway.dart';
import 'flutterfire_callable_transport.dart';

enum GeoPointFirebaseBootstrapStatus {
  ready,
  coreUnavailable,
  appCheckUnavailable,
  authenticationUnavailable,
}

class GeoPointFirebaseBootstrapReport {
  const GeoPointFirebaseBootstrapReport({
    required this.status,
    this.authenticatedPlayerId,
    this.failureReason,
  });

  final GeoPointFirebaseBootstrapStatus status;
  final String? authenticatedPlayerId;
  final String? failureReason;

  bool get isReady => status == GeoPointFirebaseBootstrapStatus.ready;
}

typedef GeoPointFirebaseAction = Future<void> Function();
typedef GeoPointFirebaseAuthentication = Future<String> Function();

/// Initialise Firebase sans rendre le jeu dépendant du réseau.
///
/// En cas d'échec, les passerelles distantes restent désactivées et toutes les
/// fonctionnalités locales de GeoPoint continuent de fonctionner.
class GeoPointFirebaseBootstrap {
  const GeoPointFirebaseBootstrap._();

  static const Duration _authenticationTimeout = Duration(seconds: 8);

  static Future<GeoPointFirebaseBootstrapReport> initialize({
    GeoPointFirebaseAction? initializeCore,
    GeoPointFirebaseAction? activateAppCheck,
    GeoPointFirebaseAuthentication? authenticate,
    GeoPointCallableTransport Function()? transportFactory,
  }) async {
    ChallengeServerConnection.clear();

    try {
      await (initializeCore ?? _initializeCore)();
    } catch (error, stackTrace) {
      return _failure(
        GeoPointFirebaseBootstrapStatus.coreUnavailable,
        error,
        stackTrace,
      );
    }

    try {
      await (activateAppCheck ?? _activateAppCheck)();
    } catch (error, stackTrace) {
      return _failure(
        GeoPointFirebaseBootstrapStatus.appCheckUnavailable,
        error,
        stackTrace,
      );
    }

    final String uid;
    try {
      uid = await (authenticate ?? _authenticate)()
          .timeout(_authenticationTimeout);
      if (uid.trim().isEmpty) {
        throw const FormatException('UID Firebase vide.');
      }
    } catch (error, stackTrace) {
      return _failure(
        GeoPointFirebaseBootstrapStatus.authenticationUnavailable,
        error,
        stackTrace,
      );
    }

    final GeoPointCallableTransport transport =
        (transportFactory ?? FlutterFireCallableTransport.new)();
    final FirebaseCallableGeoPointGateway gateway =
        FirebaseCallableGeoPointGateway(transport: transport);
    ChallengeServerConnection.configure(
      server: gateway,
      packs: gateway,
      rewards: gateway,
      officialSessions: gateway,
      rankings: gateway,
      leaderboards: gateway,
      seasonRewards: gateway,
      friends: gateway,
      administration: gateway,
      monetization: gateway,
    );

    debugPrint('GeoPoint Firebase : connexion prête pour le joueur $uid.');
    return GeoPointFirebaseBootstrapReport(
      status: GeoPointFirebaseBootstrapStatus.ready,
      authenticatedPlayerId: uid,
    );
  }

  static Future<void> _initializeCore() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  static Future<void> _activateAppCheck() {
    return FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }

  static Future<String> _authenticate() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? currentUser = auth.currentUser;
    if (currentUser != null) {
      return currentUser.uid;
    }
    final UserCredential credential = await auth.signInAnonymously();
    final User? createdUser = credential.user;
    if (createdUser == null) {
      throw StateError('Firebase n’a pas créé le joueur anonyme.');
    }
    return createdUser.uid;
  }

  static GeoPointFirebaseBootstrapReport _failure(
    GeoPointFirebaseBootstrapStatus status,
    Object error,
    StackTrace stackTrace,
  ) {
    ChallengeServerConnection.clear();
    debugPrint('GeoPoint Firebase : mode local ($status) : $error');
    debugPrintStack(stackTrace: stackTrace);
    return GeoPointFirebaseBootstrapReport(
      status: status,
      failureReason: error.toString(),
    );
  }
}
