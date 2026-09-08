import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../geo_engine/country_info.dart';
import '../../geo_engine/geo_country.dart';
import '../../game/playable_country_policy.dart';
import '../atlas/atlas_city.dart';

enum WorldQuizMode {
  mixed,
  placeCity,
  cityCountry,
  currency,
  language,
  populationRange,
  populationCompare,
  ranking,
  area,
}

enum WorldQuizKind {
  placeCity,
  cityCountry,
  currency,
  language,
  populationRange,
  populationCompare,
  ranking,
  area,
}

class WorldQuizQuestion {
  const WorldQuizQuestion({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.subtitle,
    required this.answers,
    required this.correctAnswerIndex,
    required this.explanation,
    this.targetPoint,
    this.answerCountry,
    this.correctCountryIds = const <String>{},
  });

  final String id;
  final WorldQuizKind kind;
  final String prompt;
  final String subtitle;
  final List<String> answers;
  final int correctAnswerIndex;
  final String explanation;
  final LatLng? targetPoint;
  final GeoCountry? answerCountry;
  final Set<String> correctCountryIds;

  bool get usesMap =>
      kind == WorldQuizKind.placeCity || usesMultiSelectMap;

  bool get usesMultiSelectMap =>
      kind == WorldQuizKind.currency || kind == WorldQuizKind.language;

  String get correctAnswer {
    if (correctAnswerIndex < 0 || correctAnswerIndex >= answers.length) {
      return '';
    }
    return answers[correctAnswerIndex];
  }
}

class WorldQuizEngine {
  WorldQuizEngine({
    required List<GeoCountry> countries,
    required Iterable<CountryInfo> countryInfos,
    required List<AtlasCity> cities,
    this.regionId = 'world',
    this.difficultyId = 'easy',
    math.Random? random,
  }) : _random = random ?? math.Random() {
    final Map<String, CountryInfo> infoById = <String, CountryInfo>{
      for (final CountryInfo info in countryInfos)
        info.entityId.trim().toUpperCase(): info,
    };

    for (final GeoCountry country in countries) {
      final String id = country.id.trim().toUpperCase();
      final CountryInfo? info = infoById[id];
      if (!PlayableCountryPolicy.isPlayableId(id) ||
          !_standardCountryIds.contains(id) ||
          info == null ||
          !_matchesRegion(info.continent, regionId)) {
        continue;
      }

      final _QuizCountry entry = _QuizCountry(country: country, info: info);
      _countries.add(entry);
      final String isoA2 = country.isoA2.trim().toUpperCase();
      if (isoA2.length == 2) {
        _countriesByIsoA2[isoA2] = entry;
      }
    }

    for (final AtlasCity city in cities) {
      final _QuizCountry? country =
          _countriesByIsoA2[city.countryCode.trim().toUpperCase()];
      if (country == null || !_cityMatchesDifficulty(city, difficultyId)) {
        continue;
      }
      if (!city.isMajorNonCapital && !city.isMetropolis && !city.isCapital) {
        continue;
      }
      _cities.add(_QuizCity(city: city, country: country));
    }
  }

  final math.Random _random;
  final String regionId;
  final String difficultyId;
  final List<_QuizCountry> _countries = <_QuizCountry>[];
  final Map<String, _QuizCountry> _countriesByIsoA2 =
      <String, _QuizCountry>{};
  final List<_QuizCity> _cities = <_QuizCity>[];

  bool get hasEnoughData => _countries.isNotEmpty;

  int get countryCount => _countries.length;

  int get cityCount => _cities.length;

  WorldQuizQuestion nextQuestion({
    required WorldQuizMode mode,
    required Set<String> usedQuestionIds,
  }) {
    WorldQuizQuestion? fallback;

    for (int attempt = 0; attempt < 60; attempt++) {
      final WorldQuizKind kind = _kindForMode(mode);
      final WorldQuizQuestion question = _buildQuestion(kind);
      fallback ??= question;
      if (!usedQuestionIds.contains(question.id)) {
        return question;
      }
    }

    return fallback ?? _buildQuestion(WorldQuizKind.cityCountry);
  }

