import '../geo_engine/geo_entity_id.dart';
import 'geobrain_theme.dart';

enum GeoBrainAttemptContext {
  classicGame('game'),
  training('training'),
  expedition('expedition'),
  challenge('challenge'),
  tutorial('tutorial'),
  childMode('child_mode'),
  unknown('unknown');

  const GeoBrainAttemptContext(this.id);

  final String id;

  static GeoBrainAttemptContext fromId(String value) {
    final String normalized = value.trim().toLowerCase();
    for (final GeoBrainAttemptContext context in values) {
      if (context.id == normalized) {
        return context;
      }
    }
    return GeoBrainAttemptContext.unknown;
  }
}

class GeoBrainAttempt {
  const GeoBrainAttempt({
    required this.countryId,
    required this.theme,
    required this.answeredAt,
    required this.modeId,
    required this.difficultyId,
    required this.isCorrect,
    required this.context,
    this.distanceInKilometers,
    this.responseTimeMilliseconds,
    this.helpId,
    this.proposedAnswerId,
  });

  final String countryId;
  final GeoBrainTheme theme;
  final DateTime answeredAt;
  final String modeId;
  final String difficultyId;
  final bool isCorrect;
  final double? distanceInKilometers;
  final int? responseTimeMilliseconds;
  final String? helpId;
  final String? proposedAnswerId;
  final GeoBrainAttemptContext context;

  bool get usedHelp => helpId != null && helpId!.trim().isNotEmpty;

  Duration? get responseTime {
    final int? milliseconds = responseTimeMilliseconds;
    return milliseconds == null ? null : Duration(milliseconds: milliseconds);
  }

  GeoBrainAttempt normalized() {
    return GeoBrainAttempt(
      countryId: GeoEntityId.require(countryId),
      theme: theme,
      answeredAt: answeredAt,
      modeId: _normalizedRequiredId(modeId, fallback: theme.id),
      difficultyId: _normalizedRequiredId(
        difficultyId,
        fallback: 'unknown',
      ),
      isCorrect: isCorrect,
      distanceInKilometers: _normalizedDistance(distanceInKilometers),
      responseTimeMilliseconds: responseTimeMilliseconds?.clamp(0, 1 << 31),
      helpId: _normalizedOptionalId(helpId),
      proposedAnswerId: _normalizedOptionalAnswer(proposedAnswerId),
      context: context,
    );
  }

  Map<String, dynamic> toJson() {
    final GeoBrainAttempt value = normalized();
    return <String, dynamic>{
      'countryId': value.countryId,
      'theme': value.theme.id,
      'answeredAt': value.answeredAt.toIso8601String(),
      'modeId': value.modeId,
      'difficultyId': value.difficultyId,
      'isCorrect': value.isCorrect,
      'distanceInKilometers': value.distanceInKilometers,
      'responseTimeMilliseconds': value.responseTimeMilliseconds,
      'helpId': value.helpId,
      'proposedAnswerId': value.proposedAnswerId,
      'context': value.context.id,
    };
  }

  factory GeoBrainAttempt.fromJson(Map<String, dynamic> json) {
    final String countryId = GeoEntityId.normalize(
      json['countryId']?.toString() ?? '',
    );
    final GeoBrainTheme? theme = GeoBrainTheme.fromId(
      json['theme']?.toString() ?? '',
    );
    final DateTime? answeredAt = DateTime.tryParse(
      json['answeredAt']?.toString() ?? '',
    );
    if (countryId.isEmpty || theme == null || answeredAt == null) {
      throw const FormatException('Tentative GeoBrain incomplète.');
    }

    return GeoBrainAttempt(
      countryId: countryId,
      theme: theme,
      answeredAt: answeredAt,
      modeId: _normalizedRequiredId(
        json['modeId']?.toString() ?? '',
        fallback: theme.id,
      ),
      difficultyId: _normalizedRequiredId(
        json['difficultyId']?.toString() ?? '',
        fallback: 'unknown',
      ),
      isCorrect: _readBool(json['isCorrect']),
      distanceInKilometers: _normalizedDistance(
        _readOptionalDouble(json['distanceInKilometers']),
      ),
      responseTimeMilliseconds:
          _readOptionalInt(json['responseTimeMilliseconds'])?.clamp(0, 1 << 31),
      helpId: _normalizedOptionalId(json['helpId']?.toString()),
      proposedAnswerId: _normalizedOptionalAnswer(
        json['proposedAnswerId']?.toString(),
      ),
      context: GeoBrainAttemptContext.fromId(
        json['context']?.toString() ?? '',
      ),
    );
  }

  static String _normalizedRequiredId(
    String value, {
    required String fallback,
  }) {
    final String normalized = value.trim().toLowerCase();
    return normalized.isEmpty ? fallback : normalized;
  }

  static String? _normalizedOptionalId(String? value) {
    final String normalized = value?.trim().toLowerCase() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static String? _normalizedOptionalAnswer(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static double? _normalizedDistance(double? value) {
    if (value == null || !value.isFinite || value < 0) {
      return null;
    }
    return value;
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    return value?.toString().trim().toLowerCase() == 'true';
  }

  static int? _readOptionalInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _readOptionalDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}
