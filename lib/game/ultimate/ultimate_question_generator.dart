import 'dart:math';

import '../../geo_engine/geo_country.dart';
import 'ultimate_question.dart';

class UltimateQuestionGenerator {
  UltimateQuestionGenerator({
    Random? random,
  }) : _random = random ?? Random();

  final Random _random;

  final Set<String> _usedAnswerCountryIds =
      <String>{};

  UltimateQuestion? createQuestion({
    required List<GeoCountry> availableCountries,
    required Map<String, int> countryDifficulties,
  }) {
    final List<GeoCountry> eligibleCountries =
        availableCountries.where(
      (GeoCountry country) {
        return country.polygons.isNotEmpty;
      },
    ).toList();

    if (eligibleCountries.length < 4) {
      return null;
    }

    List<GeoCountry> possibleAnswers =
        eligibleCountries.where(
      (GeoCountry country) {
        return !_usedAnswerCountryIds.contains(
          _normalizeId(
            country.id,
          ),
        );
      },
    ).toList();

    if (possibleAnswers.isEmpty) {
      _usedAnswerCountryIds.clear();

      possibleAnswers =
          List<GeoCountry>.from(
        eligibleCountries,
      );
    }

    final GeoCountry answerCountry =
        possibleAnswers[
      _random.nextInt(
        possibleAnswers.length,
      )
    ];

    final List<GeoCountry> distractors =
        _selectDistractors(
      answerCountry:
          answerCountry,
      availableCountries:
          eligibleCountries,
      countryDifficulties:
          countryDifficulties,
    );

    if (distractors.length < 3) {
      return null;
    }

    final List<GeoCountry> choices =
        <GeoCountry>[
      answerCountry,
      ...distractors.take(3),
    ]..shuffle(
            _random,
          );

    _usedAnswerCountryIds.add(
      _normalizeId(
        answerCountry.id,
      ),
    );

    return UltimateQuestion(
      answerCountry:
          answerCountry,
      choices:
          choices,
    );
  }

  List<GeoCountry> _selectDistractors({
    required GeoCountry answerCountry,
    required List<GeoCountry> availableCountries,
    required Map<String, int> countryDifficulties,
  }) {
    final int answerDifficulty =
        _difficultyFor(
      answerCountry,
      countryDifficulties,
    );

    final List<_DistractorCandidate> candidates =
        availableCountries
            .where(
              (GeoCountry country) {
                return _normalizeId(
                      country.id,
                    ) !=
                    _normalizeId(
                      answerCountry.id,
                    );
              },
            )
            .map<_DistractorCandidate>(
              (GeoCountry country) {
                final int countryDifficulty =
                    _difficultyFor(
                  country,
                  countryDifficulties,
                );

                final int difficultyDifference =
                    (
                      countryDifficulty -
                      answerDifficulty
                    ).abs();

                final bool sameContinent =
                    _normalizeText(
                      country.continent,
                    ) ==
                    _normalizeText(
                      answerCountry.continent,
                    );

                final double shapeSimilarity =
                    _calculateShapeSimilarity(
                  answerCountry,
                  country,
                );

                final double score =
                    _calculateCandidateScore(
                  sameContinent:
                      sameContinent,
                  difficultyDifference:
                      difficultyDifference,
                  shapeSimilarity:
                      shapeSimilarity,
                );

                return _DistractorCandidate(
                  country:
                      country,
                  score:
                      score,
                );
              },
            )
            .toList();

    candidates.sort(
      (
        _DistractorCandidate a,
        _DistractorCandidate b,
      ) {
        return b.score.compareTo(
          a.score,
        );
      },
    );

    final List<GeoCountry> result =
        <GeoCountry>[];

    final List<_DistractorCandidate> preferredPool =
        candidates.take(
      min(
        12,
        candidates.length,
      ),
    ).toList();

    while (preferredPool.isNotEmpty &&
        result.length < 3) {
      final int index =
          _random.nextInt(
        preferredPool.length,
      );

      result.add(
        preferredPool.removeAt(
          index,
        ).country,
      );
    }

    if (result.length < 3) {
      final Set<String> selectedIds =
          result
              .map<String>(
                (GeoCountry country) {
                  return _normalizeId(
                    country.id,
                  );
                },
              )
              .toSet();

      for (final _DistractorCandidate candidate
          in candidates) {
        final String candidateId =
            _normalizeId(
          candidate.country.id,
        );

        if (selectedIds.contains(
          candidateId,
        )) {
          continue;
        }

        result.add(
          candidate.country,
        );

        selectedIds.add(
          candidateId,
        );

        if (result.length >= 3) {
          break;
        }
      }
    }

    return result;
  }

  double _calculateCandidateScore({
    required bool sameContinent,
    required int difficultyDifference,
    required double shapeSimilarity,
  }) {
    double score = 0;

    if (sameContinent) {
      score += 40;
    }

    score +=
        max(
      0,
      30 - difficultyDifference,
    );

    score +=
        shapeSimilarity * 30;

    score +=
        _random.nextDouble() * 8;

    return score;
  }

  double _calculateShapeSimilarity(
    GeoCountry first,
    GeoCountry second,
  ) {
    final double firstWidth =
        first.bounds.maxLongitude -
            first.bounds.minLongitude;

    final double firstHeight =
        first.bounds.maxLatitude -
            first.bounds.minLatitude;

    final double secondWidth =
        second.bounds.maxLongitude -
            second.bounds.minLongitude;

    final double secondHeight =
        second.bounds.maxLatitude -
            second.bounds.minLatitude;

    if (firstWidth <= 0 ||
        firstHeight <= 0 ||
        secondWidth <= 0 ||
        secondHeight <= 0) {
      return 0;
    }

    final double firstRatio =
        firstWidth /
            firstHeight;

    final double secondRatio =
        secondWidth /
            secondHeight;

    final double ratioDifference =
        (
          firstRatio -
          secondRatio
        ).abs();

    final double ratioSimilarity =
        1 /
            (
              1 +
              ratioDifference
            );

    final double firstArea =
        firstWidth *
            firstHeight;

    final double secondArea =
        secondWidth *
            secondHeight;

    final double largerArea =
        max(
      firstArea,
      secondArea,
    );

    final double smallerArea =
        min(
      firstArea,
      secondArea,
    );

    final double areaSimilarity =
        largerArea <= 0
            ? 0
            : smallerArea /
                largerArea;

    return (
      ratioSimilarity * 0.65 +
      areaSimilarity * 0.35
    ).clamp(
      0,
      1,
    );
  }

  int _difficultyFor(
    GeoCountry country,
    Map<String, int> countryDifficulties,
  ) {
    return countryDifficulties[
          _normalizeId(
            country.id,
          )
        ] ??
        100;
  }

  String _normalizeId(
    String value,
  ) {
    return value
        .trim()
        .toUpperCase();
  }

  String _normalizeText(
    String value,
  ) {
    return value
        .trim()
        .toLowerCase();
  }

  void reset() {
    _usedAnswerCountryIds.clear();
  }

  int get usedQuestionCount {
    return _usedAnswerCountryIds.length;
  }
}

class _DistractorCandidate {
  const _DistractorCandidate({
    required this.country,
    required this.score,
  });

  final GeoCountry country;
  final double score;
}