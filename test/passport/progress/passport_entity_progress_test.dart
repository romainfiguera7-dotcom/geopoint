import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/passport/progress/passport_entity_progress.dart';
import 'package:geopoint/passport/progress/passport_progress_rules.dart';

void main() {
  group('PassportEntityProgress', () {
    final DateTime firstDate = DateTime.utc(2026, 8, 28, 12);

    test('normalise toujours l’identifiant de l’entité', () {
      final PassportEntityProgress progress =
          PassportEntityProgress.initial(' fra ');

      expect(progress.entityId, 'FRA');
    });

    test('une découverte Atlas ne débloque pas le tampon', () {
      final PassportEntityProgress progress =
          PassportEntityProgress.initial('FRA').markDiscovered(
        source: PassportDiscoverySource.atlas,
        discoveredAt: firstDate,
      );

      expect(progress.learningState, PassportLearningState.discovered);
      expect(progress.stampStage, PassportCountryStampStage.locked);
    });

    test('la première bonne réponse débloque le tampon', () {
      final PassportEntityProgress progress =
          PassportEntityProgress.initial('FRA').registerAnswer(
        theme: PassportKnowledgeTheme.location,
        isCorrect: true,
        masteryLevelAfterAnswer: 1,
        source: PassportDiscoverySource.game,
        answeredAt: firstDate,
      );

      expect(progress.learningState, PassportLearningState.learning);
      expect(progress.stampStage, PassportCountryStampStage.discovered);
      expect(progress.stampUnlockSource, PassportDiscoverySource.game);
    });

    test('le tampon évolue avec la maîtrise de la localisation', () {
      final PassportEntityProgress learned =
          PassportEntityProgress.initial('FRA').registerAnswer(
        theme: PassportKnowledgeTheme.location,
        isCorrect: true,
        masteryLevelAfterAnswer: 3,
        source: PassportDiscoverySource.game,
        answeredAt: firstDate,
      );
      final PassportEntityProgress mastered = learned.registerAnswer(
        theme: PassportKnowledgeTheme.location,
        isCorrect: true,
        masteryLevelAfterAnswer: 5,
        source: PassportDiscoverySource.game,
        answeredAt: firstDate.add(const Duration(days: 1)),
      );

      expect(learned.stampStage, PassportCountryStampStage.learned);
      expect(mastered.stampStage, PassportCountryStampStage.mastered);
      expect(mastered.learningState, PassportLearningState.mastered);
    });

    test('visiter un pays ne modifie jamais sa maîtrise', () {
      final PassportEntityProgress progress =
          PassportEntityProgress.initial('FRA').setVisited(true);

      expect(progress.isVisited, isTrue);
      expect(progress.learningState, PassportLearningState.undiscovered);
      expect(progress.isMastered, isFalse);
      expect(progress.stampStage, PassportCountryStampStage.locked);
    });

    test('visité et à visiter restent mutuellement exclusifs', () {
      final PassportEntityProgress progress =
          PassportEntityProgress.initial('FRA')
              .setWishlisted(true)
              .setVisited(true);

      expect(progress.isVisited, isTrue);
      expect(progress.isWishlisted, isFalse);
    });

    test('la sérialisation conserve tous les états', () {
      final PassportEntityProgress source =
          PassportEntityProgress.initial('FRA')
              .registerAnswer(
                theme: PassportKnowledgeTheme.location,
                isCorrect: true,
                masteryLevelAfterAnswer: 3,
                source: PassportDiscoverySource.expedition,
                answeredAt: firstDate,
              )
              .setFavorite(true)
              .setVisited(true);
      final PassportEntityProgress restored =
          PassportEntityProgress.fromJson(source.toJson());

      expect(restored.entityId, source.entityId);
      expect(restored.learningState, source.learningState);
      expect(restored.stampStage, source.stampStage);
      expect(restored.isFavorite, isTrue);
      expect(restored.isVisited, isTrue);
      expect(restored.isWishlisted, isFalse);
    });
  });
}
