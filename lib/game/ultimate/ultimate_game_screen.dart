import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../challenges/challenge_result.dart';
import '../../features/atlas/atlas_personal_progress.dart';
import '../../features/atlas/atlas_personal_storage.dart';
import '../../features/settings/gameplay_feedback.dart';
import '../../features/passport/passport_country_stamp_view.dart';
import '../../features/passport/passport_major_level_up_overlay.dart';
import '../../features/passport/passport_progress_notification_overlay.dart';
import '../../geo_engine/country_info.dart';
import '../../geo_engine/country_info_loader.dart';
import '../../geo_engine/geo_country.dart';
import '../../geo_engine/geopoint_map.dart';
import '../../passport/achievements/passport_achievement.dart';
import '../../passport/achievements/passport_achievement_catalog.dart';
import '../../passport/achievements/passport_achievement_progress.dart';
import '../../passport/achievements/passport_achievement_snapshot_builder.dart';
import '../../passport/achievements/passport_achievement_storage.dart';
import '../../passport/collections/passport_collection_item.dart';
import '../../passport/notifications/passport_progress_notification.dart';
import '../../passport/progress/passport_entity_progress.dart';
import '../../passport/progress/passport_progress_v2.dart';
import '../../passport/progression/passport_major_level_up.dart';
import '../../passport/settings/passport_display_preferences.dart';
import '../../passport/settings/passport_display_preferences_storage.dart';
import '../../player/player_profile.dart';
import '../continent/continent_progress.dart';
import '../continent/continent_storage.dart';
import '../expedition/expedition_progress.dart';
import '../expedition/expedition_storage.dart';
import '../game_controller.dart';
import 'country_silhouette.dart';
import 'ultimate_question.dart';
import 'ultimate_question_generator.dart';

typedef UltimateAnswerCallback = Future<PassportEntityProgress?> Function({
  required String countryId,
  required bool isCorrect,
  required int elapsedSeconds,
  required String difficultyId,
  String? proposedAnswerId,
});

class UltimateGameResult {
  const UltimateGameResult({
    required this.earnedStars,
    required this.totalScore,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.totalElapsedSeconds,
    this.answerEvidence = const <ChallengeAnswerEvidence>[],
  });

  final int earnedStars;
  final int totalScore;
  final int correctAnswers;
  final int totalQuestions;
  final int totalElapsedSeconds;
  final List<ChallengeAnswerEvidence> answerEvidence;
}

class UltimateGameScreen extends StatefulWidget {
  const UltimateGameScreen({
    required this.controller,
    required this.availableCountries,
    required this.countryDifficulties,
    required this.difficultyId,
    required this.previousBestScore,
    this.onAnswer,
    this.missionTitle = 'Défi Silhouettes',
    this.questionCount,
    this.randomSeed,
    this.returnButtonLabel = 'RETOUR À L’EXPÉDITION',
    super.key,
  });

  final GameController controller;
  final List<GeoCountry> availableCountries;
  final Map<String, int> countryDifficulties;
  final String difficultyId;
  final int previousBestScore;
  final UltimateAnswerCallback? onAnswer;
  final String missionTitle;
  final int? questionCount;
  final int? randomSeed;
  final String returnButtonLabel;

  @override
  State<UltimateGameScreen> createState() {
    return _UltimateGameScreenState();
  }
}

class _UltimateGameScreenState extends State<UltimateGameScreen> {
  late final UltimateQuestionGenerator _questionGenerator;

  Timer? _timer;
  Timer? _stampUnlockOverlayTimer;

  UltimateQuestion? _currentQuestion;

  int _questionNumber = 0;
  int _totalScore = 0;
  int _correctAnswers = 0;
  int _secondsRemaining = 15;
  int _totalElapsedSeconds = 0;
  final List<ChallengeAnswerEvidence> _answerEvidence =
      <ChallengeAnswerEvidence>[];

  bool _hasAnswered = false;
  bool _isTimeUp = false;
  bool _showGameOver = false;
  bool _isResultPanelCollapsed = false;

  String? _selectedCountryId;
  LatLng? _currentAnswerPoint;

