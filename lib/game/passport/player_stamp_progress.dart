import 'passport_stamp.dart';

class PlayerStampProgress {
  const PlayerStampProgress({
    required this.stampId,
    required this.bestScore,
    required this.attempts,
    required this.medal,
    required this.lastPlayedAt,
    required this.firstValidatedAt,
  });

  /// Identifiant du tampon concerné.
  ///
  /// Exemples :
  /// countries
  /// capitals
  /// flags
  /// mixed
  final String stampId;

  /// Meilleur score obtenu pour ce tampon.
  final int bestScore;

  /// Nombre total de parties jouées sur ce tampon.
  final int attempts;

  /// Meilleure médaille obtenue.
  final PassportMedal medal;

  /// Date de la dernière tentative.
  final DateTime? lastPlayedAt;

  /// Date de la première validation du tampon.
  final DateTime? firstValidatedAt;

  factory PlayerStampProgress.empty(
    String stampId,
  ) {
    return PlayerStampProgress(
      stampId: stampId.trim().toLowerCase(),
      bestScore: 0,
      attempts: 0,
      medal: PassportMedal.none,
      lastPlayedAt: null,
      firstValidatedAt: null,
    );
  }

  bool get hasPlayed {
    return attempts > 0;
  }

  bool get isValidated {
    return medal.isValidated;
  }

  PlayerStampProgress registerResult({
    required PassportStamp stamp,
    required int score,
    DateTime? playedAt,
  }) {
    if (stamp.id != stampId) {
      throw ArgumentError(
        'Le tampon ${stamp.id} ne correspond pas '
        'à la progression $stampId.',
      );
    }

    final DateTime effectivePlayedAt =
        playedAt ?? DateTime.now();

    final int updatedBestScore =
        score > bestScore
            ? score
            : bestScore;

    final PassportMedal resultMedal =
        stamp.medalForScore(
      score,
    );

    final PassportMedal updatedMedal =
        resultMedal.rank > medal.rank
            ? resultMedal
            : medal;

    final DateTime? updatedFirstValidatedAt =
        firstValidatedAt ??
            (
              updatedMedal.isValidated
                  ? effectivePlayedAt
                  : null
            );

    return PlayerStampProgress(
      stampId: stampId,
      bestScore: updatedBestScore,
      attempts: attempts + 1,
      medal: updatedMedal,
      lastPlayedAt: effectivePlayedAt,
      firstValidatedAt:
          updatedFirstValidatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stampId': stampId,
      'bestScore': bestScore,
      'attempts': attempts,
      'medal': medal.jsonValue,
      'lastPlayedAt':
          lastPlayedAt?.toIso8601String(),
      'firstValidatedAt':
          firstValidatedAt?.toIso8601String(),
    };
  }

  factory PlayerStampProgress.fromJson(
    Map<String, dynamic> json,
  ) {
    return PlayerStampProgress(
      stampId: _readRequiredString(
        json,
        'stampId',
      ).toLowerCase(),
      bestScore: _readInt(
        json['bestScore'],
        fallback: 0,
      ),
      attempts: _readInt(
        json['attempts'],
        fallback: 0,
      ),
      medal:
          PassportMedalExtension.fromString(
        json['medal']?.toString() ?? '',
      ),
      lastPlayedAt:
          _readOptionalDateTime(
        json['lastPlayedAt'],
      ),
      firstValidatedAt:
          _readOptionalDateTime(
        json['firstValidatedAt'],
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
        'PlayerStampProgress : $key.',
      );
    }

    return value;
  }

  static int _readInt(
    Object? value, {
    required int fallback,
  }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  static DateTime? _readOptionalDateTime(
    Object? value,
  ) {
    final String text =
        value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  @override
  String toString() {
    return 'PlayerStampProgress('
        'stampId: $stampId, '
        'bestScore: $bestScore, '
        'attempts: $attempts, '
        'medal: ${medal.label}'
        ')';
  }
}