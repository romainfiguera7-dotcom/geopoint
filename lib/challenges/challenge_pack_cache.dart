import 'challenge_pack.dart';

class ChallengePackCache {
  const ChallengePackCache({
    required this.revision,
    required this.fetchedAtUtc,
    required this.pack,
  });

  static const int currentSchemaVersion = 1;

  final int revision;
  final DateTime fetchedAtUtc;
  final ChallengePack pack;

  factory ChallengePackCache.fromJson(Map<String, dynamic> json) {
    final Object? rawPack = json['pack'];
    if (rawPack is! Map) {
      throw const FormatException('Le cache ne contient aucun pack valide.');
    }
    final int? revision = json['revision'] is int
        ? json['revision'] as int
        : int.tryParse('${json['revision']}');
    final DateTime? fetchedAtUtc =
        DateTime.tryParse('${json['fetchedAtUtc']}')?.toUtc();
    if (revision == null || revision <= 0 || fetchedAtUtc == null) {
      throw const FormatException('Les métadonnées du cache sont invalides.');
    }
    return ChallengePackCache(
      revision: revision,
      fetchedAtUtc: fetchedAtUtc,
      pack: ChallengePack.fromJson(
        rawPack.map<String, dynamic>(
          (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'revision': revision,
      'fetchedAtUtc': fetchedAtUtc.toUtc().toIso8601String(),
      'pack': pack.toJson(),
    };
  }
}