  WorldQuizKind _kindForMode(WorldQuizMode mode) {
    switch (mode) {
      case WorldQuizMode.placeCity:
        return WorldQuizKind.placeCity;
      case WorldQuizMode.cityCountry:
        return WorldQuizKind.cityCountry;
      case WorldQuizMode.currency:
        return WorldQuizKind.currency;
      case WorldQuizMode.language:
        return WorldQuizKind.language;
      case WorldQuizMode.populationRange:
        return WorldQuizKind.populationRange;
      case WorldQuizMode.populationCompare:
        return WorldQuizKind.populationCompare;
      case WorldQuizMode.ranking:
        return WorldQuizKind.ranking;
      case WorldQuizMode.area:
        return WorldQuizKind.area;
      case WorldQuizMode.mixed:
        return WorldQuizKind.values[_random.nextInt(WorldQuizKind.values.length)];
    }
  }

  WorldQuizQuestion _buildQuestion(WorldQuizKind kind) {
    switch (kind) {
      case WorldQuizKind.placeCity:
        return _placeCityQuestion();
      case WorldQuizKind.cityCountry:
        return _cityCountryQuestion();
      case WorldQuizKind.currency:
        return _currencyQuestion();
      case WorldQuizKind.language:
        return _languageQuestion();
      case WorldQuizKind.populationRange:
        return _populationRangeQuestion();
      case WorldQuizKind.populationCompare:
        return _populationComparisonQuestion();
      case WorldQuizKind.ranking:
        return _rankingQuestion();
      case WorldQuizKind.area:
        return _areaQuestion();
    }
  }

  WorldQuizQuestion _placeCityQuestion() {
    final _QuizCity selected = _pick(_cities);
    final AtlasCity city = selected.city;

    return WorldQuizQuestion(
      id: 'place-city-${city.id}',
      kind: WorldQuizKind.placeCity,
      prompt: 'Place ${city.name} sur la carte',
      subtitle: 'Pose ton repère au plus près de la ville.',
      answers: const <String>[],
      correctAnswerIndex: -1,
      explanation:
          '${city.name} se trouve en ${selected.country.name}. '
          '${city.shortDescription}',
      targetPoint: city.position,
      answerCountry: selected.country.country,
    );
  }

  WorldQuizQuestion _cityCountryQuestion() {
    final _QuizCity selected = _pick(_cities);
    final bool inverted = _random.nextBool();

    if (inverted) {
      final List<String> distractors = _cities
          .where((_QuizCity item) {
            return item.country.id != selected.country.id &&
                item.city.name != selected.city.name;
          })
          .map((_QuizCity item) => item.city.name)
          .toList(growable: false);
      final _ChoiceSet choices = _makeChoices(
        correct: selected.city.name,
        distractors: distractors,
      );

      return WorldQuizQuestion(
        id: 'country-city-${selected.country.id}-${selected.city.id}',
        kind: WorldQuizKind.cityCountry,
        prompt: 'Laquelle de ces villes se trouve en ${selected.country.name} ?',
        subtitle: 'Question inversée • une seule bonne réponse',
        answers: choices.answers,
        correctAnswerIndex: choices.correctIndex,
        explanation:
            '${selected.city.name} est située en ${selected.country.name}.',
        answerCountry: selected.country.country,
      );
    }

    final _ChoiceSet choices = _makeChoices(
      correct: selected.country.name,
      distractors: _countries
          .where((_QuizCountry item) => item.id != selected.country.id)
          .map((_QuizCountry item) => item.name)
          .toList(growable: false),
    );

    return WorldQuizQuestion(
      id: 'city-country-${selected.city.id}',
      kind: WorldQuizKind.cityCountry,
      prompt: 'Dans quel pays se trouve ${selected.city.name} ?',
      subtitle: 'Grande ville • choix multiple',
      answers: choices.answers,
      correctAnswerIndex: choices.correctIndex,
      explanation:
          '${selected.city.name} est située en ${selected.country.name}.',
      answerCountry: selected.country.country,
    );
  }

