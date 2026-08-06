class GameDifficulty {
  const GameDifficulty({
    required this.id,
    required this.order,
    required this.name,
    required this.description,
    required this.iconName,
    required this.questionDurationSeconds,
    required this.questionCount,
    required this.minimumScoreToComplete,
    required this.includeIndependentCountries,
    required this.includeTerritories,
    required this.includeSmallCountries,
    required this.usePlayerRegion,
    required this.initialZoom,
    required this.isEnabled,
  });

  /// Identifiant technique stable.
  ///
  /// Exemples :
  /// discovery
  /// easy
  /// intermediate
  /// hard
  /// expert
  final String id;

  /// Ordre d’affichage et de déblocage.
  final int order;

  /// Nom visible par le joueur.
  final String name;

  /// Description courte.
  final String description;

  /// Nom de l’icône Flutter.
  final String iconName;

  /// Durée disponible par question.
  final int questionDurationSeconds;

  /// Nombre de questions par épreuve.
  final int questionCount;

  /// Score minimum pour valider une épreuve.
  final int minimumScoreToComplete;

  /// Inclut les pays indépendants.
  final bool includeIndependentCountries;

  /// Inclut les territoires.
  final bool includeTerritories;

  /// Inclut les micro-États et petits territoires.
  final bool includeSmallCountries;

  /// Utilise la région choisie par le joueur
  /// pour sélectionner les premières questions.
  final bool usePlayerRegion;

  /// Zoom initial conseillé pour la carte.
  final double initialZoom;

  /// Permet de préparer une difficulté
  /// sans encore la rendre jouable.
  final bool isEnabled;

  bool get isDiscovery {
    return id == 'discovery';
  }

  bool get isEasy {
    return id == 'easy';
  }

  bool get isIntermediate {
    return id == 'intermediate';
  }

  bool get isHard {
    return id == 'hard';
  }

  bool get isExpert {
    return id == 'expert';
  }

  factory GameDifficulty.fromJson(
    Map<String, dynamic> json,
  ) {
    final GameDifficulty difficulty =
        GameDifficulty(
      id: _readRequiredString(
        json,
        'id',
      ).toLowerCase(),
      order: _readRequiredInt(
        json,
        'order',
      ),
      name: _readRequiredString(
        json,
        'name',
      ),
      description: _readRequiredString(
        json,
        'description',
      ),
      iconName: _readRequiredString(
        json,
        'iconName',
      ),
      questionDurationSeconds:
          _readRequiredInt(
        json,
        'questionDurationSeconds',
      ),
      questionCount: _readRequiredInt(
        json,
        'questionCount',
      ),
      minimumScoreToComplete:
          _readRequiredInt(
        json,
        'minimumScoreToComplete',
      ),
      includeIndependentCountries:
          _readBool(
        json['includeIndependentCountries'],
        fallback: true,
      ),
      includeTerritories: _readBool(
        json['includeTerritories'],
        fallback: false,
      ),
      includeSmallCountries: _readBool(
        json['includeSmallCountries'],
        fallback: false,
      ),
      usePlayerRegion: _readBool(
        json['usePlayerRegion'],
        fallback: false,
      ),
      initialZoom: _readRequiredDouble(
        json,
        'initialZoom',
      ),
      isEnabled: _readBool(
        json['isEnabled'],
        fallback: true,
      ),
    );

    if (!difficulty.isValid) {
      throw FormatException(
        'Difficulté invalide : ${difficulty.id}.',
      );
    }

    return difficulty;
  }

  bool get isValid {
    return id.trim().isNotEmpty &&
        order >= 1 &&
        name.trim().isNotEmpty &&
        questionDurationSeconds > 0 &&
        questionCount > 0 &&
        minimumScoreToComplete >= 0 &&
        initialZoom >= 0;
  }

  static String _readRequiredString(
    Map<String, dynamic> json,
    String key,
  ) {
    final String value =
        json[key]?.toString().trim() ?? '';

    if (value.isEmpty) {
      throw FormatException(
        'Champ obligatoire manquant '
        'dans GameDifficulty : $key.',
      );
    }

    return value;
  }

  static int _readRequiredInt(
    Map<String, dynamic> json,
    String key,
  ) {
    final Object? value = json[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final int? parsed = int.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) {
      throw FormatException(
        'Valeur entière invalide '
        'dans GameDifficulty : $key.',
      );
    }

    return parsed;
  }

  static double _readRequiredDouble(
    Map<String, dynamic> json,
    String key,
  ) {
    final Object? value = json[key];

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    final double? parsed = double.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) {
      throw FormatException(
        'Valeur décimale invalide '
        'dans GameDifficulty : $key.',
      );
    }

    return parsed;
  }

  static bool _readBool(
    Object? value, {
    required bool fallback,
  }) {
    if (value is bool) {
      return value;
    }

    final String text =
        value?.toString().trim().toLowerCase() ?? '';

    if (text == 'true') {
      return true;
    }

    if (text == 'false') {
      return false;
    }

    return fallback;
  }

  @override
  String toString() {
    return 'GameDifficulty('
        'id: $id, '
        'order: $order, '
        'name: $name, '
        'duration: $questionDurationSeconds, '
        'questions: $questionCount'
        ')';
  }
}