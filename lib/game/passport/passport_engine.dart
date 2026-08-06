import 'passport_license.dart';
import 'passport_result.dart';
import 'passport_stamp.dart';
import 'player_passport.dart';
import 'player_stamp_progress.dart';

class PassportEngine {
  const PassportEngine({
    required this.stamps,
    required this.licenses,
  });

  final Map<String, PassportStamp> stamps;
  final List<PassportLicense> licenses;

  PassportResult registerResult({
    required PlayerPassport passport,
    required String stampId,
    required int score,
    DateTime? playedAt,
  }) {
    final String normalizedStampId =
        stampId.trim().toLowerCase();

    final PassportStamp? stamp =
        stamps[normalizedStampId];

    if (stamp == null) {
      throw ArgumentError(
        'Tampon inconnu : $normalizedStampId.',
      );
    }

    if (!stamp.isEnabled) {
      throw StateError(
        'Le tampon ${stamp.id} est désactivé.',
      );
    }

    if (score < 0) {
      throw ArgumentError(
        'Le score ne peut pas être négatif.',
      );
    }

    final DateTime effectivePlayedAt =
        playedAt ?? DateTime.now();

    final PlayerStampProgress previousProgress =
        passport.progressFor(
      normalizedStampId,
    );

    final PassportMedal previousMedal =
        previousProgress.medal;

    final PlayerStampProgress updatedProgress =
        previousProgress.registerResult(
      stamp: stamp,
      score: score,
      playedAt: effectivePlayedAt,
    );

    PlayerPassport updatedPassport =
        passport.updateStampProgress(
      updatedProgress,
      updatedAt: effectivePlayedAt,
    );

    final List<PassportLicense> unlockedLicenses =
        _findNewlyUnlockedLicenses(
      previousPassport: passport,
      updatedPassport: updatedPassport,
    );

    if (unlockedLicenses.isNotEmpty) {
      final int highestUnlockedLicenseId =
          unlockedLicenses
              .map(
                (PassportLicense license) =>
                    license.id,
              )
              .reduce(
                (
                  int first,
                  int second,
                ) =>
                    first > second
                        ? first
                        : second,
              );

      updatedPassport =
          updatedPassport.unlockLicense(
        highestUnlockedLicenseId,
        updatedAt: effectivePlayedAt,
      );
    }

    final bool isNewBestScore =
        score > previousProgress.bestScore;

    final bool isFirstAttempt =
        previousProgress.attempts == 0;

    final bool isFirstValidation =
        !previousProgress.isValidated &&
            updatedProgress.isValidated;

    return PassportResult(
      updatedPassport: updatedPassport,
      stamp: stamp,
      previousProgress:
          previousProgress,
      updatedProgress:
          updatedProgress,
      previousMedal:
          previousMedal,
      newMedal:
          updatedProgress.medal,
      score: score,
      isNewBestScore:
          isNewBestScore,
      isFirstAttempt:
          isFirstAttempt,
      isFirstValidation:
          isFirstValidation,
      unlockedLicenses:
          List<PassportLicense>.unmodifiable(
        unlockedLicenses,
      ),
    );
  }

  List<PassportLicense>
      _findNewlyUnlockedLicenses({
    required PlayerPassport previousPassport,
    required PlayerPassport updatedPassport,
  }) {
    final List<PassportLicense> unlocked =
        <PassportLicense>[];

    for (final PassportLicense license
        in licenses) {
      if (license.id <=
          previousPassport.currentLicenseId) {
        continue;
      }

      final bool wasAlreadyUnlocked =
          _isLicenseUnlocked(
        passport: previousPassport,
        license: license,
      );

      final bool isNowUnlocked =
          _isLicenseUnlocked(
        passport: updatedPassport,
        license: license,
      );

      if (!wasAlreadyUnlocked &&
          isNowUnlocked) {
        unlocked.add(
          license,
        );
      }
    }

    unlocked.sort(
      (
        PassportLicense first,
        PassportLicense second,
      ) {
        return first.id.compareTo(
          second.id,
        );
      },
    );

    return unlocked;
  }

  bool isLicenseUnlocked({
    required PlayerPassport passport,
    required int licenseId,
  }) {
    final PassportLicense? license =
        licenseById(
      licenseId,
    );

    if (license == null) {
      return false;
    }

    return _isLicenseUnlocked(
      passport: passport,
      license: license,
    );
  }

  bool _isLicenseUnlocked({
    required PlayerPassport passport,
    required PassportLicense license,
  }) {
    if (license.isUnlockedByDefault) {
      return true;
    }

    for (final PassportLicenseRequirement requirement
        in license.requirements) {
      final PlayerStampProgress progress =
          passport.progressFor(
        requirement.stampId,
      );

      if (progress.medal.rank <
          requirement.minimumMedal.rank) {
        return false;
      }
    }

    return true;
  }

  PassportLicense? licenseById(
    int licenseId,
  ) {
    for (final PassportLicense license
        in licenses) {
      if (license.id == licenseId) {
        return license;
      }
    }

    return null;
  }

  PassportStamp? stampById(
    String stampId,
  ) {
    return stamps[
        stampId.trim().toLowerCase()];
  }

  List<PassportLicense>
      unlockedLicensesFor(
    PlayerPassport passport,
  ) {
    final List<PassportLicense> result =
        <PassportLicense>[];

    for (final PassportLicense license
        in licenses) {
      if (_isLicenseUnlocked(
        passport: passport,
        license: license,
      )) {
        result.add(
          license,
        );
      }
    }

    result.sort(
      (
        PassportLicense first,
        PassportLicense second,
      ) {
        return first.id.compareTo(
          second.id,
        );
      },
    );

    return List<PassportLicense>.unmodifiable(
      result,
    );
  }

  PassportLicense? highestUnlockedLicenseFor(
    PlayerPassport passport,
  ) {
    final List<PassportLicense> unlocked =
        unlockedLicensesFor(
      passport,
    );

    if (unlocked.isEmpty) {
      return null;
    }

    return unlocked.last;
  }
}