  WorldQuizQuestion _currencyQuestion() {
    final List<_QuizCountry> eligible = _countries
        .where((_QuizCountry item) =>
            item.currency.isNotEmpty &&
            !_multiMapExcludedCountryIds.contains(item.id))
        .toList(growable: false);
    final Map<String, List<_QuizCountry>> groups =
        _groupCountriesByValue(
      eligible,
      (_QuizCountry country) => country.currency,
    );
    final MapEntry<String, List<_QuizCountry>> selected =
        _pickKnowledgeGroup(
      groups,
      easyValues: _easyCurrencies,
    );
    final String currency = selected.value.first.currency;
    final List<String> countryNames = selected.value
        .map((_QuizCountry country) => country.name)
        .toList(growable: false)
      ..sort();

    return WorldQuizQuestion(
      id: 'currency-map-${_normalized(currency)}-${_normalized(regionId)}',
      kind: WorldQuizKind.currency,
      prompt:
          'Sélectionne tous les pays jouables de ${_regionLabel(regionId)} utilisant « $currency ».',
      subtitle: 'Monnaies • sélection multiple sur la carte',
      answers: const <String>[],
      correctAnswerIndex: -1,
      explanation:
          '${countryNames.join(', ')} ${countryNames.length == 1 ? 'utilise' : 'utilisent'} « $currency » dans cette zone.',
      correctCountryIds: selected.value
          .map((_QuizCountry country) => country.id)
          .toSet(),
    );
  }

  WorldQuizQuestion _languageQuestion() {
    final List<_QuizCountry> eligible = _countries
        .where((_QuizCountry item) =>
            item.languages.isNotEmpty &&
            !_multiMapExcludedCountryIds.contains(item.id))
        .toList(growable: false);
    final Map<String, List<_QuizCountry>> groups = <String, List<_QuizCountry>>{};
    for (final _QuizCountry country in eligible) {
      for (final String language in country.languages) {
        final String key = _normalized(language);
        if (key.isEmpty) {
          continue;
        }
        final List<_QuizCountry> countriesForLanguage =
            groups.putIfAbsent(key, () => <_QuizCountry>[]);
        if (!countriesForLanguage.any(
          (_QuizCountry item) => item.id == country.id,
        )) {
          countriesForLanguage.add(country);
        }
      }
    }
    final MapEntry<String, List<_QuizCountry>> selected =
        _pickKnowledgeGroup(
      groups,
      easyValues: _easyLanguages,
    );
    final String language = selected.value
        .expand((_QuizCountry country) => country.languages)
        .firstWhere(
          (String value) => _normalized(value) == selected.key,
          orElse: () => selected.key,
        );
    final List<String> countryNames = selected.value
        .map((_QuizCountry country) => country.name)
        .toSet()
        .toList(growable: false)
      ..sort();

    return WorldQuizQuestion(
      id: 'language-map-${_normalized(language)}-${_normalized(regionId)}',
      kind: WorldQuizKind.language,
      prompt:
          'Sélectionne tous les pays jouables de ${_regionLabel(regionId)} où $language est officielle ou coofficielle.',
      subtitle: 'Langues • sélection multiple sur la carte',
      answers: const <String>[],
      correctAnswerIndex: -1,
      explanation:
          '${countryNames.join(', ')} ${countryNames.length == 1 ? 'reconnaît' : 'reconnaissent'} officiellement $language dans cette zone.',
      correctCountryIds: selected.value
          .map((_QuizCountry country) => country.id)
          .toSet(),
    );
  }

