class CountryInfo {
  const CountryInfo({
    required this.entityId,
    required this.title,
    required this.continent,
    this.population,
    this.areaSquareKilometers,
    this.currency,
    this.languages = const <String>[],
    this.shortFact,
    this.history,
  });

  /// Identifiant correspondant au pays ou territoire du GeoJSON.
  ///
  /// Exemples : FRA, PRT, CLP, ATC.
  final String entityId;

  /// Nom affiché dans la fiche.
  final String title;

  /// Continent ou grande zone géographique.
  final String continent;

  /// Population facultative.
  final int? population;

  /// Superficie facultative en km².
  final double? areaSquareKilometers;

  /// Monnaie principale.
  final String? currency;

  /// Langues principales.
  final List<String> languages;

  /// Anecdote courte affichable directement après la réponse.
  final String? shortFact;

  /// Texte plus complet pour le bouton « En savoir plus ».
  final String? history;

  bool get hasPopulation {
    return population != null;
  }

  bool get hasArea {
    return areaSquareKilometers != null;
  }

  bool get hasShortFact {
    return shortFact != null &&
        shortFact!.trim().isNotEmpty;
  }

  bool get hasHistory {
    return history != null &&
        history!.trim().isNotEmpty;
  }

  String get formattedPopulation {
    final int? value = population;

    if (value == null) {
      return '';
    }

    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)} milliard(s)';
    }

    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} million(s)';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} mille';
    }

    return '$value';
  }

  String get formattedArea {
    final double? value =
        areaSquareKilometers;

    if (value == null) {
      return '';
    }

    if (value < 10) {
      return '${value.toStringAsFixed(1)} km²';
    }

    return '${value.round()} km²';
  }

  factory CountryInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    final String entityId =
        _readRequiredString(
      json,
      'entityId',
    ).toUpperCase();

    final String title =
        _readRequiredString(
      json,
      'title',
    );

    final String continent =
        _readRequiredString(
      json,
      'continent',
    );

    return CountryInfo(
      entityId: entityId,
      title: title,
      continent: continent,
      population:
          _readOptionalInt(
        json['population'],
      ),
      areaSquareKilometers:
          _readOptionalDouble(
        json['areaSquareKilometers'],
      ),
      currency:
          _readOptionalString(
        json['currency'],
      ),
      languages:
          _readStringList(
        json['languages'],
      ),
      shortFact:
          _readOptionalString(
        json['shortFact'],
      ),
      history:
          _readOptionalString(
        json['history'],
      ),
    );
  }

  static String _readRequiredString(
    Map<String, dynamic> json,
    String key,
  ) {
    final String value =
        json[key]?.toString().trim() ?? '';

    if (value.isEmpty) {
      throw FormatException(
        'Champ obligatoire manquant dans CountryInfo : $key.',
      );
    }

    return value;
  }

  static String? _readOptionalString(
    Object? value,
  ) {
    final String text =
        value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  static int? _readOptionalInt(
    Object? value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static double? _readOptionalDouble(
    Object? value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  static List<String> _readStringList(
    Object? value,
  ) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .map(
          (Object? item) =>
              item?.toString().trim() ?? '',
        )
        .where(
          (String item) => item.isNotEmpty,
        )
        .toList(
          growable: false,
        );
  }
}