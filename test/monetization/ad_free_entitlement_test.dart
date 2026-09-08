import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/monetization/ad_free_entitlement.dart';

void main() {
  test('décode un achat Google Play permanent', () {
    final AdFreeEntitlement entitlement = AdFreeEntitlement.fromJson(
      <String, dynamic>{
        'active': true,
        'source': 'google_play',
        'grantedAtUtc': '2026-09-08T12:00:00Z',
      },
    );

    expect(entitlement.active, isTrue);
    expect(entitlement.source, AdFreeEntitlementSource.googlePlay);
    expect(entitlement.grantedAtUtc, DateTime.utc(2026, 9, 8, 12));
  });

  test('décode un cadeau administrateur', () {
    final AdFreeEntitlement entitlement = AdFreeEntitlement.fromJson(
      const <String, dynamic>{
        'active': true,
        'source': 'administrator_gift',
      },
    );

    expect(entitlement.active, isTrue);
    expect(entitlement.source, AdFreeEntitlementSource.administratorGift);
  });

  test('un droit absent reste inactif', () {
    final AdFreeEntitlement entitlement = AdFreeEntitlement.fromJson(
      const <String, dynamic>{'active': false, 'source': 'none'},
    );

    expect(entitlement.active, isFalse);
    expect(entitlement.source, AdFreeEntitlementSource.none);
  });
}
