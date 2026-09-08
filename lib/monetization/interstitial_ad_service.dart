import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_free_entitlement.dart';
import 'ad_consent_service.dart';

class InterstitialAdService {
  InterstitialAdService._();

  static final InterstitialAdService instance = InterstitialAdService._();

  static const String _counterKey = 'geopoint_interstitial_game_counter';
  static const int gamesBetweenAds = 3;
  static const String _androidTestId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestId =
      'ca-app-pub-3940256099942544/4411468910';

  InterstitialAd? _ad;
  bool _loading = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    _initialized = true;
    if (!AdFreeAccess.instance.advertisementsAllowed) {
      return;
    }
    final bool consentAllowsAds =
        await AdConsentService.instance.gatherAtLaunch();
    if (!consentAllowsAds) {
      debugPrint(
        'PointGeo publicité : aucune demande envoyée sans consentement valide.',
      );
      return;
    }
    await MobileAds.instance.initialize();
    _load();
  }

  /// À appeler une seule fois après une partie d'entraînement ou d'expédition
  /// réellement terminée. Les défis ont leur propre publicité récompensée.
  Future<bool> registerCompletedGame() async {
    if (!_initialized ||
        !AdFreeAccess.instance.advertisementsAllowed ||
        !AdConsentService.instance.canRequestAds) {
      return false;
    }
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final int next = (preferences.getInt(_counterKey) ?? 0) + 1;
    if (next < gamesBetweenAds) {
      await preferences.setInt(_counterKey, next);
      return false;
    }
    final InterstitialAd? readyAd = _ad;
    if (readyAd == null) {
      await preferences.setInt(_counterKey, gamesBetweenAds);
      _load();
      return false;
    }
    _ad = null;
    await preferences.setInt(_counterKey, 0);
    final Completer<void> closed = Completer<void>();
    readyAd.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
        _load();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
        _load();
      },
    );
    readyAd.show();
    await closed.future;
    return true;
  }

  void _load() {
    if (_loading ||
        _ad != null ||
        !_initialized ||
        !AdConsentService.instance.canRequestAds) {
      return;
    }
    _loading = true;
    InterstitialAd.load(
      adUnitId: Platform.isAndroid ? _androidTestId : _iosTestId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _loading = false;
          _ad = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _loading = false;
          debugPrint('GeoPoint publicité : chargement différé ($error).');
        },
      ),
    );
  }
}