  Map<String, List<_QuizCountry>> _groupCountriesByValue(
    List<_QuizCountry> countries,
    String Function(_QuizCountry country) valueFor,
  ) {
    final Map<String, List<_QuizCountry>> result =
        <String, List<_QuizCountry>>{};
    for (final _QuizCountry country in countries) {
      final String key = _normalized(valueFor(country));
      if (key.isEmpty) {
        continue;
      }
      result.putIfAbsent(key, () => <_QuizCountry>[]).add(country);
    }
    return result;
  }

  MapEntry<String, List<_QuizCountry>> _pickKnowledgeGroup(
    Map<String, List<_QuizCountry>> groups, {
    required Set<String> easyValues,
  }) {
    if (groups.isEmpty) {
      throw StateError('Aucune donnée compatible dans cette zone.');
    }

    final String difficulty = difficultyId.trim().toLowerCase();
    Iterable<MapEntry<String, List<_QuizCountry>>> candidates = groups.entries;

    if (difficulty == 'easy') {
      candidates = candidates.where(
        (MapEntry<String, List<_QuizCountry>> entry) =>
            easyValues.contains(entry.key) || entry.value.length >= 4,
      );
    } else if (difficulty == 'intermediate') {
      candidates = candidates.where(
        (MapEntry<String, List<_QuizCountry>> entry) => entry.value.length >= 2,
      );
    } else if (difficulty == 'hard') {
      candidates = candidates.where(
        (MapEntry<String, List<_QuizCountry>> entry) => entry.value.length <= 6,
      );
    }

    final List<MapEntry<String, List<_QuizCountry>>> pool =
        candidates.toList(growable: false);
    final List<MapEntry<String, List<_QuizCountry>>> effectivePool =
        pool.isEmpty ? groups.entries.toList(growable: false) : pool;
    return _pick(effectivePool);
  }

  WorldQuizQuestion _populationRangeQuestion() {
    final List<_QuizCountry> eligible = _countries
        .where((_QuizCountry item) => item.population != null)
        .toList(growable: false);
    final _QuizCountry selected = _pick(eligible);
    final int population = selected.population!;
    final String correct = _populationRange(population);
    final _ChoiceSet choices = _makeChoices(
      correct: correct,
      distractors: _populationRanges.where((String value) => value != correct),
    );

    return WorldQuizQuestion(
      id: 'population-range-${selected.id}',
      kind: WorldQuizKind.populationRange,
      prompt: 'Dans quelle tranche se situe la population de ${selected.name} ?',
      subtitle: 'Population par tranches',
      answers: choices.answers,
      correctAnswerIndex: choices.correctIndex,
      explanation:
          '${selected.name} compte environ ${_formatInteger(population)} habitants.',
    );
  }

  WorldQuizQuestion _populationComparisonQuestion() {
    final List<_QuizCountry> eligible = _countries
        .where((_QuizCountry item) => item.population != null)
        .toList(growable: false);
    final List<_QuizCountry> selected = _sample(eligible, 2);
    final _QuizCountry first = selected[0];
    final _QuizCountry second = selected[1];
    final bool asksMore = _random.nextBool();
    final bool firstWins = asksMore
        ? first.population! > second.population!
        : first.population! < second.population!;
    final String correct = firstWins ? first.name : second.name;
    final List<String> answers = <String>[first.name, second.name]..shuffle(_random);

    return WorldQuizQuestion(
      id: 'population-compare-${asksMore ? 'more' : 'less'}-'
          '${first.id}-${second.id}',
      kind: WorldQuizKind.populationCompare,
      prompt: asksMore
          ? 'Quel pays est le plus peuplé ?'
          : 'Quel pays est le moins peuplé ?',
      subtitle: '${first.name} ou ${second.name}',
      answers: answers,
      correctAnswerIndex: answers.indexOf(correct),
      explanation:
          '${first.name} : ${_formatInteger(first.population!)} hab. • '
          '${second.name} : ${_formatInteger(second.population!)} hab.',
    );
  }

