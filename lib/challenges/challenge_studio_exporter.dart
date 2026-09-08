import 'dart:convert';

import 'challenge_definition.dart';
import 'challenge_pack.dart';
import 'challenge_pack_validator.dart';
import 'challenge_studio_draft.dart';

class ChallengeStudioExport {
  const ChallengeStudioExport({
    required this.pack,
    required this.issues,
    required this.json,
  });

  final ChallengePack pack;
  final List<ChallengeValidationIssue> issues;
  final String json;

  bool get isValid => !ChallengePackValidator.hasErrors(issues);
}

class ChallengeStudioExporter {
  const ChallengeStudioExporter._();

  static ChallengeStudioExport build({
    required List<ChallengeStudioDraft> drafts,
    required Set<String> countryIds,
  }) {
    if (drafts.isEmpty) {
      throw const FormatException('Crée au moins un défi avant l’export.');
    }
    final List<ChallengeDefinition> definitions = drafts
        .expand((ChallengeStudioDraft draft) => draft.toDefinitions())
        .toList(growable: false);
    DateTime validFromUtc = definitions.first.validFromUtc;
    DateTime validUntilUtc = definitions.first.validUntilUtc;
    for (final ChallengeDefinition challenge in definitions.skip(1)) {
      if (challenge.validFromUtc.isBefore(validFromUtc)) {
        validFromUtc = challenge.validFromUtc;
      }
      if (challenge.validUntilUtc.isAfter(validUntilUtc)) {
        validUntilUtc = challenge.validUntilUtc;
      }
    }
    final DateTime month = validFromUtc.toUtc();
    final String monthKey =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final ChallengePack pack = ChallengePack(
      schemaVersion: ChallengePack.currentSchemaVersion,
      id: 'studio_pack_${monthKey.replaceAll('-', '_')}',
      title: 'Défis PointGeo $monthKey',
      monthKey: monthKey,
      validFromUtc: validFromUtc,
      validUntilUtc: validUntilUtc,
      challenges: definitions,
    );
    final List<ChallengeValidationIssue> issues =
        ChallengePackValidator.validate(
      pack,
      context: ChallengePackValidationContext(countryIds: countryIds),
    );
    return ChallengeStudioExport(
      pack: pack,
      issues: issues,
      json: const JsonEncoder.withIndent('  ').convert(pack.toJson()),
    );
  }
}
