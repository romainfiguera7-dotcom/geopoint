import 'challenge_definition.dart';

class ChallengePack {
  const ChallengePack({
    required this.schemaVersion,
    required this.id,
    required this.title,
    required this.monthKey,
    required this.validFromUtc,
    required this.validUntilUtc,
    required this.challenges,
    this.disabledChallengeIds = const <String>{},
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String title;
  final String monthKey;
  final DateTime validFromUtc;
  final DateTime validUntilUtc;
  final List<ChallengeDefinition> challenges;

  /// Coupe immédiatement un défi sans supprimer sa configuration.
  final Set<String> disabledChallengeIds;

  bool isActiveAt(DateTime now) {
    final DateTime utcNow = now.toUtc();
    return !utcNow.isBefore(validFromUtc) && utcNow.isBefore(validUntilUtc);
  }

  List<ChallengeDefinition> activeChallengesAt(DateTime now) {
    final bool timedChallengesAreActive = isActiveAt(now);
    return challenges
        .where(
          (ChallengeDefinition challenge) =>
              !disabledChallengeIds.contains(challenge.id) &&
              (challenge.period == ChallengePeriod.permanent ||
                  (timedChallengesAreActive && challenge.isActiveAt(now))),
        )
        .toList(growable: false);
  }

  ChallengeDefinition? challengeById(String challengeId) {
    final String normalizedId = challengeId.trim();
    for (final ChallengeDefinition challenge in challenges) {
      if (challenge.id == normalizedId) {
        return challenge;
      }
    }
    return null;
  }

  factory ChallengePack.fromJson(Map<String, dynamic> json) {
    final Object? rawChallenges = json['challenges'];
    if (rawChallenges is! List) {
      throw const FormatException(
        'Le pack de défis doit contenir une liste challenges.',
      );
    }

    final List<ChallengeDefinition> challenges = <ChallengeDefinition>[];
    for (final Object? rawChallenge in rawChallenges) {
      if (rawChallenge is! Map) {
        throw const FormatException(
          'Chaque défi du pack doit être un objet JSON.',
        );
      }
      challenges.add(
        ChallengeDefinition.fromJson(
          rawChallenge.map<String, dynamic>(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          ),
        ),
      );
    }

    return ChallengePack(
      schemaVersion: _readPositiveInt(
        json['schemaVersion'],
        field: 'schemaVersion',
      ),
      id: _readRequiredString(json['id'], field: 'id'),
      title: _readRequiredString(json['title'], field: 'title'),
      monthKey: _readRequiredString(json['monthKey'], field: 'monthKey'),
      validFromUtc: _readDateTime(
        json['validFromUtc'],
        field: 'validFromUtc',
      ),
      validUntilUtc: _readDateTime(
        json['validUntilUtc'],
        field: 'validUntilUtc',
      ),
      challenges: List<ChallengeDefinition>.unmodifiable(challenges),
      disabledChallengeIds: Set<String>.unmodifiable(
        _readStringList(json['disabledChallengeIds']).toSet(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final List<String> disabledIds = disabledChallengeIds.toList()..sort();
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'id': id,
      'title': title,
      'monthKey': monthKey,
      'validFromUtc': validFromUtc.toUtc().toIso8601String(),
      'validUntilUtc': validUntilUtc.toUtc().toIso8601String(),
      'disabledChallengeIds': disabledIds,
      'challenges': challenges
          .map((ChallengeDefinition challenge) => challenge.toJson())
          .toList(growable: false),
    };
  }
}

String _readRequiredString(Object? value, {required String field}) {
  final String result = value?.toString().trim() ?? '';
  if (result.isEmpty) {
    throw FormatException('Le champ $field est obligatoire.');
  }
  return result;
}

int _readPositiveInt(Object? value, {required String field}) {
  final int? result = value is int
      ? value
      : int.tryParse(value?.toString() ?? '');
  if (result == null || result <= 0) {
    throw FormatException('Le champ $field doit être un entier positif.');
  }
  return result;
}

DateTime _readDateTime(Object? value, {required String field}) {
  final DateTime? result = DateTime.tryParse(value?.toString() ?? '');
  if (result == null) {
    throw FormatException('Le champ $field doit être une date ISO 8601.');
  }
  return result.toUtc();
}

List<String> _readStringList(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is! List) {
    throw const FormatException('Une liste de textes était attendue.');
  }
  return value
      .map((Object? item) => item?.toString().trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}