  Map<String, CountryInfo> _countryInfos =
      const <String, CountryInfo>{};
  GeoCountry? _stampUnlockCountry;
  PassportEntityProgress? _stampUnlockProgress;
  bool _stampAnimationsEnabled = true;
  bool _majorLevelAnimationsEnabled = true;
  AtlasPersonalProgress _atlasProgress = AtlasPersonalProgress.initial();
  bool _savingPersonalProgress = false;
  bool _finishingGame = false;
  late final PassportProgressV2 _progressAtGameStart;
  late final PlayerProfile _profileAtGameStart;
  late final int _licenseIdAtGameStart;
  ExpeditionProgress _expeditionAtGameStart = ExpeditionProgress.initial();
  ContinentProgress _continentAtGameStart = ContinentProgress.initial();
  PassportAchievementProgress _achievementsAtGameStart =
      PassportAchievementProgress.initial();
  Future<void>? _notificationBaselineFuture;
  PassportProgressNotificationBatch? _progressNotificationBatch;
  PassportMajorLevelUp? _majorLevelUp;

  int get _totalQuestions {
    final int? requestedCount = widget.questionCount;
    if (requestedCount != null) {
      return requestedCount.clamp(1, 50);
    }
    switch (widget.difficultyId) {
      case 'discovery':
        return 10;

      case 'easy':
        return 12;

      case 'intermediate':
        return 15;

      case 'hard':
        return 18;

      case 'expert':
        return 20;

      default:
        return 10;
    }
  }

  int get _questionDurationSeconds {
    switch (widget.difficultyId) {
      case 'discovery':
        return 18;

      case 'easy':
        return 16;

      case 'intermediate':
        return 14;

      case 'hard':
        return 12;

      case 'expert':
        return 10;

      default:
        return 15;
    }
  }

  @override
  void initState() {
    super.initState();

    _questionGenerator = UltimateQuestionGenerator(
      random: widget.randomSeed == null
          ? null
          : math.Random(widget.randomSeed),
    );
    _progressAtGameStart = widget.controller.passportProgress;
    _profileAtGameStart = widget.controller.playerProfile;
    _licenseIdAtGameStart = widget.controller.passport.currentLicenseId;
    _notificationBaselineFuture = _loadProgressNotificationBaseline();

    unawaited(_loadCountryInfos());
    unawaited(_loadPassportDisplayPreferences());
    unawaited(_loadAtlasProgress());
    _startNextQuestion();
  }

