import 'passport_license.dart';
import 'passport_stamp.dart';
import 'player_passport.dart';
import 'player_stamp_progress.dart';

class PassportResult {
  const PassportResult({
    required this.updatedPassport,
    required this.stamp,
    required this.previousProgress,
    required this.updatedProgress,
    required this.previousMedal,
    required this.newMedal,
    required this.score,
    required this.isNewBestScore,
    required this.isFirstAttempt,
    required this.isFirstValidation,
    required this.unlockedLicenses,
  });

  /// Passeport après application du résultat.
  final PlayerPassport updatedPassport;

  /// Tampon concerné par la partie.
  final PassportStamp stamp;

  /// Progression avant la partie.
  final PlayerStampProgress previousProgress;

  /// Progression après la partie.
  final PlayerStampProgress updatedProgress;

  /// Médaille possédée avant la partie.
  final PassportMedal previousMedal;

  /// Médaille possédée après la partie.
  final PassportMedal newMedal;

  /// Score obtenu pendant la partie.
  final int score;

  /// Indique si le joueur vient de battre son record.
  final bool isNewBestScore;

  /// Indique s’il s’agissait de la première tentative
  /// sur ce tampon.
  final bool isFirstAttempt;

  /// Indique si le tampon vient d’être validé
  /// pour la première fois.
  final bool isFirstValidation;

  /// Licences débloquées grâce à cette partie.
  ///
  /// La liste sera généralement vide ou contiendra
  /// une seule licence, mais elle reste extensible.
  final List<PassportLicense> unlockedLicenses;

  bool get hasMedalUpgrade {
    return newMedal.rank >
        previousMedal.rank;
  }

  bool get hasUnlockedLicense {
    return unlockedLicenses.isNotEmpty;
  }

  PassportLicense? get latestUnlockedLicense {
    if (unlockedLicenses.isEmpty) {
      return null;
    }

    return unlockedLicenses.last;
  }

  int get previousBestScore {
    return previousProgress.bestScore;
  }

  int get updatedBestScore {
    return updatedProgress.bestScore;
  }

  int get attempts {
    return updatedProgress.attempts;
  }

  bool get reachedBronze {
    return previousMedal.rank <
            PassportMedal.bronze.rank &&
        newMedal.rank >=
            PassportMedal.bronze.rank;
  }

  bool get reachedSilver {
    return previousMedal.rank <
            PassportMedal.silver.rank &&
        newMedal.rank >=
            PassportMedal.silver.rank;
  }

  bool get reachedGold {
    return previousMedal.rank <
            PassportMedal.gold.rank &&
        newMedal.rank >=
            PassportMedal.gold.rank;
  }

  String get medalUpgradeLabel {
    if (!hasMedalUpgrade) {
      return '';
    }

    return newMedal.label;
  }

  @override
  String toString() {
    return 'PassportResult('
        'stamp: ${stamp.id}, '
        'score: $score, '
        'previousMedal: ${previousMedal.label}, '
        'newMedal: ${newMedal.label}, '
        'isNewBestScore: $isNewBestScore, '
        'unlockedLicenses: '
        '${unlockedLicenses.map(
          (PassportLicense license) =>
              license.id,
        ).toList()}'
        ')';
  }
}