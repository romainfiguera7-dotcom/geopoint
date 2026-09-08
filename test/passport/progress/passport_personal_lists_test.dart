import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/features/atlas/atlas_personal_progress.dart';
import 'package:geopoint/passport/progress/passport_entity_progress.dart';
import 'package:geopoint/passport/progress/passport_progress_rules.dart';

void main() {
  group('Listes personnelles du Passeport', () {
    test('visité et à visiter restent mutuellement exclusifs', () {
      final AtlasPersonalProgress progress = AtlasPersonalProgress.initial()
          .toggleWishlist('FRA')
          .toggleVisited('FRA');

      expect(progress.visitedCountryIds, contains('FRA'));
      expect(progress.wishlistCountryIds, isNot(contains('FRA')));
    });

    test('un favori peut aussi être visité sans modifier son statut', () {
      final AtlasPersonalProgress progress = AtlasPersonalProgress.initial()
          .toggleFavorite('FRA')
          .toggleVisited('FRA');

      expect(progress.isFavorite('FRA'), isTrue);
      expect(progress.statusFor('FRA'), AtlasCountryStatus.visited);

      final AtlasPersonalProgress restored =
          AtlasPersonalProgress.fromJson(progress.toJson());

      expect(restored.isFavorite('FRA'), isTrue);
      expect(restored.statusFor('FRA'), AtlasCountryStatus.visited);
    });

    test('un voyage ne crée aucune maîtrise GeoBrain', () {
      final PassportEntityProgress progress =
          PassportEntityProgress.initial('FRA')
              .setFavorite(true)
              .setVisited(true);

      expect(progress.isVisited, isTrue);
      expect(progress.isFavorite, isTrue);
      expect(progress.isMastered, isFalse);
      expect(progress.learningState, PassportLearningState.undiscovered);
      expect(progress.locationProgress.totalAttempts, 0);
    });
  });
}
