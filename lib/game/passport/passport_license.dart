import 'passport_stamp.dart';

class PassportLicenseRequirement {
  const PassportLicenseRequirement({
    required this.stampId,
    required this.minimumMedal,
  });

  final String stampId;
  final PassportMedal minimumMedal;

  factory PassportLicenseRequirement.fromJson(
    Map<String, dynamic> json,
  ) {
    return PassportLicenseRequirement(
      stampId: _readRequiredString(
        json,
        'stampId',
      ).toLowerCase(),
      minimumMedal:
          PassportMedalExtension.fromString(
        _readRequiredString(
          json,
          'minimumMedal',
        ),
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
        'Champ obligatoire manquant dans '
        'PassportLicenseRequirement : $key.',
      );
    }

    return value;
  }
}

class PassportLicense {
  const PassportLicense({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.difficultyMax,
    required this.questionCount,
    required this.questionDurationSeconds,
    required this.categories,
    required this.requirements,
    required this.isUnlockedByDefault,
  });

  final int id;

  /// Nom de la licence.
  ///
  /// Exemple : Premiers pas.
  final String name;

  /// Titre obtenu par le joueur.
  ///
  /// Exemple : Voyageur.
  final String title;

  final String description;

  /// Difficulté maximale des entités proposées.
  final int difficultyMax;

  final int questionCount;

  final int questionDurationSeconds;

  /// Catégories géographiques autorisées.
  ///
  /// Exemples :
  /// country
  /// microstate
  /// territory
  final List<String> categories;

  /// Tampons et médailles nécessaires
  /// pour obtenir cette licence.
  final List<PassportLicenseRequirement>
      requirements;

  final bool isUnlockedByDefault;

  bool get isFirstLicense {
    return id == 1;
  }

  bool get hasRequirements {
    return requirements.isNotEmpty;
  }

  factory PassportLicense.fromJson(
    Map<String, dynamic> json,
  ) {
    final List<String> categories =
        _readStringList(
      json['categories'],
    );

    if (categories.isEmpty) {
      throw FormatException(
        'La licence ${json['id']} doit contenir '
        'au moins une catégorie.',
      );
    }

    final List<PassportLicenseRequirement>
        requirements =
        _readRequirements(
      json['requirements'],
    );

    if (requirements.isEmpty) {
      throw FormatException(
        'La licence ${json['id']} doit contenir '
        'au moins une exigence.',
      );
    }

    return PassportLicense(
      id: _readRequiredInt(
        json,
        'id',
      ),
      name: _readRequiredString(
        json,
        'name',
      ),
      title: _readRequiredString(
        json,
        'title',
      ),
      description: _readRequiredString(
        json,
        'description',
      ),
      difficultyMax: _readRequiredInt(
        json,
        'difficultyMax',
      ),
      questionCount: _readRequiredInt(
        json,
        'questionCount',
      ),
      questionDurationSeconds:
          _readRequiredInt(
        json,
        'questionDurationSeconds',
      ),
      categories:
          List<String>.unmodifiable(
        categories,
      ),
      requirements:
          List<PassportLicenseRequirement>
              .unmodifiable(
        requirements,
      ),
      isUnlockedByDefault:
          _readBool(
        json['isUnlockedByDefault'],
        fallback: false,
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
        'Champ obligatoire manquant dans '
        'PassportLicense : $key.',
      );
    }

    return value;
  }

  static int _readRequiredInt(
    Map<String, dynamic> json,
    String key,
  ) {
    final Object? value =
        json[key];

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
        'Valeur entière invalide dans '
        'PassportLicense : $key.',
      );
    }

    return parsed;
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
          (String item) =>
              item.isNotEmpty,
        )
        .toList(
          growable: false,
        );
  }

  static List<PassportLicenseRequirement>
      _readRequirements(
    Object? value,
  ) {
    if (value is! List) {
      return const <
          PassportLicenseRequirement>[];
    }

    final List<PassportLicenseRequirement>
        result =
        <PassportLicenseRequirement>[];

    for (final Object? item in value) {
      if (item is! Map) {
        continue;
      }

      final Map<String, dynamic> json =
          item.map<String, dynamic>(
        (
          dynamic key,
          dynamic value,
        ) {
          return MapEntry<String, dynamic>(
            key.toString(),
            value,
          );
        },
      );

      result.add(
        PassportLicenseRequirement.fromJson(
          json,
        ),
      );
    }

    return result;
  }

  static bool _readBool(
    Object? value, {
    required bool fallback,
  }) {
    if (value is bool) {
      return value;
    }

    final String text =
        value
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

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
    return 'PassportLicense('
        'id: $id, '
        'name: $name, '
        'title: $title, '
        'difficultyMax: $difficultyMax, '
        'requirements: ${requirements.length}'
        ')';
  }
}