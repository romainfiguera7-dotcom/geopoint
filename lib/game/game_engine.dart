import 'dart:math';

import '../geo_engine/geo_country.dart';
import 'game_question.dart';

class GameEngine {
  GameEngine({
    Random? random,
  }) : _random = random ?? Random();

  final Random _random;

  final Set<String> _usedCountryIds =
      <String>{};

  final List<String> _mixedModeBag =
      <String>[];

  static const List<String> _mixedModes =
      <String>[
    'find_country',
    'find_capital',
    'find_flag',
  ];

  GameQuestion? createNextQuestion(
    List<GeoCountry> countries, {
    String modeId = 'find_country',
  }) {
    if (countries.isEmpty) {
      return null;
    }

    final String normalizedModeId =
        _normalizeModeId(
      modeId,
    );

    final String resolvedQuestionMode =
        normalizedModeId == 'mixed'
            ? _nextMixedMode()
            : normalizedModeId;

    final List<GeoCountry> availableCountries =
        countries.where(
      (GeoCountry country) {
        return !_usedCountryIds.contains(
          country.id,
        );
      },
    ).toList();

    if (availableCountries.isEmpty) {
      _usedCountryIds.clear();

      availableCountries.addAll(
        countries,
      );
    }

    final GeoCountry selectedCountry =
        availableCountries[
      _random.nextInt(
        availableCountries.length,
      )
    ];

    _usedCountryIds.add(
      selectedCountry.id,
    );

    return GameQuestion(
      modeId: resolvedQuestionMode,
      countryId:
          selectedCountry.id,
      countryName:
          selectedCountry.name,
      isoA2:
          selectedCountry.isoA2,
      continent:
          selectedCountry.continent,
    );
  }

  String _nextMixedMode() {
    if (_mixedModeBag.isEmpty) {
      /*
       * Sac équilibré de 9 questions :
       * 3 pays, 3 capitales et 3 drapeaux.
       *
       * Pour une partie de 10 questions, la
       * dixième démarre simplement un nouveau sac.
       */
      _mixedModeBag.addAll(
        <String>[
          ..._mixedModes,
          ..._mixedModes,
          ..._mixedModes,
        ],
      );

      _mixedModeBag.shuffle(
        _random,
      );
    }

    return _mixedModeBag.removeLast();
  }

  String _normalizeModeId(
    String modeId,
  ) {
    final String normalized =
        modeId.trim().toLowerCase();

    switch (normalized) {
      case 'find_country':
      case 'find_capital':
      case 'find_flag':
      case 'mixed':
        return normalized;

      default:
        return 'find_country';
    }
  }

  void reset() {
    _usedCountryIds.clear();
    _mixedModeBag.clear();
  }

  int get usedQuestionCount {
    return _usedCountryIds.length;
  }
}
