import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AdFreeEntitlementSource {
  none,
  googlePlay,
  administratorGift,
}

extension AdFreeEntitlementSourceRules on AdFreeEntitlementSource {
  static AdFreeEntitlementSource fromId(Object? value) {
    switch (value?.toString().trim()) {
      case 'google_play':
        return AdFreeEntitlementSource.googlePlay;
      case 'administrator_gift':
        return AdFreeEntitlementSource.administratorGift;
      default:
        return AdFreeEntitlementSource.none;
    }
  }

  String get label {
    switch (this) {
      case AdFreeEntitlementSource.none:
        return 'Aucun avantage actif';
      case AdFreeEntitlementSource.googlePlay:
        return 'Achat Google Play';
      case AdFreeEntitlementSource.administratorGift:
        return 'Cadeau PointGeo';
    }
  }
}

class AdFreeEntitlement {
  const AdFreeEntitlement({
    required this.active,
    required this.source,
    this.grantedAtUtc,
  });

  const AdFreeEntitlement.inactive()
      : active = false,
        source = AdFreeEntitlementSource.none,
        grantedAtUtc = null;

  final bool active;
  final AdFreeEntitlementSource source;
  final DateTime? grantedAtUtc;

  factory AdFreeEntitlement.fromJson(Map<String, dynamic> json) {
    return AdFreeEntitlement(
      active: json['active'] == true,
      source: AdFreeEntitlementSourceRules.fromId(json['source']),
      grantedAtUtc: DateTime.tryParse(
        json['grantedAtUtc']?.toString() ?? '',
      )?.toUtc(),
    );
  }
}

abstract interface class AdFreeEntitlementGateway {
  Future<AdFreeEntitlement> fetchEntitlement();

  Future<AdFreeEntitlement> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
  });
}

/// Source de vérité utilisée par tous les futurs emplacements publicitaires.
///
/// Le cache ne crée jamais un droit : il ne fait que conserver sur l'appareil
/// un droit précédemment confirmé par Firebase afin de masquer les publicités
/// pendant une coupure réseau.
class AdFreeAccess extends ChangeNotifier {
  AdFreeAccess._();

  static final AdFreeAccess instance = AdFreeAccess._();
  static const String productId = 'geopoint_no_ads';
  static const String _cacheKey = 'geopoint_ad_free_confirmed';
  static const String _cacheSourceKey = 'geopoint_ad_free_source';

  AdFreeEntitlement _entitlement = const AdFreeEntitlement.inactive();
  AdFreeEntitlementGateway? _gateway;

  AdFreeEntitlement get entitlement => _entitlement;
  bool get isActive => _entitlement.active;
  bool get advertisementsAllowed => !isActive;

  Future<void> initialize(AdFreeEntitlementGateway? gateway) async {
    _gateway = gateway;
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_cacheKey) == true) {
      final AdFreeEntitlementSource cachedSource =
          AdFreeEntitlementSourceRules.fromId(
        preferences.getString(_cacheSourceKey),
      );
      _entitlement = AdFreeEntitlement(
        active: true,
        source: cachedSource == AdFreeEntitlementSource.none
            ? AdFreeEntitlementSource.googlePlay
            : cachedSource,
      );
    }
    unawaited(refresh());
  }

  Future<AdFreeEntitlement> refresh() async {
    final AdFreeEntitlementGateway? gateway = _gateway;
    if (gateway == null) {
      return _entitlement;
    }
    try {
      return await _apply(await gateway.fetchEntitlement());
    } on Object catch (error) {
      debugPrint('GeoPoint sans publicité : synchronisation différée : $error');
      return _entitlement;
    }
  }

  Future<AdFreeEntitlement> verifyGooglePlayPurchase(
    String purchaseToken,
  ) async {
    final AdFreeEntitlementGateway? gateway = _gateway;
    if (gateway == null) {
      throw StateError('La vérification Firebase est indisponible.');
    }
    final AdFreeEntitlement verified = await gateway.verifyGooglePlayPurchase(
      productId: productId,
      purchaseToken: purchaseToken,
    );
    if (!verified.active) {
      throw const FormatException('L’achat n’a pas été confirmé.');
    }
    return _apply(verified);
  }

  Future<AdFreeEntitlement> _apply(AdFreeEntitlement entitlement) async {
    _entitlement = entitlement;
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_cacheKey, entitlement.active);
    if (entitlement.active) {
      await preferences.setString(
        _cacheSourceKey,
        switch (entitlement.source) {
          AdFreeEntitlementSource.googlePlay => 'google_play',
          AdFreeEntitlementSource.administratorGift =>
            'administrator_gift',
          AdFreeEntitlementSource.none => 'none',
        },
      );
    } else {
      await preferences.remove(_cacheSourceKey);
    }
    notifyListeners();
    return entitlement;
  }
}
