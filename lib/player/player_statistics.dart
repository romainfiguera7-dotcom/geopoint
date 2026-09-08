class DifficultyStatistics {
  const DifficultyStatistics({
    required this.gamesPlayed,
    required this.questionsPlayed,
    required this.correctAnswers,
    required this.totalScore,
    required this.bestScore,
  });

  final int gamesPlayed;
  final int questionsPlayed;
  final int correctAnswers;
  final int totalScore;
  final int bestScore;

  factory DifficultyStatistics.initial() {
    return const DifficultyStatistics(
      gamesPlayed: 0,
      questionsPlayed: 0,
      correctAnswers: 0,
      totalScore: 0,
      bestScore: 0,
    );
  }

  bool get hasPlayed => gamesPlayed > 0;

  double get averageScore {
    if (gamesPlayed <= 0) {
      return 0;
    }

    return totalScore / gamesPlayed;
  }

  double get accuracy {
    if (questionsPlayed <= 0) {
      return 0;
    }

    return correctAnswers / questionsPlayed;
  }

  DifficultyStatistics registerGame({
    required int score,
    required int correctAnswers,
    required int totalQuestions,
  }) {
    return DifficultyStatistics(
      gamesPlayed: gamesPlayed + 1,
      questionsPlayed: questionsPlayed + totalQuestions,
      correctAnswers: this.correctAnswers + correctAnswers,
      totalScore: totalScore + score,
      bestScore: score > bestScore ? score : bestScore,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'gamesPlayed': gamesPlayed,
      'questionsPlayed': questionsPlayed,
      'correctAnswers': correctAnswers,
      'totalScore': totalScore,
      'bestScore': bestScore,
    };
  }

  factory DifficultyStatistics.fromJson(Map<String, dynamic> json) {
    final int questions = _readNonNegativeInt(json['questionsPlayed']);
    final int correct = _readNonNegativeInt(json['correctAnswers']);

    return DifficultyStatistics(
      gamesPlayed: _readNonNegativeInt(json['gamesPlayed']),
      questionsPlayed: questions,
      correctAnswers: correct > questions ? questions : correct,
      totalScore: _readNonNegativeInt(json['totalScore']),
      bestScore: _readNonNegativeInt(json['bestScore']),
    );
  }
}

class ModeStatistics {
  const ModeStatistics({
    required this.modeId,
    required this.gamesPlayed,
    required this.questionsPlayed,
    required this.correctAnswers,
    required this.totalScore,
    required this.bestScore,
    required this.byDifficulty,
  });

  final String modeId;
  final int gamesPlayed;
  final int questionsPlayed;
  final int correctAnswers;
  final int totalScore;
  final int bestScore;
  final Map<String, DifficultyStatistics> byDifficulty;

  factory ModeStatistics.initial(String modeId) {
    return ModeStatistics(
      modeId: _normalizeId(modeId, fallback: 'find_country'),
      gamesPlayed: 0,
      questionsPlayed: 0,
      correctAnswers: 0,
      totalScore: 0,
      bestScore: 0,
      byDifficulty: const <String, DifficultyStatistics>{},
    );
  }

  bool get hasPlayed => gamesPlayed > 0;

  double get averageScore {
    if (gamesPlayed <= 0) {
      return 0;
    }

    return totalScore / gamesPlayed;
  }

  double get accuracy {
    if (questionsPlayed <= 0) {
      return 0;
    }

    return correctAnswers / questionsPlayed;
  }

  DifficultyStatistics statisticsForDifficulty(String difficultyId) {
    final String normalizedId = _normalizeId(
      difficultyId,
      fallback: 'discovery',
    );

    return byDifficulty[normalizedId] ?? DifficultyStatistics.initial();
  }

