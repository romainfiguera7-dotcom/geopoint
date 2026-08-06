class CountryMastery {
  const CountryMastery({
    required this.countryId,
    required this.masteryLevel,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.totalAttempts,
    required this.currentStreak,
    required this.bestStreak,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    required this.isWishlisted,
    required this.isVisited,
  });

  static const int minimumMasteryLevel = 0;
  static const int maximumMasteryLevel = 5;

  final String countryId;

  /// Niveau de connaissance :
  /// 0 = jamais appris
  /// 1 = découvert
  /// 2 = fragile
  /// 3 = connu
  /// 4 = bien maîtrisé
  /// 5 = maîtrisé
  final int masteryLevel;

  final int correctAnswers;
  final int wrongAnswers;
  final int totalAttempts;

  final int currentStreak;
  final int bestStreak;

  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  final bool isWishlisted;
  final bool isVisited;

  factory CountryMastery.initial(
    String countryId,
  ) {
    final String normalizedId =
        countryId.trim().toUpperCase();

    if (normalizedId.isEmpty) {
      throw ArgumentError(
        'L’identifiant du pays est obligatoire.',
      );
    }

    return CountryMastery(
      countryId: normalizedId,
      masteryLevel: minimumMasteryLevel,
      correctAnswers: 0,
      wrongAnswers: 0,
      totalAttempts: 0,
      currentStreak: 0,
      bestStreak: 0,
      lastReviewedAt: null,
      nextReviewAt: null,
      isWishlisted: false,
      isVisited: false,
    );
  }

  bool get hasBeenSeen {
    return totalAttempts > 0;
  }

  bool get isMastered {
    return masteryLevel >= maximumMasteryLevel;
  }

  double get accuracy {
    if (totalAttempts <= 0) {
      return 0;
    }

    return correctAnswers / totalAttempts;
  }

  bool get isDueForReview {
    final DateTime? reviewDate =
        nextReviewAt;

    if (reviewDate == null) {
      return true;
    }

    return !reviewDate.isAfter(
      DateTime.now(),
    );
  }

  String get starsLabel {
    final int level =
        masteryLevel.clamp(
      minimumMasteryLevel,
      maximumMasteryLevel,
    );

    return '${'★' * level}'
        '${'☆' * (maximumMasteryLevel - level)}';
  }

  CountryMastery registerAnswer({
    required bool isCorrect,
    DateTime? answeredAt,
  }) {
    final DateTime now =
        answeredAt ?? DateTime.now();

    final int updatedStreak =
        isCorrect
            ? currentStreak + 1
            : 0;

    final int updatedBestStreak =
        updatedStreak > bestStreak
            ? updatedStreak
            : bestStreak;

    final int updatedMasteryLevel =
        _calculateUpdatedMasteryLevel(
      isCorrect: isCorrect,
      updatedStreak: updatedStreak,
    );

    return copyWith(
      masteryLevel:
          updatedMasteryLevel,
      correctAnswers:
          correctAnswers +
              (isCorrect ? 1 : 0),
      wrongAnswers:
          wrongAnswers +
              (isCorrect ? 0 : 1),
      totalAttempts:
          totalAttempts + 1,
      currentStreak:
          updatedStreak,
      bestStreak:
          updatedBestStreak,
      lastReviewedAt:
          now,
      nextReviewAt:
          _calculateNextReviewAt(
        masteryLevel:
            updatedMasteryLevel,
        isCorrect:
            isCorrect,
        reviewedAt:
            now,
      ),
    );
  }

  int _calculateUpdatedMasteryLevel({
    required bool isCorrect,
    required int updatedStreak,
  }) {
    if (!isCorrect) {
      return (
        masteryLevel - 1
      ).clamp(
        minimumMasteryLevel,
        maximumMasteryLevel,
      );
    }

    /*
     * Une seule bonne réponse ne suffit pas
     * toujours à monter de niveau.
     *
     * Plus le pays est maîtrisé, plus il faut
     * une série solide pour progresser.
     */
    final int requiredStreak;

    switch (masteryLevel) {
      case 0:
        requiredStreak = 1;
      case 1:
        requiredStreak = 2;
      case 2:
        requiredStreak = 2;
      case 3:
        requiredStreak = 3;
      case 4:
        requiredStreak = 3;
      default:
        return maximumMasteryLevel;
    }

    if (updatedStreak < requiredStreak) {
      return masteryLevel;
    }

    return (
      masteryLevel + 1
    ).clamp(
      minimumMasteryLevel,
      maximumMasteryLevel,
    );
  }

  static DateTime _calculateNextReviewAt({
    required int masteryLevel,
    required bool isCorrect,
    required DateTime reviewedAt,
  }) {
    if (!isCorrect) {
      return reviewedAt.add(
        const Duration(hours: 6),
      );
    }

    final Duration delay;

    switch (masteryLevel) {
      case 0:
      case 1:
        delay = const Duration(days: 1);

      case 2:
        delay = const Duration(days: 3);

      case 3:
        delay = const Duration(days: 7);

      case 4:
        delay = const Duration(days: 21);

      case 5:
        delay = const Duration(days: 45);

      default:
        delay = const Duration(days: 1);
    }

    return reviewedAt.add(delay);
  }

  CountryMastery toggleWishlist() {
    return copyWith(
      isWishlisted: !isWishlisted,
    );
  }

  CountryMastery markVisited(
    bool visited,
  ) {
    return copyWith(
      isVisited: visited,
      isWishlisted:
          visited
              ? false
              : isWishlisted,
    );
  }

  CountryMastery copyWith({
    String? countryId,
    int? masteryLevel,
    int? correctAnswers,
    int? wrongAnswers,
    int? totalAttempts,
    int? currentStreak,
    int? bestStreak,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    bool? isWishlisted,
    bool? isVisited,
    bool clearLastReviewedAt = false,
    bool clearNextReviewAt = false,
  }) {
    return CountryMastery(
      countryId:
          countryId ??
              this.countryId,
      masteryLevel:
          masteryLevel ??
              this.masteryLevel,
      correctAnswers:
          correctAnswers ??
              this.correctAnswers,
      wrongAnswers:
          wrongAnswers ??
              this.wrongAnswers,
      totalAttempts:
          totalAttempts ??
              this.totalAttempts,
      currentStreak:
          currentStreak ??
              this.currentStreak,
      bestStreak:
          bestStreak ??
              this.bestStreak,
      lastReviewedAt:
          clearLastReviewedAt
              ? null
              : lastReviewedAt ??
                  this.lastReviewedAt,
      nextReviewAt:
          clearNextReviewAt
              ? null
              : nextReviewAt ??
                  this.nextReviewAt,
      isWishlisted:
          isWishlisted ??
              this.isWishlisted,
      isVisited:
          isVisited ??
              this.isVisited,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'countryId': countryId,
      'masteryLevel': masteryLevel,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'totalAttempts': totalAttempts,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lastReviewedAt':
          lastReviewedAt?.toIso8601String(),
      'nextReviewAt':
          nextReviewAt?.toIso8601String(),
      'isWishlisted': isWishlisted,
      'isVisited': isVisited,
    };
  }

  factory CountryMastery.fromJson(
    Map<String, dynamic> json,
  ) {
    final String countryId =
        json['countryId']
                ?.toString()
                .trim()
                .toUpperCase() ??
            '';

    if (countryId.isEmpty) {
      throw const FormatException(
        'countryId absent dans CountryMastery.',
      );
    }

    return CountryMastery(
      countryId: countryId,
      masteryLevel: _readInt(
        json['masteryLevel'],
        fallback: 0,
      ).clamp(
        minimumMasteryLevel,
        maximumMasteryLevel,
      ),
      correctAnswers: _readInt(
        json['correctAnswers'],
        fallback: 0,
      ),
      wrongAnswers: _readInt(
        json['wrongAnswers'],
        fallback: 0,
      ),
      totalAttempts: _readInt(
        json['totalAttempts'],
        fallback: 0,
      ),
      currentStreak: _readInt(
        json['currentStreak'],
        fallback: 0,
      ),
      bestStreak: _readInt(
        json['bestStreak'],
        fallback: 0,
      ),
      lastReviewedAt:
          _readOptionalDateTime(
        json['lastReviewedAt'],
      ),
      nextReviewAt:
          _readOptionalDateTime(
        json['nextReviewAt'],
      ),
      isWishlisted: _readBool(
        json['isWishlisted'],
        fallback: false,
      ),
      isVisited: _readBool(
        json['isVisited'],
        fallback: false,
      ),
    );
  }

  static int _readInt(
    Object? value, {
    required int fallback,
  }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  static bool _readBool(
    Object? value, {
    required bool fallback,
  }) {
    if (value is bool) {
      return value;
    }

    final String text =
        value
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    if (text == 'true') {
      return true;
    }

    if (text == 'false') {
      return false;
    }

    return fallback;
  }

  static DateTime? _readOptionalDateTime(
    Object? value,
  ) {
    final String text =
        value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  @override
  String toString() {
    return 'CountryMastery('
        'countryId: $countryId, '
        'masteryLevel: $masteryLevel, '
        'accuracy: $accuracy, '
        'isDueForReview: $isDueForReview, '
        'isWishlisted: $isWishlisted, '
        'isVisited: $isVisited'
        ')';
  }
}