import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/features/atlas/atlas_personal_progress.dart';
import 'package:geopoint/game/passport/player_passport.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';
import 'package:geopoint/passport/progress/passport_progress_migrator.dart';
import 'package:geopoint/passport/progress/passport_progress_rules.dart';
import 'package:geopoint/player/player_profile.dart';

void main() {
  test('le Passeport reçoit les thèmes GeoBrain sans les mélanger', () {
    final DateTime now = DateTime.utc(2026, 8, 29, 21);
    GeoBrainProfile geoBrain = GeoBrainProfile.initial(createdAt: now);
    geoBrain = geoBrain.registerAttempt(
      GeoBrainAttempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.capital,
        answeredAt: now,
        modeId: 'find_capital',
        difficultyId: 'hard',
        isCorrect: true,
        context: GeoBrainAttemptContext.expedition,
      ),
    );
    geoBrain = geoBrain.registerAttempt(
      GeoBrainAttempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.flag,
        answeredAt: now.add(const Duration(minutes: 1)),
        modeId: 'find_flag',
        difficultyId: 'hard',
        isCorrect: false,
        context: GeoBrainAttemptContext.expedition,
      ),
    );

    final progress = PassportProgressMigrator.fromLegacy(
      passport: PlayerPassport.initial(createdAt: now),
      playerProfile: PlayerProfile.initial(createdAt: now),
      geoBrainProfile: geoBrain,
      atlasProgress: AtlasPersonalProgress.initial(),
      migratedAt: now.add(const Duration(minutes: 2)),
    );
    final entity = progress.progressFor('FRA');

    expect(entity.locationProgress.totalAttempts, 0);
    expect(
      entity.progressFor(PassportKnowledgeTheme.capital).totalAttempts,
      1,
    );
    expect(
      entity.progressFor(PassportKnowledgeTheme.flag).totalAttempts,
      1,
    );
    expect(
      entity.progressFor(PassportKnowledgeTheme.capital).correctAnswers,
      1,
    );
    expect(
      entity.progressFor(PassportKnowledgeTheme.flag).wrongAnswers,
      1,
    );
  });
}