  WorldQuizQuestion _rankingQuestion() {
    final bool byPopulation = _random.nextBool();
    final List<_QuizCountry> eligible = _countries.where((_QuizCountry item) {
      return byPopulation ? item.population != null : item.area != null;
    }).toList(growable: false);
    final List<_QuizCountry> selected = _sample(eligible, 4);
    final List<_QuizCountry> ordered = List<_QuizCountry>.of(selected)
      ..sort((_QuizCountry first, _QuizCountry second) {
        final num firstValue = byPopulation ? first.population! : first.area!;
        final num secondValue = byPopulation ? second.population! : second.area!;
        return secondValue.compareTo(firstValue);
      });
    final String correct = ordered.map((_QuizCountry item) => item.name).join(' › ');
    final Set<String> permutations = <String>{correct};

    while (permutations.length < 4) {
      final List<_QuizCountry> shuffled = List<_QuizCountry>.of(selected)
        ..shuffle(_random);
      permutations.add(shuffled.map((_QuizCountry item) => item.name).join(' › '));
    }

    final List<String> answers = permutations.toList()..shuffle(_random);

    return WorldQuizQuestion(
      id: 'ranking-${byPopulation ? 'population' : 'area'}-'
          '${selected.map((_QuizCountry item) => item.id).join('-')}',
      kind: WorldQuizKind.ranking,
      prompt: byPopulation
          ? 'Quel classement va du plus au moins peuplé ?'
          : 'Quel classement va du plus grand au plus petit territoire ?',
      subtitle: 'Classement de quatre pays',
      answers: answers,
      correctAnswerIndex: answers.indexOf(correct),
      explanation: byPopulation
          ? ordered
              .map((_QuizCountry item) {
                return '${item.name} (${_formatInteger(item.population!)})';
              })
              .join(' • ')
          : ordered
              .map((_QuizCountry item) {
                return '${item.name} (${_formatArea(item.area!)})';
              })
              .join(' • '),
    );
  }

  WorldQuizQuestion _areaQuestion() {
    final List<_QuizCountry> eligible = _countries
        .where((_QuizCountry item) => item.area != null && item.area! > 0)
        .toList(growable: false);
    final _QuizCountry selected = _pick(eligible);
    final bool inverted = _random.nextBool();

    if (inverted) {
      final _ChoiceSet choices = _makeChoices(
        correct: selected.name,
        distractors: eligible
            .where((_QuizCountry item) => item.id != selected.id)
            .map((_QuizCountry item) => item.name)
            .toList(growable: false),
      );
      return WorldQuizQuestion(
        id: 'area-country-${selected.id}',
        kind: WorldQuizKind.area,
        prompt: 'Quel pays possède une superficie proche de ${_formatArea(selected.area!)} ?',
        subtitle: 'Question inversée • superficie vers pays',
        answers: choices.answers,
        correctAnswerIndex: choices.correctIndex,
        explanation:
            'La superficie de ${selected.name} est d’environ ${_formatArea(selected.area!)}.',
      );
    }

    final String correct = _areaRange(selected.area!);
    final _ChoiceSet choices = _makeChoices(
      correct: correct,
      distractors: _areaRanges.where((String value) => value != correct),
    );
    return WorldQuizQuestion(
      id: 'country-area-${selected.id}',
      kind: WorldQuizKind.area,
      prompt: 'Dans quelle tranche se situe la superficie de ${selected.name} ?',
      subtitle: 'Superficies • choix multiple',
      answers: choices.answers,
      correctAnswerIndex: choices.correctIndex,
      explanation:
          'La superficie de ${selected.name} est d’environ ${_formatArea(selected.area!)}.',
    );
  }

  _ChoiceSet _makeChoices({
    required String correct,
    required Iterable<String> distractors,
  }) {
    final String normalizedCorrect = _normalized(correct);
    final List<String> pool = distractors
        .where((String value) => value.trim().isNotEmpty)
        .where((String value) => _normalized(value) != normalizedCorrect)
        .toSet()
        .toList(growable: false)
      ..shuffle(_random);
    final List<String> answers = <String>[correct, ...pool.take(3)]
      ..shuffle(_random);
    return _ChoiceSet(
      answers: List<String>.unmodifiable(answers),
      correctIndex: answers.indexOf(correct),
    );
  }

