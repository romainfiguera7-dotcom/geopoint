import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/features/exploration/france/france_expedition_catalog.dart';
import 'package:geopoint/game/continent/africa_expedition.dart';
import 'package:geopoint/game/continent/americas_expedition.dart';
import 'package:geopoint/game/continent/asia_expedition.dart';
import 'package:geopoint/game/continent/continent_expedition.dart';
import 'package:geopoint/game/continent/europe_expedition.dart';
import 'package:geopoint/game/continent/oceania_expedition.dart';
import 'package:geopoint/game/continent/world_expedition.dart';
import 'package:geopoint/game/playable_country_policy.dart';

void main() {
  test('le Vatican est exclu de toutes les questions jouables', () {
    expect(PlayableCountryPolicy.isPlayableId('VAT'), isFalse);
    expect(PlayableCountryPolicy.isPlayableId(' vat '), isFalse);
  });

  test('un pays standard reste jouable', () {
    expect(PlayableCountryPolicy.isPlayableId('FRA'), isTrue);
  });

  test('le Vatican ne figure plus dans les parcours d’expédition', () {
    expect(
      EuropeExpeditionCatalog.allEuropeanCountries,
      isNot(contains('VAT')),
    );
    expect(
      EuropeExpeditionCatalog.europe.levels
          .expand((level) => level.countryIds),
      isNot(contains('VAT')),
    );
    expect(
      WorldExpeditionCatalog.world.levels.expand((level) => level.countryIds),
      isNot(contains('VAT')),
    );
  });

  test('les fleuves ne figurent plus dans l’expédition France', () {
    expect(
      FranceExpeditionCatalog.levels.map((level) => level.category),
      isNot(contains('river')),
    );
  });

  test('les reliefs ne figurent plus dans l’expédition France', () {
    expect(
      FranceExpeditionCatalog.levels.map((level) => level.category),
      isNot(contains('mountain')),
    );
  });

  test('villes, monnaies et langues sont intégrées aux expéditions', () {
    const List<String> expectedModes = <String>[
      'place_city',
      'currency',
      'language',
    ];
    final List<ContinentExpedition> expeditions = <ContinentExpedition>[
      EuropeExpeditionCatalog.europe,
      AfricaExpeditionCatalog.africa,
      AsiaExpeditionCatalog.asia,
      AmericasExpeditionCatalog.americas,
      OceaniaExpeditionCatalog.oceania,
      WorldExpeditionCatalog.world,
    ];

    for (final ContinentExpedition expedition in expeditions) {
      final Set<String> modes = expedition.levels
          .map((level) => level.modeId)
          .toSet();
      expect(modes, containsAll(expectedModes), reason: expedition.name);
    }
  });
}
