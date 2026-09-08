import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../features/atlas/atlas_personal_progress.dart';
import '../features/atlas/atlas_personal_storage.dart';
import '../features/design/geopoint_design.dart';
import '../features/passport/passport_country_stamp_view.dart';
import '../features/passport/passport_major_level_up_overlay.dart';
import '../geo_engine/country_info.dart';
import '../geo_engine/country_info_loader.dart';
import '../geo_engine/flag_emoji.dart';
import '../geo_engine/geo_country.dart';
import '../geo_engine/geopoint_map.dart';
import '../monetization/interstitial_ad_service.dart';
import '../passport/achievements/passport_achievement.dart';
import '../passport/achievements/passport_achievement_catalog.dart';
import '../passport/achievements/passport_achievement_progress.dart';
import '../passport/achievements/passport_achievement_snapshot_builder.dart';
import '../passport/achievements/passport_achievement_storage.dart';
import '../passport/collections/passport_collection_item.dart';
import '../passport/notifications/passport_progress_notification.dart';
import '../passport/progress/passport_progress_v2.dart';
import '../passport/progress/passport_stamp_unlock_event.dart';
import '../passport/progression/passport_major_level_up.dart';
import '../passport/settings/passport_display_preferences.dart';
import '../passport/settings/passport_display_preferences_storage.dart';
import '../player/level_result.dart';
import '../player/player_profile.dart';
import 'continent/continent_expedition.dart';
import 'continent/continent_progress.dart';
import 'continent/continent_storage.dart';
import 'expedition/expedition_progress.dart';
import 'expedition/expedition_storage.dart';
import 'game_controller.dart';
import 'game_play_result.dart';
import 'game_question.dart';
import 'learning/guided_level.dart';
import 'passport/passport_result.dart';
import 'passport/passport_stamp.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.controller,
    this.modeId = 'find_country',
    this.difficultyId = 'discovery',
    this.missionTitle = 'Trouver le pays',
    this.guidedLevel,
    this.continentExpeditionId,
    this.continentExpeditionName,
    this.continentLevel,
    this.isTraining = false,
    this.trainingQuestionCount = 10,
    this.trainingRegionId = 'world',
    this.completeTraining = false,
    this.reviewDifficultiesOnly = false,
    this.trainingCountryIds,
    this.isChallenge = false,
    this.challengeId,
    this.challengeQuestionCount,
    this.challengeRegionId = 'world',
    this.challengeCountryIds,
    this.challengeGeoBrainPersonalizationAllowed = false,
    super.key,
  });

  final GameController controller;

  /// Identifiant technique de l’épreuve.
  final String modeId;

  /// Identifiant technique de l’expédition.
  final String difficultyId;

  /// Nom visible de la mission.
  final String missionTitle;

  final GuidedLevel? guidedLevel;

  final String? continentExpeditionId;
  final String? continentExpeditionName;
  final ContinentLevel? continentLevel;

  final bool isTraining;
  final int trainingQuestionCount;
  final String trainingRegionId;
  final bool completeTraining;
  final bool reviewDifficultiesOnly;
  final Set<String>? trainingCountryIds;
  final bool isChallenge;
  final String? challengeId;
  final int? challengeQuestionCount;
  final String challengeRegionId;
  final Set<String>? challengeCountryIds;
  final bool challengeGeoBrainPersonalizationAllowed;

  @override
  State<GameScreen> createState() {
    return _GameScreenState();
  }
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;

  bool _showGameOverPanel = false;
  bool _isResultPanelCollapsed = true;
  bool _missionProgressSaved = false;
  bool _advertisementCounted = false;
  int _previousMissionRecord = 0;
  bool _missionRecordLoaded = false;
  Map<String, CountryInfo> _countryInfos =
      const <String, CountryInfo>{};
  AtlasPersonalProgress _atlasProgress =
      AtlasPersonalProgress.initial();
  final Set<String> _savingAtlasCountryIds = <String>{};

  LatLng? _pendingSelectedPoint;
  Timer? _stampUnlockOverlayTimer;
  PassportStampUnlockEvent? _stampUnlockOverlayEvent;
  bool _stampAnimationsEnabled = true;
  bool _majorLevelAnimationsEnabled = true;
  int _handledStampUnlockSequence = 0;
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

  @override
  void initState() {
    super.initState();

    _controller = widget.controller;
    _handledStampUnlockSequence =
        _controller.latestCountryStampUnlock?.sequence ?? 0;

    final GuidedLevel? guidedLevel =
        widget.guidedLevel;

    final ContinentLevel? continentLevel =
        widget.continentLevel;

    if (widget.isChallenge) {
      _controller.startChallengeMission(
        challengeId: widget.challengeId ?? 'challenge',
        difficultyId: widget.difficultyId,
        modeId: widget.modeId,
        questionCount: widget.challengeQuestionCount ?? 10,
        regionId: widget.challengeRegionId,
        allowedCountryIds: widget.challengeCountryIds,
        geoBrainPersonalizationAllowed:
            widget.challengeGeoBrainPersonalizationAllowed,
      );
    } else if (widget.isTraining) {
      _controller.startTrainingMission(
        difficultyId: widget.difficultyId,
        modeId: widget.modeId,
        questionCount: widget.trainingQuestionCount,
        regionId: widget.trainingRegionId,
        completeRegion: widget.completeTraining,
        reviewDifficultiesOnly: widget.reviewDifficultiesOnly,
        allowedCountryIds: widget.trainingCountryIds,
      );
    } else if (guidedLevel != null) {
      _controller.startGuidedMission(
        guidedLevel,
      );
    } else if (continentLevel != null) {
      _controller.startContinentMission(
        continentLevel,
      );
    } else {
      _controller.startMission(
        difficultyId:
            widget.difficultyId,
        modeId:
            widget.modeId,
      );
    }

    _showGameOverPanel = false;
    _missionProgressSaved = false;
    _progressAtGameStart = _controller.passportProgress;
    _profileAtGameStart = _controller.playerProfile;
    _licenseIdAtGameStart = _controller.passport.currentLicenseId;
    _notificationBaselineFuture = _loadProgressNotificationBaseline();

    unawaited(
      _loadMissionRecord(),
    );

    unawaited(
      _loadCountryInfos(),
    );

    unawaited(
      _loadAtlasProgress(),
    );

    unawaited(
      _loadPassportDisplayPreferences(),
    );

    _controller.addListener(
      _handleControllerChanged,
    );

  }

  Future<void> _loadProgressNotificationBaseline() async {
    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      PassportAchievementStorage.load(),
      ExpeditionStorage.load(),
      ContinentStorage.load(),
    ]);
    _expeditionAtGameStart = values[1] as ExpeditionProgress;
    _continentAtGameStart = values[2] as ContinentProgress;

    final PassportAchievementSnapshot initialSnapshot =
        PassportAchievementSnapshotBuilder.build(
      progress: _progressAtGameStart,
      profile: _profileAtGameStart,
      countries: _controller.countries,
      expeditionProgress: _expeditionAtGameStart,
      continentProgress: _continentAtGameStart,
    );
    final PassportAchievementProgress loaded =
        (values[0] as PassportAchievementProgress).mergeCompletedTierDates(
      _progressAtGameStart.completedAchievementTierDates,
    );
    _achievementsAtGameStart = loaded.synchronize(snapshot: initialSnapshot);
    await _controller.ensureAchievementXpBaseline(
      _achievementsAtGameStart.completedAtByTierId.keys,
    );
    if (!identical(loaded, _achievementsAtGameStart)) {
      await _controller.synchronizePassportAchievementProgress(
        _achievementsAtGameStart,
      );
    }
  }

  Future<void> _loadMissionRecord() async {
    if (widget.guidedLevel != null ||
        widget.isTraining ||
        widget.isChallenge) {
      _missionRecordLoaded = true;
      return;
    }

    final ContinentLevel? continentLevel =
        widget.continentLevel;

    final String? continentExpeditionId =
        widget.continentExpeditionId;

    if (continentLevel != null &&
        continentExpeditionId != null) {
      final ContinentProgress progress =
          await ContinentStorage.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _previousMissionRecord =
            progress.bestScoreFor(
          expeditionId: continentExpeditionId,
          levelId: continentLevel.id,
        );
        _missionRecordLoaded = true;
      });

      return;
    }

    final ExpeditionProgress progress =
        await ExpeditionStorage.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _previousMissionRecord =
          progress.bestScoreFor(
        difficultyId:
            widget.difficultyId,
        missionId: widget.modeId,
      );
      _missionRecordLoaded = true;
    });
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
        'GeoPoint : chargement des fiches pays impossible : $error',
      );
    }
  }

  Future<void> _loadAtlasProgress() async {
    final AtlasPersonalProgress progress =
        await AtlasPersonalStorage.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _atlasProgress = progress;
    });
  }

  Future<void> _toggleAtlasVisited(GeoCountry country) async {
    await _saveAtlasProgress(
      country,
      _atlasProgress.toggleVisited(country.id),
    );
  }

  Future<void> _toggleAtlasWishlist(GeoCountry country) async {
    await _saveAtlasProgress(
      country,
      _atlasProgress.toggleWishlist(country.id),
    );
  }

  Future<void> _toggleAtlasFavorite(GeoCountry country) async {
    await _saveAtlasProgress(
      country,
      _atlasProgress.toggleFavorite(country.id),
    );
  }

  Future<void> _saveAtlasProgress(
    GeoCountry country,
    AtlasPersonalProgress next,
  ) async {
    final String countryId = country.id.trim().toUpperCase();

    if (countryId.isEmpty || _savingAtlasCountryIds.isNotEmpty) {
      return;
    }

    setState(() {
      _savingAtlasCountryIds.add(countryId);
    });

    final bool saved = await AtlasPersonalStorage.save(next);

    if (saved) {
      await _controller.synchronizePassportPersonalProgress(next);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (saved) {
        _atlasProgress = next;
      }
      _savingAtlasCountryIds.remove(countryId);
    });

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de sauvegarder ce pays pour le moment.'),
        ),
      );
    }
  }

  bool get _isSavingAtlasCountry {
    return _savingAtlasCountryIds.isNotEmpty;
  }

  CountryInfo? _countryInfoFor(
    GeoCountry? country,
  ) {
    final String countryId =
        country?.id.trim().toUpperCase() ?? '';

    if (countryId.isEmpty) {
      return null;
    }

    return _countryInfos[countryId];
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
      // Une préférence illisible ne doit jamais empêcher de jouer.
    }
  }

  GeoCountry? _countryForStampUnlock(
    PassportStampUnlockEvent event,
  ) {
    final String entityId = event.entityId.trim().toUpperCase();

    for (final GeoCountry country in _controller.countries) {
      if (country.id.trim().toUpperCase() == entityId) {
        return country;
      }
    }

    return null;
  }

  void _showStampUnlockOverlay(PassportStampUnlockEvent event) {
    _stampUnlockOverlayTimer?.cancel();
    _stampUnlockOverlayEvent = event;
    _stampUnlockOverlayTimer = Timer(
      const Duration(milliseconds: 2400),
      () {
        if (!mounted || _stampUnlockOverlayEvent?.sequence != event.sequence) {
          return;
        }

        setState(() {
          _stampUnlockOverlayEvent = null;
        });
      },
    );
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    final PassportStampUnlockEvent? latestUnlock =
        _controller.latestCountryStampUnlock;

    setState(() {
      if (latestUnlock != null &&
          latestUnlock.sequence > _handledStampUnlockSequence) {
        _handledStampUnlockSequence = latestUnlock.sequence;

        if (_stampAnimationsEnabled) {
          _showStampUnlockOverlay(latestUnlock);
        }
      }
    });
  }

  void _handlePointSelected(
    LatLng point,
  ) {
    _pendingSelectedPoint = point;
  }

  void _handleCountrySelected(
    GeoCountry? selectedCountry,
  ) {
    final LatLng? selectedPoint =
        _pendingSelectedPoint;

    if (selectedPoint == null) {
      return;
    }

    // La correction s'ouvre d'abord sous forme compacte afin de laisser la
    // carte cadrer immédiatement le point choisi et la réponse attendue.
    _isResultPanelCollapsed = true;

    _controller.submitAnswer(
      selectedPoint: selectedPoint,
      selectedCountry: selectedCountry,
    );

    _pendingSelectedPoint = null;
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

  Future<PassportProgressNotificationBatch>
      _prepareProgressNotifications() async {
    try {
      await _notificationBaselineFuture;
      await _controller.waitForPassportProgressSynchronization();

      final List<Object> values = await Future.wait<Object>(<Future<Object>>[
        ExpeditionStorage.load(),
        ContinentStorage.load(),
      ]);
      final ExpeditionProgress currentExpedition =
          values[0] as ExpeditionProgress;
      final ContinentProgress currentContinent =
          values[1] as ContinentProgress;
      final PassportProgressV2 progressBeforeRewards =
          _controller.passportProgress;
      PlayerProfile currentProfile = _controller.playerProfile;

      final PassportAchievementSnapshot beforeAchievementSnapshot =
          PassportAchievementSnapshotBuilder.build(
        progress: _progressAtGameStart,
        profile: _profileAtGameStart,
        countries: _controller.countries,
        expeditionProgress: _expeditionAtGameStart,
        continentProgress: _continentAtGameStart,
      );
      final PassportAchievementSnapshot afterAchievementSnapshot =
          PassportAchievementSnapshotBuilder.build(
        progress: progressBeforeRewards,
        profile: currentProfile,
        countries: _controller.countries,
        expeditionProgress: currentExpedition,
        continentProgress: currentContinent,
      );
      final PassportAchievementProgress updatedAchievements =
          _achievementsAtGameStart.synchronize(
        snapshot: afterAchievementSnapshot,
      );

      final Set<String> newTierIds = updatedAchievements
          .newlyCompletedTierIdsComparedWith(_achievementsAtGameStart);
      await _controller.registerAchievementCompletions(
        tierIds: newTierIds,
      );
      currentProfile = _controller.playerProfile;

      if (!identical(_achievementsAtGameStart, updatedAchievements)) {
        await _controller.synchronizePassportAchievementProgress(
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
          await _controller.unlockPassportCollectionItem(rewardItemId);
        }
      }
      await _controller.waitForPassportProgressSynchronization();

      final PassportProgressV2 currentProgress =
          _controller.passportProgress;
      final PassportCollectionSnapshot beforeCollections =
          _collectionSnapshot(
        progress: _progressAtGameStart,
        profile: _profileAtGameStart,
        achievementSnapshot: beforeAchievementSnapshot,
        licenseId: _licenseIdAtGameStart,
      );
      final PassportCollectionSnapshot afterCollections =
          _collectionSnapshot(
        progress: currentProgress,
        profile: currentProfile,
        achievementSnapshot: afterAchievementSnapshot,
        licenseId: _controller.passport.currentLicenseId,
      );

      return PassportProgressNotificationBuilder.build(
        beforeProgress: _progressAtGameStart,
        afterProgress: currentProgress,
        beforeProfile: _profileAtGameStart,
        afterProfile: currentProfile,
        beforeCollections: beforeCollections,
        afterCollections: afterCollections,
        beforeAchievements: _achievementsAtGameStart,
        afterAchievements: updatedAchievements,
        countries: _controller.countries,
      );
    } on Object catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : préparation des notifications impossible : $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return PassportProgressNotificationBatch.fromItems(
        const <PassportProgressNotification>[],
      );
    }
  }

  Future<void> _handleNextQuestion() async {
    _pendingSelectedPoint = null;
    _isResultPanelCollapsed = true;

    if (_controller.session.isLastQuestion &&
        _controller.hasAnswered) {
      if (widget.guidedLevel == null && !widget.isTraining) {
        await _controller.waitForCurrentGameCompletion();

        if (!mounted) {
          return;
        }

        if (!widget.isChallenge) {
          await _saveMissionProgress();
        }
      }

      if (!mounted) {
        return;
      }

      PassportProgressNotificationBatch? notificationBatch;
      PassportMajorLevelUp? majorLevelUp;
      if (widget.guidedLevel == null && !widget.isTraining) {
        final PassportProgressNotificationBatch prepared =
            await _prepareProgressNotifications();
        if (prepared.isNotEmpty) {
          notificationBatch = prepared;
        }
        majorLevelUp = PassportMajorLevelUp.between(
          beforeProfile: _profileAtGameStart,
          afterProfile: _controller.playerProfile,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _showGameOverPanel = true;
        _progressNotificationBatch = notificationBatch;
        _majorLevelUp = majorLevelUp;
      });

      return;
    }

    _controller.startNextQuestion();
  }

  void _toggleResultPanel() {
    setState(() {
      _isResultPanelCollapsed =
          !_isResultPanelCollapsed;
    });
  }

  int _calculateEarnedStars() {
    if (widget.isTraining) {
      return 0;
    }

    final ContinentLevel? continentLevel =
        widget.continentLevel;

    if (continentLevel != null) {
      return continentLevel.starsForScore(
        _controller.session.totalScore,
      );
    }

    final int maximumScore =
        _controller.session.maximumGameScore;

    if (maximumScore <= 0) {
      return 0;
    }

    final double ratio =
        _controller.session.totalScore /
            maximumScore;

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

  Future<void> _saveMissionProgress() async {
    if (_missionProgressSaved) {
      return;
    }

    _missionProgressSaved = true;

    final ContinentLevel? continentLevel =
        widget.continentLevel;

    final String? continentExpeditionId =
        widget.continentExpeditionId;

    if (continentLevel != null &&
        continentExpeditionId != null) {
      final ContinentProgress currentProgress =
          await ContinentStorage.load();

      final int previousRecord =
          currentProgress.bestScoreFor(
        expeditionId: continentExpeditionId,
        levelId: continentLevel.id,
      );
      final int previousStars = currentProgress.starsFor(
        expeditionId: continentExpeditionId,
        levelId: continentLevel.id,
      );
      final int earnedStars = _calculateEarnedStars();

      final ContinentProgress updatedProgress =
          currentProgress.registerLevelResult(
        expeditionId: continentExpeditionId,
        levelId: continentLevel.id,
        stars: earnedStars,
        score: _controller.session.totalScore,
      );

      final bool saved =
          await ContinentStorage.save(
        updatedProgress,
      );

      if (!saved) {
        _missionProgressSaved = false;
        return;
      }

      if (previousStars < 1 && earnedStars >= 1) {
        await _controller.registerExpeditionMissionCompletion(
          expeditionId: continentExpeditionId,
          missionId: continentLevel.id,
          isExam: continentLevel.isExam || continentLevel.isMaster,
        );
      }

      if (mounted) {
        setState(() {
          _previousMissionRecord = previousRecord;
          _missionRecordLoaded = true;
        });
      }

      return;
    }

    final ExpeditionProgress currentProgress =
        await ExpeditionStorage.load();

    final int previousRecord =
        currentProgress.bestScoreFor(
      difficultyId: widget.difficultyId,
      missionId: widget.modeId,
    );
    final int previousStars = currentProgress.starsFor(
      difficultyId: widget.difficultyId,
      missionId: widget.modeId,
    );
    final int earnedStars = _calculateEarnedStars();

    final ExpeditionProgress updatedProgress =
        currentProgress.registerMissionResult(
      difficultyId:
          widget.difficultyId,
      missionId:
          widget.modeId,
      stars:
          earnedStars,
      score:
          _controller.session.totalScore,
    );

    final bool saved =
        await ExpeditionStorage.save(
      updatedProgress,
    );

    if (!saved) {
      _missionProgressSaved = false;
      return;
    }

    if (previousStars < 1 && earnedStars >= 1) {
      await _controller.registerExpeditionMissionCompletion(
        expeditionId: 'classic-${widget.difficultyId}',
        missionId: widget.modeId,
      );
    }

    if (mounted) {
      setState(() {
        _previousMissionRecord =
            previousRecord;
        _missionRecordLoaded = true;
      });
    }
  }

  Future<void> _handleBackToHome() async {
    if (!_advertisementCounted &&
        _showGameOverPanel &&
        (widget.isTraining || widget.continentLevel != null)) {
      _advertisementCounted = true;
      await InterstitialAdService.instance.registerCompletedGame();
      if (!mounted) return;
    }
    if (!widget.isChallenge) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop<GamePlayResult>(
      GamePlayResult(
        totalScore: _controller.session.totalScore,
        correctAnswers: _controller.correctAnswers,
        totalQuestions: _controller.session.totalQuestions,
        averageDistanceInKilometers:
            _controller.averageDistanceInKilometers,
        totalElapsedSeconds: _controller.totalElapsedSeconds,
        answerEvidence: _controller.currentChallengeAnswerEvidence,
      ),
    );
  }

  String _expeditionLabel(
    String difficultyId,
  ) {
    if (widget.isChallenge) {
      return 'Défi';
    }
    if (widget.completeTraining) {
      return 'Parcours complet';
    }

    if (widget.guidedLevel != null) {
      return 'Tutoriel';
    }

    final String? continentExpeditionName =
        widget.continentExpeditionName;

    if (continentExpeditionName != null &&
        continentExpeditionName.trim().isNotEmpty) {
      return continentExpeditionName;
    }

    switch (difficultyId) {
      case 'discovery':
        return 'Initiation';
      case 'easy':
        return 'Voyageur';
      case 'intermediate':
        return 'Explorateur';
      case 'hard':
        return 'Aventurier';
      case 'expert':
        return 'Maître cartographe';
      default:
        return difficultyId;
    }
  }

  double? _resultRadiusInKilometers(
    GameQuestion? question,
  ) {
    final String currentModeId =
        question?.modeId ??
            widget.modeId;

    /*
     * Les modes Pays et Drapeaux utilisent le
     * territoire lui-même comme zone correcte.
     * Seules les questions de capitale ont une
     * tolérance géographique circulaire.
     */
    if (currentModeId != 'find_capital') {
      return null;
    }

    switch (widget.difficultyId) {
      case 'discovery':
        return 300;
      case 'easy':
        return 220;
      case 'intermediate':
        return 150;
      case 'hard':
        return 90;
      case 'expert':
        return 50;
      default:
        return 150;
    }
  }

  double _maximumMapZoom() {
    /*
     * Le zoom maximal ne sert plus d'indice sur la
     * position de la reponse. Il limite seulement le
     * niveau de detail disponible pendant la recherche.
     *
     * Les niveaux eleves autorisent davantage de zoom
     * car ils contiennent des micro-Etats, des iles et
     * des capitales qui seraient sinon impossibles a
     * selectionner. La difficulte vient du depart neutre,
     * du temps et de la precision, pas d'une carte rendue
     * artificiellement inutilisable.
     */
    if (widget.completeTraining || widget.modeId == 'mixed') {
      return 12;
    }

    final bool isCapitalMode =
        widget.modeId == 'find_capital';

    switch (widget.difficultyId) {
      case 'discovery':
        return isCapitalMode ? 8 : 6.5;

      case 'easy':
        return isCapitalMode ? 9 : 7.5;

      case 'intermediate':
        return isCapitalMode ? 10 : 9;

      case 'hard':
        return isCapitalMode ? 11 : 10.5;

      case 'expert':
      default:
        return 12;
    }
  }

  @override
  void dispose() {
    _stampUnlockOverlayTimer?.cancel();
    _controller.removeListener(
      _handleControllerChanged,
    );

    /*
     * On ne détruit pas le contrôleur ici.
     *
     * Il appartient désormais à HomeScreen,
     * qui le conserve afin de préserver le
     * Passeport et les résultats du joueur.
     */
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GameQuestion? question =
        _controller.session.currentQuestion;
    final PassportStampUnlockEvent? stampUnlockEvent =
        _stampUnlockOverlayEvent;
    final GeoCountry? stampUnlockCountry = stampUnlockEvent == null
        ? null
        : _countryForStampUnlock(stampUnlockEvent);

    final int questionNumber =
        _controller.session.questionNumber;

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GeoPointMap(
                initialZoom:
                    _controller.currentInitialZoom,
                initialCenter:
                    _controller.currentInitialCenter,
                maximumZoom:
                    _maximumMapZoom(),
                hintCountryId:
                    _controller
                        .guidedHintCountryId,
                hintPoint:
                    _controller
                        .guidedHintPoint,
                hintRadiusInKilometers:
                    _controller
                        .guidedHintRadiusInKilometers,
                answerPoint:
                    _controller.answerPoint,
                answerCountry:
                    _controller.answerCountry,
                validatedCountries:
                    _controller.validatedCountries,
                resultRadiusInKilometers:
                    _resultRadiusInKilometers(
                  question,
                ),
                resultPanelCollapsed:
                    _isResultPanelCollapsed,
                showInformationPanel: false,
                allowInteraction:
                    !_controller.hasAnswered &&
                    !_showGameOverPanel,
                onTap: _handlePointSelected,
                onCountrySelected:
                    _handleCountrySelected,
              ),
            ),

            Positioned(
              top:
                  MediaQuery.paddingOf(context)
                          .top +
                      12,
              left: 12,
              right: 12,
              child: _GameHeader(
                missionTitle:
                    widget.missionTitle,
                expeditionLabel:
                    _expeditionLabel(
                  widget.difficultyId,
                ),
                question: question,
                questionNumber:
                    questionNumber,
                totalQuestions:
                    _controller
                        .session
                        .totalQuestions,
                totalScore:
                    _controller
                        .session
                        .totalScore,
                secondsRemaining:
                    _controller
                        .secondsRemaining,
                showTimer:
                    _controller
                        .guidedMissionHasTimer,
                onClose:
                    _handleBackToHome,
              ),
            ),

            if (widget.guidedLevel != null &&
                !_controller.hasAnswered &&
                _controller.guidedInstruction != null)
              Positioned(
                top:
                    MediaQuery.paddingOf(context)
                            .top +
                        145,
                left: 20,
                right: 20,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A3973)
                            .withValues(alpha: 0.90),
                        borderRadius:
                            BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF53D8FF),
                        ),
                      ),
                      child: Text(
                        _controller.guidedInstruction!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (_controller.hasAnswered &&
                !_showGameOverPanel)
              Positioned(
                left: 12,
                right: 12,
                bottom:
                    MediaQuery.paddingOf(context)
                            .bottom +
                        12,
                child: widget.guidedLevel != null
                    ? _TutorialResultPanel(
                        modeId:
                            question?.modeId ??
                                widget.modeId,
                        isCorrect: _controller
                            .session
                            .isCorrectCountry,
                        answerCountry:
                            _controller.answerCountry,
                        answerCapitalName:
                            _controller.answerCapitalName,
                        countryStatus:
                            _controller.answerCountry == null
                                ? AtlasCountryStatus.none
                                : _atlasProgress.statusFor(
                                    _controller.answerCountry!.id,
                                  ),
                        countryFavorite: _controller.answerCountry != null &&
                            _atlasProgress.isFavorite(
                              _controller.answerCountry!.id,
                            ),
                        isSavingCountry:
                            _controller.answerCountry != null &&
                                _isSavingAtlasCountry,
                        onToggleVisited:
                            _controller.answerCountry == null
                                ? null
                                : () => _toggleAtlasVisited(
                                      _controller.answerCountry!,
                                    ),
                        onToggleWishlist:
                            _controller.answerCountry == null
                                ? null
                                : () => _toggleAtlasWishlist(
                                      _controller.answerCountry!,
                                    ),
                        onToggleFavorite:
                            _controller.answerCountry == null
                                ? null
                                : () => _toggleAtlasFavorite(
                                      _controller.answerCountry!,
                                    ),
                        isLastQuestion:
                            _controller
                                .session
                                .isLastQuestion,
                        onNext:
                            _handleNextQuestion,
                      )
                    : _ResultPanel(
                  modeId:
                      question?.modeId ??
                          widget.modeId,
                  difficultyId:
                      widget.difficultyId,
                  isCorrect:
                      _controller
                          .session
                          .isCorrectCountry,
                  isTimeUp:
                      _controller.isTimeUp,
                  lastScore:
                      _controller
                          .session
                          .lastScore,
                  distanceInKilometers:
                      _controller
                          .distanceInKilometers,
                  selectedCountry:
                      _controller
                          .selectedCountry,
                  answerCountry:
                      _controller
                          .answerCountry,
                  countryInfo:
                      _countryInfoFor(
                    _controller
                        .answerCountry,
                  ),
                  answerCapitalName:
                      _controller
                          .answerCapitalName,
                  answerReferencePointName:
                      _controller
                          .answerReferencePointName,
                  answerReferencePointTypeLabel:
                      _controller
                          .answerReferencePointTypeLabel,
                  answerOfficialCapitalName:
                      _controller
                          .answerOfficialCapitalName,
                  usesReferenceOverride:
                      _controller
                          .usesReferenceOverride,
                  countryStatus:
                      _controller.answerCountry == null
                          ? AtlasCountryStatus.none
                          : _atlasProgress.statusFor(
                              _controller.answerCountry!.id,
                            ),
                  countryFavorite: _controller.answerCountry != null &&
                      _atlasProgress.isFavorite(
                        _controller.answerCountry!.id,
                      ),
                  isSavingCountry:
                      _controller.answerCountry != null &&
                          _isSavingAtlasCountry,
                  onToggleVisited:
                      _controller.answerCountry == null
                          ? null
                          : () => _toggleAtlasVisited(
                                _controller.answerCountry!,
                              ),
                  onToggleWishlist:
                      _controller.answerCountry == null
                          ? null
                          : () => _toggleAtlasWishlist(
                                _controller.answerCountry!,
                              ),
                  onToggleFavorite:
                      _controller.answerCountry == null
                          ? null
                          : () => _toggleAtlasFavorite(
                                _controller.answerCountry!,
                              ),
                  isLastQuestion:
                      _controller
                          .session
                          .isLastQuestion,
                  isCollapsed:
                      _isResultPanelCollapsed,
                  onToggleCollapsed:
                      _toggleResultPanel,
                  onNext:
                      _handleNextQuestion,
                      ),
              ),

            if (_showGameOverPanel)
              Positioned.fill(
                child: widget.guidedLevel != null
                    ? _TutorialCompletePanel(
                        onClose: _handleBackToHome,
                      )
                    : _GameOverPanel(
                  totalScore:
                      _controller
                          .session
                          .totalScore,
                  maximumScore:
                      _controller
                          .session
                          .maximumGameScore,
                  missionRecord:
                      _missionRecordLoaded
                          ? _previousMissionRecord
                          : 0,
                  correctAnswers:
                      _controller
                          .correctAnswers,
                  totalQuestions:
                      _controller
                          .session
                          .totalQuestions,
                  averageDistanceInKilometers:
                      _controller
                          .averageDistanceInKilometers,
                  averageElapsedSeconds:
                      _controller
                          .averageElapsedSeconds,
                  bestScore:
                      _controller
                          .bestScore,
                  worstScore:
                      _controller
                          .worstScore,
                  passportResult:
                      _controller
                          .lastPassportResult,
                  missionTitle:
                      widget.missionTitle,
                  earnedStars:
                      _calculateEarnedStars(),
                  earnedXp:
                      _controller
                              .lastLevelResult
                              ?.earnedXp ??
                          0,
                  xpRewards:
                      _controller.lastLevelResult?.rewardBreakdown ??
                          const <PlayerXpRewardSummary>[],
                  playerLevel:
                      _controller
                          .playerProfile
                          .majorLevel,
                  playerTitle:
                      _controller
                          .playerProfile
                          .displayLevelTitle,
                  levelProgress:
                      _controller
                          .playerProfile
                          .levelProgress,
                  isTraining:
                      widget.isTraining,
                  encounteredCountries:
                      _controller.encounteredCountries,
                  atlasProgress:
                      _atlasProgress,
                  savingAtlasCountryIds:
                      _savingAtlasCountryIds,
                  onToggleVisited:
                      _toggleAtlasVisited,
                  onToggleWishlist:
                      _toggleAtlasWishlist,
                  onToggleFavorite:
                      _toggleAtlasFavorite,
                  onBackToHome:
                      _handleBackToHome,
                      ),
              ),

            if (stampUnlockEvent != null && stampUnlockCountry != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: PassportStampUnlockOverlay(
                    country: stampUnlockCountry,
                    progress: _controller.passportProgress.progressFor(
                      stampUnlockCountry.id,
                    ),
                  ),
                ),
              ),

            if (_progressNotificationBatch != null)
              Positioned.fill(
                child: _ProgressNotificationOverlay(
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
        ),
      ),
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({
    required this.missionTitle,
    required this.expeditionLabel,
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.totalScore,
    required this.secondsRemaining,
    required this.showTimer,
    required this.onClose,
  });

  final String missionTitle;
  final String expeditionLabel;

  final GameQuestion? question;
  final int questionNumber;
  final int totalQuestions;
  final int totalScore;
  final int secondsRemaining;
  final bool showTimer;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final String questionPrompt =
        question?.prompt ??
            'Chargement...';

    final bool isUrgent =
        secondsRemaining <= 5;

    final bool isCritical =
        secondsRemaining <= 3;

    final Color timerColor =
        isCritical
            ? const Color(0xFFFF5C5C)
            : isUrgent
                ? const Color(0xFFFFD166)
                : Colors.white;

    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 560,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: GeoColors.navy.withValues(alpha: 0.94),
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: GeoColors.blue.withValues(alpha: 0.58),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.18,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  tooltip:
                      'Retour à l’accueil',
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),

                const GeoCompassLogo(size: 35, showShadow: false),

                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisSize:
                        MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${expeditionLabel.toUpperCase()} • '
                        '${missionTitle.toUpperCase()}',
                        style: GoogleFonts.nunitoSans(
                          color: GeoColors.sky,
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        'QUESTION '
                        '$questionNumber / '
                        '$totalQuestions',
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white
                              .withValues(
                            alpha: 0.56,
                          ),
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                if (showTimer) ...<Widget>[
                  Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.timer_outlined,
                        color: timerColor,
                        size: 20,
                      ),
                      Text(
                        '$secondsRemaining',
                        style: GoogleFonts.fredoka(
                          color: timerColor,
                          fontSize: 23,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      Text(
                        'SEC.',
                        style: GoogleFonts.nunitoSans(
                          color: timerColor
                              .withValues(alpha: 0.78),
                          fontSize: 9,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                ],

                Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '$totalScore',
                      style: GoogleFonts.fredoka(
                        color: GeoColors.gold,
                        fontSize: 21,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    Text(
                      'POINTS',
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white
                            .withValues(
                          alpha: 0.66,
                        ),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            if (question?.isFindFlag == true)
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    question!.flagEmoji,
                    style: const TextStyle(
                      fontSize: 42,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      questionPrompt.toUpperCase(),
                      softWrap: true,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: 2,
                ),
                child: Text(
                  questionPrompt.toUpperCase(),
                  softWrap: true,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TutorialResultPanel
    extends StatelessWidget {
  const _TutorialResultPanel({
    required this.modeId,
    required this.isCorrect,
    required this.answerCountry,
    required this.answerCapitalName,
    required this.countryStatus,
    required this.countryFavorite,
    required this.isSavingCountry,
    required this.onToggleVisited,
    required this.onToggleWishlist,
    required this.onToggleFavorite,
    required this.isLastQuestion,
    required this.onNext,
  });

  final String modeId;
  final bool isCorrect;
  final GeoCountry? answerCountry;
  final String? answerCapitalName;
  final AtlasCountryStatus countryStatus;
  final bool countryFavorite;
  final bool isSavingCountry;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onToggleWishlist;
  final VoidCallback? onToggleFavorite;
  final bool isLastQuestion;
  final VoidCallback onNext;

  String get _answerLabel {
    if (modeId == 'find_capital' &&
        answerCapitalName != null) {
      return 'La capitale était : $answerCapitalName';
    }

    return 'La réponse était : ${answerCountry?.name ?? '—'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10263E)
            .withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFF63E276)
              : const Color(0xFFFFD166),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.28,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.lightbulb_rounded,
                color: isCorrect
                    ? const Color(0xFF63E276)
                    : const Color(0xFFFFD166),
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isCorrect
                          ? 'Bravo !'
                          : 'Ce n’est pas grave',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _answerLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.72,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (answerCountry != null &&
              onToggleVisited != null &&
              onToggleWishlist != null &&
              onToggleFavorite != null) ...<Widget>[
            _GameTravelActions(
              status: countryStatus,
              favorite: countryFavorite,
              busy: isSavingCountry,
              onToggleVisited: onToggleVisited!,
              onToggleWishlist: onToggleWishlist!,
              onToggleFavorite: onToggleFavorite!,
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNext,
              icon: Icon(
                isLastQuestion
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
              ),
              label: Text(
                isLastQuestion
                    ? 'TERMINER LE TUTORIEL'
                    : 'QUESTION SUIVANTE',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactAnswerLabel extends StatelessWidget {
  const _CompactAnswerLabel({
    required this.eyebrow,
    required this.flag,
    required this.name,
    required this.color,
    this.alignEnd = false,
  });

  final String eyebrow;
  final String flag;
  final String name;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow,
          maxLines: 1,
          style: TextStyle(
            color: color.withValues(alpha: 0.82),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.45,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${flag.isEmpty ? '' : '$flag '}$name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.modeId,
    required this.difficultyId,
    required this.isCorrect,
    required this.isTimeUp,
    required this.lastScore,
    required this.distanceInKilometers,
    required this.selectedCountry,
    required this.answerCountry,
    required this.countryInfo,
    required this.answerCapitalName,
    required this.answerReferencePointName,
    required this.answerReferencePointTypeLabel,
    required this.answerOfficialCapitalName,
    required this.usesReferenceOverride,
    required this.countryStatus,
    required this.countryFavorite,
    required this.isSavingCountry,
    required this.onToggleVisited,
    required this.onToggleWishlist,
    required this.onToggleFavorite,
    required this.isLastQuestion,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onNext,
  });

  final String modeId;
  final String difficultyId;
  final bool isCorrect;
  final bool isTimeUp;
  final int lastScore;

  final double? distanceInKilometers;

  final GeoCountry? selectedCountry;
  final GeoCountry? answerCountry;
  final CountryInfo? countryInfo;

  final String? answerCapitalName;
  final String? answerReferencePointName;
  final String? answerReferencePointTypeLabel;
  final String? answerOfficialCapitalName;

  final bool usesReferenceOverride;
  final AtlasCountryStatus countryStatus;
  final bool countryFavorite;
  final bool isSavingCountry;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onToggleWishlist;
  final VoidCallback? onToggleFavorite;
  final bool isLastQuestion;
  final bool isCollapsed;

  final VoidCallback onToggleCollapsed;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final double? distance =
        distanceInKilometers;

    final String resultTitle;

    final bool isCapitalMode =
        modeId == 'find_capital';

    final bool isFlagMode =
        modeId == 'find_flag';

    final bool isCountryMode =
        modeId == 'find_country';

    if (isTimeUp) {
      resultTitle = 'Temps écoulé !';
    } else if (isCorrect) {
      if (isCapitalMode) {
        resultTitle = 'Capitale trouvée !';
      } else if (isFlagMode) {
        resultTitle = 'Drapeau reconnu !';
      } else {
        resultTitle = 'Bonne réponse !';
      }
    } else {
      if (isCapitalMode) {
        resultTitle =
            'Trop loin de la capitale !';
      } else if (isFlagMode) {
        resultTitle =
            'Ce n’était pas le bon pays !';
      } else {
        resultTitle = 'Mauvais pays !';
      }
    }

    final Color resultColor;

    if (isTimeUp) {
      resultColor =
          const Color(0xFFFF5C5C);
    } else if (isCorrect) {
      resultColor =
          const Color(0xFF80ED99);
    } else {
      resultColor =
          const Color(0xFFFFD166);
    }

    final String selectedCountryName =
        selectedCountry?.displayNameWithFlag ??
            '🌊 Océan';

    final String compactSelectedCountryName =
        selectedCountry?.name.trim().isNotEmpty == true
            ? selectedCountry!.name.trim()
            : 'Océan';

    final String selectedFlag = FlagEmoji.fromIsoA2(
      selectedCountry?.isoA2 ?? '',
    );

    final String infoTitle =
        countryInfo?.title.trim() ?? '';

    final String countryName =
        infoTitle.isNotEmpty
            ? infoTitle
            : answerCountry?.name ??
                'Pays inconnu';

    final String flag =
        FlagEmoji.fromIsoA2(
      answerCountry?.isoA2 ?? '',
    );

    final String infoContinent =
        countryInfo?.continent.trim() ?? '';

    final String continentName =
        infoContinent.isNotEmpty
            ? infoContinent
            : answerCountry?.continent
                    .trim() ??
                '';

    final String savedFact =
        countryInfo?.shortFact?.trim() ?? '';

    final String pedagogicalFact =
        savedFact.isNotEmpty
            ? savedFact
            : continentName.isNotEmpty
                ? '$countryName se situe en '
                    '$continentName.'
                : 'Observe bien sa position '
                    'sur la carte pour mieux '
                    'la mémoriser.';

    final String distanceText =
        distance == null
            ? ''
            : '${distance.round()} km';

    final String capitalName =
        (
          answerOfficialCapitalName ??
          answerCapitalName ??
          ''
        ).trim();

    final String referencePointName =
        answerReferencePointName
                ?.trim() ??
            '';

    final String referenceType =
        answerReferencePointTypeLabel
                ?.trim() ??
            'Point de référence';

    final String capitalPrecisionLabel =
        isCapitalMode && distance != null
            ? _capitalPrecisionLabel(
                distance,
              )
            : '';

    final String capitalToleranceText =
        isCapitalMode
            ? 'Tolérance de validation : '
                '${_capitalValidationRadiusKm().round()} km'
            : '';

    final double maxPanelHeight =
        (MediaQuery.sizeOf(context).height *
                0.62)
            .clamp(330.0, 550.0)
            .toDouble();

    if (isCollapsed) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 520,
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: GeoColors.navy.withValues(alpha: 0.94),
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color: GeoColors.blue.withValues(alpha: 0.48),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.22,
                ),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    isCorrect
                        ? Icons.check_circle
                        : isTimeUp
                            ? Icons.timer_off
                            : Icons.info,
                    color: resultColor,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          resultTitle,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: resultColor,
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+$lastScore',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleCollapsed,
                    tooltip: 'Rouvrir la fiche',
                    icon: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: resultColor.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _CompactAnswerLabel(
                        eyebrow: isCorrect ? 'TA RÉPONSE' : 'TON CHOIX',
                        flag: selectedFlag,
                        name: compactSelectedCountryName,
                        color: isCorrect
                            ? const Color(0xFF80ED99)
                            : const Color(0xFFFFD166),
                      ),
                    ),
                    if (distanceText.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: GeoColors.blue.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: GeoColors.sky.withValues(alpha: 0.48),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.straighten_rounded,
                              color: GeoColors.sky,
                              size: 15,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              distanceText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 7),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white54,
                          size: 19,
                        ),
                      ),
                    Expanded(
                      child: _CompactAnswerLabel(
                        eyebrow: 'RÉPONSE',
                        flag: flag,
                        name: countryName,
                        color: const Color(0xFF80ED99),
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNext,
                  icon: Icon(
                    isLastQuestion
                        ? Icons.emoji_events
                        : Icons.arrow_forward,
                  ),
                  label: Text(
                    isLastQuestion
                        ? 'VOIR LES RÉSULTATS'
                        : 'QUESTION SUIVANTE',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: maxPanelHeight,
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              GeoColors.navy.withValues(alpha: 0.97),
              const Color(0xFF0B2A55).withValues(alpha: 0.97),
            ],
          ),
          borderRadius:
              BorderRadius.circular(26),
          border: Border.all(
            color: resultColor.withValues(alpha: 0.54),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.22,
              ),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: resultColor.withValues(alpha: 0.52),
                    ),
                  ),
                  child: Icon(
                    isCorrect
                        ? Icons.check_rounded
                        : isTimeUp
                            ? Icons.timer_off_rounded
                            : Icons.close_rounded,
                    color: resultColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    resultTitle,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 21,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleCollapsed,
                  tooltip: 'Réduire la fiche',
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),

            if (capitalPrecisionLabel.isNotEmpty)
              ...<Widget>[
                const SizedBox(height: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _capitalPrecisionColor(
                      distance!,
                    ).withValues(
                      alpha: 0.16,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    border: Border.all(
                      color:
                          _capitalPrecisionColor(
                        distance,
                      ).withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                  child: Text(
                    capitalPrecisionLabel,
                    style: TextStyle(
                      color:
                          _capitalPrecisionColor(
                        distance,
                      ),
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],

            const SizedBox(height: 9),

            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: <Widget>[
                    if (!isCapitalMode &&
                        !isCorrect &&
                        !isTimeUp)
                      ...<Widget>[
                        Text(
                          'Tu as choisi :',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            color: Colors.white
                                .withValues(
                              alpha: 0.70,
                            ),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          selectedCountryName,
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color: Color(
                              0xFFFFD166,
                            ),
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        const SizedBox(
                          height: 9,
                        ),
                      ],

                    Text(
                      isCapitalMode
                          ? isCorrect
                              ? 'Tu as localisé :'
                              : 'La capitale était :'
                          : isFlagMode
                              ? isCorrect
                                  ? 'Ce drapeau appartient à :'
                                  : 'Le drapeau appartenait à :'
                              : isCorrect
                                  ? 'Tu as trouvé :'
                                  : 'La bonne réponse était :',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color: Colors.white
                            .withValues(
                          alpha: 0.70,
                        ),
                        fontSize: 14,
                      ),
                    ),

                    if (isCapitalMode &&
                        capitalName.isNotEmpty)
                      ...<Widget>[
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          capitalName,
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],

                    const SizedBox(height: 7),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: <Widget>[
                        if (flag.isNotEmpty)
                          ...<Widget>[
                            Text(
                              flag,
                              style:
                                  const TextStyle(
                                fontSize: 38,
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                          ],
                        Flexible(
                          child: Text(
                            countryName,
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (usesReferenceOverride &&
                        referencePointName
                            .isNotEmpty)
                      ...<Widget>[
                        const SizedBox(height: 8),
                        _ResultInformationRow(
                          icon: Icons
                              .location_on_outlined,
                          label: referenceType,
                          value:
                              referencePointName,
                        ),
                      ],

                    if (!isCapitalMode &&
                        capitalName.isNotEmpty)
                      ...<Widget>[
                        const SizedBox(height: 7),
                        _ResultInformationRow(
                          icon:
                              Icons.location_city,
                          label:
                              usesReferenceOverride
                                  ? 'Capitale officielle'
                                  : 'Capitale',
                          value: capitalName,
                        ),
                      ],

                    if (continentName.isNotEmpty)
                      ...<Widget>[
                        const SizedBox(height: 7),
                        _ResultInformationRow(
                          icon: Icons.public,
                          label: 'Continent',
                          value: continentName,
                        ),
                      ],

                    if (distanceText.isNotEmpty &&
                        !((isCountryMode ||
                                isFlagMode) &&
                            isCorrect))
                      ...<Widget>[
                        const SizedBox(height: 7),
                        _ResultInformationRow(
                          icon: Icons.straighten,
                          label: 'Distance',
                          value: distanceText,
                        ),
                      ],

                    if (capitalToleranceText
                        .isNotEmpty)
                      ...<Widget>[
                        const SizedBox(height: 7),
                        _ResultInformationRow(
                          icon:
                              Icons.adjust_rounded,
                          label: 'Niveau',
                          value:
                              capitalToleranceText,
                        ),
                      ],

                    const SizedBox(height: 7),

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF53D8FF,
                        ).withValues(
                          alpha: 0.11,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFF53D8FF,
                          ).withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.lightbulb_outline,
                            color: Color(
                              0xFF53D8FF,
                            ),
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: <Widget>[
                                Text(
                                  savedFact.isNotEmpty
                                      ? 'LE SAVAIS-TU ?'
                                      : 'À RETENIR',
                                  style:
                                      const TextStyle(
                                    color: Color(
                                      0xFF53D8FF,
                                    ),
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  pedagogicalFact,
                                  style:
                                      const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.3,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (answerCountry != null &&
                onToggleVisited != null &&
                onToggleWishlist != null &&
                onToggleFavorite != null) ...<Widget>[
              const SizedBox(height: 10),
              _GameTravelActions(
                status: countryStatus,
                favorite: countryFavorite,
                busy: isSavingCountry,
                onToggleVisited: onToggleVisited!,
                onToggleWishlist: onToggleWishlist!,
                onToggleFavorite: onToggleFavorite!,
              ),
            ],

            const SizedBox(height: 10),

            Text(
              '+$lastScore points',
              style: const TextStyle(
                color:
                    Color(0xFFFFD166),
                fontSize: 22,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 13),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNext,
                icon: Icon(
                  isLastQuestion
                      ? Icons.emoji_events
                      : Icons.arrow_forward,
                ),
                label: Text(
                  isLastQuestion
                      ? 'VOIR LES RÉSULTATS'
                      : 'QUESTION SUIVANTE',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  double _capitalValidationRadiusKm() {
    switch (difficultyId) {
      case 'discovery':
        return 300;

      case 'easy':
        return 220;

      case 'intermediate':
        return 150;

      case 'hard':
        return 90;

      case 'expert':
        return 50;

      default:
        return 220;
    }
  }

  String _capitalPrecisionLabel(
    double distance,
  ) {
    if (distance <= 20) {
      return '🎯 Parfait';
    }

    if (distance <= 50) {
      return '🥇 Excellent';
    }

    if (distance <= 100) {
      return '🥈 Très bien';
    }

    if (distance <= 200) {
      return '🥉 Bien';
    }

    if (distance <= 300) {
      return '👍 Correct';
    }

    if (distance <= 500) {
      return '📚 À renforcer';
    }

    return '🧭 À revoir';
  }

  Color _capitalPrecisionColor(
    double distance,
  ) {
    if (distance <= 50) {
      return const Color(0xFF80ED99);
    }

    if (distance <= 200) {
      return const Color(0xFF53D8FF);
    }

    if (distance <= 300) {
      return const Color(0xFFFFD166);
    }

    return const Color(0xFFFF9F68);
  }

}

class _GameTravelActions extends StatelessWidget {
  const _GameTravelActions({
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
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _GameTravelButton(
                label: 'VISITÉ',
                icon: Icons.flight_takeoff_rounded,
                active: status == AtlasCountryStatus.visited,
                activeColor: const Color(0xFF55D6A6),
                busy: busy,
                onPressed: onToggleVisited,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GameTravelButton(
                label: 'À VISITER',
                icon: Icons.bookmark_rounded,
                active: status == AtlasCountryStatus.wishlist,
                activeColor: const Color(0xFFFF756B),
                busy: busy,
                onPressed: onToggleWishlist,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          width: double.infinity,
          child: _GameTravelButton(
            label: 'FAVORI',
            icon: Icons.favorite_rounded,
            active: favorite,
            activeColor: const Color(0xFFFFCE59),
            busy: busy,
            onPressed: onToggleFavorite,
          ),
        ),
      ],
    );
  }
}

class _GameTravelButton extends StatelessWidget {
  const _GameTravelButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: active
            ? activeColor
            : Colors.white.withValues(alpha: 0.10),
        foregroundColor: active ? GeoColors.navy : Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: active ? activeColor : Colors.white24,
          ),
        ),
        elevation: 0,
      ),
      icon: busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 17),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}


class _ResultInformationRow
    extends StatelessWidget {
  const _ResultInformationRow({
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
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color:
                const Color(0xFF80ED99),
            size: 19,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white
                        .withValues(
                      alpha: 0.58,
                    ),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
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

class _TutorialCompletePanel
    extends StatelessWidget {
  const _TutorialCompletePanel({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.74),
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            margin: const EdgeInsets.all(22),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF10263E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF63E276),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF63E276),
                  size: 62,
                ),
                const SizedBox(height: 12),
                const Text(
                  'TUTORIEL TERMINÉ !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu sais maintenant déplacer la carte, '
                  'zoomer et placer ta réponse.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.76,
                    ),
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.rocket_launch_rounded,
                    ),
                    label: const Text(
                      'CHOISIR UNE EXPÉDITION',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressNotificationOverlay extends StatelessWidget {
  const _ProgressNotificationOverlay({
    required this.batch,
    required this.onContinue,
  });

  final PassportProgressNotificationBatch batch;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: GeoColors.navy.withValues(alpha: 0.88),
      child: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            tween: Tween<double>(begin: 0.82, end: 1),
            builder: (BuildContext context, double value, Widget? child) {
              return Transform.scale(
                scale: value,
                child: Opacity(opacity: value.clamp(0, 1), child: child),
              );
            },
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.sizeOf(context).height * 0.84,
              ),
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FF),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: GeoColors.gold.withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: GeoColors.ink,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'BELLE PROGRESSION !',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(
                      color: GeoColors.ink,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    batch.items.length == 1
                        ? 'Une nouveauté rejoint ton Passeport.'
                        : '${batch.items.length} nouveautés réunies dans ton Passeport.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 17),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: batch.items.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 9);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return _ProgressNotificationRow(
                          item: batch.items[index],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 17),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onContinue,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('VOIR MES RÉSULTATS'),
                      style: FilledButton.styleFrom(
                        backgroundColor: GeoColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: GoogleFonts.fredoka(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressNotificationRow extends StatelessWidget {
  const _ProgressNotificationRow({required this.item});

  final PassportProgressNotification item;

  @override
  Widget build(BuildContext context) {
    final Color color = _notificationColor(item.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _notificationIcon(item.type),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title.toUpperCase(),
                  style: GoogleFonts.nunitoSans(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 16,
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

Color _notificationColor(PassportProgressNotificationType type) {
  switch (type) {
    case PassportProgressNotificationType.stamp:
      return GeoColors.blue;
    case PassportProgressNotificationType.mastery:
      return const Color(0xFF18A879);
    case PassportProgressNotificationType.level:
      return GeoColors.gold;
    case PassportProgressNotificationType.title:
      return GeoColors.purple;
    case PassportProgressNotificationType.collection:
      return GeoColors.coral;
    case PassportProgressNotificationType.achievement:
      return const Color(0xFFDD7B14);
  }
}

IconData _notificationIcon(PassportProgressNotificationType type) {
  switch (type) {
    case PassportProgressNotificationType.stamp:
      return Icons.approval_rounded;
    case PassportProgressNotificationType.mastery:
      return Icons.school_rounded;
    case PassportProgressNotificationType.level:
      return Icons.trending_up_rounded;
    case PassportProgressNotificationType.title:
      return Icons.workspace_premium_rounded;
    case PassportProgressNotificationType.collection:
      return Icons.redeem_rounded;
    case PassportProgressNotificationType.achievement:
      return Icons.emoji_events_rounded;
  }
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({
    required this.missionTitle,
    required this.totalScore,
    required this.maximumScore,
    required this.missionRecord,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.averageDistanceInKilometers,
    required this.averageElapsedSeconds,
    required this.bestScore,
    required this.worstScore,
    required this.passportResult,
    required this.earnedStars,
    required this.earnedXp,
    required this.xpRewards,
    required this.playerLevel,
    required this.playerTitle,
    required this.levelProgress,
    required this.isTraining,
    required this.encounteredCountries,
    required this.atlasProgress,
    required this.savingAtlasCountryIds,
    required this.onToggleVisited,
    required this.onToggleWishlist,
    required this.onToggleFavorite,
    required this.onBackToHome,
  });

  final String missionTitle;
  final int totalScore;
  final int maximumScore;
  final int missionRecord;

  final int correctAnswers;
  final int totalQuestions;

  final double averageDistanceInKilometers;
  final double averageElapsedSeconds;

  final int bestScore;
  final int worstScore;

  final PassportResult? passportResult;

  final int earnedStars;
  final int earnedXp;
  final List<PlayerXpRewardSummary> xpRewards;
  final int playerLevel;
  final String playerTitle;
  final double levelProgress;
  final bool isTraining;

  final List<GeoCountry> encounteredCountries;
  final AtlasPersonalProgress atlasProgress;
  final Set<String> savingAtlasCountryIds;
  final Future<void> Function(GeoCountry) onToggleVisited;
  final Future<void> Function(GeoCountry) onToggleWishlist;
  final Future<void> Function(GeoCountry) onToggleFavorite;

  final VoidCallback onBackToHome;

  String _getRank() {
    if (totalScore >= 1151) {
      return 'Légende PointGeo';
    }

    if (totalScore >= 1001) {
      return 'Maître cartographe';
    }

    if (totalScore >= 801) {
      return 'Expert';
    }

    if (totalScore >= 601) {
      return 'Géographe';
    }

    if (totalScore >= 401) {
      return 'Aventurier';
    }

    if (totalScore >= 201) {
      return 'Explorateur';
    }

    return 'Voyageur débutant';
  }

  String _starText(
    int stars,
  ) {
    final int normalizedStars =
        stars.clamp(0, 3);

    return '${'★' * normalizedStars}'
        '${'☆' * (3 - normalizedStars)}';
  }

  @override
  Widget build(BuildContext context) {
    final int displayedRecord =
        totalScore > missionRecord
            ? totalScore
            : missionRecord;

    final bool isNewRecord =
        totalScore > missionRecord;

    final String rank =
        _getRank();

    final bool hasMedalUpgrade =
        passportResult?.hasMedalUpgrade ==
            true;

    final String medalLabel =
        passportResult?.newMedal.label
            ?? '';

    final Set<String> displayedCountryIds = <String>{};
    final List<GeoCountry> displayedCountries = encounteredCountries.where(
      (GeoCountry country) {
        final String id = country.id.trim().toUpperCase();
        return id.isNotEmpty && displayedCountryIds.add(id);
      },
    ).toList(growable: false);

    return ColoredBox(
      color: Colors.black.withValues(
        alpha: 0.72,
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(20),
            child: Container(
              constraints:
                  const BoxConstraints(
                maxWidth: 520,
              ),
              padding:
                  const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF16202A,
                ),
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
                border: Border.all(
                  color: Colors.white
                      .withValues(
                    alpha: 0.25,
                  ),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black
                        .withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: 20,
                    offset:
                        const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: <Widget>[
                  const GeoCompassLogo(size: 66),

                  const SizedBox(height: 8),

                  Text(
                    isTraining
                        ? 'ENTRAÎNEMENT TERMINÉ'
                        : 'PARTIE TERMINÉE',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (!isTraining) ...<Widget>[
                    Text(
                      _starText(
                        earnedStars,
                      ),
                      textAlign:
                          TextAlign.center,
                      style: const TextStyle(
                        color: Color(
                          0xFFFFD166,
                        ),
                        fontSize: 34,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 13),
                  ],

                  Text(
                    '$totalScore / '
                    '$maximumScore',
                    textAlign:
                        TextAlign.center,
                    style: const TextStyle(
                      color: Color(
                        0xFFFFD166,
                      ),
                      fontSize: 34,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    rank,
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF80ED99),
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (isTraining)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF55D6A6)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF55D6A6)
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.gps_fixed_rounded,
                            color: Color(0xFF55D6A6),
                          ),
                          SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              'SESSION LIBRE • PROGRESSION INCHANGÉE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF55D6A6),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFFD166,
                      ).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFFFFD166,
                        ).withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(
                            0xFFFFD166,
                          ),
                          size: 23,
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            isNewRecord
                                ? 'NOUVEAU RECORD : '
                                    '$displayedRecord pts'
                                : 'RECORD : '
                                    '$displayedRecord pts',
                            textAlign:
                                TextAlign.center,
                            style: const TextStyle(
                              color: Color(
                                0xFFFFD166,
                              ),
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!isTraining &&
                      hasMedalUpgrade &&
                      medalLabel.isNotEmpty)
                    ...<Widget>[
                      const SizedBox(
                        height: 16,
                      ),

                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(
                          13,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFFFD166,
                          ).withValues(
                            alpha: 0.13,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                          border: Border.all(
                            color:
                                const Color(
                              0xFFFFD166,
                            ).withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            const Text(
                              '🛂 NOUVEAU TAMPON',
                              style: TextStyle(
                                color: Color(
                                  0xFFFFD166,
                                ),
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              '$missionTitle — $medalLabel',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                  if (!isTraining) ...<Widget>[
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withValues(
                        alpha: 0.07,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.auto_awesome,
                              color: Color(
                                0xFF53D8FF,
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child: Text(
                                'Niveau $playerLevel '
                                '• $playerTitle',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '+$earnedXp XP',
                              style: const TextStyle(
                                color: Color(0xFF80ED99),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                          child:
                              LinearProgressIndicator(
                            value:
                                levelProgress,
                            minHeight: 9,
                            backgroundColor:
                                Colors.white
                                    .withValues(
                              alpha: 0.13,
                            ),
                            valueColor:
                                const AlwaysStoppedAnimation<
                                    Color>(
                              Color(
                                0xFF53D8FF,
                              ),
                            ),
                          ),
                        ),
                        if (xpRewards.length > 1) ...<Widget>[
                          const SizedBox(height: 10),
                          ...xpRewards.map(
                            (PlayerXpRewardSummary reward) => Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      reward.label,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '+${reward.xp} XP',
                                    style: const TextStyle(
                                      color: Color(0xFF80ED99),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ],

                  const SizedBox(height: 18),

                  _StatisticRow(
                    icon:
                        Icons.check_circle,
                    label:
                        'Bonnes réponses',
                    value:
                        '$correctAnswers / '
                        '$totalQuestions',
                  ),

                  _StatisticRow(
                    icon:
                        Icons.timer_outlined,
                    label:
                        'Temps moyen',
                    value:
                        '${averageElapsedSeconds.toStringAsFixed(1)} s',
                  ),

                  _StatisticRow(
                    icon:
                        Icons.location_on,
                    label:
                        'Distance moyenne',
                    value:
                        '${averageDistanceInKilometers.round()} km',
                  ),

                  _StatisticRow(
                    icon:
                        Icons.trending_up,
                    label:
                        'Meilleure question',
                    value:
                        '$bestScore points',
                  ),

                  _StatisticRow(
                    icon:
                        Icons.trending_down,
                    label:
                        'Plus faible score',
                    value:
                        '$worstScore points',
                  ),

                  if (displayedCountries.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PAYS RENCONTRÉS',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    _MissionTravelCountries(
                      countries: displayedCountries,
                      progress: atlasProgress,
                      savingCountryIds: savingAtlasCountryIds,
                      onToggleVisited: onToggleVisited,
                      onToggleWishlist: onToggleWishlist,
                      onToggleFavorite: onToggleFavorite,
                    ),
                  ],

                  const SizedBox(height: 18),

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        FilledButton.icon(
                      onPressed:
                          onBackToHome,
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                      ),
                      label: const Text(
                        'CONTINUER',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissionTravelCountries extends StatelessWidget {
  const _MissionTravelCountries({
    required this.countries,
    required this.progress,
    required this.savingCountryIds,
    required this.onToggleVisited,
    required this.onToggleWishlist,
    required this.onToggleFavorite,
  });

  final List<GeoCountry> countries;
  final AtlasPersonalProgress progress;
  final Set<String> savingCountryIds;
  final Future<void> Function(GeoCountry) onToggleVisited;
  final Future<void> Function(GeoCountry) onToggleWishlist;
  final Future<void> Function(GeoCountry) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < countries.length; index++) ...<Widget>[
            _MissionTravelCountryRow(
              country: countries[index],
              status: progress.statusFor(countries[index].id),
              favorite: progress.isFavorite(countries[index].id),
              busy: savingCountryIds.isNotEmpty,
              onToggleVisited: () => onToggleVisited(countries[index]),
              onToggleWishlist: () => onToggleWishlist(countries[index]),
              onToggleFavorite: () => onToggleFavorite(countries[index]),
            ),
            if (index < countries.length - 1)
              const Divider(height: 1, color: Colors.white12),
          ],
        ],
      ),
    );
  }
}

class _MissionTravelCountryRow extends StatelessWidget {
  const _MissionTravelCountryRow({
    required this.country,
    required this.status,
    required this.favorite,
    required this.busy,
    required this.onToggleVisited,
    required this.onToggleWishlist,
    required this.onToggleFavorite,
  });

  final GeoCountry country;
  final AtlasCountryStatus status;
  final bool favorite;
  final bool busy;
  final VoidCallback onToggleVisited;
  final VoidCallback onToggleWishlist;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 7, 7),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              country.displayNameWithFlag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _MissionStatusButton(
            icon: Icons.flight_takeoff_rounded,
            tooltip: 'Pays visité',
            active: status == AtlasCountryStatus.visited,
            activeColor: const Color(0xFF55D6A6),
            busy: busy,
            onPressed: onToggleVisited,
          ),
          const SizedBox(width: 4),
          _MissionStatusButton(
            icon: Icons.bookmark_rounded,
            tooltip: 'À visiter',
            active: status == AtlasCountryStatus.wishlist,
            activeColor: const Color(0xFFFF756B),
            busy: busy,
            onPressed: onToggleWishlist,
          ),
          const SizedBox(width: 4),
          _MissionStatusButton(
            icon: Icons.favorite_rounded,
            tooltip: 'Favori',
            active: favorite,
            activeColor: const Color(0xFFFFCE59),
            busy: busy,
            onPressed: onToggleFavorite,
          ),
        ],
      ),
    );
  }
}

class _MissionStatusButton extends StatelessWidget {
  const _MissionStatusButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.activeColor,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final Color activeColor;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: busy ? null : onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: active
              ? activeColor
              : Colors.white.withValues(alpha: 0.08),
          foregroundColor: active ? GeoColors.navy : Colors.white70,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
          padding: EdgeInsets.zero,
        ),
        icon: busy
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
      ),
    );
  }
}

class _StatisticRow extends StatelessWidget {
  const _StatisticRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color:
                const Color(0xFFFFD166),
            size: 21,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white
                    .withValues(
                  alpha: 0.78,
                ),
                fontSize: 15,
              ),
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
