import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'challenges/challenge_server_connection.dart';
import 'features/settings/gameplay_feedback.dart';
import 'monetization/ad_free_entitlement.dart';
import 'monetization/interstitial_ad_service.dart';
import 'server/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GameplayFeedback.initialize();
  await GeoPointFirebaseBootstrap.initialize();
  await AdFreeAccess.instance.initialize(
    ChallengeServerConnection.monetizationGateway,
  );
  unawaited(InterstitialAdService.instance.initialize());

  runApp(
    const GeoPointApp(),
  );
}