  ModeStatistics registerGame({
    required String difficultyId,
    required int score,
    required int correctAnswers,
    required int totalQuestions,
  }) {
    final String normalizedDifficultyId = _normalizeId(
      difficultyId,
      fallback: 'discovery',
    );

    final Map<String, DifficultyStatistics> updatedByDifficulty =
        Map<String, DifficultyStatistics>.from(byDifficulty);

    final DifficultyStatistics current = statisticsForDifficulty(
      normalizedDifficultyId,
    );

    updatedByDifficulty[normalizedDifficultyId] = current.registerGame(
      score: score,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
    );

    return ModeStatistics(
      modeId: modeId,
      gamesPlayed: gamesPlayed + 1,
      questionsPlayed: questionsPlayed + totalQuestions,
      correctAnswers: this.correctAnswers + correctAnswers,
      totalScore: totalScore + score,
      bestScore: score > bestScore ? score : bestScore,
      byDifficulty: Map<String, DifficultyStatistics>.unmodifiable(
        updatedByDifficulty,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'modeId': modeId,
      'gamesPlayed': gamesPlayed,
      'questionsPlayed': questionsPlayed,
      'correctAnswers': correctAnswers,
      'totalScore': totalScore,
      'bestScore': bestScore,
      'byDifficulty': <String, dynamic>{
        for (final MapEntry<String, DifficultyStatistics> entry
            in byDifficulty.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }

  factory ModeStatistics.fromJson(String modeId, Map<String, dynamic> json) {
    final String normalizedModeId = _normalizeId(
      json['modeId']?.toString() ?? modeId,
      fallback: _normalizeId(modeId, fallback: 'find_country'),
    );

    final Map<String, DifficultyStatistics> difficulties =
        <String, DifficultyStatistics>{};

    final Object? rawDifficulties = json['byDifficulty'];

    if (rawDifficulties is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawDifficulties.entries) {
        final String difficultyId = _normalizeId(
          entry.key.toString(),
          fallback: '',
        );

        if (difficultyId.isEmpty || entry.value is! Map) {
          continue;
        }

        final Map<String, dynamic> difficultyJson = (entry.value as Map)
            .map<String, dynamic>((dynamic key, dynamic value) {
              return MapEntry<String, dynamic>(key.toString(), value);
            });

        difficulties[difficultyId] = DifficultyStatistics.fromJson(
          difficultyJson,
        );
      }
    }

    final int questions = _readNonNegativeInt(json['questionsPlayed']);
    final int correct = _readNonNegativeInt(json['correctAnswers']);

    return ModeStatistics(
      modeId: normalizedModeId,
      gamesPlayed: _readNonNegativeInt(json['gamesPlayed']),
      questionsPlayed: questions,
      correctAnswers: correct > questions ? questions : correct,
      totalScore: _readNonNegativeInt(json['totalScore']),
      bestScore: _readNonNegativeInt(json['bestScore']),
      byDifficulty: Map<String, DifficultyStatistics>.unmodifiable(
        difficulties,
      ),
    );
  }
}

/// Résultat minimal d'une question utilisé pour enrichir les statistiques
/// détaillées sans conserver l'historique complet des réponses.
class QuestionStatisticsResult {
  const QuestionStatisticsResult({
    required this.countryId,
    required this.continentId,
    required this.themeId,
    required this.isCorrect,
    required this.elapsedSeconds,
    this.distanceInKilometers,
  });

  final String countryId;
  final String continentId;
  final String themeId;
  final bool isCorrect;
  final int elapsedSeconds;
  final double? distanceInKilometers;
}

/// Compteurs compacts partageables par période, thème et zone géographique.
class PerformanceStatistics {
  const PerformanceStatistics({
    required this.gamesPlayed,
    required this.questionsPlayed,
    required this.correctAnswers,
    required this.totalElapsedSeconds,
    required this.totalDistanceInKilometers,
    required this.answersWithDistance,
    required this.bestDistanceInKilometers,
    required this.placementsUnder10Kilometers,
    required this.placementsUnder50Kilometers,
    required this.currentStreak,
    required this.bestStreak,
  });

  final int gamesPlayed;
  final int questionsPlayed;
  final int correctAnswers;
  final int totalElapsedSeconds;
  final double totalDistanceInKilometers;
  final int answersWithDistance;
  final double? bestDistanceInKilometers;
  final int placementsUnder10Kilometers;
  final int placementsUnder50Kilometers;
  final int currentStreak;
  final int bestStreak;

  factory PerformanceStatistics.initial() {
    return const PerformanceStatistics(
      gamesPlayed: 0,
      questionsPlayed: 0,
      correctAnswers: 0,
      totalElapsedSeconds: 0,
      totalDistanceInKilometers: 0,
      answersWithDistance: 0,
      bestDistanceInKilometers: null,
      placementsUnder10Kilometers: 0,
      placementsUnder50Kilometers: 0,
      currentStreak: 0,
      bestStreak: 0,
    );
  }

  bool get hasAnswers => questionsPlayed > 0;

  double get accuracy {
    return questionsPlayed == 0 ? 0 : correctAnswers / questionsPlayed;
  }

  double get averageDistanceInKilometers {
    return answersWithDistance == 0
        ? 0
        : totalDistanceInKilometers / answersWithDistance;
  }

  Duration get playTime => Duration(seconds: totalElapsedSeconds);

  PerformanceStatistics registerGame() {
    return copyWith(gamesPlayed: gamesPlayed + 1);
  }

  PerformanceStatistics registerQuestion(QuestionStatisticsResult result) {
    final double? distance = result.distanceInKilometers
        ?.clamp(0, double.infinity)
        .toDouble();
    final int streak = result.isCorrect ? currentStreak + 1 : 0;
    final double? bestDistance = distance == null
        ? bestDistanceInKilometers
        : bestDistanceInKilometers == null ||
                distance < bestDistanceInKilometers!
            ? distance
            : bestDistanceInKilometers;

    return PerformanceStatistics(
      gamesPlayed: gamesPlayed,
      questionsPlayed: questionsPlayed + 1,
      correctAnswers: correctAnswers + (result.isCorrect ? 1 : 0),
      totalElapsedSeconds:
          totalElapsedSeconds + result.elapsedSeconds.clamp(0, 86400),
      totalDistanceInKilometers:
          totalDistanceInKilometers + (distance ?? 0),
      answersWithDistance: answersWithDistance + (distance == null ? 0 : 1),
      bestDistanceInKilometers: bestDistance,
      placementsUnder10Kilometers:
          placementsUnder10Kilometers + (distance != null && distance <= 10 ? 1 : 0),
      placementsUnder50Kilometers:
          placementsUnder50Kilometers + (distance != null && distance <= 50 ? 1 : 0),
      currentStreak: streak,
      bestStreak: streak > bestStreak ? streak : bestStreak,
    );
  }

  /// Fusionne des agrégats. Utilisé uniquement pour les vues 7 et 30 jours.
  PerformanceStatistics merge(PerformanceStatistics other) {
    final double? bestDistance = bestDistanceInKilometers == null
        ? other.bestDistanceInKilometers
        : other.bestDistanceInKilometers == null
            ? bestDistanceInKilometers
            : bestDistanceInKilometers! < other.bestDistanceInKilometers!
                ? bestDistanceInKilometers
                : other.bestDistanceInKilometers;

    return PerformanceStatistics(
      gamesPlayed: gamesPlayed + other.gamesPlayed,
      questionsPlayed: questionsPlayed + other.questionsPlayed,
      correctAnswers: correctAnswers + other.correctAnswers,
      totalElapsedSeconds: totalElapsedSeconds + other.totalElapsedSeconds,
      totalDistanceInKilometers:
          totalDistanceInKilometers + other.totalDistanceInKilometers,
      answersWithDistance: answersWithDistance + other.answersWithDistance,
      bestDistanceInKilometers: bestDistance,
      placementsUnder10Kilometers:
          placementsUnder10Kilometers + other.placementsUnder10Kilometers,
      placementsUnder50Kilometers:
          placementsUnder50Kilometers + other.placementsUnder50Kilometers,
      currentStreak: other.questionsPlayed > 0 ? other.currentStreak : currentStreak,
      bestStreak: other.bestStreak > bestStreak ? other.bestStreak : bestStreak,
    );
  }

  PerformanceStatistics copyWith({
    int? gamesPlayed,
    int? questionsPlayed,
    int? correctAnswers,
    int? totalElapsedSeconds,
    double? totalDistanceInKilometers,
    int? answersWithDistance,
    double? bestDistanceInKilometers,
    int? placementsUnder10Kilometers,
    int? placementsUnder50Kilometers,
    int? currentStreak,
    int? bestStreak,
  }) {
    return PerformanceStatistics(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      questionsPlayed: questionsPlayed ?? this.questionsPlayed,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalElapsedSeconds: totalElapsedSeconds ?? this.totalElapsedSeconds,
      totalDistanceInKilometers:
          totalDistanceInKilometers ?? this.totalDistanceInKilometers,
      answersWithDistance: answersWithDistance ?? this.answersWithDistance,
      bestDistanceInKilometers:
          bestDistanceInKilometers ?? this.bestDistanceInKilometers,
      placementsUnder10Kilometers:
          placementsUnder10Kilometers ?? this.placementsUnder10Kilometers,
      placementsUnder50Kilometers:
          placementsUnder50Kilometers ?? this.placementsUnder50Kilometers,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'gamesPlayed': gamesPlayed,
      'questionsPlayed': questionsPlayed,
      'correctAnswers': correctAnswers,
      'totalElapsedSeconds': totalElapsedSeconds,
      'totalDistanceInKilometers': totalDistanceInKilometers,
      'answersWithDistance': answersWithDistance,
      'bestDistanceInKilometers': bestDistanceInKilometers,
      'placementsUnder10Kilometers': placementsUnder10Kilometers,
      'placementsUnder50Kilometers': placementsUnder50Kilometers,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
    };
  }

  factory PerformanceStatistics.fromJson(Map<String, dynamic> json) {
    final int questions = _readNonNegativeInt(json['questionsPlayed']);
    final int correct = _readNonNegativeInt(json['correctAnswers']);
    final int distanceAnswers = _readNonNegativeInt(json['answersWithDistance']);
    final double? bestDistance = _readOptionalNonNegativeDouble(
      json['bestDistanceInKilometers'],
    );
    final int placementsUnder10 = _readNonNegativeInt(
      json['placementsUnder10Kilometers'],
    ).clamp(0, distanceAnswers);
    final int placementsUnder50 = _readNonNegativeInt(
      json['placementsUnder50Kilometers'],
    ).clamp(placementsUnder10, distanceAnswers);

    return PerformanceStatistics(
      gamesPlayed: _readNonNegativeInt(json['gamesPlayed']),
      questionsPlayed: questions,
      correctAnswers: correct > questions ? questions : correct,
      totalElapsedSeconds: _readNonNegativeInt(json['totalElapsedSeconds']),
      totalDistanceInKilometers:
          _readNonNegativeDouble(json['totalDistanceInKilometers']),
      answersWithDistance:
          distanceAnswers > questions ? questions : distanceAnswers,
      bestDistanceInKilometers: bestDistance,
      placementsUnder10Kilometers: placementsUnder10,
      placementsUnder50Kilometers: placementsUnder50,
      currentStreak: _readNonNegativeInt(json['currentStreak']),
      bestStreak: _readNonNegativeInt(json['bestStreak']),
    );
  }
}

/// Statistiques Passeport 2.0. Les cartes restent agrégées afin que la
/// sauvegarde demeure légère, même après plusieurs années d'utilisation.
class DetailedPlayerStatistics {
  const DetailedPlayerStatistics({
    required this.schemaVersion,
    required this.allTime,
    required this.byTheme,
    required this.byContinent,
    required this.byCountry,
    required this.byMode,
    required this.byDifficulty,
    required this.byDay,
  });

  static const int currentSchemaVersion = 2;
  static const int maximumDailyHistory = 400;

  final int schemaVersion;
  final PerformanceStatistics allTime;
  final Map<String, PerformanceStatistics> byTheme;
  final Map<String, PerformanceStatistics> byContinent;
  final Map<String, PerformanceStatistics> byCountry;
  final Map<String, PerformanceStatistics> byMode;
  final Map<String, PerformanceStatistics> byDifficulty;
  final Map<String, PerformanceStatistics> byDay;

  factory DetailedPlayerStatistics.initial() {
    return DetailedPlayerStatistics(
      schemaVersion: currentSchemaVersion,
      allTime: PerformanceStatistics.initial(),
      byTheme: const <String, PerformanceStatistics>{},
      byContinent: const <String, PerformanceStatistics>{},
      byCountry: const <String, PerformanceStatistics>{},
      byMode: const <String, PerformanceStatistics>{},
      byDifficulty: const <String, PerformanceStatistics>{},
      byDay: const <String, PerformanceStatistics>{},
    );
  }

  PerformanceStatistics statisticsForTheme(String themeId) {
    return byTheme[_normalizedKey(themeId, 'location')] ??
        PerformanceStatistics.initial();
  }

  PerformanceStatistics statisticsForContinent(String continentId) {
    return byContinent[_normalizedKey(continentId, 'unknown')] ??
        PerformanceStatistics.initial();
  }

  PerformanceStatistics statisticsForCountry(String countryId) {
    return byCountry[countryId.trim().toUpperCase()] ??
        PerformanceStatistics.initial();
  }

  PerformanceStatistics statisticsForMode(String modeId) {
    return byMode[_normalizedKey(modeId, 'find_country')] ??
        PerformanceStatistics.initial();
  }

  PerformanceStatistics statisticsForDifficulty(String difficultyId) {
    return byDifficulty[_normalizedKey(difficultyId, 'discovery')] ??
        PerformanceStatistics.initial();
  }

  PerformanceStatistics statisticsForRecentDays(
    int days, {
    DateTime? now,
  }) {
    if (days <= 0) {
      return PerformanceStatistics.initial();
    }

    final DateTime today = _dateOnly(now ?? DateTime.now());
    final DateTime firstDay = today.subtract(Duration(days: days - 1));
    final List<MapEntry<String, PerformanceStatistics>> entries = byDay.entries
        .where((MapEntry<String, PerformanceStatistics> entry) {
          final DateTime? date = DateTime.tryParse(entry.key);
          return date != null && !date.isBefore(firstDay) && !date.isAfter(today);
        })
        .toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    PerformanceStatistics result = PerformanceStatistics.initial();
    for (final MapEntry<String, PerformanceStatistics> entry in entries) {
      result = result.merge(entry.value);
    }
    return result;
  }

  DetailedPlayerStatistics registerGame({
    required String modeId,
    required String difficultyId,
    required List<QuestionStatisticsResult> questions,
    DateTime? playedAt,
  }) {
    final String normalizedMode = _normalizedKey(modeId, 'find_country');
    final String normalizedDifficulty = _normalizedKey(
      difficultyId,
      'discovery',
    );
    final String dayKey = _dayKey(playedAt ?? DateTime.now());

    PerformanceStatistics updatedAllTime = allTime.registerGame();
    final Map<String, PerformanceStatistics> updatedThemes =
        Map<String, PerformanceStatistics>.from(byTheme);
    final Map<String, PerformanceStatistics> updatedContinents =
        Map<String, PerformanceStatistics>.from(byContinent);
    final Map<String, PerformanceStatistics> updatedCountries =
        Map<String, PerformanceStatistics>.from(byCountry);
    final Map<String, PerformanceStatistics> updatedModes =
        Map<String, PerformanceStatistics>.from(byMode);
    final Map<String, PerformanceStatistics> updatedDifficulties =
        Map<String, PerformanceStatistics>.from(byDifficulty);
    final Map<String, PerformanceStatistics> updatedDays =
        Map<String, PerformanceStatistics>.from(byDay);

    PerformanceStatistics mode = (updatedModes[normalizedMode] ??
            PerformanceStatistics.initial())
        .registerGame();
    PerformanceStatistics difficulty =
        (updatedDifficulties[normalizedDifficulty] ??
                PerformanceStatistics.initial())
            .registerGame();
    PerformanceStatistics day =
        (updatedDays[dayKey] ?? PerformanceStatistics.initial()).registerGame();

    for (final QuestionStatisticsResult question in questions) {
      updatedAllTime = updatedAllTime.registerQuestion(question);
      mode = mode.registerQuestion(question);
      difficulty = difficulty.registerQuestion(question);
      day = day.registerQuestion(question);

      _registerInMap(updatedThemes, question.themeId, question, 'location');
      _registerInMap(
        updatedContinents,
        question.continentId,
        question,
        'unknown',
      );
      _registerInMap(
        updatedCountries,
        question.countryId.trim().toUpperCase(),
        question,
        'unknown',
        normalizeToLowerCase: false,
      );
    }

    updatedModes[normalizedMode] = mode;
    updatedDifficulties[normalizedDifficulty] = difficulty;
    updatedDays[dayKey] = day;
    _trimDailyHistory(updatedDays);

    return DetailedPlayerStatistics(
      schemaVersion: currentSchemaVersion,
      allTime: updatedAllTime,
      byTheme: Map<String, PerformanceStatistics>.unmodifiable(updatedThemes),
      byContinent:
          Map<String, PerformanceStatistics>.unmodifiable(updatedContinents),
      byCountry:
          Map<String, PerformanceStatistics>.unmodifiable(updatedCountries),
      byMode: Map<String, PerformanceStatistics>.unmodifiable(updatedModes),
      byDifficulty:
          Map<String, PerformanceStatistics>.unmodifiable(updatedDifficulties),
      byDay: Map<String, PerformanceStatistics>.unmodifiable(updatedDays),
    );
  }

  /// Enregistre une question jouée dans un écran autonome (par exemple le
  /// défi Silhouettes), sans la compter comme une partie complète.
  DetailedPlayerStatistics registerStandaloneQuestion({
    required String modeId,
    required String difficultyId,
    required QuestionStatisticsResult question,
    DateTime? answeredAt,
  }) {
    final String normalizedMode = _normalizedKey(modeId, 'find_country');
    final String normalizedDifficulty = _normalizedKey(
      difficultyId,
      'discovery',
    );
    final DateTime resolvedAnsweredAt = answeredAt ?? DateTime.now();
    final String dayKey = _dayKey(resolvedAnsweredAt);
    final int previousModeGames = statisticsForMode(normalizedMode).gamesPlayed;
    final int previousDifficultyGames =
        statisticsForDifficulty(normalizedDifficulty).gamesPlayed;
    final int previousDayGames =
        (byDay[dayKey] ?? PerformanceStatistics.initial()).gamesPlayed;
    final DetailedPlayerStatistics registered = registerGame(
      modeId: normalizedMode,
      difficultyId: normalizedDifficulty,
      questions: <QuestionStatisticsResult>[question],
      playedAt: resolvedAnsweredAt,
    );
    final Map<String, PerformanceStatistics> modes =
        Map<String, PerformanceStatistics>.from(registered.byMode);
    final Map<String, PerformanceStatistics> difficulties =
        Map<String, PerformanceStatistics>.from(registered.byDifficulty);
    final Map<String, PerformanceStatistics> days =
        Map<String, PerformanceStatistics>.from(registered.byDay);

    modes[normalizedMode] = modes[normalizedMode]!.copyWith(
      gamesPlayed: previousModeGames,
    );
    difficulties[normalizedDifficulty] =
        difficulties[normalizedDifficulty]!.copyWith(
      gamesPlayed: previousDifficultyGames,
    );
    days[dayKey] = days[dayKey]!.copyWith(gamesPlayed: previousDayGames);

    return DetailedPlayerStatistics(
      schemaVersion: currentSchemaVersion,
      allTime: registered.allTime.copyWith(gamesPlayed: allTime.gamesPlayed),
      byTheme: registered.byTheme,
      byContinent: registered.byContinent,
      byCountry: registered.byCountry,
      byMode: Map<String, PerformanceStatistics>.unmodifiable(modes),
      byDifficulty:
          Map<String, PerformanceStatistics>.unmodifiable(difficulties),
      byDay: Map<String, PerformanceStatistics>.unmodifiable(days),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'allTime': allTime.toJson(),
      'byTheme': _mapToJson(byTheme),
      'byContinent': _mapToJson(byContinent),
      'byCountry': _mapToJson(byCountry),
      'byMode': _mapToJson(byMode),
      'byDifficulty': _mapToJson(byDifficulty),
      'byDay': _mapToJson(byDay),
    };
  }

  factory DetailedPlayerStatistics.fromJson(Map<String, dynamic> json) {
    return DetailedPlayerStatistics(
      schemaVersion: currentSchemaVersion,
      allTime: _statisticsFromValue(json['allTime']),
      byTheme: _mapFromJson(json['byTheme'], lowerCaseKeys: true),
      byContinent: _mapFromJson(json['byContinent'], lowerCaseKeys: true),
      byCountry: _mapFromJson(json['byCountry'], upperCaseKeys: true),
      byMode: _mapFromJson(json['byMode'], lowerCaseKeys: true),
      byDifficulty: _mapFromJson(json['byDifficulty'], lowerCaseKeys: true),
      byDay: _mapFromJson(json['byDay']),
    );
  }

  static void _registerInMap(
    Map<String, PerformanceStatistics> target,
    String rawKey,
    QuestionStatisticsResult question,
    String fallback, {
    bool normalizeToLowerCase = true,
  }) {
    final String key = normalizeToLowerCase
        ? _normalizedKey(rawKey, fallback)
        : rawKey.trim().isEmpty
            ? fallback
            : rawKey.trim();
    target[key] = (target[key] ?? PerformanceStatistics.initial())
        .registerQuestion(question);
  }

  static void _trimDailyHistory(
    Map<String, PerformanceStatistics> values,
  ) {
    if (values.length <= maximumDailyHistory) {
      return;
    }
    final List<String> keys = values.keys.toList()..sort();
    for (final String key in keys.take(values.length - maximumDailyHistory)) {
      values.remove(key);
    }
  }

  static Map<String, dynamic> _mapToJson(
    Map<String, PerformanceStatistics> values,
  ) {
    return <String, dynamic>{
      for (final MapEntry<String, PerformanceStatistics> entry in values.entries)
        entry.key: entry.value.toJson(),
    };
  }

  static Map<String, PerformanceStatistics> _mapFromJson(
    Object? value, {
    bool lowerCaseKeys = false,
    bool upperCaseKeys = false,
  }) {
    if (value is! Map) {
      return const <String, PerformanceStatistics>{};
    }
    final Map<String, PerformanceStatistics> result =
        <String, PerformanceStatistics>{};
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      String key = entry.key.toString().trim();
      if (lowerCaseKeys) {
        key = key.toLowerCase();
      } else if (upperCaseKeys) {
        key = key.toUpperCase();
      }
      if (key.isEmpty || entry.value is! Map) {
        continue;
      }
      result[key] = _statisticsFromValue(entry.value);
    }
    return Map<String, PerformanceStatistics>.unmodifiable(result);
  }

  static PerformanceStatistics _statisticsFromValue(Object? value) {
    if (value is! Map) {
      return PerformanceStatistics.initial();
    }
    return PerformanceStatistics.fromJson(
      value.map<String, dynamic>((dynamic key, dynamic item) {
        return MapEntry<String, dynamic>(key.toString(), item);
      }),
    );
  }

  static String _normalizedKey(String value, String fallback) {
    final String normalized = value.trim().toLowerCase();
    return normalized.isEmpty ? fallback : normalized;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _dayKey(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

int _readNonNegativeInt(Object? value) {
  final int parsed;

  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else {
    parsed = int.tryParse(value?.toString() ?? '') ?? 0;
  }

  return parsed < 0 ? 0 : parsed;
}

double _readNonNegativeDouble(Object? value) {
  final double parsed;
  if (value is num) {
    parsed = value.toDouble();
  } else {
    parsed = double.tryParse(value?.toString() ?? '') ?? 0;
  }
  return parsed < 0 ? 0 : parsed;
}

double? _readOptionalNonNegativeDouble(Object? value) {
  if (value == null) {
    return null;
  }
  final double? parsed = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());
  if (parsed == null || parsed < 0) {
    return null;
  }
  return parsed;
}

String _normalizeId(String value, {required String fallback}) {
  final String normalized = value.trim().toLowerCase();

  return normalized.isEmpty ? fallback : normalized;
}
