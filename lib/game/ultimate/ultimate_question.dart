import '../../geo_engine/geo_country.dart';

class UltimateQuestion {
  UltimateQuestion({
    required this.answerCountry,
    required List<GeoCountry> choices,
  }) : choices = List<GeoCountry>.unmodifiable(
          choices,
        ) {
    if (choices.length != 4) {
      throw ArgumentError.value(
        choices.length,
        'choices',
        'Une question ultime doit contenir '
            'exactement 4 propositions.',
      );
    }

    final Set<String> choiceIds = choices
        .map<String>(
          (GeoCountry country) =>
              country.id.trim().toUpperCase(),
        )
        .toSet();

    if (choiceIds.length != 4) {
      throw ArgumentError(
        'Les quatre propositions doivent '
        'être différentes.',
      );
    }

    if (!choiceIds.contains(
      answerCountry.id.trim().toUpperCase(),
    )) {
      throw ArgumentError(
        'La bonne réponse doit être présente '
        'dans les quatre propositions.',
      );
    }
  }

  final GeoCountry answerCountry;

  final List<GeoCountry> choices;

  String get answerCountryId {
    return answerCountry.id
        .trim()
        .toUpperCase();
  }

  bool isCorrectChoice(
    String countryId,
  ) {
    return countryId.trim().toUpperCase() ==
        answerCountryId;
  }

  @override
  String toString() {
    return 'UltimateQuestion('
        'answer: ${answerCountry.name}, '
        'choices: '
        '${choices.map((GeoCountry c) => c.name).join(", ")}'
        ')';
  }
}