  T _pick<T>(List<T> values) {
    if (values.isEmpty) {
      throw StateError('Aucune donnée compatible pour ce quiz.');
    }
    return values[_random.nextInt(values.length)];
  }

  List<T> _sample<T>(List<T> values, int count) {
    final List<T> shuffled = List<T>.of(values)..shuffle(_random);
    return shuffled.take(count).toList(growable: false);
  }

  static String _normalized(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }

  static bool _matchesRegion(String continent, String regionId) {
    final String region = _normalized(regionId);
    final String value = _normalized(continent);
    if (region == 'world' || region.isEmpty) {
      return true;
    }
    if (region == 'americas') {
      return value.contains('amerique') || value.contains('america');
    }
    if (region == 'europe') {
      return value.contains('europe');
    }
    if (region == 'africa') {
      return value.contains('afrique') || value.contains('africa');
    }
    if (region == 'asia') {
      return value.contains('asie') || value.contains('asia');
    }
    if (region == 'oceania') {
      return value.contains('oceanie') || value.contains('oceania');
    }
    if (region == 'antarctica') {
      return value.contains('antarctique') || value.contains('antarctica');
    }
    return true;
  }

  static bool _cityMatchesDifficulty(AtlasCity city, String difficultyId) {
    switch (difficultyId.trim().toLowerCase()) {
      case 'easy':
        return city.population >= 1500000 ||
            (city.isCapital && city.population >= 750000);
      case 'intermediate':
        return city.population >= 750000 ||
            (city.isCapital && city.population >= 300000);
      case 'hard':
        return city.population >= 250000 || city.isCapital;
      case 'expert':
        return true;
      default:
        return city.population >= 750000;
    }
  }

  static String _regionLabel(String regionId) {
    switch (regionId.trim().toLowerCase()) {
      case 'europe':
        return 'l’Europe';
      case 'africa':
        return 'l’Afrique';
      case 'asia':
        return 'l’Asie';
      case 'americas':
        return 'les Amériques';
      case 'oceania':
        return 'l’Océanie';
      case 'antarctica':
        return 'l’Antarctique';
      default:
        return 'la zone Monde';
    }
  }

  static String _populationRange(int value) {
    if (value < 1000000) return 'Moins de 1 million';
    if (value < 10000000) return 'De 1 à 10 millions';
    if (value < 50000000) return 'De 10 à 50 millions';
    if (value < 100000000) return 'De 50 à 100 millions';
    return 'Plus de 100 millions';
  }

  static String _areaRange(double value) {
    if (value < 10000) return 'Moins de 10 000 km²';
    if (value < 100000) return 'De 10 000 à 100 000 km²';
    if (value < 1000000) return 'De 100 000 à 1 million km²';
    return 'Plus de 1 million km²';
  }

