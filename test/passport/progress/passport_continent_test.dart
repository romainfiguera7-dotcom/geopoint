import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/passport/progress/passport_continent.dart';

void main() {
  test('regroupe les deux Amériques dans une seule zone', () {
    expect(
      PassportContinent.fromGeoValue('Amérique du Nord'),
      PassportContinent.americas,
    );
    expect(
      PassportContinent.fromGeoValue('Amérique du Sud'),
      PassportContinent.americas,
    );
  });

  test('accepte les noms français et anglais', () {
    expect(
      PassportContinent.fromGeoValue('Africa'),
      PassportContinent.africa,
    );
    expect(
      PassportContinent.fromGeoValue('Océanie'),
      PassportContinent.oceania,
    );
    expect(
      PassportContinent.fromGeoValue('Antarctica'),
      PassportContinent.polar,
    );
  });

  test('retourne null pour une zone inconnue', () {
    expect(PassportContinent.fromGeoValue('Inconnu'), isNull);
  });

  test('rattache les territoires maritimes à leur vraie zone', () {
    expect(
      PassportContinent.forEntity(
        entityId: 'SYC',
        geoContinent: 'Seven seas (open ocean)',
      ),
      PassportContinent.africa,
    );
    expect(
      PassportContinent.forEntity(
        entityId: 'MDV',
        geoContinent: 'Seven seas (open ocean)',
      ),
      PassportContinent.asia,
    );
    expect(
      PassportContinent.forEntity(
        entityId: 'CLP',
        geoContinent: 'Seven seas (open ocean)',
      ),
      PassportContinent.americas,
    );
    expect(
      PassportContinent.forEntity(
        entityId: 'ATF',
        geoContinent: 'Seven seas (open ocean)',
      ),
      PassportContinent.polar,
    );
  });
}
