enum PassportMedal {
  none,
  bronze,
  silver,
  gold,
}

extension PassportMedalExtension on PassportMedal {
  String get label {
    switch (this) {
      case PassportMedal.none:
        return 'Aucun tampon';

      case PassportMedal.bronze:
        return 'Bronze';

      case PassportMedal.silver:
        return 'Argent';

      case PassportMedal.gold:
        return 'Or';
    }
  }

  int get rank {
    switch (this) {
      case PassportMedal.none:
        return 0;

      case PassportMedal.bronze:
        return 1;

      case PassportMedal.silver:
        return 2;

      case PassportMedal.gold:
        return 3;
    }
  }

  bool get isValidated {
    return this != PassportMedal.none;
  }

  String get jsonValue {
    switch (this) {
      case PassportMedal.none:
        return 'none';

      case PassportMedal.bronze:
        return 'bronze';

      case PassportMedal.silver:
        return 'silver';

      case PassportMedal.gold:
        return 'gold';
    }
  }

  static PassportMedal fromString(
    String value,
  ) {
    switch (value.trim().toLowerCase()) {
      case 'bronze':
        return PassportMedal.bronze;

      case 'silver':
      case 'argent':
        return PassportMedal.silver;

      case 'gold':
      case 'or':
        return PassportMedal.gold;

      default:
        return PassportMedal.none;
    }
  }
}

class PassportStamp {
  const PassportStamp({
    required this.id,
    required this.modeId,
    required this.name,
    required this.description,
    required this.iconName,
    required this.bronzeScore,
    required this.silverScore,
    required this.goldScore,
    required this.isEnabled,
  });

  /// Identifiant technique permanent.
  ///
  /// Exemples :
  /// countries
  /// capitals
  /// flags
  /// mixed
  final String id;

  /// Mode de jeu utilisé pour améliorer ce tampon.
  ///
  /// Exemples :
  /// find_country
  /// find_capital
  /// find_flag
  /// mixed
  final String modeId;

  /// Nom affiché dans le Passeport.
  final String name;

  /// Description courte du tampon.
  final String description;

  /// Nom de l’icône Flutter associée.
  final String iconName;

  /// Seuils nécessaires pour chaque médaille.
  final int bronzeScore;
  final int silverScore;
  final int goldScore;

  /// Permet de préparer de futurs tampons sans les rendre jouables.
  final bool isEnabled;

  bool get hasValidThresholds {
    return bronzeScore >= 0 &&
        silverScore >= bronzeScore &&
        goldScore >= silverScore;
  }

  PassportMedal medalForScore(
    int score,
  ) {
    if (score >= goldScore) {
      return PassportMedal.gold;
    }

    if (score >= silverScore) {
      return PassportMedal.silver;
    }

    if (score >= bronzeScore) {
      return PassportMedal.bronze;
    }

    return PassportMedal.none;
  }

  int requiredScoreFor(
    PassportMedal medal,
  ) {
    switch (medal) {
      case PassportMedal.none:
        return 0;

      case PassportMedal.bronze:
        return bronzeScore;

      case PassportMedal.silver:
        return silverScore;

      case PassportMedal.gold:
        return goldScore;
    }
  }

  factory PassportStamp.fromJson(
    Map<String, dynamic> json,
  ) {
    final PassportStamp stamp =
        PassportStamp(
      id: _readRequiredString(
        json,
        'id',
      ).toLowerCase(),
      modeId: _readRequiredString(
        json,
        'modeId',
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
      bronzeScore: _readRequiredInt(
        json,
        'bronzeScore',
      ),
      silverScore: _readRequiredInt(
        json,
        'silverScore',
      ),
      goldScore: _readRequiredInt(
        json,
        'goldScore',
      ),
      isEnabled: _readBool(
        json['isEnabled'],
        fallback: true,
      ),
    );

    if (!stamp.hasValidThresholds) {
      throw FormatException(
        'Seuils invalides pour le tampon ${stamp.id}.',
      );
    }

    return stamp;
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
        'dans PassportStamp : $key.',
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

    final int? parsed =
        int.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) {
      throw FormatException(
        'Valeur entière invalide '
        'dans PassportStamp : $key.',
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
    return 'PassportStamp('
        'id: $id, '
        'modeId: $modeId, '
        'bronze: $bronzeScore, '
        'silver: $silverScore, '
        'gold: $goldScore'
        ')';
  }
}