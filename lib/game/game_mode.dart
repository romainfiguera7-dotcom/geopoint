class GameMode {
  const GameMode({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.isEnabled,
  });

  /// Identifiant technique stable.
  ///
  /// Exemples :
  /// find_country
  /// find_capital
  /// find_flag
  /// mixed
  final String id;

  /// Nom affiché au joueur.
  final String name;

  /// Courte explication du mode.
  final String description;

  /// Nom de l’icône associé au mode.
  ///
  /// L’interface transformera ensuite cette valeur
  /// en véritable IconData Flutter.
  final String iconName;

  /// Permet de préparer un mode sans encore
  /// l’afficher comme jouable.
  final bool isEnabled;

  bool get isFindCountry {
    return id == 'find_country';
  }

  bool get isFindCapital {
    return id == 'find_capital';
  }

  bool get isFindFlag {
    return id == 'find_flag';
  }

  bool get isMixed {
    return id == 'mixed';
  }

  factory GameMode.fromJson(
    Map<String, dynamic> json,
  ) {
    return GameMode(
      id: _readRequiredString(
        json,
        'id',
      ).toLowerCase(),
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
      isEnabled: _readBool(
        json['isEnabled'],
        fallback: true,
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
        'Champ obligatoire manquant dans GameMode : $key.',
      );
    }

    return value;
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
    return 'GameMode('
        'id: $id, '
        'name: $name, '
        'isEnabled: $isEnabled'
        ')';
  }
}