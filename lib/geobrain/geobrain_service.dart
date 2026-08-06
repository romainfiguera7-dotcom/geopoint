import 'package:flutter/foundation.dart';

import 'country_mastery.dart';
import 'geobrain_profile.dart';
import 'geobrain_storage.dart';

class GeoBrainService {
  GeoBrainService._(
    this._profile,
  );

  GeoBrainProfile _profile;

  GeoBrainProfile get profile => _profile;

  static Future<GeoBrainService> create() async {
    final GeoBrainProfile? saved =
        await GeoBrainStorage.load();

    return GeoBrainService._(
      saved ?? GeoBrainProfile.initial(),
    );
  }

  Future<void> save() async {
    await GeoBrainStorage.save(
      _profile,
    );
  }

  Future<void> clear() async {
    await GeoBrainStorage.clear();

    _profile = GeoBrainProfile.initial();
  }

  CountryMastery masteryFor(
    String countryId,
  ) {
    return _profile.masteryFor(
      countryId,
    );
  }

  Future<void> registerAnswer({
    required String countryId,
    required bool isCorrect,
  }) async {
    _profile = _profile.registerAnswer(
      countryId: countryId,
      isCorrect: isCorrect,
    );

    await save();

    debugPrint(
      'GeoBrain : '
      '$countryId -> '
      '${isCorrect ? "bonne réponse" : "mauvaise réponse"} '
      '(${masteryFor(countryId).starsLabel})',
    );
  }

  Future<void> toggleWishlist(
    String countryId,
  ) async {
    _profile =
        _profile.toggleWishlist(
      countryId,
    );

    await save();
  }

  Future<void> markVisited({
    required String countryId,
    required bool visited,
  }) async {
    _profile =
        _profile.markVisited(
      countryId: countryId,
      visited: visited,
    );

    await save();
  }

  double worldMastery({
    required int totalCountries,
  }) {
    return _profile.worldMasteryPercentage(
      totalCountryCount:
          totalCountries,
    );
  }

  List<CountryMastery>
      get countriesDueForReview {
    return _profile
        .countriesDueForReview;
  }

  List<CountryMastery>
      get weakestCountries {
    return _profile
        .weakestCountries;
  }

  List<CountryMastery>
      get strongestCountries {
    return _profile
        .strongestCountries;
  }

  List<CountryMastery>
      get visitedCountries {
    return _profile
        .visitedCountries;
  }

  List<CountryMastery>
      get wishlistedCountries {
    return _profile
        .wishlistedCountries;
  }

  int countAtLevel(
    int masteryLevel,
  ) {
    return _profile
        .countCountriesAtMasteryLevel(
      masteryLevel,
    );
  }
}