  static String _formatInteger(int value) {
    final String digits = value.toString();
    final StringBuffer result = StringBuffer();
    for (int index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        result.write(' ');
      }
      result.write(digits[index]);
    }
    return result.toString();
  }

  static String _formatArea(double value) {
    return '${_formatInteger(value.round())} km²';
  }

  static const List<String> _populationRanges = <String>[
    'Moins de 1 million',
    'De 1 à 10 millions',
    'De 10 à 50 millions',
    'De 50 à 100 millions',
    'Plus de 100 millions',
  ];

  static const List<String> _areaRanges = <String>[
    'Moins de 10 000 km²',
    'De 10 000 à 100 000 km²',
    'De 100 000 à 1 million km²',
    'Plus de 1 million km²',
  ];

  static const Set<String> _easyCurrencies = <String>{
    'euro',
    'dollar americain',
    'livre sterling',
    'yen japonais',
    'franc suisse',
    'yuan renminbi chinois',
  };

  static const Set<String> _easyLanguages = <String>{
    'anglais',
    'francais',
    'espagnol',
    'arabe',
    'portugais',
    'allemand',
  };

  static const Set<String> _multiMapExcludedCountryIds = <String>{
    'VAT',
    'SMR',
  };

  static const Set<String> _standardCountryIds = <String>{
    'AFG', 'ALB', 'DZA', 'AND', 'AGO', 'ATG', 'ARG', 'ARM', 'AUS', 'AUT',
    'AZE', 'BHS', 'BHR', 'BGD', 'BRB', 'BLR', 'BEL', 'BLZ', 'BEN', 'BTN',
    'BOL', 'BIH', 'BWA', 'BRA', 'BRN', 'BGR', 'BFA', 'BDI', 'CPV', 'KHM',
    'CMR', 'CAN', 'CAF', 'TCD', 'CHL', 'CHN', 'COL', 'COM', 'COD', 'COG',
    'CRI', 'CIV', 'HRV', 'CUB', 'CYP', 'CZE', 'DNK', 'DJI', 'DMA', 'DOM',
    'ECU', 'EGY', 'SLV', 'GNQ', 'ERI', 'EST', 'SWZ', 'ETH', 'FJI', 'FIN',
    'FRA', 'GAB', 'GMB', 'GEO', 'DEU', 'GHA', 'GRC', 'GRD', 'GTM', 'GIN',
    'GNB', 'GUY', 'HTI', 'HND', 'HUN', 'ISL', 'IND', 'IDN', 'IRN', 'IRQ',
    'IRL', 'ISR', 'ITA', 'JAM', 'JPN', 'JOR', 'KAZ', 'KEN', 'KIR', 'PRK',
    'KOR', 'KWT', 'KGZ', 'LAO', 'LVA', 'LBN', 'LSO', 'LBR', 'LBY', 'LIE',
    'LTU', 'LUX', 'MDG', 'MWI', 'MYS', 'MDV', 'MLI', 'MLT', 'MHL', 'MRT',
    'MUS', 'MEX', 'FSM', 'MDA', 'MCO', 'MNG', 'MNE', 'MAR', 'MOZ', 'MMR',
    'NAM', 'NRU', 'NPL', 'NLD', 'NZL', 'NIC', 'NER', 'NGA', 'MKD', 'NOR',
    'OMN', 'PAK', 'PLW', 'PAN', 'PNG', 'PRY', 'PER', 'PHL', 'POL', 'PRT',
    'QAT', 'ROU', 'RUS', 'RWA', 'KNA', 'LCA', 'VCT', 'WSM', 'SMR', 'STP',
    'SAU', 'SEN', 'SRB', 'SYC', 'SLE', 'SGP', 'SVK', 'SVN', 'SLB', 'SOM',
    'ZAF', 'SDS', 'ESP', 'LKA', 'SDN', 'SUR', 'SWE', 'CHE', 'SYR', 'TWN',
    'TJK', 'TZA', 'THA', 'TLS', 'TGO', 'TON', 'TTO', 'TUN', 'TUR', 'TKM',
    'TUV', 'UGA', 'UKR', 'ARE', 'GBR', 'USA', 'URY', 'UZB', 'VUT',
    'VEN', 'VNM', 'YEM', 'ZMB', 'ZWE', 'PSX', 'KOS',
  };
}

class _QuizCountry {
  const _QuizCountry({required this.country, required this.info});

  final GeoCountry country;
  final CountryInfo info;

  String get id => country.id.trim().toUpperCase();
  String get name => info.title;
  int? get population => info.population;
  double? get area => info.areaSquareKilometers;
  String get currency => info.currency?.trim() ?? '';
  List<String> get languages => info.languages;
}

class _QuizCity {
  const _QuizCity({required this.city, required this.country});

  final AtlasCity city;
  final _QuizCountry country;
}

class _ChoiceSet {
  const _ChoiceSet({required this.answers, required this.correctIndex});

  final List<String> answers;
  final int correctIndex;
}
