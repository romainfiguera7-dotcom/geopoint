import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentService {
  AdConsentService._();

  static final AdConsentService instance = AdConsentService._();

  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  bool get canRequestAds => _canRequestAds;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  bool get _isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> gatherAtLaunch() async {
    if (!_isSupported) return false;
    final Completer<FormError?> update = Completer<FormError?>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: false),
      () => update.complete(null),
      (FormError error) => update.complete(error),
    );
    final FormError? updateError = await update.future;
    if (updateError != null) {
      debugPrint(
        'PointGeo consentement : mise à jour différée '
        '(${updateError.message}).',
      );
      await _refreshStatus();
      return _canRequestAds;
    }

    final Completer<FormError?> form = Completer<FormError?>();
    ConsentForm.loadAndShowConsentFormIfRequired(
      (FormError? error) => form.complete(error),
    );
    final FormError? formError = await form.future;
    if (formError != null) {
      debugPrint(
        'PointGeo consentement : formulaire indisponible '
        '(${formError.message}).',
      );
    }
    await _refreshStatus();
    return _canRequestAds;
  }

  Future<String?> showPrivacyOptions() async {
    if (!_isSupported) {
      return 'Les choix publicitaires ne sont pas disponibles sur cet appareil.';
    }
    await _refreshStatus();
    if (!_privacyOptionsRequired) {
      return 'Google ne demande actuellement aucun réglage supplémentaire.';
    }
    final Completer<FormError?> form = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm(
      (FormError? error) => form.complete(error),
    );
    final FormError? error = await form.future;
    await _refreshStatus();
    return error?.message;
  }

  Future<void> _refreshStatus() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    final PrivacyOptionsRequirementStatus status = await ConsentInformation
        .instance
        .getPrivacyOptionsRequirementStatus();
    _privacyOptionsRequired =
        status == PrivacyOptionsRequirementStatus.required;
  }
}
