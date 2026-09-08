import 'dart:convert';

import 'package:flutter/services.dart';

import 'challenge_pack.dart';

class ChallengePackLoader {
  const ChallengePackLoader._();

  static const String defaultAssetPath =
      'assets/data/challenge_pack_2026_09.json';

  static Future<ChallengePack> load({
    String assetPath = defaultAssetPath,
  }) async {
    final String source = await rootBundle.loadString(assetPath);
    return decode(source, sourceName: assetPath);
  }

  static ChallengePack decode(
    String source, {
    String sourceName = 'pack de défis',
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('$sourceName contient un JSON invalide : $error');
    }

    if (decoded is! Map) {
      throw FormatException('$sourceName doit contenir un objet JSON.');
    }

    final Map<String, dynamic> packJson = decoded.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );

    return ChallengePack.fromJson(_expandConfiguration(packJson));
  }

  /// Déplie la configuration éditoriale compacte d'un pack mensuel.
  ///
  /// Un pack peut contenir des défis complets dans `challenges`, mais aussi
  /// des `templates` réutilisés par une liste `schedule`. Cette deuxième forme
  /// évite de recopier les mêmes règles trente fois pour les défis quotidiens.
  static Map<String, dynamic> _expandConfiguration(
    Map<String, dynamic> source,
  ) {
    final Map<String, Map<String, dynamic>> templates =
        <String, Map<String, dynamic>>{};
    final Object? rawTemplates = source['templates'];
    if (rawTemplates != null && rawTemplates is! List) {
      throw const FormatException(
        'Le champ templates doit contenir une liste.',
      );
    }
    if (rawTemplates is List) {
      for (final Object? rawTemplate in rawTemplates) {
        final Map<String, dynamic> template = _readMap(
          rawTemplate,
          field: 'templates',
        );
        final String templateId =
            template['templateId']?.toString().trim() ?? '';
        if (templateId.isEmpty) {
          throw const FormatException(
            'Chaque modèle de défi doit avoir un templateId.',
          );
        }
        if (templates.containsKey(templateId)) {
          throw FormatException(
            'Le modèle de défi $templateId est défini plusieurs fois.',
          );
        }
        templates[templateId] = template;
      }
    }

    final List<Map<String, dynamic>> expanded = <Map<String, dynamic>>[];
    final Object? rawChallenges = source['challenges'];
    if (rawChallenges != null && rawChallenges is! List) {
      throw const FormatException(
        'Le champ challenges doit contenir une liste.',
      );
    }
    if (rawChallenges is List) {
      for (final Object? rawChallenge in rawChallenges) {
        final Map<String, dynamic> challenge =
            _readMap(rawChallenge, field: 'challenges');
        expanded.add(_applyAutomaticRanking(challenge));
      }
    }

    final Object? rawSchedule = source['schedule'];
    if (rawSchedule != null && rawSchedule is! List) {
      throw const FormatException(
        'Le champ schedule doit contenir une liste.',
      );
    }
    if (rawSchedule is List) {
      for (final Object? rawEntry in rawSchedule) {
        final Map<String, dynamic> entry = _readMap(
          rawEntry,
          field: 'schedule',
        );
        final String challengeId = entry['id']?.toString().trim() ?? '';
        final String templateId =
            entry['templateId']?.toString().trim() ?? '';
        if (challengeId.isEmpty || templateId.isEmpty) {
          throw const FormatException(
            'Chaque entrée schedule doit avoir un id et un templateId.',
          );
        }
        final Map<String, dynamic>? template = templates[templateId];
        if (template == null) {
          throw FormatException(
            'Le modèle de défi $templateId est introuvable.',
          );
        }

        final Map<String, dynamic> challenge = _deepMerge(template, entry)
          ..remove('templateId');
        _applyAutomaticRanking(challenge);
        final String childTemplateId =
            challenge.remove('childVariantTemplateId')?.toString().trim() ??
                '';
        final String beginnerTemplateId = challenge
                .remove('beginnerVariantTemplateId')
                ?.toString()
                .trim() ??
            '';

        if (childTemplateId.isNotEmpty) {
          final Map<String, dynamic>? childTemplate =
              templates[childTemplateId];
          if (childTemplate == null) {
            throw FormatException(
              'Le modèle enfant $childTemplateId est introuvable.',
            );
          }
          final String childId = '${challengeId}__child';
          challenge['childVariantId'] = childId;

          final Map<String, dynamic> child = _deepMerge(
            childTemplate,
            <String, dynamic>{
              'id': childId,
              'validFromUtc': challenge['validFromUtc'],
              'validUntilUtc': challenge['validUntilUtc'],
              'modeId': challenge['modeId'],
              if (challenge.containsKey('continentId'))
                'continentId': challenge['continentId'],
              if (challenge.containsKey('countryIds'))
                'countryIds': challenge['countryIds'],
            },
          )
            ..remove('templateId')
            ..remove('childVariantTemplateId')
            ..remove('childVariantId')
            ..remove('rankingGroupId')
            ..['audience'] = 'child'
            ..['geoBrainPersonalizationAllowed'] = false;
          expanded.add(child);
        }

        if (beginnerTemplateId.isNotEmpty &&
            challenge['minimumPlayerLevel'] != 1) {
          final Map<String, dynamic>? beginnerTemplate =
              templates[beginnerTemplateId];
          if (beginnerTemplate == null) {
            throw FormatException(
              'Le modèle débutant $beginnerTemplateId est introuvable.',
            );
          }
          final String beginnerId = '${challengeId}__beginner';
          challenge['beginnerVariantId'] = beginnerId;

          final Map<String, dynamic> beginner = _deepMerge(
            beginnerTemplate,
            <String, dynamic>{
              'id': beginnerId,
              'validFromUtc': challenge['validFromUtc'],
              'validUntilUtc': challenge['validUntilUtc'],
              'modeId': challenge['modeId'],
              if (challenge.containsKey('continentId'))
                'continentId': challenge['continentId'],
              if (challenge.containsKey('countryIds'))
                'countryIds': challenge['countryIds'],
              'retryPolicy': <String, dynamic>{
                'maximumAttempts': 1,
                'unlimitedFreeAttempts': false,
                'diamondRetryCost': 0,
                'maximumDiamondRetries': 0,
                'rewardedAdvertisementAllowed': true,
                'maximumRewardedAdvertisementRetries': 0,
                'unlimitedRewardedAdvertisementRetries': true,
                'childAdvertisementsAllowed': false,
              },
            },
          )
            ..remove('templateId')
            ..remove('childVariantTemplateId')
            ..remove('beginnerVariantTemplateId')
            ..remove('childVariantId')
            ..remove('beginnerVariantId')
            ..remove('rankingGroupId')
            ..['audience'] = 'beginner'
            ..['geoBrainPersonalizationAllowed'] = false;
          expanded.add(beginner);
        }

        expanded.add(challenge);
      }
    }

    return <String, dynamic>{
      ...source,
      'challenges': expanded,
    };
  }

  static Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> overrides,
  ) {
    final Map<String, dynamic> result = <String, dynamic>{...base};
    for (final MapEntry<String, dynamic> entry in overrides.entries) {
      final Object? previous = result[entry.key];
      final Object? next = entry.value;
      if (previous is Map && next is Map) {
        result[entry.key] = _deepMerge(
          _readMap(previous, field: entry.key),
          _readMap(next, field: entry.key),
        );
      } else {
        result[entry.key] = next;
      }
    }
    return result;
  }

  static Map<String, dynamic> _applyAutomaticRanking(
    Map<String, dynamic> challenge,
  ) {
    final String audience =
        challenge['audience']?.toString().trim().toLowerCase() ?? 'standard';
    if (audience != 'standard') {
      return challenge;
    }
    final String challengeId = challenge['id']?.toString().trim() ?? '';
    if (challengeId.isNotEmpty) {
      challenge['rankingGroupId'] = challengeId;
    }
    challenge['minimumPlayerLevel'] = 1;
    challenge['geoBrainPersonalizationAllowed'] = false;
    return challenge;
  }

  static Map<String, dynamic> _readMap(
    Object? value, {
    required String field,
  }) {
    if (value is! Map) {
      throw FormatException('Le champ $field doit contenir des objets JSON.');
    }
    return value.map<String, dynamic>(
      (dynamic key, dynamic item) =>
          MapEntry<String, dynamic>(key.toString(), item),
    );
  }
}
