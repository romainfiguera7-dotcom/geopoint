import 'challenge_definition.dart';
import 'challenge_pack.dart';

enum ChallengeValidationSeverity {
  error,
  warning,
}

class ChallengeValidationIssue {
  const ChallengeValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.challengeId,
  });

  final ChallengeValidationSeverity severity;
  final String code;
  final String message;
  final String? challengeId;

  bool get isError => severity == ChallengeValidationSeverity.error;
}

class ChallengePackValidationContext {
  const ChallengePackValidationContext({
    required this.countryIds,
    this.continentIds = const <String>{
      'world',
      'africa',
      'americas',
      'asia',
      'europe',
      'oceania',
      'polar',
    },
    this.modeIds = const <String>{
      'find_country',
      'find_capital',
      'find_flag',
      'ultimate',
      'mixed',
    },
    this.difficultyIds = const <String>{
      'discovery',
      'easy',
      'intermediate',
      'hard',
      'expert',
    },
  });

  final Set<String> countryIds;
  final Set<String> continentIds;
  final Set<String> modeIds;
  final Set<String> difficultyIds;
}

class ChallengePackValidator {
  const ChallengePackValidator._();

  static List<ChallengeValidationIssue> validate(
    ChallengePack pack, {
    required ChallengePackValidationContext context,
  }) {
    final List<ChallengeValidationIssue> issues = <ChallengeValidationIssue>[];

    if (pack.schemaVersion != ChallengePack.currentSchemaVersion) {
      issues.add(
        ChallengeValidationIssue(
          severity: ChallengeValidationSeverity.error,
          code: 'unsupported_schema',
          message: 'Version de pack ${pack.schemaVersion} non prise en charge.',
        ),
      );
    }
    if (!pack.validFromUtc.isBefore(pack.validUntilUtc)) {
      issues.add(
        const ChallengeValidationIssue(
          severity: ChallengeValidationSeverity.error,
          code: 'invalid_pack_dates',
          message: 'La date de fin du pack doit suivre sa date de début.',
        ),
      );
    }
    if (!_isMonthKey(pack.monthKey)) {
      issues.add(
        const ChallengeValidationIssue(
          severity: ChallengeValidationSeverity.error,
          code: 'invalid_month_key',
          message: 'monthKey doit utiliser le format AAAA-MM.',
        ),
      );
    }
    if (pack.challenges.isEmpty) {
      issues.add(
        const ChallengeValidationIssue(
          severity: ChallengeValidationSeverity.error,
          code: 'empty_pack',
          message: 'Le pack doit contenir au moins un défi.',
        ),
      );
    }

    final Set<String> ids = <String>{};
    final Map<String, ChallengeDefinition> rankedReferences =
        <String, ChallengeDefinition>{};

    for (final ChallengeDefinition challenge in pack.challenges) {
      if (!ids.add(challenge.id)) {
        issues.add(
          _error(
            challenge,
            'duplicate_id',
            'L’identifiant ${challenge.id} est utilisé plusieurs fois.',
          ),
        );
      }
      if (challenge.validFromUtc.isBefore(pack.validFromUtc) ||
          challenge.validUntilUtc.isAfter(pack.validUntilUtc)) {
        issues.add(
          _error(
            challenge,
            'challenge_outside_pack',
            'La période du défi dépasse celle du pack.',
          ),
        );
      }
      if (!challenge.validFromUtc.isBefore(challenge.validUntilUtc)) {
        issues.add(
          _error(
            challenge,
            'invalid_challenge_dates',
            'La date de fin doit suivre la date de début.',
          ),
        );
      }
      if (!context.modeIds.contains(challenge.modeId)) {
        issues.add(
          _error(
            challenge,
            'unknown_mode',
            'Mode inconnu : ${challenge.modeId}.',
          ),
        );
      }
      if (!context.difficultyIds.contains(challenge.difficultyId)) {
        issues.add(
          _error(
            challenge,
            'unknown_difficulty',
            'Difficulté inconnue : ${challenge.difficultyId}.',
          ),
        );
      }
      if (challenge.continentId != null &&
          !context.continentIds.contains(challenge.continentId)) {
        issues.add(
          _error(
            challenge,
            'unknown_continent',
            'Continent inconnu : ${challenge.continentId}.',
          ),
        );
      }
      for (final String countryId in challenge.countryIds) {
        if (!context.countryIds.contains(countryId)) {
          issues.add(
            _error(
              challenge,
              'unknown_country',
              'Pays inconnu : $countryId.',
            ),
          );
        }
      }
      if (challenge.continentId == null && challenge.countryIds.isEmpty) {
        issues.add(
          _error(
            challenge,
            'missing_geographic_scope',
            'Définir un continent ou une sélection de pays.',
          ),
        );
      }
      if (challenge.countryIds.toSet().length != challenge.countryIds.length) {
        issues.add(
          _error(
            challenge,
            'duplicate_country',
            'Un pays est présent plusieurs fois dans la sélection.',
          ),
        );
      }

      final bool hasQuestionCount = challenge.questionCount != null;
      final bool hasDuration = challenge.durationSeconds != null;
      if (hasQuestionCount == hasDuration) {
        issues.add(
          _error(
            challenge,
            'invalid_length_rule',
            'Définir soit questionCount, soit durationSeconds, jamais les deux.',
          ),
        );
      }
      if ((challenge.questionCount ?? 1) <= 0 ||
          (challenge.durationSeconds ?? 1) <= 0) {
        issues.add(
          _error(
            challenge,
            'non_positive_length',
            'Le nombre de questions ou la durée doit être positif.',
          ),
        );
      }
      if (challenge.successCondition.minimumCorrectAnswers < 0 ||
          challenge.successCondition.minimumScore < 0 ||
          (challenge.successCondition.maximumAverageDistanceKilometers ?? 0) <
              0) {
        issues.add(
          _error(
            challenge,
            'invalid_success_condition',
            'Les conditions de réussite ne peuvent pas être négatives.',
          ),
        );
      }
      if (challenge.questionCount != null &&
          challenge.successCondition.minimumCorrectAnswers >
              challenge.questionCount!) {
        issues.add(
          _error(
            challenge,
            'impossible_success_condition',
            'Le minimum de bonnes réponses dépasse le nombre de questions.',
          ),
        );
      }
      if (challenge.retryPolicy.maximumAttempts <= 0 ||
          challenge.retryPolicy.diamondRetryCost < 0 ||
          challenge.retryPolicy.maximumDiamondRetries < 0 ||
          challenge.retryPolicy.maximumRewardedAdvertisementRetries < 0) {
        issues.add(
          _error(
            challenge,
            'invalid_retry_policy',
            'La règle de relance contient une valeur invalide.',
          ),
        );
      }
      if (!challenge.retryPolicy.rewardedAdvertisementAllowed &&
          (challenge.retryPolicy.maximumRewardedAdvertisementRetries > 0 ||
              challenge.retryPolicy
                  .unlimitedRewardedAdvertisementRetries)) {
        issues.add(
          _error(
            challenge,
            'advertisement_retry_inconsistent',
            'Une relance publicitaire est comptée alors que la publicité est désactivée.',
          ),
        );
      }
      if (challenge.retryPolicy.rewardedAdvertisementAllowed &&
          !challenge.retryPolicy.unlimitedRewardedAdvertisementRetries &&
          challenge.retryPolicy.maximumRewardedAdvertisementRetries == 0) {
        issues.add(
          _error(
            challenge,
            'advertisement_retry_missing_limit',
            'La publicité est activée sans limite finie ni règle illimitée.',
          ),
        );
      }
      if (challenge.audience == ChallengeAudience.child &&
          (challenge.retryPolicy.rewardedAdvertisementAllowed ||
              challenge.retryPolicy
                  .unlimitedRewardedAdvertisementRetries ||
              challenge.retryPolicy.childAdvertisementsAllowed)) {
        issues.add(
          _error(
            challenge,
            'child_advertisement_forbidden',
            'La publicité récompensée est désactivée dans les défis enfant.',
          ),
        );
      }
      if (challenge.audience == ChallengeAudience.child &&
          challenge.isRanked) {
        issues.add(
          _error(
            challenge,
            'ranked_child_variant_forbidden',
            'La variante enfant utilise un défi personnel non classé.',
          ),
        );
      }
      if (challenge.audience == ChallengeAudience.beginner &&
          challenge.isRanked) {
        issues.add(
          _error(
            challenge,
            'ranked_beginner_variant_forbidden',
            'La variante débutant utilise un défi personnel non classé.',
          ),
        );
      }
      if (challenge.reward.xp < 0 ||
          challenge.reward.coins < 0 ||
          challenge.reward.diamonds < 0 ||
          challenge.reward.progressionPoints < 0) {
        issues.add(
          _error(
            challenge,
            'negative_reward',
            'Une récompense ne peut pas être négative.',
          ),
        );
      }
      if (challenge.reward.isEmpty) {
        issues.add(
          _warning(
            challenge,
            'empty_reward',
            'Le défi ne distribue aucune récompense.',
          ),
        );
      }
      if (challenge.reward.diamonds > 5) {
        issues.add(
          _warning(
            challenge,
            'high_diamond_reward',
            'La récompense de diamants dépasse le plafond conseillé de 5.',
          ),
        );
      }
      if (challenge.minimumPlayerLevel <= 0) {
        issues.add(
          _error(
            challenge,
            'invalid_minimum_level',
            'Le niveau minimum doit être positif.',
          ),
        );
      }
      if (challenge.isRanked && challenge.geoBrainPersonalizationAllowed) {
        issues.add(
          _error(
            challenge,
            'ranked_geobrain_forbidden',
            'GeoBrain ne peut pas personnaliser un défi classé.',
          ),
        );
      }
      if (challenge.rankingGroupId != null) {
        final ChallengeDefinition? reference =
            rankedReferences[challenge.rankingGroupId!];
        if (reference == null) {
          rankedReferences[challenge.rankingGroupId!] = challenge;
        } else if (reference.competitiveSignature !=
            challenge.competitiveSignature) {
          issues.add(
            _error(
              challenge,
              'unequal_ranked_rules',
              'Deux défis du même classement n’utilisent pas les mêmes règles.',
            ),
          );
        }
      }
    }

    for (final String disabledId in pack.disabledChallengeIds) {
      if (!ids.contains(disabledId)) {
        issues.add(
          ChallengeValidationIssue(
            severity: ChallengeValidationSeverity.error,
            code: 'unknown_disabled_challenge',
            message: 'Le défi désactivé $disabledId n’existe pas dans le pack.',
          ),
        );
      }
    }

    for (final ChallengeDefinition challenge in pack.challenges) {
      final String? beginnerVariantId = challenge.beginnerVariantId;
      if (beginnerVariantId != null) {
        final ChallengeDefinition? beginner =
            pack.challengeById(beginnerVariantId);
        if (beginner == null) {
          issues.add(
            _error(
              challenge,
              'missing_beginner_variant',
              'La variante débutant $beginnerVariantId est introuvable.',
            ),
          );
        } else if (beginner.audience != ChallengeAudience.beginner) {
          issues.add(
            _error(
              challenge,
              'invalid_beginner_variant',
              'La variante $beginnerVariantId doit cibler les débutants.',
            ),
          );
        } else if (beginner.validFromUtc != challenge.validFromUtc ||
            beginner.validUntilUtc != challenge.validUntilUtc) {
          issues.add(
            _error(
              challenge,
              'beginner_variant_period_mismatch',
              'La variante débutant doit utiliser la même période.',
            ),
          );
        }
      }

      final String? childVariantId = challenge.childVariantId;
      if (childVariantId == null) {
        continue;
      }
      final ChallengeDefinition? variant = pack.challengeById(childVariantId);
      if (variant == null) {
        issues.add(
          _error(
            challenge,
            'missing_child_variant',
            'La variante enfant $childVariantId est introuvable.',
          ),
        );
      } else if (variant.audience != ChallengeAudience.child) {
        issues.add(
          _error(
            challenge,
            'invalid_child_variant',
            'La variante $childVariantId doit cibler le public enfant.',
          ),
        );
      } else if (variant.validFromUtc != challenge.validFromUtc ||
          variant.validUntilUtc != challenge.validUntilUtc) {
        issues.add(
          _error(
            challenge,
            'child_variant_period_mismatch',
            'La variante enfant doit utiliser la même période de validité.',
          ),
        );
      }
    }

    return List<ChallengeValidationIssue>.unmodifiable(issues);
  }

  static bool hasErrors(Iterable<ChallengeValidationIssue> issues) {
    return issues.any((ChallengeValidationIssue issue) => issue.isError);
  }

  static ChallengeValidationIssue _error(
    ChallengeDefinition challenge,
    String code,
    String message,
  ) {
    return ChallengeValidationIssue(
      severity: ChallengeValidationSeverity.error,
      code: code,
      message: message,
      challengeId: challenge.id,
    );
  }

  static ChallengeValidationIssue _warning(
    ChallengeDefinition challenge,
    String code,
    String message,
  ) {
    return ChallengeValidationIssue(
      severity: ChallengeValidationSeverity.warning,
      code: code,
      message: message,
      challengeId: challenge.id,
    );
  }

  static bool _isMonthKey(String value) {
    return RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value);
  }

}