  Future<void> _loadProgressNotificationBaseline() async {
    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      PassportAchievementStorage.load(),
      ExpeditionStorage.load(),
      ContinentStorage.load(),
    ]);
    _expeditionAtGameStart = values[1] as ExpeditionProgress;
    _continentAtGameStart = values[2] as ContinentProgress;
    final PassportAchievementSnapshot snapshot =
        PassportAchievementSnapshotBuilder.build(
      progress: _progressAtGameStart,
      profile: _profileAtGameStart,
      countries: widget.controller.countries,
      expeditionProgress: _expeditionAtGameStart,
      continentProgress: _continentAtGameStart,
    );
    final PassportAchievementProgress loaded =
        (values[0] as PassportAchievementProgress).mergeCompletedTierDates(
      _progressAtGameStart.completedAchievementTierDates,
    );
    _achievementsAtGameStart = loaded.synchronize(snapshot: snapshot);
    await widget.controller.ensureAchievementXpBaseline(
      _achievementsAtGameStart.completedAtByTierId.keys,
    );
    if (!identical(loaded, _achievementsAtGameStart)) {
      await widget.controller.synchronizePassportAchievementProgress(
        _achievementsAtGameStart,
      );
    }
  }

  Future<void> _loadAtlasProgress() async {
    final AtlasPersonalProgress progress = await AtlasPersonalStorage.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _atlasProgress = progress;
    });
  }

  Future<void> _saveAtlasProgress(AtlasPersonalProgress next) async {
    if (_savingPersonalProgress) {
      return;
    }

    setState(() {
      _savingPersonalProgress = true;
    });

    final bool saved = await AtlasPersonalStorage.save(next);

    if (saved) {
      await widget.controller.synchronizePassportPersonalProgress(next);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (saved) {
        _atlasProgress = next;
      }
      _savingPersonalProgress = false;
    });

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de sauvegarder ce pays pour le moment.'),
        ),
      );
    }
  }

  Future<void> _loadPassportDisplayPreferences() async {
    try {
      final PassportDisplayPreferences preferences =
          await PassportDisplayPreferencesStorage.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _stampAnimationsEnabled = preferences.stampAnimationsEnabled;
        _majorLevelAnimationsEnabled =
            preferences.majorLevelAnimationsEnabled;
      });
    } on Object catch (_) {
      // Une préférence illisible ne doit jamais bloquer une expédition.
    }
  }

  Future<void> _registerPassportAnswer({
    required GeoCountry country,
    required bool isCorrect,
    String? proposedAnswerId,
  }) async {
    final UltimateAnswerCallback? onAnswer = widget.onAnswer;

    if (onAnswer == null) {
      return;
    }

    try {
      final PassportEntityProgress? unlockedProgress = await onAnswer(
        countryId: country.id,
        isCorrect: isCorrect,
        elapsedSeconds: _questionDurationSeconds - _secondsRemaining,
        difficultyId: widget.difficultyId,
        proposedAnswerId: proposedAnswerId,
      );

      if (!mounted ||
          unlockedProgress == null ||
          !_stampAnimationsEnabled) {
        return;
      }

      _stampUnlockOverlayTimer?.cancel();
      setState(() {
        _stampUnlockCountry = country;
        _stampUnlockProgress = unlockedProgress;
      });
      _stampUnlockOverlayTimer = Timer(
        const Duration(milliseconds: 2400),
        () {
          if (!mounted || _stampUnlockCountry?.id != country.id) {
            return;
          }

          setState(() {
            _stampUnlockCountry = null;
            _stampUnlockProgress = null;
          });
        },
      );
    } on Object catch (_) {
      // La progression ne doit jamais interrompre la partie en cours.
    }
  }

  Future<void> _loadCountryInfos() async {
    try {
      final Map<String, CountryInfo> countryInfos =
          await CountryInfoLoader.loadCountryInfos();

      if (!mounted) {
        return;
      }

      setState(() {
        _countryInfos = countryInfos;
      });
    } on Object catch (error) {
      debugPrint(
        'GeoPoint : chargement des fiches pays '
        'impossible dans le défi Silhouettes : $error',
      );
    }
  }

  CountryInfo? _countryInfoFor(GeoCountry country) {
    final String countryId =
        country.id.trim().toUpperCase();

    if (countryId.isEmpty) {
      return null;
    }

    return _countryInfos[countryId];
  }

  PassportCollectionSnapshot _collectionSnapshot({
    required PassportProgressV2 progress,
    required PlayerProfile profile,
    required PassportAchievementSnapshot achievementSnapshot,
    required int licenseId,
  }) {
    return PassportCollectionSnapshot(
      playerLevel: profile.currentLevel,
      discoveredEntities: progress.discoveredEntityCount,
      masteredEntities: progress.masteredEntityCount,
      countryStamps: progress.unlockedCountryStampCount,
      visitedEntities: progress.visitedEntityCount,
      gamesPlayed: profile.gamesPlayed,
      questionsPlayed: profile.totalAnswers,
      expeditionStars: achievementSnapshot.valueFor(
        PassportAchievementMetric.expeditionStars,
      ),
      completedExpeditionLevels: achievementSnapshot.valueFor(
        PassportAchievementMetric.completedExpeditionLevels,
      ),
      currentLicenseId: licenseId,
      explicitlyUnlockedItemIds: progress.unlockedCollectionItemIds,
    );
  }

  Future<void> _finishGame() async {
    if (_finishingGame) {
      return;
    }
    _finishingGame = true;

    PassportProgressNotificationBatch? notificationBatch;
    PassportMajorLevelUp? majorLevelUp;
    try {
      await _notificationBaselineFuture;
      await widget.controller.waitForPassportProgressSynchronization();
      final PassportProgressV2 progressBeforeRewards =
          widget.controller.passportProgress;
      PlayerProfile currentProfile = widget.controller.playerProfile;
      final PassportAchievementSnapshot beforeSnapshot =
          PassportAchievementSnapshotBuilder.build(
        progress: _progressAtGameStart,
        profile: _profileAtGameStart,
        countries: widget.controller.countries,
        expeditionProgress: _expeditionAtGameStart,
        continentProgress: _continentAtGameStart,
      );
      final PassportAchievementSnapshot afterSnapshot =
          PassportAchievementSnapshotBuilder.build(
        progress: progressBeforeRewards,
        profile: currentProfile,
        countries: widget.controller.countries,
        expeditionProgress: _expeditionAtGameStart,
        continentProgress: _continentAtGameStart,
      );
      final PassportAchievementProgress updatedAchievements =
          _achievementsAtGameStart.synchronize(snapshot: afterSnapshot);

      final Set<String> newTierIds = updatedAchievements
          .newlyCompletedTierIdsComparedWith(_achievementsAtGameStart);
      await widget.controller.registerAchievementCompletions(
        tierIds: newTierIds,
        combineWithCurrentGame: false,
      );
      currentProfile = widget.controller.playerProfile;

      if (!identical(_achievementsAtGameStart, updatedAchievements)) {
        await widget.controller.synchronizePassportAchievementProgress(
          updatedAchievements,
        );
      }
      final Map<String, PassportAchievementTier> tiersById =
          <String, PassportAchievementTier>{
        for (final PassportAchievementTier tier
            in PassportAchievementCatalog.allTiers())
          tier.id.toLowerCase(): tier,
      };
      for (final String tierId in newTierIds) {
        final String? rewardItemId = tiersById[tierId]?.rewardItemId;
        if (rewardItemId != null) {
          await widget.controller.unlockPassportCollectionItem(rewardItemId);
        }
      }
      await widget.controller.waitForPassportProgressSynchronization();

      final PassportProgressV2 currentProgress =
          widget.controller.passportProgress;
      final PassportProgressNotificationBatch prepared =
          PassportProgressNotificationBuilder.build(
        beforeProgress: _progressAtGameStart,
        afterProgress: currentProgress,
        beforeProfile: _profileAtGameStart,
        afterProfile: currentProfile,
        beforeCollections: _collectionSnapshot(
          progress: _progressAtGameStart,
          profile: _profileAtGameStart,
          achievementSnapshot: beforeSnapshot,
          licenseId: _licenseIdAtGameStart,
        ),
        afterCollections: _collectionSnapshot(
          progress: currentProgress,
          profile: currentProfile,
          achievementSnapshot: afterSnapshot,
          licenseId: widget.controller.passport.currentLicenseId,
        ),
        beforeAchievements: _achievementsAtGameStart,
        afterAchievements: updatedAchievements,
        countries: widget.controller.countries,
      );
      if (prepared.isNotEmpty) {
        notificationBatch = prepared;
      }
      majorLevelUp = PassportMajorLevelUp.between(
        beforeProfile: _profileAtGameStart,
        afterProfile: currentProfile,
      );
    } on Object catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : notifications Silhouettes impossibles : $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _showGameOver = true;
      _progressNotificationBatch = notificationBatch;
      _majorLevelUp = majorLevelUp;
    });
  }

  void _startNextQuestion() {
    _stopTimer();

    if (_questionNumber >= _totalQuestions) {
      unawaited(_finishGame());

      return;
    }

    final UltimateQuestion? question = _questionGenerator.createQuestion(
      availableCountries: widget.availableCountries,
      countryDifficulties: widget.countryDifficulties,
    );

    if (question == null) {
      unawaited(_finishGame());

      return;
    }

    setState(() {
      _currentQuestion = question;
      _currentAnswerPoint =
          _representativePointFor(question.answerCountry);
      _questionNumber++;
      _secondsRemaining = _questionDurationSeconds;
      _hasAnswered = false;
      _isTimeUp = false;
      _isResultPanelCollapsed = false;
      _selectedCountryId = null;
    });

    _startTimer();
  }

  void _startTimer() {
    _stopTimer();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted || _hasAnswered || _showGameOver) {
        _stopTimer();
        return;
      }

      if (_secondsRemaining <= 1) {
        _handleTimeout();
        return;
      }

      setState(() {
        _secondsRemaining--;
      });
    });
  }

  void _handleTimeout() {
    if (_hasAnswered) {
      return;
    }

    _stopTimer();

    setState(() {
      _totalElapsedSeconds += _questionDurationSeconds;
      _secondsRemaining = 0;
      _hasAnswered = true;
      _isTimeUp = true;
      _selectedCountryId = null;
      _answerEvidence.add(
        ChallengeAnswerEvidence(
          modeId: 'ultimate',
          isCorrect: false,
          elapsedSeconds: _questionDurationSeconds,
        ),
      );
    });

    GameplayFeedback.answer(isCorrect: false);

    final UltimateQuestion? question = _currentQuestion;

    if (question != null) {
      unawaited(
        _registerPassportAnswer(
          country: question.answerCountry,
          isCorrect: false,
        ),
      );
    }
  }

  void _submitChoice(GeoCountry country) {
    final UltimateQuestion? question = _currentQuestion;

    if (question == null || _hasAnswered) {
      return;
    }

    _stopTimer();

    final bool isCorrect = question.isCorrectChoice(country.id);

    final int earnedScore = isCorrect ? 100 + _calculateTimeBonus() : 0;
    final int elapsedSeconds =
        _questionDurationSeconds - _secondsRemaining;

    setState(() {
      _selectedCountryId = country.id;
      _hasAnswered = true;
      _isTimeUp = false;
      _totalScore += earnedScore;
      _totalElapsedSeconds += elapsedSeconds;

      if (isCorrect) {
        _correctAnswers++;
      }
      _answerEvidence.add(
        ChallengeAnswerEvidence(
          modeId: 'ultimate',
          isCorrect: isCorrect,
          elapsedSeconds: elapsedSeconds,
        ),
      );
    });

    GameplayFeedback.answer(isCorrect: isCorrect);

    unawaited(
      _registerPassportAnswer(
        country: question.answerCountry,
        isCorrect: isCorrect,
        proposedAnswerId: country.id,
      ),
    );
  }

  int _calculateTimeBonus() {
    final int elapsedSeconds = _questionDurationSeconds - _secondsRemaining;

    if (elapsedSeconds <= 3) {
      return 20;
    }

    if (elapsedSeconds <= 5) {
      return 15;
    }

    if (elapsedSeconds <= 8) {
      return 10;
    }

    if (elapsedSeconds <= 11) {
      return 5;
    }

    return 0;
  }

  bool _isSelected(GeoCountry country) {
    return _selectedCountryId?.trim().toUpperCase() ==
        country.id.trim().toUpperCase();
  }

  bool _isCorrectChoice(GeoCountry country) {
    return _currentQuestion?.isCorrectChoice(country.id) ?? false;
  }

  Color _choiceColor(GeoCountry country) {
    if (!_hasAnswered) {
      return Colors.white.withValues(alpha: 0.09);
    }

    if (_isCorrectChoice(country)) {
      return const Color(0xFF28B67A).withValues(alpha: 0.45);
    }

    if (_isSelected(country)) {
      return const Color(0xFFFF5C5C).withValues(alpha: 0.40);
    }

    return Colors.white.withValues(alpha: 0.05);
  }

  Color _choiceBorderColor(GeoCountry country) {
    if (!_hasAnswered) {
      return Colors.white.withValues(alpha: 0.18);
    }

    if (_isCorrectChoice(country)) {
      return const Color(0xFF80ED99);
    }

    if (_isSelected(country)) {
      return const Color(0xFFFF5C5C);
    }

    return Colors.white.withValues(alpha: 0.12);
  }

  String _resultTitle() {
    if (_isTimeUp) {
      return 'Temps écoulé !';
    }

    final UltimateQuestion? question = _currentQuestion;

    if (question == null) {
      return '';
    }

    final String selectedId = _selectedCountryId ?? '';

    return question.isCorrectChoice(selectedId)
        ? 'Bonne réponse !'
        : 'Mauvaise réponse';
  }

  Color _resultColor() {
    if (_isTimeUp) {
      return const Color(0xFFFFD166);
    }

    final UltimateQuestion? question = _currentQuestion;

    final String selectedId = _selectedCountryId ?? '';

    if (question != null && question.isCorrectChoice(selectedId)) {
      return const Color(0xFF80ED99);
    }

    return const Color(0xFFFF5C5C);
  }

  int _calculateEarnedStars() {
    final int maximumScore = _totalQuestions * 120;

    if (maximumScore <= 0) {
      return 0;
    }

    final double ratio = _totalScore / maximumScore;

    if (ratio >= 0.85) {
      return 3;
    }

    if (ratio >= 0.65) {
      return 2;
    }

    if (ratio >= 0.40) {
      return 1;
    }

    return 0;
  }

  String _starText(int stars) {
    final int normalized = stars.clamp(0, 3);

    return '${'★' * normalized}'
        '${'☆' * (3 - normalized)}';
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  LatLng _representativePointFor(GeoCountry country) {
    final List<List<LatLng>> polygons = country.polygons
        .where((List<LatLng> polygon) => polygon.length >= 3)
        .toList(growable: false);

    if (polygons.isEmpty) {
      return LatLng(
        (country.bounds.minLatitude +
                country.bounds.maxLatitude) /
            2,
        (country.bounds.minLongitude +
                country.bounds.maxLongitude) /
            2,
      );
    }

    final List<LatLng> polygon = polygons.reduce(
      (List<LatLng> first, List<LatLng> second) {
        return _polygonArea(first) >= _polygonArea(second)
            ? first
            : second;
      },
    );

    final LatLng? centroid = _polygonCentroid(polygon);

    if (centroid != null &&
        _pointIsInsidePolygon(centroid, polygon)) {
      return centroid;
    }

    double minLatitude = double.infinity;
    double maxLatitude = double.negativeInfinity;
    double minLongitude = double.infinity;
    double maxLongitude = double.negativeInfinity;

    for (final LatLng point in polygon) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
    }

    final LatLng boundsCenter = LatLng(
      (minLatitude + maxLatitude) / 2,
      (minLongitude + maxLongitude) / 2,
    );

    if (_pointIsInsidePolygon(boundsCenter, polygon)) {
      return boundsCenter;
    }

    const int gridSize = 20;

    for (int radius = 1; radius <= gridSize; radius++) {
      for (int latitudeStep = -radius;
          latitudeStep <= radius;
          latitudeStep++) {
        for (int longitudeStep = -radius;
            longitudeStep <= radius;
            longitudeStep++) {
          if (latitudeStep.abs() != radius &&
              longitudeStep.abs() != radius) {
            continue;
          }

          final LatLng candidate = LatLng(
            boundsCenter.latitude +
                (maxLatitude - minLatitude) *
                    latitudeStep /
                    (gridSize * 2),
            boundsCenter.longitude +
                (maxLongitude - minLongitude) *
                    longitudeStep /
                    (gridSize * 2),
          );

          if (_pointIsInsidePolygon(candidate, polygon)) {
            return candidate;
          }
        }
      }
    }

    return polygon[polygon.length ~/ 2];
  }

  double _polygonArea(List<LatLng> polygon) {
    double doubledArea = 0;

    for (int index = 0; index < polygon.length; index++) {
      final LatLng current = polygon[index];
      final LatLng next = polygon[(index + 1) % polygon.length];

      doubledArea += current.longitude * next.latitude -
          next.longitude * current.latitude;
    }

    return doubledArea.abs() / 2;
  }

  LatLng? _polygonCentroid(List<LatLng> polygon) {
    double doubledArea = 0;
    double longitudeTotal = 0;
    double latitudeTotal = 0;

    for (int index = 0; index < polygon.length; index++) {
      final LatLng current = polygon[index];
      final LatLng next = polygon[(index + 1) % polygon.length];
      final double cross = current.longitude * next.latitude -
          next.longitude * current.latitude;

      doubledArea += cross;
      longitudeTotal +=
          (current.longitude + next.longitude) * cross;
      latitudeTotal +=
          (current.latitude + next.latitude) * cross;
    }

    if (doubledArea.abs() < 0.0000001) {
      return null;
    }

    return LatLng(
      latitudeTotal / (3 * doubledArea),
      longitudeTotal / (3 * doubledArea),
    );
  }

  bool _pointIsInsidePolygon(
    LatLng point,
    List<LatLng> polygon,
  ) {
    bool isInside = false;

    for (int index = 0, previous = polygon.length - 1;
        index < polygon.length;
        previous = index++) {
      final LatLng currentPoint = polygon[index];
      final LatLng previousPoint = polygon[previous];

      final bool crossesLatitude =
          (currentPoint.latitude > point.latitude) !=
              (previousPoint.latitude > point.latitude);

      if (!crossesLatitude) {
        continue;
      }

      final double crossingLongitude =
          (previousPoint.longitude - currentPoint.longitude) *
                  (point.latitude - currentPoint.latitude) /
                  (previousPoint.latitude - currentPoint.latitude) +
              currentPoint.longitude;

      if (point.longitude < crossingLongitude) {
        isInside = !isInside;
      }
    }

    return isInside;
  }

  void _toggleResultPanel() {
    setState(() {
      _isResultPanelCollapsed = !_isResultPanelCollapsed;
    });
  }

  @override
  void dispose() {
    _stopTimer();
    _stampUnlockOverlayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UltimateQuestion? question = _currentQuestion;

    if (_showGameOver) {
      return _buildGameOverScreen();
    }

    if (question == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF071B3A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF071B3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071B3A),
        foregroundColor: Colors.white,
        title: Text(
          widget.missionTitle.toUpperCase(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _hasAnswered
                    ? _buildMapReveal(question)
                    : _buildQuestionView(question),
              ),
            ),
          ),
          if (_stampUnlockCountry != null && _stampUnlockProgress != null)
            Positioned.fill(
              child: IgnorePointer(
                child: PassportStampUnlockOverlay(
                  country: _stampUnlockCountry!,
                  progress: _stampUnlockProgress!,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionView(UltimateQuestion question) {
    return Column(
      key: ValueKey<String>('question-${question.answerCountry.id}'),
      children: <Widget>[
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Column(
              children: <Widget>[
                Text(
                  'QUEL EST CE PAYS ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: CountrySilhouette(
                    country: question.answerCountry,
                  ),
                ),
                const SizedBox(height: 18),
                for (final GeoCountry country
                    in question.choices) ...<Widget>[
                  _buildChoiceButton(country),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapReveal(UltimateQuestion question) {
    final LatLng answerPoint = _currentAnswerPoint ??
        _representativePointFor(question.answerCountry);

    return Stack(
      key: ValueKey<String>('map-${question.answerCountry.id}'),
      children: <Widget>[
        Positioned.fill(
          child: GeoPointMap(
            answerPoint: answerPoint,
            answerCountry: question.answerCountry,
            preferProvidedAnswerCountry: true,
            resultPanelCollapsed: _isResultPanelCollapsed,
            showInformationPanel: false,
            allowInteraction: false,
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildHeader(),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: MediaQuery.paddingOf(context).bottom + 12,
          child: _buildResultPanel(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final bool urgent = _secondsRemaining <= 5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'QUESTION '
              '$_questionNumber / '
              '$_totalQuestions',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            Icons.timer_outlined,
            color: urgent ? const Color(0xFFFFD166) : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            '$_secondsRemaining s',
            style: TextStyle(
              color: urgent ? const Color(0xFFFFD166) : Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            '$_totalScore pts',
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton(GeoCountry country) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: _choiceColor(country),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _hasAnswered
              ? null
              : () {
                  _submitChoice(country);
                },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _choiceBorderColor(country),
                width: 1.5,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    country.displayNameWithFlag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_hasAnswered && _isCorrectChoice(country))
                  const Icon(Icons.check_circle, color: Color(0xFF80ED99))
                else if (_hasAnswered && _isSelected(country))
                  const Icon(Icons.cancel, color: Color(0xFFFF5C5C)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultPanel() {
    final UltimateQuestion? question = _currentQuestion;

    if (question == null) {
      return const SizedBox.shrink();
    }

    final String selectedId = _selectedCountryId ?? '';

    final bool isCorrect = question.isCorrectChoice(selectedId);

    final int earnedScore = isCorrect ? 100 + _calculateTimeBonus() : 0;

    final CountryInfo? countryInfo =
        _countryInfoFor(question.answerCountry);

    final String savedFact =
        countryInfo?.shortFact?.trim() ?? '';

    final String continent =
        (countryInfo?.continent.trim().isNotEmpty ?? false)
            ? countryInfo!.continent.trim()
            : question.answerCountry.continent.trim();

    final String selectedCountryName =
        _selectedChoiceName(question);

    if (_isResultPanelCollapsed) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
          decoration: _resultPanelDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    isCorrect
                        ? Icons.check_circle
                        : _isTimeUp
                            ? Icons.timer_off
                            : Icons.info,
                    color: _resultColor(),
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _resultTitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _resultColor(),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          question.answerCountry.displayNameWithFlag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+$earnedScore',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleResultPanel,
                    tooltip: 'Rouvrir la fiche',
                    icon: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildNextButton(),
            ],
          ),
        ),
      );
    }

    final double maxPanelHeight =
        (MediaQuery.sizeOf(context).height * 0.62)
            .clamp(330.0, 560.0)
            .toDouble();

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: maxPanelHeight,
        ),
        padding: const EdgeInsets.all(16),
        decoration: _resultPanelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    _resultTitle(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _resultColor(),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleResultPanel,
                  tooltip: 'Réduire la fiche',
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),

            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!isCorrect &&
                        !_isTimeUp &&
                        selectedCountryName.isNotEmpty) ...<Widget>[
                      Text(
                        'Tu as choisi : $selectedCountryName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                    Text(
                      question.answerCountry.displayNameWithFlag,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (continent.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _SilhouetteInformationRow(
                        icon: Icons.public,
                        label: 'Continent',
                        value: continent,
                      ),
                    ],
                    const SizedBox(height: 9),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF53D8FF)
                            .withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF53D8FF)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.lightbulb_outline,
                            color: Color(0xFF53D8FF),
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              savedFact.isNotEmpty
                                  ? savedFact
                                  : 'Observe sa forme et sa position '
                                      'sur la carte pour mieux la mémoriser.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _UltimatePersonalActions(
                      status: _atlasProgress.statusFor(
                        question.answerCountry.id,
                      ),
                      favorite: _atlasProgress.isFavorite(
                        question.answerCountry.id,
                      ),
                      busy: _savingPersonalProgress,
                      onToggleVisited: () {
                        _saveAtlasProgress(
                          _atlasProgress.toggleVisited(
                            question.answerCountry.id,
                          ),
                        );
                      },
                      onToggleWishlist: () {
                        _saveAtlasProgress(
                          _atlasProgress.toggleWishlist(
                            question.answerCountry.id,
                          ),
                        );
                      },
                      onToggleFavorite: () {
                        _saveAtlasProgress(
                          _atlasProgress.toggleFavorite(
                            question.answerCountry.id,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '+$earnedScore points',
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  BoxDecoration _resultPanelDecoration() {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _resultColor().withValues(alpha: 0.65)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _startNextQuestion,
        icon: Icon(
          _questionNumber >= _totalQuestions
              ? Icons.emoji_events
              : Icons.arrow_forward,
        ),
        label: Text(
          _questionNumber >= _totalQuestions
              ? 'VOIR LES RÉSULTATS'
              : 'QUESTION SUIVANTE',
        ),
      ),
    );
  }

  String _selectedChoiceName(UltimateQuestion question) {
    for (final GeoCountry country in question.choices) {
      if (_isSelected(country)) {
        return country.displayNameWithFlag;
      }
    }

    return '';
  }

  Widget _buildGameOverScreen() {
    final int earnedStars = _calculateEarnedStars();

    final int displayedRecord = _totalScore > widget.previousBestScore
        ? _totalScore
        : widget.previousBestScore;

    final bool isNewRecord = _totalScore > widget.previousBestScore;

    final Widget results = Scaffold(
      backgroundColor: const Color(0xFF071B3A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF132A49),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.extension_rounded,
                    color: Color(0xFFFFD166),
                    size: 60,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.missionTitle.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _starText(earnedStars),
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$_totalScore / '
                    '${_totalQuestions * 120}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$_correctAnswers / '
                    '$_totalQuestions '
                    'bonnes réponses',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFFFD166).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFFFFD166),
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            isNewRecord
                                ? 'NOUVEAU RECORD : '
                                      '$displayedRecord pts'
                                : 'RECORD : '
                                      '$displayedRecord pts',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFD166),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(
                          UltimateGameResult(
                            earnedStars: earnedStars,
                            totalScore: _totalScore,
                            correctAnswers: _correctAnswers,
                            totalQuestions: _totalQuestions,
                            totalElapsedSeconds: _totalElapsedSeconds,
                            answerEvidence:
                                List<ChallengeAnswerEvidence>.unmodifiable(
                              _answerEvidence,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: Text(widget.returnButtonLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(child: results),
        if (_progressNotificationBatch != null)
          Positioned.fill(
            child: PassportProgressNotificationOverlay(
              batch: _progressNotificationBatch!,
              onContinue: () {
                setState(() => _progressNotificationBatch = null);
              },
            ),
          ),
        if (_majorLevelUp != null)
          Positioned.fill(
            child: PassportMajorLevelUpOverlay(
              transition: _majorLevelUp!,
              animationsEnabled: _majorLevelAnimationsEnabled,
              onContinue: () {
                setState(() => _majorLevelUp = null);
              },
            ),
          ),
      ],
    );
  }
}

class _UltimatePersonalActions extends StatelessWidget {
  const _UltimatePersonalActions({
    required this.status,
    required this.favorite,
    required this.busy,
    required this.onToggleVisited,
    required this.onToggleWishlist,
    required this.onToggleFavorite,
  });

  final AtlasCountryStatus status;
  final bool favorite;
  final bool busy;
  final VoidCallback onToggleVisited;
  final VoidCallback onToggleWishlist;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _UltimatePersonalButton(
            label: 'Visité',
            icon: Icons.flight_takeoff_rounded,
            active: status == AtlasCountryStatus.visited,
            color: const Color(0xFF55D6A6),
            busy: busy,
            onPressed: onToggleVisited,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _UltimatePersonalButton(
            label: 'À visiter',
            icon: Icons.bookmark_rounded,
            active: status == AtlasCountryStatus.wishlist,
            color: const Color(0xFFFF756B),
            busy: busy,
            onPressed: onToggleWishlist,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _UltimatePersonalButton(
            label: 'Favori',
            icon: Icons.favorite_rounded,
            active: favorite,
            color: const Color(0xFFFFCE59),
            busy: busy,
            onPressed: onToggleFavorite,
          ),
        ),
      ],
    );
  }
}

class _UltimatePersonalButton extends StatelessWidget {
  const _UltimatePersonalButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor:
            active ? color : Colors.white.withValues(alpha: 0.08),
        foregroundColor: active ? const Color(0xFF071B3A) : Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: active ? color : Colors.white24),
        ),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(active ? Icons.check_circle_rounded : icon, size: 17),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SilhouetteInformationRow extends StatelessWidget {
  const _SilhouetteInformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color: const Color(0xFF80ED99),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
