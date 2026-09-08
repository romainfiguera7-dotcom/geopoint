import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../challenges/challenge_server_connection.dart';
import '../challenges/challenge_pack_cache_storage.dart';
import '../challenges/challenge_result.dart';
import '../challenges/challenge_storage.dart';
import '../app/geopoint_features.dart';
import '../features/atlas/atlas_personal_progress.dart';
import '../features/atlas/atlas_personal_storage.dart';
import '../features/exploration/france/national_expedition_storage.dart';
import '../features/settings/gameplay_feedback.dart';
import '../geo_engine/capital.dart';
import '../geo_engine/capital_loader.dart';
import '../geo_engine/geo_country.dart';
import '../geo_engine/reference_point.dart';
import '../geo_engine/reference_point_loader.dart';
import '../geobrain/country_selector.dart';
import '../geobrain/geobrain_difficulty_adapter.dart';
import '../geobrain/geobrain_attempt.dart';
import '../geobrain/geobrain_service.dart';
import '../geobrain/geobrain_theme.dart';
import '../player/level_result.dart';
import '../player/player_identity_service.dart';
import '../player/player_identity_storage.dart';
import '../player/player_online_identity.dart';
import '../player/player_online_link_service.dart';
import '../player/player_profile.dart';
import '../player/player_statistics.dart';
import '../player/player_storage.dart';
import '../player/player_xp_debug_tools.dart';
import '../player/player_xp_ledger.dart';
import '../player/xp_system.dart';
import '../server/geopoint_server_contract.dart';
import '../passport/achievements/passport_achievement.dart';
import '../passport/achievements/passport_achievement_catalog.dart';
import '../passport/progress/passport_entity_progress.dart';
import '../passport/progress/passport_continent.dart';
import '../passport/progress/passport_progress_coordinator.dart';
import '../passport/progress/passport_progress_rules.dart';
import '../passport/progress/passport_progress_storage.dart';
import '../passport/progress/passport_progress_v2.dart';
import '../passport/progress/passport_stamp_unlock_event.dart';
import '../passport/achievements/passport_achievement_progress.dart';
import '../passport/achievements/passport_achievement_snapshot_builder.dart';
import '../passport/achievements/passport_achievement_storage.dart';
import 'continent/continent_expedition.dart';
import 'continent/continent_progress.dart';
import 'continent/continent_storage.dart';
import 'country_difficulty_loader.dart';
import 'expedition/expedition_progress.dart';
import 'expedition/expedition_storage.dart';
import 'game_difficulty.dart';
import 'game_difficulty_loader.dart';
import 'game_engine.dart';
import 'game_question.dart';
import 'game_session.dart';
import 'learning/guided_level.dart';
import 'passport/passport_engine.dart';
import 'passport/passport_result.dart';
import 'passport/passport_service.dart';
import 'passport/passport_stamp.dart';
import 'passport/passport_storage.dart';
import 'passport/player_passport.dart';
import 'playable_country_policy.dart';
import 'score_system.dart';

class GameController extends ChangeNotifier {
  static const Set<String>
      _completeTrainingExcludedEntityIds =
      <String>{
    'SMR',
  };

  GameController({
    GameEngine? gameEngine,
    ScoreSystem? scoreSystem,
    XpSystem? xpSystem,
  })  : _gameEngine = gameEngine ?? GameEngine(),
        _scoreSystem =
            scoreSystem ?? const ScoreSystem(),
        _xpSystem =
            xpSystem ?? const XpSystem();

  final GameEngine _gameEngine;
  final ScoreSystem _scoreSystem;
  final XpSystem _xpSystem;

  late PassportEngine _passportEngine;
  late PlayerPassport _passport;
  late PlayerProfile _playerProfile;
  late PlayerOnlineIdentity _playerIdentity;
  late GeoBrainService _geoBrainService;
  late PassportProgressV2 _passportProgress;
  late CountrySelector _countrySelector;

  PassportStampUnlockEvent? _latestCountryStampUnlock;
  int _countryStampUnlockSequence = 0;

  Future<void> _passportSynchronizationQueue = Future<void>.value();
  Future<void> _currentGameCompletion = Future<void>.value();

  PassportResult? _lastPassportResult;
  LevelResult? _lastLevelResult;

  int _xpSessionSequence = 0;
  String? _currentXpGrantId;
  Set<String> _xpSeenCountryIdsAtSessionStart = const <String>{};
  Set<String> _xpMasteredCountryIdsAtSessionStart = const <String>{};

  bool _passportResultRegisteredForCurrentGame =
      false;

  List<GeoCountry> _countries =
      const <GeoCountry>[];

  Map<String, Capital> _capitals =
      const <String, Capital>{};

  Map<String, ReferencePoint>
      _referenceOverrides =
      const <String, ReferencePoint>{};

  Map<String, int> _countryDifficulties =
      const <String, int>{};

  Map<String, GameDifficulty> _difficulties =
      const <String, GameDifficulty>{};

  List<GeoCountry> _missionCountries =
      const <GeoCountry>[];

  final List<GeoCountry> _encounteredCountries = <GeoCountry>[];
  final List<GeoCountry> _validatedCountries = <GeoCountry>[];
  final List<QuestionStatisticsResult> _currentGameQuestionResults =
      <QuestionStatisticsResult>[];
  final List<ChallengeAnswerEvidence> _currentChallengeAnswerEvidence =
      <ChallengeAnswerEvidence>[];

  bool _isDisposed = false;

  bool _isTrainingMission = false;
  bool _isChallengeMission = false;
  bool _isCompleteTraining = false;
  int? _trainingQuestionCount;
  String _trainingRegionId = 'world';
  final List<GeoCountry> _completeTrainingQueue = <GeoCountry>[];

  GuidedLevel? _currentGuidedLevel;

  ContinentLevel? _currentContinentLevel;

  final List<GeoCountry> _guidedQuestionQueue =
      <GeoCountry>[];

  String _currentDifficultyId =
      'discovery';

  String _currentModeId =
      'find_country';

  GameSession _session =
      GameSession.initial(
    questionDurationSeconds: 25,
    totalQuestions: 5,
  );

  LatLng? _selectedPoint;
  LatLng? _answerPoint;

  GeoCountry? _selectedCountry;
  GeoCountry? _answerCountry;

  Capital? _answerCapital;
  ReferencePoint? _answerReferencePoint;

  double? _distanceInKilometers;

  Timer? _questionTimer;

  GameSession get session =>
      _session;

  List<ChallengeAnswerEvidence> get currentChallengeAnswerEvidence =>
      List<ChallengeAnswerEvidence>.unmodifiable(
        _currentChallengeAnswerEvidence,
      );

  PlayerPassport get passport =>
      _passport;

  PassportEngine get passportEngine =>
      _passportEngine;

  PassportResult? get lastPassportResult =>
      _lastPassportResult;

  PlayerProfile get playerProfile =>
      _playerProfile;

  PlayerOnlineIdentity get playerIdentity =>
      _playerIdentity;

  LevelResult? get lastLevelResult =>
      _lastLevelResult;

  GeoBrainService get geoBrainService =>
      _geoBrainService;

  PassportProgressV2 get passportProgress =>
      _passportProgress;

  PassportStampUnlockEvent? get latestCountryStampUnlock =>
      _latestCountryStampUnlock;

  Future<void> waitForPassportProgressSynchronization() {
    return _passportSynchronizationQueue;
  }

  Future<void> waitForCurrentGameCompletion() {
    return _waitForCurrentGameCompletionSafely();
  }

  Future<void> _waitForCurrentGameCompletionSafely() async {
    try {
      await _currentGameCompletion;
    } on Object catch (error, stackTrace) {
      debugPrint('GeoPoint : finalisation de partie incomplète : $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _startNewXpSession() {
    _xpSessionSequence++;
    final int startedAtMicroseconds =
        DateTime.now().toUtc().microsecondsSinceEpoch;
    _currentXpGrantId =
        'game-$startedAtMicroseconds-$_xpSessionSequence';
    _currentGameCompletion = Future<void>.value();
    _xpSeenCountryIdsAtSessionStart = Set<String>.unmodifiable(
      _geoBrainService.profile.countries.entries
          .where((entry) => entry.value.hasBeenSeen)
          .map((entry) => entry.key.trim().toUpperCase()),
    );
    _xpMasteredCountryIdsAtSessionStart = Set<String>.unmodifiable(
      _geoBrainService.profile.countries.entries
          .where((entry) => entry.value.isMastered)
          .map((entry) => entry.key.trim().toUpperCase()),
    );
  }

  String _resolveCurrentXpGrantId(DateTime completedAt) {
    final String? currentGrantId = _currentXpGrantId;

    if (currentGrantId != null && currentGrantId.isNotEmpty) {
      return currentGrantId;
    }

    _xpSessionSequence++;
    final String fallbackGrantId =
        'game-${completedAt.toUtc().microsecondsSinceEpoch}-'
        '$_xpSessionSequence';
    _currentXpGrantId = fallbackGrantId;
    return fallbackGrantId;
  }

  List<GeoCountry> get countries =>
      _countries;

  Map<String, Capital> get capitals =>
      _capitals;

  Map<String, int> get countryDifficulties =>
      _countryDifficulties;

  Map<String, ReferencePoint>
      get referenceOverrides =>
          _referenceOverrides;

  String get currentDifficultyId =>
      _currentDifficultyId;

  String get currentModeId =>
      _currentModeId;

  GuidedLevel? get currentGuidedLevel =>
      _currentGuidedLevel;

  ContinentLevel? get currentContinentLevel =>
      _currentContinentLevel;

  bool get isTrainingMission =>
      _isTrainingMission;

  bool get isChallengeMission =>
      _isChallengeMission;

  bool get isCompleteTraining =>
      _isCompleteTraining;

  bool get isGuidedMission =>
      _currentGuidedLevel != null;

  bool get guidedMissionHasTimer =>
      _currentGuidedLevel?.hasTimer ?? true;

  String? get guidedInstruction {
    final GuidedLevel? level =
        _currentGuidedLevel;

    if (level == null || hasAnswered) {
      return null;
    }

    switch (_session.currentQuestion?.modeId) {
      case 'find_capital':
        return 'Touche la zone bleue autour de la capitale';

      case 'find_flag':
        return 'Repère le drapeau puis touche le pays bleu';

      case 'find_country':
        return 'Touche le pays coloré en bleu';

      default:
        return level.instruction;
    }
  }

  String? get guidedHintCountryId {
    if (hasAnswered ||
        _currentGuidedLevel == null) {
      return null;
    }

    final GameQuestion? question =
        _session.currentQuestion;

    if (question == null) {
      return null;
    }

    if (question.modeId == 'find_capital') {
      return null;
    }

    return question.countryId;
  }

  LatLng? get guidedHintPoint {
    if (hasAnswered ||
        _currentGuidedLevel == null) {
      return null;
    }

    final GameQuestion? question =
        _session.currentQuestion;

    if (question == null ||
        question.modeId != 'find_capital') {
      return null;
    }

    final GeoCountry? country =
        _findCountryById(question.countryId);

    if (country == null) {
      return null;
    }

    return _findCapital(country)?.position;
  }

  double? get guidedHintRadiusInKilometers {
    if (guidedHintPoint == null) {
      return null;
    }

    return _capitalValidationRadiusKm();
  }

  double get currentInitialZoom =>
      _currentGuidedLevel?.initialZoom ??
      _currentContinentLevel?.initialZoom ??
      _difficulties[_currentDifficultyId]
          ?.initialZoom ??
      2.0;

  LatLng get currentInitialCenter {
    final GuidedLevel? guidedLevel =
        _currentGuidedLevel;

    if (guidedLevel != null) {
      return guidedLevel.initialCenter;
    }

    final ContinentLevel? continentLevel =
        _currentContinentLevel;

    if (continentLevel != null) {
      return continentLevel.initialCenter;
    }

    /*
     * La camera ne doit jamais utiliser la capitale,
     * le point de reference ou le centre du pays a
     * trouver : ce cadrage revelait presque directement
     * la reponse.
     *
     * Les deux premiers niveaux donnent uniquement un
     * indice continental volontaire. Tous les pays d'un
     * meme continent partagent donc exactement le meme
     * centre. A partir du niveau Intermediaire, la vue de
     * depart est totalement neutre.
     */
    if (_currentDifficultyId !=
            'discovery' &&
        _currentDifficultyId != 'easy') {
      return const LatLng(
        20,
        0,
      );
    }

    final GameQuestion? question =
        _session.currentQuestion;

    if (question == null) {
      return const LatLng(
        20,
        0,
      );
    }

    return _initialCenterForContinent(
      question.continent,
    );
  }

  LatLng _initialCenterForContinent(
    String continent,
  ) {
    final String normalized =
        continent.trim().toLowerCase();

    switch (normalized) {
      case 'afrique':
      case 'africa':
        return const LatLng(5, 20);

      case 'amerique du nord':
      case 'amérique du nord':
      case 'north america':
        return const LatLng(38, -100);

      case 'amerique du sud':
      case 'amérique du sud':
      case 'south america':
        return const LatLng(-18, -60);

      case 'asie':
      case 'asia':
        return const LatLng(34, 90);

      case 'europe':
        return const LatLng(46, 15);

      case 'oceanie':
      case 'océanie':
      case 'oceania':
        return const LatLng(-23, 135);

      case 'antarctique':
      case 'antarctica':
        return const LatLng(-58, 0);

      default:
        return const LatLng(20, 0);
    }
  }

  bool get isFindCapitalMode =>
      _currentModeId == 'find_capital';

  bool get isFindFlagMode =>
      _currentModeId == 'find_flag';

  bool get isMixedMode =>
      _currentModeId == 'mixed';

  int get totalQuestions =>
      _session.totalQuestions;

  int get questionDurationSeconds =>
      _session.questionDurationSeconds;

  int get availableCountryCount =>
      _missionCountries.length;

  List<GeoCountry> get encounteredCountries =>
      List<GeoCountry>.unmodifiable(_encounteredCountries);

  List<GeoCountry> get validatedCountries =>
      List<GeoCountry>.unmodifiable(_validatedCountries);

  int availableTrainingCountryCount({
    required String difficultyId,
    required String modeId,
    required String regionId,
    required bool completeRegion,
    Set<String>? allowedCountryIds,
  }) {
    final String normalizedDifficulty = difficultyId.trim().toLowerCase();
    final String resolvedDifficulty =
        _difficulties.containsKey(normalizedDifficulty)
            ? normalizedDifficulty
            : 'easy';
    final String resolvedMode = _normalizeModeId(modeId);
    final String normalizedRegion =
        _normalizeTrainingRegionId(regionId);
    final int maximumDifficulty = completeRegion
        ? resolvedDifficulty == 'expert'
            ? 100
            : 85
        : _maximumCountryDifficultyFor(resolvedDifficulty);
    final bool requiresCapital =
        resolvedMode == 'find_capital' || resolvedMode == 'mixed';
    final bool requiresFlag =
        resolvedMode == 'find_flag' || resolvedMode == 'mixed';
    final Set<String>? normalizedAllowedIds = allowedCountryIds
        ?.map<String>((String id) => id.trim().toUpperCase())
        .toSet();

    return _countries.where((GeoCountry country) {
      if (_isExcludedFromQuestions(country) ||
          !_matchesTrainingRegion(country, regionId)) {
        return false;
      }

      final String countryId = country.id.trim().toUpperCase();
      if (normalizedAllowedIds != null &&
          !normalizedAllowedIds.contains(countryId)) {
        return false;
      }
      if (completeRegion &&
          _completeTrainingExcludedEntityIds.contains(countryId)) {
        return false;
      }

      final int difficulty = _countryDifficulties[countryId] ?? 100;
      final bool isPlayableAntarctica =
          normalizedRegion == 'antarctica' && countryId == 'ATA';
      final bool usesTerritorialReference =
          _findReferenceOverride(country) != null;
      final bool hasRequiredCapital = !requiresCapital ||
          (!usesTerritorialReference && _findCapital(country) != null);
      final bool hasRequiredFlag = !requiresFlag ||
          (!usesTerritorialReference &&
              RegExp(r'^[A-Z]{2}$')
                  .hasMatch(country.isoA2.trim().toUpperCase()));

      return (normalizedAllowedIds != null ||
              difficulty <= maximumDifficulty ||
              isPlayableAntarctica) &&
          hasRequiredCapital &&
          hasRequiredFlag;
    }).length;
  }

  GeoBrainDifficultyRecommendation recommendedTrainingDifficulty({
    required String modeId,
    required String regionId,
    Set<String>? allowedCountryIds,
  }) {
    final String normalizedMode = _normalizeModeId(modeId);
    final Set<GeoBrainTheme> relevantThemes;
    if (normalizedMode == 'mixed') {
      relevantThemes = <GeoBrainTheme>{
        GeoBrainTheme.location,
        GeoBrainTheme.capital,
        GeoBrainTheme.flag,
      };
    } else {
      final GeoBrainTheme? theme = GeoBrainTheme.fromModeId(normalizedMode);
      relevantThemes = theme == null
          ? GeoBrainTheme.values.toSet()
          : <GeoBrainTheme>{theme};
    }

    final Set<String>? normalizedAllowedIds = allowedCountryIds
        ?.map<String>((String id) => id.trim().toUpperCase())
        .toSet();
    final Set<String> regionalCountryIds = _countries
        .where(
          (GeoCountry country) =>
              _matchesTrainingRegion(country, regionId) &&
              (normalizedAllowedIds == null ||
                  normalizedAllowedIds.contains(
                    country.id.trim().toUpperCase(),
                  )),
        )
        .map<String>((GeoCountry country) => country.id.trim().toUpperCase())
        .toSet();
    final List<GeoBrainAttempt> attempts = _geoBrainService.profile.attemptHistory
        .where(
          (GeoBrainAttempt attempt) =>
              regionalCountryIds.contains(attempt.countryId) &&
              relevantThemes.contains(attempt.theme),
        )
        .toList(growable: false);

    return const GeoBrainDifficultyAdapter().recommend(attempts: attempts);
  }

  LatLng? get selectedPoint =>
      _selectedPoint;

  LatLng? get answerPoint =>
      _answerPoint;

  GeoCountry? get selectedCountry =>
      _selectedCountry;

  GeoCountry? get answerCountry =>
      _answerCountry;

  Capital? get answerCapital =>
      _answerCapital;

  ReferencePoint? get answerReferencePoint =>
      _answerReferencePoint;

  String? get answerCapitalName =>
      _answerCapital?.name;

  String? get answerReferencePointName =>
      _answerReferencePoint?.name;

  String? get answerReferencePointTypeLabel =>
      _answerReferencePoint?.typeLabel;

  String? get answerParentCountryName =>
      _answerReferencePoint
          ?.parentCountryName;

  String? get answerOfficialCapitalName =>
      _answerReferencePoint
              ?.officialCapitalName ??
          _answerCapital?.name;

  String? get answerReferenceDescription =>
      _answerReferencePoint
          ?.description;

  bool get usesReferenceOverride =>
      _answerReferencePoint != null;

  double? get distanceInKilometers =>
      _distanceInKilometers;

  bool get hasStarted =>
      _session.currentQuestion != null;

  bool get hasAnswered =>
      _session.hasAnswered;

  bool get isGameOver =>
      _session.isGameOver;

  int get secondsRemaining =>
      _session.secondsRemaining;

  bool get isTimeUp =>
      _session.isTimeUp;

  int get correctAnswers =>
      _session.correctAnswers;

  double get averageDistanceInKilometers =>
      _session.averageDistanceInKilometers;

  double get averageElapsedSeconds =>
      _session.averageElapsedSeconds;

  int get totalElapsedSeconds =>
      _session.totalElapsedSeconds;

  int get bestScore =>
      _session.bestScore ?? 0;

  int get worstScore =>
      _session.worstScore ?? 0;

  Future<void> initialize(
    List<GeoCountry> countries,
  ) async {
    _stopTimer();

    _countries =
        List<GeoCountry>.unmodifiable(
      countries,
    );

    final Map<String, Capital> capitals =
        await CapitalLoader.loadCapitals();

    final Map<String, ReferencePoint>
        referenceOverrides =
        await ReferencePointLoader
            .loadOverrides();

    final Map<String, int>
        countryDifficulties =
        await CountryDifficultyLoader
            .loadDifficulties();

    final List<GameDifficulty>
        difficultyList =
        await GameDifficultyLoader
            .loadDifficulties();

    final PassportEngine passportEngine =
        await PassportService.createEngine();

    final PlayerPassport? savedPassport =
        await PassportStorage.load();

    final PlayerProfile? savedProfile =
        await PlayerStorage.load();

    final GeoBrainService geoBrainService =
        await GeoBrainService.create();

    final AtlasPersonalProgress? savedAtlasPersonalProgress =
        await AtlasPersonalStorage.loadOrNull();
    final AtlasPersonalProgress atlasPersonalProgress =
        savedAtlasPersonalProgress ?? AtlasPersonalProgress.initial();

    _capitals =
        Map<String, Capital>.unmodifiable(
      capitals,
    );

    _referenceOverrides =
        Map<String, ReferencePoint>
            .unmodifiable(
      referenceOverrides,
    );

    _countryDifficulties =
        Map<String, int>.unmodifiable(
      countryDifficulties,
    );

    _difficulties =
        Map<String, GameDifficulty>
            .unmodifiable(
      <String, GameDifficulty>{
        for (
          final GameDifficulty difficulty
          in difficultyList
        )
          difficulty.id: difficulty,
      },
    );

    _passportEngine =
        passportEngine;

    _passport =
        savedPassport ??
            PlayerPassport.initial();

    _playerProfile = savedProfile ?? PlayerProfile.initial();
    if (!GeoPointFeatures.childModeEnabled && _playerProfile.isChildProfile) {
      _playerProfile = _playerProfile.copyWith(
        profileType: PlayerProfileType.adult,
      );
      await PlayerStorage.save(_playerProfile);
    }

    _geoBrainService =
        geoBrainService;

    _passportProgress =
        await PassportProgressCoordinator.synchronize(
      passport: _passport,
      playerProfile: _playerProfile,
      geoBrainProfile: _geoBrainService.profile,
      atlasProgress: atlasPersonalProgress,
      preserveUnifiedPersonalLists: savedAtlasPersonalProgress == null,
    );
    _passport = _passportProgress.licenseProgress;
    _playerProfile = _passportProgress.playerProfile;

    final PlayerIdentityBootstrapResult identityBootstrap =
        await PlayerIdentityService.bootstrap(
      playerProfile: _playerProfile,
      passport: _passport,
    );
    _playerIdentity = identityBootstrap.identity;
    _passport = identityBootstrap.passport;
    _playerProfile = identityBootstrap.playerProfile;
    // Une synchronisation de progression ou une ancienne identité ne doit pas
    // réactiver le profil enfant pendant que le module est coupé pour la V1.
    if (!GeoPointFeatures.childModeEnabled && _playerProfile.isChildProfile) {
      _playerProfile = _playerProfile.copyWith(
        profileType: PlayerProfileType.adult,
      );
      await PlayerStorage.save(_playerProfile);
    }
    _passportProgress = _passportProgress
        .replaceCoreProgress(
          licenseProgress: _passport,
          playerProfile: _playerProfile,
        )
        .recordMigrationVersions(
      <String, int>{
        'playerOnlineIdentity': PlayerOnlineIdentity.currentSchemaVersion,
      },
    );
    await PassportProgressStorage.save(_passportProgress);

    _countrySelector =
        CountrySelector(
      geoBrain:
          _geoBrainService,
    );

    _lastPassportResult = null;
    _lastLevelResult = null;

    _passportResultRegisteredForCurrentGame =
        false;

    debugPrint(
      'GeoPoint : '
      '${_capitals.length} capitales chargées.',
    );

    debugPrint(
      'GeoPoint : '
      '${_referenceOverrides.length} '
      'points de référence spéciaux chargés.',
    );

    debugPrint(
      'GeoPoint : '
      '${_passportEngine.stamps.length} '
      'tampons du Passeport chargés.',
    );

    debugPrint(
      'GeoPoint : '
      '${_passportEngine.licenses.length} '
      'licences du Passeport chargées.',
    );

    debugPrint(
      'GeoPoint : '
      '${_countryDifficulties.length} '
      'difficultés de pays chargées.',
    );

    debugPrint(
      'GeoPoint : '
      '${_difficulties.length} '
      'expéditions configurées.',
    );

    if (savedPassport != null) {
      debugPrint(
        'GeoPoint : Passeport sauvegardé chargé. '
        '${_passport.totalAttempts} partie(s), '
        '${_passport.validatedStampCount} '
        'tampon(s) validé(s).',
      );
    } else {
      debugPrint(
        'GeoPoint : nouveau Passeport créé.',
      );
    }

    if (savedProfile != null) {
      debugPrint(
        'GeoPoint : profil joueur chargé. '
        'Niveau ${_playerProfile.currentLevel}, '
        '${_playerProfile.totalXp} XP, '
        '${_playerProfile.gamesPlayed} partie(s).',
      );
    } else {
      debugPrint(
        'GeoPoint : nouveau profil joueur créé.',
      );
    }

    debugPrint(
      'GeoPoint GeoBrain : '
      '${_geoBrainService.profile.seenCountryCount} '
      'entité(s) déjà vue(s), '
      '${_geoBrainService.profile.masteredCountryCount} '
      'maîtrisée(s).',
    );

    debugPrint(
      'GeoPoint Passeport 2.0 v${_passportProgress.schemaVersion} : '
      '${_passportProgress.discoveredEntityCount} entité(s) découverte(s), '
      '${_passportProgress.masteredEntityCount} maîtrisée(s), '
      '${_passportProgress.visitedEntityCount} visitée(s), '
      '${_passportProgress.wishlistedEntityCount} à visiter.',
    );

    _applyMissionConfiguration(
      'discovery',
    );

    _gameEngine.reset();
    _session = _createInitialSession();
    _startNewXpSession();
    _encounteredCountries.clear();
    _validatedCountries.clear();
    _currentGameQuestionResults.clear();
    _completeTrainingQueue.clear();

    _clearAnswer();

    notifyListeners();
    unawaited(_synchronizeOnlineIdentity());
  }

  Future<void> _synchronizeOnlineIdentity() async {
    final gateway = ChallengeServerConnection.coreGateway;
    if (gateway == null) {
      return;
    }

    if (_playerIdentity.isLinked) {
      try {
        final PlayerIdentityRegistrationResponse registration =
            await gateway.registerPlayerIdentity(
          PlayerIdentityRegistrationRequest.fromLocalProgress(
            identity: _playerIdentity,
            playerProfile: _playerProfile,
            passport: _passport,
          ),
        );
        if (GeoPointFeatures.childModeEnabled &&
            registration.isChildProfile &&
            !_playerProfile.isChildProfile) {
          _playerProfile = _playerProfile.activateChildProtection(
            registration.childAgeGroup ?? PlayerChildAgeGroup.ages6To8,
          );
          await PlayerStorage.save(_playerProfile);
          await _synchronizePassportProgress(
            preferProvidedPlayerProfile: true,
          );
          notifyListeners();
        }
        if (registration.isChildProfile) {
          debugPrint('GeoPoint : protection enfant synchronisée avec Firebase.');
        }
      } on Object catch (error) {
        if (_playerProfile.isChildProfile) {
          debugPrint(
            'GeoPoint : protection enfant locale, synchronisation Firebase '
            'différée : $error',
          );
        }
      }
      return;
    }

    final PlayerOnlineLinkReport report = _playerIdentity.isMigrationPending
        ? await PlayerOnlineLinkService.refreshMigration(
            identity: _playerIdentity,
            gateway: gateway,
          )
        : await PlayerOnlineLinkService.link(
            identity: _playerIdentity,
            playerProfile: _playerProfile,
            passport: _passport,
            gateway: gateway,
          );

    if (_isDisposed) {
      return;
    }
    _playerIdentity = report.identity;
    if (report.status == PlayerOnlineLinkStatus.serverUnavailable) {
      debugPrint(
        'GeoPoint Firebase : synchronisation différée, jeu local conservé.',
      );
      return;
    }
    debugPrint(
      'GeoPoint Firebase : identité joueur ${report.status.name}.',
    );
    notifyListeners();
  }

  Future<bool> activateChildProtection(PlayerChildAgeGroup ageGroup) async {
    if (!GeoPointFeatures.childModeEnabled) {
      return false;
    }
    if (_playerProfile.isChildProfile) {
      return true;
    }
    final PlayerProfile previous = _playerProfile;
    final PlayerProfile protectedProfile =
        previous.activateChildProtection(ageGroup);
    if (!await PlayerStorage.save(protectedProfile)) {
      return false;
    }
    _playerProfile = protectedProfile;
    await _synchronizePassportProgress(preferProvidedPlayerProfile: true);
    notifyListeners();
    await _synchronizeOnlineIdentity();
    return true;
  }

  Future<bool> renamePlayer(String displayName) async {
    final String normalized = displayName.trim();
    if (normalized.length < 2 || normalized.length > 20) {
      return false;
    }
    final PlayerProfile updatedProfile = _playerProfile.rename(normalized);
    final PlayerPassport updatedPassport = _passport.rename(normalized);
    final List<bool> saved = await Future.wait(<Future<bool>>[
      PlayerStorage.save(updatedProfile),
      PassportStorage.save(updatedPassport),
    ]);
    if (saved.any((bool value) => !value)) {
      return false;
    }
    _playerProfile = updatedProfile;
    _passport = updatedPassport;
    _passportProgress = _passportProgress.replaceCoreProgress(
      licenseProgress: _passport,
      playerProfile: _playerProfile,
    );
    notifyListeners();
    unawaited(_synchronizeOnlineIdentity());
    return true;
  }

  Future<void> refreshOnlineIdentityAfterAccountChange() async {
    _playerIdentity = _playerIdentity.unlink();
    await PlayerIdentityStorage.save(_playerIdentity);
    await _synchronizeOnlineIdentity();
    notifyListeners();
  }

  /// Efface les sauvegardes personnelles de cet appareil après la suppression
  /// distante du compte, puis recrée un profil invité neuf.
  Future<void> deleteLocalPlayerData() async {
    _stopTimer();
    await Future.wait<dynamic>(<Future<dynamic>>[
      PassportStorage.clear(),
      PlayerStorage.clear(),
      _geoBrainService.clear(),
      AtlasPersonalStorage.clear(),
      ExpeditionStorage.clear(),
      ContinentStorage.clear(),
      NationalExpeditionStorage.clear(),
      ChallengeStorage.clear(),
      ChallengePackCacheStorage.clear(),
      PassportProgressStorage.clear(),
      PassportAchievementStorage.clear(),
      PlayerIdentityStorage.clear(),
    ]);
    await initialize(_countries);
  }

  void startMission({
    required String difficultyId,
    String modeId = 'find_country',
  }) {
    _stopTimer();

    _currentGuidedLevel = null;
    _currentContinentLevel = null;
    _isTrainingMission = false;
    _isChallengeMission = false;
    _isCompleteTraining = false;
    _trainingQuestionCount = null;
    _trainingRegionId = 'world';
    _completeTrainingQueue.clear();
    _guidedQuestionQueue.clear();

    _currentModeId =
        _normalizeModeId(
      modeId,
    );

    _applyMissionConfiguration(
      difficultyId,
    );

    _gameEngine.reset();
    _session = _createInitialSession();
    _startNewXpSession();
    _encounteredCountries.clear();
    _validatedCountries.clear();
    _currentGameQuestionResults.clear();

    _lastPassportResult = null;
    _lastLevelResult = null;

    _passportResultRegisteredForCurrentGame =
        false;

    _clearAnswer();

    startNextQuestion();
  }

  void startGuidedMission(
    GuidedLevel level,
  ) {
    _stopTimer();

    _currentGuidedLevel = level;
    _currentContinentLevel = null;
    _isTrainingMission = false;
    _isChallengeMission = false;
    _isCompleteTraining = false;
    _trainingQuestionCount = null;
    _trainingRegionId = 'world';
    _completeTrainingQueue.clear();
    _currentModeId = _normalizeModeId(
      level.modeId,
    );
    _currentDifficultyId = 'discovery';

    _applyGuidedConfiguration(level);

    _gameEngine.reset();
    _encounteredCountries.clear();
    _validatedCountries.clear();
    _currentGameQuestionResults.clear();
    _guidedQuestionQueue
      ..clear()
      ..addAll(_missionCountries);

    _session = GameSession.initial(
      questionDurationSeconds:
          level.hasTimer
              ? level.questionDurationSeconds
              : 3600,
      totalQuestions: level.questionCount,
    );

    _lastPassportResult = null;
    _lastLevelResult = null;
    _passportResultRegisteredForCurrentGame =
        false;

    _clearAnswer();
    startNextQuestion();
  }

  void startContinentMission(
    ContinentLevel level,
  ) {
    _stopTimer();

    _currentGuidedLevel = null;
    _currentContinentLevel = level;
    _isTrainingMission = false;
    _isChallengeMission = false;
    _isCompleteTraining = false;
    _trainingQuestionCount = null;
    _trainingRegionId = 'world';
    _completeTrainingQueue.clear();
    _guidedQuestionQueue.clear();

    _currentModeId = _normalizeModeId(
      level.modeId,
    );

    final String requestedDifficultyId =
        level.difficultyId.trim().toLowerCase();

    _currentDifficultyId =
        _difficulties.containsKey(requestedDifficultyId)
            ? requestedDifficultyId
            : 'discovery';

    _applyContinentConfiguration(level);

    _gameEngine.reset();
    _encounteredCountries.clear();
    _validatedCountries.clear();
    _currentGameQuestionResults.clear();
    _session = GameSession.initial(
      questionDurationSeconds:
          level.questionDurationSeconds,
      totalQuestions: level.questionCount,
    );
    _startNewXpSession();

    _lastPassportResult = null;
    _lastLevelResult = null;
    _passportResultRegisteredForCurrentGame = false;

    _clearAnswer();
    startNextQuestion();
  }

  void startTrainingMission({
    required String difficultyId,
    required String modeId,
    required int questionCount,
    String regionId = 'world',
    bool completeRegion = false,
    bool reviewDifficultiesOnly = false,
    Set<String>? allowedCountryIds,
  }) {
    _stopTimer();

    final int resolvedQuestionCount = questionCount < 1
        ? 1
        : questionCount > 50
            ? 50
            : questionCount;

    _currentGuidedLevel = null;
    _currentContinentLevel = null;
    _isTrainingMission = true;
    _isChallengeMission = false;
    _isCompleteTraining = completeRegion;
    _trainingRegionId = _normalizeTrainingRegionId(regionId);
    _guidedQuestionQueue.clear();
    _completeTrainingQueue.clear();

    _currentModeId = _normalizeModeId(modeId);

    _applyMissionConfiguration(
      difficultyId,
      questionCountOverride: resolvedQuestionCount,
      regionId: _trainingRegionId,
      selectAllEligible: completeRegion,
      selectionProfile: reviewDifficultiesOnly
          ? GeoBrainSelectionProfile.reviewDifficulties
          : GeoBrainSelectionProfile.balanced,
      allowedCountryIds: allowedCountryIds,
    );

    final int availableCount = _missionCountries.length;
    _trainingQuestionCount = completeRegion
        ? availableCount
        : resolvedQuestionCount > availableCount
            ? availableCount
            : resolvedQuestionCount;

    if (completeRegion) {
      _completeTrainingQueue
        ..addAll(_missionCountries)
        ..shuffle();
    }

    _gameEngine.reset();
    _encounteredCountries.clear();
    _validatedCountries.clear();
    _currentGameQuestionResults.clear();
    _currentChallengeAnswerEvidence.clear();
    _session = _createInitialSession();

    _lastPassportResult = null;
    _lastLevelResult = null;
    _passportResultRegisteredForCurrentGame = false;

    _clearAnswer();
    startNextQuestion();
  }

  void startChallengeMission({
    required String challengeId,
    required String difficultyId,
    required String modeId,
    required int questionCount,
    String regionId = 'world',
    Set<String>? allowedCountryIds,
    bool geoBrainPersonalizationAllowed = false,
  }) {
    _stopTimer();

    final int resolvedQuestionCount = questionCount.clamp(1, 50);
    _currentGuidedLevel = null;
    _currentContinentLevel = null;
    _isTrainingMission = false;
    _isChallengeMission = true;
    _isCompleteTraining = false;
    _trainingQuestionCount = resolvedQuestionCount;
    _trainingRegionId = _normalizeTrainingRegionId(regionId);
    _guidedQuestionQueue.clear();
    _completeTrainingQueue.clear();
    _currentModeId = _normalizeModeId(modeId);

    _applyMissionConfiguration(
      difficultyId,
      questionCountOverride: resolvedQuestionCount,
      regionId: _trainingRegionId,
      allowedCountryIds: allowedCountryIds,
      useGeoBrainPersonalization: geoBrainPersonalizationAllowed,
      deterministicSelectionSeed: challengeId,
    );

    final int availableCount = _missionCountries.length;
    _trainingQuestionCount = resolvedQuestionCount > availableCount
        ? availableCount
        : resolvedQuestionCount;
    _gameEngine.reset(
      randomSeed: challengeRandomSeed(challengeId),
    );
    _encounteredCountries.clear();
    _validatedCountries.clear();
    _currentGameQuestionResults.clear();
    _currentChallengeAnswerEvidence.clear();
    _session = _createInitialSession();
    _startNewXpSession();
    _lastPassportResult = null;
    _lastLevelResult = null;
    _passportResultRegisteredForCurrentGame = false;
    _clearAnswer();
    startNextQuestion();
  }

  void startNextQuestion() {
    if (_missionCountries.isEmpty ||
        !_session.canStartNextQuestion) {
      return;
    }

    _stopTimer();

    final GameQuestion? question = _isCompleteTraining
        ? _createNextCompleteTrainingQuestion()
        : _currentGuidedLevel == null
            ? _gameEngine.createNextQuestion(
                _missionCountries,
                modeId: _currentModeId,
              )
            : _createNextGuidedQuestion();

    if (question == null) {
      return;
    }

    _session =
        _session.startQuestion(
      question,
    );

    _clearAnswer();
    _startTimer();

    notifyListeners();
  }

  void submitAnswer({
    required LatLng selectedPoint,
    required GeoCountry? selectedCountry,
  }) {
    final GameQuestion? question =
        _session.currentQuestion;

    if (question == null ||
        _session.hasAnswered ||
        _session.isTimeUp ||
        _session.isGameOver) {
      return;
    }

    final GeoCountry? answerCountry =
        _findCountryById(
      question.countryId,
    );

    if (answerCountry == null) {
      return;
    }

    final String questionModeId =
        question.modeId;

    _stopTimer();

    final Capital? capital =
        _findCapital(
      answerCountry,
    );

    final ReferencePoint? referencePoint =
        _findReferenceOverride(
      answerCountry,
    );

    if (questionModeId ==
            'find_capital' &&
        capital == null) {
      debugPrint(
        'GeoPoint : aucune capitale disponible '
        'pour ${answerCountry.name}.',
      );
      return;
    }

    final LatLng answerPoint =
        questionModeId ==
                'find_capital'
            ? capital!.position
            : referencePoint?.position ??
                capital?.position ??
                _calculateCountryCenter(
                  answerCountry,
                );

    const Distance distanceCalculator =
        Distance();

    final double distanceInKilometers =
        distanceCalculator.as(
      LengthUnit.Kilometer,
      selectedPoint,
      answerPoint,
    );

    final bool isCorrectCountry =
        questionModeId ==
                'find_capital'
            ? distanceInKilometers <=
                _capitalValidationRadiusKm()
            : selectedCountry?.id ==
                answerCountry.id;

    final int score =
        _scoreSystem.calculateScore(
      modeId:
          questionModeId,
      difficultyId:
          _currentDifficultyId,
      isCorrectCountry:
          isCorrectCountry,
      distanceInKilometers:
          distanceInKilometers,
      secondsRemaining:
          _session.secondsRemaining,
      questionDurationSeconds:
          _session
              .questionDurationSeconds,
    );

    final int elapsedSeconds =
        _session.questionDurationSeconds -
            _session.secondsRemaining;

    _selectedPoint =
        selectedPoint;

    _selectedCountry =
        selectedCountry;

    _answerPoint =
        answerPoint;

    _answerCountry =
        answerCountry;

    _recordEncounteredCountry(answerCountry);

    if (isCorrectCountry) {
      _recordValidatedCountry(answerCountry);
    }

    _answerCapital =
        capital;

    _answerReferencePoint =
        referencePoint;

    _distanceInKilometers =
        distanceInKilometers;

    _session =
        _session.answer(
      score: score,
      isCorrectCountry:
          isCorrectCountry,
      distanceInKilometers:
          distanceInKilometers,
      elapsedSeconds:
          elapsedSeconds,
      includeDistanceInAverage:
          questionModeId ==
                  'find_capital' ||
          !isCorrectCountry,
    );

    GameplayFeedback.answer(isCorrect: isCorrectCountry);

    _currentGameQuestionResults.add(
      _statisticsResultForQuestion(
        question: question,
        isCorrect: isCorrectCountry,
        elapsedSeconds: elapsedSeconds,
        distanceInKilometers: questionModeId == 'find_capital' ||
                !isCorrectCountry
            ? distanceInKilometers
            : null,
      ),
    );
    if (_isChallengeMission) {
      _currentChallengeAnswerEvidence.add(
        ChallengeAnswerEvidence(
          modeId: questionModeId,
          isCorrect: isCorrectCountry,
          elapsedSeconds: elapsedSeconds,
          distanceInKilometers: questionModeId == 'find_capital' ||
                  !isCorrectCountry
              ? distanceInKilometers
              : null,
        ),
      );
    }

    if (_isCompleteTraining && !isCorrectCountry) {
      _queueCompleteTrainingRetry(answerCountry);
    }

    if (PassportProgressRules.themeForGameMode(questionModeId) != null) {
      final Future<void> progressOperation = _registerPassportAnswer(
        countryId: answerCountry.id,
        modeId: questionModeId,
        isCorrect: isCorrectCountry,
        source: _passportSourceForCurrentGame(),
        difficultyId: _currentDifficultyId,
        elapsedSeconds: elapsedSeconds,
        distanceInKilometers: distanceInKilometers,
        proposedAnswerId: selectedCountry?.id,
        helpId: _currentGuidedLevel == null ? null : 'guided_target',
        context: _geoBrainContextForCurrentGame(),
        registerPassportProgress: _currentGuidedLevel == null,
      );
      if (_session.isGameOver) {
        _currentGameCompletion =
            progressOperation.whenComplete(_registerCompletedGame);
        unawaited(_currentGameCompletion);
      } else {
        unawaited(progressOperation);
      }
    } else {
      _registerCompletedGame();
      _currentGameCompletion = Future<void>.value();
    }

    if (referencePoint != null) {
      debugPrint(
        'GeoPoint : point spécial utilisé → '
        '${referencePoint.name} '
        '(${referencePoint.entityId})',
      );
    } else if (capital != null) {
      debugPrint(
        'GeoPoint : capitale utilisée → '
        '${capital.name} '
        '(${capital.isoA3})',
      );
    } else {
      debugPrint(
        'GeoPoint : centre géographique utilisé → '
        '${answerCountry.name}',
      );
    }

    notifyListeners();
  }

  void resetGame() {
    _stopTimer();

    final GuidedLevel? guidedLevel =
        _currentGuidedLevel;

    _gameEngine.reset();
    _encounteredCountries.clear();
    _validatedCountries.clear();
    _currentGameQuestionResults.clear();

    if (_isCompleteTraining) {
      _completeTrainingQueue
        ..clear()
        ..addAll(_missionCountries)
        ..shuffle();
    }

    if (guidedLevel == null) {
      _session = _createInitialSession();
    } else {
      _guidedQuestionQueue
        ..clear()
        ..addAll(_missionCountries);

      _session = GameSession.initial(
        questionDurationSeconds:
            guidedLevel.hasTimer
                ? guidedLevel
                    .questionDurationSeconds
                : 3600,
        totalQuestions:
          guidedLevel.questionCount,
      );
    }
    _startNewXpSession();

    _lastPassportResult = null;
    _lastLevelResult = null;

    _passportResultRegisteredForCurrentGame =
        false;

    _clearAnswer();

    startNextQuestion();
  }

  Future<void> clearSavedPassport() async {
    final bool cleared =
        await PassportStorage.clear();

    if (!cleared) {
      debugPrint(
        'GeoPoint : impossible de supprimer '
        'la sauvegarde du Passeport.',
      );

      return;
    }

    _passport =
        PlayerPassport.initial(playerId: _playerIdentity.localPlayerId);

    _lastPassportResult = null;

    _passportResultRegisteredForCurrentGame =
        false;

    debugPrint(
      'GeoPoint : Passeport réinitialisé.',
    );

    await _synchronizePassportProgress(preferProvidedPassport: true);

    notifyListeners();
  }

  Future<void> clearSavedPlayerProfile() async {
    final PlayerProfile previousProfile = _playerProfile;
    await PlayerStorage.clear();

    _playerProfile = PlayerProfile.initial(
      playerId: _playerIdentity.localPlayerId,
      profileType: previousProfile.profileType,
      childAgeGroup: previousProfile.childAgeGroup,
    );

    _lastLevelResult = null;

    debugPrint(
      'GeoPoint : profil joueur réinitialisé.',
    );

    await _synchronizePassportProgress(preferProvidedPlayerProfile: true);

    notifyListeners();
  }

  Future<void> applyDebugPlayerXpAction(
    PlayerXpDebugAction action, {
    int amount = 0,
  }) async {
    if (!kDebugMode) {
      throw UnsupportedError(
        'Les outils XP de développement sont désactivés en production.',
      );
    }

    await waitForPassportProgressSynchronization();

    final PlayerProfile previousProfile = _playerProfile;
    final PlayerProfile updatedProfile = PlayerXpDebugTools.apply(
      profile: previousProfile,
      action: action,
      amount: amount,
    );

    if (identical(previousProfile, updatedProfile)) {
      return;
    }

    _playerProfile = updatedProfile;
    _lastLevelResult = null;

    final bool saved = await PlayerStorage.save(updatedProfile);
    if (!saved) {
      _playerProfile = previousProfile;
      throw StateError('La sauvegarde du profil de test a échoué.');
    }

    await _synchronizePassportProgress(
      preferProvidedPlayerProfile: true,
    );

    debugPrint(
      'GeoPoint debug XP : ${_playerProfile.totalXp} XP, '
      '${_playerProfile.displayLevelTitle}.',
    );
    notifyListeners();
  }

  Future<void> clearSavedGeoBrain() async {
    await _geoBrainService.clear();

    final GuidedLevel? guidedLevel =
        _currentGuidedLevel;

    final ContinentLevel? continentLevel =
        _currentContinentLevel;

    if (guidedLevel != null) {
      _applyGuidedConfiguration(
        guidedLevel,
      );
    } else if (continentLevel != null) {
      _applyContinentConfiguration(
        continentLevel,
      );
    } else if (_isTrainingMission) {
      _applyMissionConfiguration(
        _currentDifficultyId,
        questionCountOverride: _trainingQuestionCount,
        regionId: _trainingRegionId,
        selectAllEligible: _isCompleteTraining,
      );
    } else {
      _applyMissionConfiguration(
        _currentDifficultyId,
      );
    }

    debugPrint(
      'GeoPoint GeoBrain : progression réinitialisée.',
    );

    await PassportProgressStorage.clear();
    await _synchronizePassportProgress();

    notifyListeners();
  }

  Future<void> synchronizePassportPersonalProgress(
    AtlasPersonalProgress atlasProgress,
  ) async {
    await _synchronizePassportProgress(
      atlasProgress: atlasProgress,
    );

    notifyListeners();
  }

  Future<void> markPassportEntityDiscoveredFromAtlas(
    String entityId,
  ) async {
    if (_passportProgress.progressFor(entityId).hasBeenDiscovered) {
      return;
    }

    final DateTime discoveredAt = DateTime.now();
    final Future<void> operation = _passportSynchronizationQueue.then(
      (_) async {
        _passportProgress = _passportProgress.markDiscovered(
          entityId: entityId,
          source: PassportDiscoverySource.atlas,
          discoveredAt: discoveredAt,
        );

        await PassportProgressStorage.save(_passportProgress);
      },
    );

    _passportSynchronizationQueue = operation;
    await operation;
    notifyListeners();
  }

  Future<void> unlockPassportCollectionItem(String itemId) async {
    final String normalizedId = itemId.trim().toLowerCase();
    if (normalizedId.isEmpty ||
        _passportProgress.unlockedCollectionItemIds.contains(normalizedId)) {
      return;
    }

    final Future<void> operation = _passportSynchronizationQueue.then(
      (_) async {
        _passportProgress = _passportProgress.unlockCollectionItem(
          normalizedId,
        );
        await PassportProgressStorage.save(_passportProgress);
      },
    );

    _passportSynchronizationQueue = operation;
    await operation;
    notifyListeners();
  }

  Future<void> synchronizePassportAchievementProgress(
    PassportAchievementProgress achievementProgress,
  ) async {
    final Future<void> operation = _passportSynchronizationQueue.then(
      (_) async {
        _passportProgress = _passportProgress
            .replaceCoreProgress(
              licenseProgress: _passport,
              playerProfile: _playerProfile,
              replacedAt: achievementProgress.updatedAt,
            )
            .recordAchievementTiers(
              achievementProgress.completedAtByTierId,
              recordedAt: achievementProgress.updatedAt,
            );
        await PassportProgressStorage.save(_passportProgress);
        await PassportAchievementStorage.save(achievementProgress);
      },
    );
    _passportSynchronizationQueue = operation;
    await operation;
    notifyListeners();
  }

  Future<PassportEntityProgress?> registerPassportSilhouetteAnswer({
    required String countryId,
    required bool isCorrect,
    required int elapsedSeconds,
    required String difficultyId,
    String? proposedAnswerId,
    PassportDiscoverySource source = PassportDiscoverySource.expedition,
    GeoBrainAttemptContext context = GeoBrainAttemptContext.expedition,
  }) async {
    final bool wasUnlocked =
        _passportProgress.progressFor(countryId).stampUnlockedAt != null;

    await _registerPassportAnswer(
      countryId: countryId,
      modeId: 'ultimate',
      isCorrect: isCorrect,
      source: source,
      difficultyId: difficultyId,
      elapsedSeconds: elapsedSeconds,
      proposedAnswerId: proposedAnswerId,
      context: context,
    );

    final GeoCountry? country = _findCountryById(countryId);
    final PassportContinent? continent = country == null
        ? null
        : PassportContinent.forEntity(
            entityId: country.id,
            geoContinent: country.continent,
          );
    _playerProfile = _playerProfile.registerStandaloneQuestionResult(
      modeId: 'ultimate',
      difficultyId: difficultyId,
      result: QuestionStatisticsResult(
        countryId: countryId,
        continentId: continent?.id ?? 'unknown',
        themeId: PassportKnowledgeTheme.silhouette.id,
        isCorrect: isCorrect,
        elapsedSeconds: elapsedSeconds,
      ),
    );
    unawaited(_savePlayerProfile());
    notifyListeners();

    final PassportEntityProgress updated =
        _passportProgress.progressFor(countryId);

    if (!wasUnlocked && updated.stampUnlockedAt != null) {
      return updated;
    }

    return null;
  }

  void _startTimer() {
    _stopTimer();

    _questionTimer =
        Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (_session.hasAnswered ||
            _session.isTimeUp ||
            _session.isGameOver) {
          _stopTimer();
          return;
        }

        _session =
            _session.tick();

        if (_session.isTimeUp) {
          _handleTimeout();
        }

        notifyListeners();
      },
    );
  }

  void _handleTimeout() {
    _stopTimer();

    final GameQuestion? question =
        _session.currentQuestion;

    if (question == null ||
        _session.hasAnswered) {
      return;
    }

    final GeoCountry? answerCountry =
        _findCountryById(
      question.countryId,
    );

    final String questionModeId =
        question.modeId;

    if (answerCountry != null) {
      final Capital? capital =
          _findCapital(
        answerCountry,
      );

      final ReferencePoint? referencePoint =
          _findReferenceOverride(
        answerCountry,
      );

      _answerCountry =
          answerCountry;

      _recordEncounteredCountry(answerCountry);

      _answerCapital =
          capital;

      _answerReferencePoint =
          referencePoint;

      _answerPoint =
          questionModeId ==
                      'find_capital' &&
                  capital != null
              ? capital.position
              : referencePoint?.position ??
                  capital?.position ??
                  _calculateCountryCenter(
                    answerCountry,
                  );
    }

    _selectedPoint = null;
    _selectedCountry = null;
    _distanceInKilometers = null;

    _session =
        _session.timeout();

    _currentGameQuestionResults.add(
      _statisticsResultForQuestion(
        question: question,
        isCorrect: false,
        elapsedSeconds: _session.questionDurationSeconds,
      ),
    );
    if (_isChallengeMission) {
      _currentChallengeAnswerEvidence.add(
        ChallengeAnswerEvidence(
          modeId: questionModeId,
          isCorrect: false,
          elapsedSeconds: _session.questionDurationSeconds,
        ),
      );
    }

    if (_isCompleteTraining && answerCountry != null) {
      _queueCompleteTrainingRetry(answerCountry);
    }

    if (answerCountry != null &&
        PassportProgressRules.themeForGameMode(questionModeId) != null) {
      final Future<void> progressOperation = _registerPassportAnswer(
        countryId:
            answerCountry.id,
        modeId:
            questionModeId,
        isCorrect: false,
        source: _passportSourceForCurrentGame(),
        difficultyId: _currentDifficultyId,
        elapsedSeconds: _session.questionDurationSeconds,
        helpId: _currentGuidedLevel == null ? null : 'guided_target',
        context: _geoBrainContextForCurrentGame(),
        registerPassportProgress: _currentGuidedLevel == null,
      );
      if (_session.isGameOver) {
        _currentGameCompletion =
            progressOperation.whenComplete(_registerCompletedGame);
        unawaited(_currentGameCompletion);
      } else {
        unawaited(progressOperation);
      }
    } else {
      _registerCompletedGame();
      _currentGameCompletion = Future<void>.value();
    }
  }

  void _registerCompletedGame() {
    if (!_session.isGameOver ||
        _passportResultRegisteredForCurrentGame) {
      return;
    }

    if (_currentGuidedLevel != null || _isTrainingMission) {
      _passportResultRegisteredForCurrentGame =
          true;

      debugPrint(
        _isTrainingMission
            ? 'GeoPoint : entraînement terminé, progression inchangée.'
            : 'GeoPoint : tutoriel terminé, progression joueur inchangée.',
      );

      return;
    }

    final String stampId =
        _stampIdForCurrentMode();

    final PassportResult passportResult =
        _passportEngine.registerResult(
      passport: _passport,
      stampId: stampId,
      score: _session.totalScore,
    );

    final DateTime completedAt = DateTime.now();
    final Set<String> newlyDiscoveredCountryIds =
        _newlyDiscoveredCountryIdsForCurrentSession();
    final Set<String> newlyMasteredCountryIds =
        _newlyMasteredCountryIdsForCurrentSession();
    final LevelResult levelResult =
        _xpSystem.applyGameResult(
      profile: _playerProfile,
      grantId: _resolveCurrentXpGrantId(completedAt),
      completedAt: completedAt,
      correctAnswers:
          _session.correctAnswers,
      totalQuestions:
          _session.totalQuestions,
      averageDistanceKm:
          _session.averageDistanceInKilometers,
      difficultyId:
          _currentDifficultyId,
      newlyDiscoveredCountryIds: newlyDiscoveredCountryIds,
      newlyMasteredCountryIds: newlyMasteredCountryIds,
    );

    final double totalGameDistance =
        _session.totalDistanceInKilometers;

    final int totalGameElapsedSeconds =
        (
          _session.averageElapsedSeconds *
          _session.totalQuestions
        ).round();

    _passport =
        passportResult.updatedPassport;

    _playerProfile =
        _playerProfile.registerGameResult(
      earnedXp:
          levelResult.earnedXp,
      updatedXpLedger:
          levelResult.updatedXpLedger,
      gameScore:
          _session.totalScore,
      gameCorrectAnswers:
          _session.correctAnswers,
      gameTotalAnswers:
          _session.totalQuestions,
      modeId: _currentModeId,
      difficultyId: _currentDifficultyId,
      gameDistanceInKilometers:
          totalGameDistance,
      gameElapsedSeconds:
          totalGameElapsedSeconds,
      questionResults: List<QuestionStatisticsResult>.unmodifiable(
        _currentGameQuestionResults,
      ),
    );

    _lastPassportResult =
        passportResult;

    _lastLevelResult =
        levelResult;

    _passportResultRegisteredForCurrentGame =
        true;

    unawaited(
      _savePassport(),
    );

    unawaited(
      _savePlayerProfile(),
    );

    unawaited(
      _synchronizePassportProgress(),
    );

    debugPrint(
      'GeoPoint Passeport : '
      'score total ${passportResult.score}, '
      'tampon ${passportResult.stamp.name}, '
      'médaille '
      '${passportResult.newMedal.label}, '
      'meilleur score '
      '${passportResult.updatedBestScore}.',
    );

    debugPrint(
      'GeoPoint XP : '
      '+${levelResult.earnedXp} XP accordée(s) '
      'par ${levelResult.grantedRewards.length} gain(s), '
      'niveau ${levelResult.previousLevel} '
      '→ ${levelResult.newLevel}, '
      'total ${levelResult.newTotalXp} XP.',
    );

    if (passportResult.hasMedalUpgrade) {
      debugPrint(
        'GeoPoint Passeport : '
        'nouvelle médaille obtenue → '
        '${passportResult.newMedal.label}.',
      );
    }

    if (passportResult.hasUnlockedLicense) {
      debugPrint(
        'GeoPoint Passeport : '
        'nouvelle licence obtenue → '
        '${passportResult.latestUnlockedLicense?.title}.',
      );
    }

    if (levelResult.hasLevelUp) {
      debugPrint(
        'GeoPoint XP : niveau supérieur → '
        'niveau ${levelResult.newLevel}, '
        '${levelResult.newTitle}.',
      );
    }

    if (levelResult.hasTitleChanged) {
      debugPrint(
        'GeoPoint XP : nouveau titre → '
        '${levelResult.newTitle}.',
      );
    }

    notifyListeners();
  }

  Set<String> _newlyDiscoveredCountryIdsForCurrentSession() {
    final Set<String> encounteredIds = _encounteredCountries
        .map((GeoCountry country) => country.id.trim().toUpperCase())
        .where((String countryId) => countryId.isNotEmpty)
        .toSet();

    return _geoBrainService.profile.countries.entries
        .where(
          (entry) =>
              encounteredIds.contains(entry.key.trim().toUpperCase()) &&
              entry.value.hasBeenSeen &&
              !_xpSeenCountryIdsAtSessionStart.contains(
                entry.key.trim().toUpperCase(),
              ),
        )
        .map((entry) => entry.key.trim().toUpperCase())
        .toSet();
  }

  Set<String> _newlyMasteredCountryIdsForCurrentSession() {
    final Set<String> encounteredIds = _encounteredCountries
        .map((GeoCountry country) => country.id.trim().toUpperCase())
        .where((String countryId) => countryId.isNotEmpty)
        .toSet();

    return _geoBrainService.profile.countries.entries
        .where(
          (entry) =>
              encounteredIds.contains(entry.key.trim().toUpperCase()) &&
              entry.value.isMastered &&
              !_xpMasteredCountryIdsAtSessionStart.contains(
                entry.key.trim().toUpperCase(),
              ),
        )
        .map((entry) => entry.key.trim().toUpperCase())
        .toSet();
  }

  QuestionStatisticsResult _statisticsResultForQuestion({
    required GameQuestion question,
    required bool isCorrect,
    required int elapsedSeconds,
    double? distanceInKilometers,
  }) {
    final PassportKnowledgeTheme? theme =
        PassportProgressRules.themeForGameMode(question.modeId);
    final PassportContinent? continent = PassportContinent.forEntity(
      entityId: question.countryId,
      geoContinent: question.continent,
    );

    return QuestionStatisticsResult(
      countryId: question.countryId,
      continentId: continent?.id ?? 'unknown',
      themeId: theme?.id ?? 'location',
      isCorrect: isCorrect,
      elapsedSeconds: elapsedSeconds,
      distanceInKilometers: distanceInKilometers,
    );
  }

  Future<void> _registerPassportAnswer({
    required String countryId,
    required String modeId,
    required bool isCorrect,
    required PassportDiscoverySource source,
    required String difficultyId,
    required int elapsedSeconds,
    double? distanceInKilometers,
    String? helpId,
    String? proposedAnswerId,
    GeoBrainAttemptContext? context,
    bool registerPassportProgress = true,
  }) async {
    final PassportKnowledgeTheme? theme =
        PassportProgressRules.themeForGameMode(modeId);
    final GeoBrainTheme? geoBrainTheme = GeoBrainTheme.fromModeId(modeId);

    if (theme == null && geoBrainTheme == null) {
      return;
    }

    final DateTime answeredAt = DateTime.now();
    final Future<void> operation = _passportSynchronizationQueue.then(
      (_) async {
        if (geoBrainTheme != null) {
          await _geoBrainService.registerAttempt(
            GeoBrainAttempt(
              countryId: countryId,
              theme: geoBrainTheme,
              answeredAt: answeredAt,
              modeId: modeId,
              difficultyId: difficultyId,
              isCorrect: isCorrect,
              distanceInKilometers: distanceInKilometers,
              responseTimeMilliseconds: elapsedSeconds * 1000,
              helpId: helpId,
              proposedAnswerId: proposedAnswerId,
              context: context ?? _geoBrainContextForCurrentGame(),
            ),
          );
        }

        if (!registerPassportProgress || theme == null) {
          return;
        }

        final DateTime? stampBeforeAnswer =
            _passportProgress.progressFor(countryId).stampUnlockedAt;

        _passportProgress = _passportProgress.registerAnswer(
          entityId: countryId,
          theme: theme,
          isCorrect: isCorrect,
          source: source,
          answeredAt: answeredAt,
        );

        final PassportEntityProgress updatedEntity =
            _passportProgress.progressFor(countryId);
        final DateTime? stampAfterAnswer = updatedEntity.stampUnlockedAt;

        if (stampBeforeAnswer == null && stampAfterAnswer != null) {
          _countryStampUnlockSequence++;
          _latestCountryStampUnlock = PassportStampUnlockEvent(
            sequence: _countryStampUnlockSequence,
            entityId: updatedEntity.entityId,
            unlockedAt: stampAfterAnswer,
            source: source,
          );
        }

        await PassportProgressStorage.save(_passportProgress);
      },
    );

    _passportSynchronizationQueue = operation;
    await operation;

    notifyListeners();
  }

  PassportDiscoverySource _passportSourceForCurrentGame() {
    if (_currentContinentLevel != null) {
      return PassportDiscoverySource.expedition;
    }
    if (_isChallengeMission) {
      return PassportDiscoverySource.challenge;
    }

    return PassportDiscoverySource.game;
  }

  GeoBrainAttemptContext _geoBrainContextForCurrentGame() {
    if (_currentGuidedLevel != null) {
      return GeoBrainAttemptContext.tutorial;
    }
    if (_currentContinentLevel != null) {
      return GeoBrainAttemptContext.expedition;
    }
    if (_isTrainingMission) {
      return GeoBrainAttemptContext.training;
    }
    if (_isChallengeMission) {
      return GeoBrainAttemptContext.challenge;
    }
    return GeoBrainAttemptContext.classicGame;
  }

  Future<void> registerGeoBrainAttempt(GeoBrainAttempt attempt) async {
    final Future<void> operation = _passportSynchronizationQueue.then(
      (_) => _geoBrainService.registerAttempt(attempt),
    );
    _passportSynchronizationQueue = operation;
    await operation;
    notifyListeners();
  }

  Future<LevelResult> registerExpeditionMissionCompletion({
    required String expeditionId,
    required String missionId,
    bool isExam = false,
    bool combineWithCurrentGame = true,
    DateTime? completedAt,
  }) async {
    final LevelResult result = _xpSystem.applyExpeditionMissionCompletion(
      profile: _playerProfile,
      expeditionId: expeditionId,
      missionId: missionId,
      completedAt: completedAt ?? DateTime.now(),
      isExam: isExam,
    );

    if (result.earnedXp <= 0) {
      return result;
    }

    _playerProfile = _playerProfile.copyWith(
      totalXp: result.newTotalXp,
      xpLedger: result.updatedXpLedger,
    );
    _lastLevelResult = !combineWithCurrentGame || _lastLevelResult == null
        ? result
        : _lastLevelResult!.followedBy(result);

    await _savePlayerProfile();
    await _synchronizePassportProgress(
      preferProvidedPlayerProfile: true,
    );

    debugPrint(
      'GeoPoint XP : +${result.earnedXp} XP pour la première validation '
      '${isExam ? "d’un examen" : "d’une mission"} '
      '$expeditionId / $missionId.',
    );

    notifyListeners();
    return result;
  }

  Future<int> registerChallengeXpReward({
    required String rewardClaimId,
    required int xp,
    required DateTime completedAt,
  }) async {
    if (xp <= 0 || rewardClaimId.trim().isEmpty) {
      return 0;
    }
    await waitForPassportProgressSynchronization();
    final PlayerXpProfileUpdate update = _playerProfile.applyXpGrant(
      PlayerXpGrantRequest(
        grantId: 'challenge-reward:${rewardClaimId.trim()}',
        source: PlayerXpSource.challengeCompleted,
        baseXp: xp,
        occurredAt: completedAt,
      ),
    );
    if (!update.decision.wasGranted) {
      return 0;
    }
    _playerProfile = update.profile;
    await _savePlayerProfile();
    await _synchronizePassportProgress(
      preferProvidedPlayerProfile: true,
    );
    notifyListeners();
    return update.decision.awardedXp;
  }

  bool get hasAchievementXpBaseline {
    return _xpSystem.hasAchievementXpBaseline(_playerProfile);
  }

  Future<void> ensureAchievementXpBaseline(
    Iterable<String> completedTierIds,
  ) async {
    if (hasAchievementXpBaseline) {
      return;
    }

    final Iterable<String> eligibleTierIds = completedTierIds.where(
      (String tierId) {
        final PassportAchievement? achievement =
            PassportAchievementCatalog.achievementForTierId(tierId);
        return achievement != null && !achievement.isPersonalOnly;
      },
    );
    final updatedLedger = _xpSystem.establishAchievementXpBaseline(
      profile: _playerProfile,
      completedTierIds: eligibleTierIds,
    );
    _playerProfile = _playerProfile.copyWith(xpLedger: updatedLedger);

    await _savePlayerProfile();
    await _synchronizePassportProgress(
      preferProvidedPlayerProfile: true,
    );

    debugPrint(
      'GeoPoint XP : référence initiale des accomplissements enregistrée '
      'sans gain rétroactif.',
    );
  }

  Future<int> registerAchievementCompletions({
    required Iterable<String> tierIds,
    bool combineWithCurrentGame = true,
    DateTime? completedAt,
  }) async {
    final Map<String, PassportAchievementTier> eligibleTiers =
        <String, PassportAchievementTier>{};
    for (final String tierId in tierIds) {
      final String normalizedTierId = tierId.trim().toLowerCase();
      final PassportAchievement? achievement =
          PassportAchievementCatalog.achievementForTierId(normalizedTierId);
      final PassportAchievementTier? tier =
          PassportAchievementCatalog.tierById(normalizedTierId);
      if (achievement == null || achievement.isPersonalOnly || tier == null) {
        continue;
      }
      eligibleTiers[normalizedTierId] = tier;
    }
    if (eligibleTiers.isEmpty) {
      return 0;
    }

    final LevelResult result = _xpSystem.applyAchievementCompletions(
      profile: _playerProfile,
      completedTierIds: eligibleTiers.keys,
      majorTierIds: eligibleTiers.entries
          .where((MapEntry<String, PassportAchievementTier> entry) {
            return entry.value.isMajor;
          })
          .map((MapEntry<String, PassportAchievementTier> entry) => entry.key),
      completedAt: completedAt ?? DateTime.now(),
    );
    if (result.earnedXp <= 0) {
      return 0;
    }

    _playerProfile = _playerProfile.copyWith(
      totalXp: result.newTotalXp,
      xpLedger: result.updatedXpLedger,
    );
    _lastLevelResult = !combineWithCurrentGame || _lastLevelResult == null
        ? result
        : _lastLevelResult!.followedBy(result);

    await _savePlayerProfile();
    await _synchronizePassportProgress(
      preferProvidedPlayerProfile: true,
    );

    debugPrint(
      'GeoPoint XP : +${result.earnedXp} XP pour '
      '${eligibleTiers.length} palier(s) d’accomplissement.',
    );

    notifyListeners();
    return result.earnedXp;
  }

  Future<int> refreshPassportAchievements({
    bool combineWithCurrentGame = false,
  }) async {
    await waitForPassportProgressSynchronization();
    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      PassportAchievementStorage.load(),
      ExpeditionStorage.load(),
      ContinentStorage.load(),
    ]);
    final PassportAchievementProgress loaded =
        (values[0] as PassportAchievementProgress).mergeCompletedTierDates(
      _passportProgress.completedAchievementTierDates,
    );
    final PassportAchievementSnapshot snapshot =
        PassportAchievementSnapshotBuilder.build(
      progress: _passportProgress,
      profile: _playerProfile,
      countries: _countries,
      expeditionProgress: values[1] as ExpeditionProgress,
      continentProgress: values[2] as ContinentProgress,
    );
    final PassportAchievementProgress updated =
        loaded.synchronize(snapshot: snapshot);
    final Set<String> newTierIds =
        updated.newlyCompletedTierIdsComparedWith(loaded);

    int earnedXp = 0;
    if (hasAchievementXpBaseline) {
      earnedXp = await registerAchievementCompletions(
        tierIds: newTierIds,
        combineWithCurrentGame: combineWithCurrentGame,
      );
    } else {
      await ensureAchievementXpBaseline(updated.completedAtByTierId.keys);
    }

    if (!identical(loaded, updated)) {
      await synchronizePassportAchievementProgress(updated);
    }
    return earnedXp;
  }

  Future<void> _synchronizePassportProgress({
    AtlasPersonalProgress? atlasProgress,
    bool preferProvidedPassport = false,
    bool preferProvidedPlayerProfile = false,
  }) {
    _passportSynchronizationQueue = _passportSynchronizationQueue.then(
      (_) async {
        _passportProgress =
            await PassportProgressCoordinator.synchronize(
          passport: _passport,
          playerProfile: _playerProfile,
          geoBrainProfile: _geoBrainService.profile,
          atlasProgress: atlasProgress,
          preferProvidedPassport: preferProvidedPassport,
          preferProvidedPlayerProfile: preferProvidedPlayerProfile,
        );
        _passport = _passportProgress.licenseProgress;
        _playerProfile = _passportProgress.playerProfile;
      },
    );

    return _passportSynchronizationQueue;
  }

  Future<void> _savePassport() async {
    final bool saved =
        await PassportStorage.save(
      _passport,
    );

    if (saved) {
      debugPrint(
        'GeoPoint : Passeport sauvegardé.',
      );
    } else {
      debugPrint(
        'GeoPoint : échec de la sauvegarde '
        'du Passeport.',
      );
    }
  }

  Future<void> _savePlayerProfile() async {
    final bool saved =
        await PlayerStorage.save(
      _playerProfile,
    );

    if (saved) {
      debugPrint(
        'GeoPoint : profil joueur sauvegardé.',
      );
    } else {
      debugPrint(
        'GeoPoint : échec de la sauvegarde '
        'du profil joueur.',
      );
    }
  }

  GameSession _createInitialSession() {
    final ContinentLevel? continentLevel =
        _currentContinentLevel;

    if (continentLevel != null) {
      return GameSession.initial(
        questionDurationSeconds:
            continentLevel.questionDurationSeconds,
        totalQuestions:
            continentLevel.questionCount,
      );
    }

    final GameDifficulty? difficulty =
        _difficulties[
          _currentDifficultyId
        ];

    return GameSession.initial(
      questionDurationSeconds:
          difficulty
                  ?.questionDurationSeconds ??
              15,
      totalQuestions:
          _trainingQuestionCount ??
          difficulty?.questionCount ??
              10,
    );
  }

  void _applyMissionConfiguration(
    String difficultyId, {
    int? questionCountOverride,
    String regionId = 'world',
    bool selectAllEligible = false,
    GeoBrainSelectionProfile selectionProfile =
        GeoBrainSelectionProfile.balanced,
    Set<String>? allowedCountryIds,
    bool useGeoBrainPersonalization = true,
    String? deterministicSelectionSeed,
  }) {
    final String normalizedId =
        difficultyId
            .trim()
            .toLowerCase();

    final String resolvedId =
        _difficulties.containsKey(
          normalizedId,
        )
            ? normalizedId
            : 'discovery';

    _currentDifficultyId =
        resolvedId;

    final int maximumDifficulty = selectAllEligible
        ? resolvedId == 'expert'
            ? 100
            : 85
        : _maximumCountryDifficultyFor(resolvedId);
    final String normalizedRegion =
        _normalizeTrainingRegionId(regionId);
    final Set<String>? normalizedAllowedIds = allowedCountryIds
        ?.map<String>((String id) => id.trim().toUpperCase())
        .toSet();

    final List<GeoCountry> playableCountries =
        _countries.where(
      (GeoCountry country) {
        return !_isExcludedFromQuestions(
          country,
        );
      },
    ).toList(
      growable: false,
    );

    final List<GeoCountry> filtered =
        playableCountries.where(
      (GeoCountry country) {
        final String countryId =
            country.id
                .trim()
                .toUpperCase();

        if (normalizedAllowedIds != null &&
            !normalizedAllowedIds.contains(countryId)) {
          return false;
        }

        if (selectAllEligible &&
            _completeTrainingExcludedEntityIds.contains(countryId)) {
          return false;
        }

        final int difficulty =
            _countryDifficulties[
              countryId
            ] ??
            100;
        final bool isPlayableAntarctica =
            normalizedRegion == 'antarctica' && countryId == 'ATA';

        final bool usesTerritorialReference =
            _findReferenceOverride(
                  country,
                ) !=
                null;

        final bool requiresCapital =
            _currentModeId ==
                    'find_capital' ||
                _currentModeId ==
                    'mixed';

        final bool hasRequiredCapital =
            !requiresCapital ||
                (!usesTerritorialReference &&
                    _findCapital(
                      country,
                    ) !=
                    null);

        final bool requiresFlag =
            _currentModeId ==
                    'find_flag' ||
                _currentModeId ==
                    'mixed';

        final bool hasRequiredFlag =
            !requiresFlag ||
                (!usesTerritorialReference &&
                    RegExp(
                      r'^[A-Z]{2}$',
                    ).hasMatch(
                      country.isoA2
                          .trim()
                          .toUpperCase(),
                    ));

        return (normalizedAllowedIds != null ||
                difficulty <= maximumDifficulty ||
                isPlayableAntarctica) &&
            hasRequiredCapital &&
            hasRequiredFlag;
      },
    ).toList(
      growable: false,
    );

    final List<GeoCountry> difficultyEligibleCountries =
        filtered.isEmpty && normalizedAllowedIds == null
            ? playableCountries
            : filtered;

    final List<GeoCountry> regionalCountries =
        difficultyEligibleCountries.where((GeoCountry country) {
      return _matchesTrainingRegion(country, regionId);
    }).toList(growable: false);

    final List<GeoCountry> eligibleCountries = regionalCountries;

    final int requestedQuestionCount =
        questionCountOverride ??
        _difficulties[
              _currentDifficultyId
            ]?.questionCount ??
            10;

    final List<GeoCountry> selectedCountries = selectAllEligible
        ? eligibleCountries
        : useGeoBrainPersonalization
            ? _countrySelector.selectCountries(
            availableCountries: eligibleCountries,
            questionCount: requestedQuestionCount,
            theme: GeoBrainTheme.fromModeId(_currentModeId),
            selectionProfile: selectionProfile,
          )
            : _deterministicChallengeCountries(
                eligibleCountries,
                requestedQuestionCount,
                deterministicSelectionSeed ?? '',
              );

    _missionCountries =
        List<GeoCountry>.unmodifiable(
      selectedCountries.isEmpty
          ? eligibleCountries
          : selectedCountries,
    );

    debugPrint(
      'GeoPoint : expédition '
      '$_currentDifficultyId → '
      '${eligibleCountries.length} '
      'entité(s) éligible(s), '
      '${_missionCountries.length} '
      'sélectionnée(s) par le GeoBrain, '
      'mode $_currentModeId, '
      'difficulté maximale '
      '$maximumDifficulty.',
    );
  }

  List<GeoCountry> _deterministicChallengeCountries(
    List<GeoCountry> countries,
    int questionCount,
    String seed,
  ) {
    final List<GeoCountry> sorted = List<GeoCountry>.from(countries)
      ..sort((GeoCountry left, GeoCountry right) {
        final int leftKey = _stableSelectionKey(seed, left.id);
        final int rightKey = _stableSelectionKey(seed, right.id);
        final int keyComparison = leftKey.compareTo(rightKey);
        return keyComparison != 0
            ? keyComparison
            : left.id.compareTo(right.id);
      });
    return sorted.take(questionCount).toList(growable: false);
  }

  int _stableSelectionKey(String seed, String countryId) {
    int hash = 0x811C9DC5;
    for (final int codeUnit
        in '$seed|${countryId.trim().toUpperCase()}'.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  int challengeRandomSeed(String challengeId) {
    return _stableSelectionKey(challengeId, 'questions');
  }

  void _applyContinentConfiguration(
    ContinentLevel level,
  ) {
    final List<String> normalizedCatalogIds =
        level.countryIds.map<String>((String id) {
      return id.trim().toUpperCase();
    }).toList(growable: false);

    final Set<String> requestedIds =
        normalizedCatalogIds.toSet();

    final bool requiresCapital =
        _currentModeId == 'find_capital' ||
            _currentModeId == 'mixed';

    final bool requiresFlag =
        _currentModeId == 'find_flag' ||
            _currentModeId == 'mixed';

    final List<GeoCountry> selected =
        _countries.where((GeoCountry country) {
      final String countryId =
          country.id.trim().toUpperCase();

      if (!requestedIds.contains(countryId) ||
          _isExcludedFromQuestions(country)) {
        return false;
      }

      final bool usesTerritorialReference =
          _findReferenceOverride(country) != null;

      final bool hasRequiredCapital =
          !requiresCapital ||
              (!usesTerritorialReference &&
                  _findCapital(country) != null);

      final bool hasRequiredFlag =
          !requiresFlag ||
              (!usesTerritorialReference &&
                  RegExp(r'^[A-Z]{2}$').hasMatch(
                    country.isoA2.trim().toUpperCase(),
                  ));

      return hasRequiredCapital && hasRequiredFlag;
    }).toList();

    selected.sort((GeoCountry first, GeoCountry second) {
      return normalizedCatalogIds
          .indexOf(first.id.trim().toUpperCase())
          .compareTo(
            normalizedCatalogIds.indexOf(
              second.id.trim().toUpperCase(),
            ),
          );
    });

    final List<GeoCountry> missionCountries =
        level.useGeoBrain && selected.isNotEmpty
            ? _countrySelector.selectCountries(
                availableCountries: selected,
                questionCount: level.questionCount,
                theme: GeoBrainTheme.fromModeId(_currentModeId),
              )
            : selected;

    _missionCountries = List<GeoCountry>.unmodifiable(
      missionCountries,
    );

    debugPrint(
      'GeoPoint : niveau continental ${level.id} → '
      '${_missionCountries.length} pays disponibles, '
      '${level.questionCount} questions, mode $_currentModeId.',
    );
  }

  void _applyGuidedConfiguration(
    GuidedLevel level,
  ) {
    final Set<String> requestedIds =
        level.countryIds
            .map<String>(
              (String id) =>
                  id.trim().toUpperCase(),
            )
            .toSet();

    final List<GeoCountry> selected =
        _countries.where(
      (GeoCountry country) {
        return requestedIds.contains(
              country.id
                  .trim()
                  .toUpperCase(),
            ) &&
            !_isExcludedFromQuestions(
              country,
            );
      },
    ).toList();

    selected.sort(
      (
        GeoCountry first,
        GeoCountry second,
      ) {
        final int firstCatalogIndex =
            level.countryIds.indexOf(
          first.id.trim().toUpperCase(),
        );

        final int secondCatalogIndex =
            level.countryIds.indexOf(
          second.id.trim().toUpperCase(),
        );

        return firstCatalogIndex.compareTo(
          secondCatalogIndex,
        );
      },
    );

    _missionCountries =
        List<GeoCountry>.unmodifiable(
      selected,
    );

    debugPrint(
      'GeoPoint : parcours guidé ${level.id} → '
      '${_missionCountries.length} pays, '
      '${level.questionCount} questions.',
    );
  }

  GameQuestion? _createNextGuidedQuestion() {
    if (_missionCountries.isEmpty) {
      return null;
    }

    if (_guidedQuestionQueue.isEmpty) {
      _guidedQuestionQueue.addAll(
        _missionCountries,
      );
    }

    final GeoCountry country =
        _guidedQuestionQueue.removeAt(0);

    final GuidedLevel? level =
        _currentGuidedLevel;

    final int questionIndex =
        _session.questionNumber;

    final String questionModeId =
        level?.modeIdForQuestion(
              questionIndex,
            ) ??
            'find_country';

    return GameQuestion(
      modeId: _normalizeModeId(
        questionModeId,
      ),
      countryId: country.id,
      countryName: country.name,
      isoA2: country.isoA2,
      continent: country.continent,
    );
  }

  GameQuestion? _createNextCompleteTrainingQuestion() {
    if (_completeTrainingQueue.isEmpty) {
      return null;
    }

    final GeoCountry country = _completeTrainingQueue.removeAt(0);

    return _gameEngine.createNextQuestion(
      <GeoCountry>[country],
      modeId: _currentModeId,
    );
  }

  String _normalizeTrainingRegionId(String regionId) {
    final String normalized = regionId.trim().toLowerCase();

    switch (normalized) {
      case 'europe':
      case 'africa':
      case 'asia':
      case 'americas':
      case 'oceania':
      case 'antarctica':
        return normalized;

      default:
        return 'world';
    }
  }

  bool _matchesTrainingRegion(
    GeoCountry country,
    String regionId,
  ) {
    final String region = _normalizeTrainingRegionId(regionId);

    if (region == 'world') {
      return true;
    }

    final String continent = country.continent.trim().toLowerCase();

    switch (region) {
      case 'europe':
        return continent.contains('europe');

      case 'africa':
        return continent.contains('africa') ||
            continent.contains('afrique');

      case 'asia':
        return continent.contains('asia') || continent.contains('asie');

      case 'americas':
        return continent.contains('america') ||
            continent.contains('amérique');

      case 'oceania':
        return continent.contains('oceania') ||
            continent.contains('océanie');

      case 'antarctica':
        return continent.contains('antarct');

      default:
        return true;
    }
  }

  String _normalizeModeId(
    String modeId,
  ) {
    final String normalized =
        modeId.trim().toLowerCase();

    switch (normalized) {
      case 'find_country':
      case 'find_capital':
      case 'find_flag':
      case 'mixed':
        return normalized;

      default:
        return 'find_country';
    }
  }

  double _capitalValidationRadiusKm() {
    switch (_currentDifficultyId) {
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

  String _stampIdForCurrentMode() {
    switch (_currentModeId) {
      case 'find_capital':
        return 'capitals';

      case 'find_flag':
        return 'flags';

      case 'mixed':
        return 'mixed';

      case 'find_country':
      default:
        return 'countries';
    }
  }

  List<GeoCountry> ultimateCountriesForDifficulty(
    String difficultyId,
  ) {
    final String normalizedId =
        difficultyId
            .trim()
            .toLowerCase();

    final String resolvedId =
        _difficulties.containsKey(
          normalizedId,
        )
            ? normalizedId
            : 'discovery';

    final int maximumDifficulty =
        _maximumCountryDifficultyFor(
      resolvedId,
    );

    final List<GeoCountry> result =
        _countries.where(
      (GeoCountry country) {
        final String countryId =
            country.id
                .trim()
                .toUpperCase();

        final int difficulty =
            _countryDifficulties[
                  countryId
                ] ??
                100;

        final bool hasUsableShape =
            country.polygons.any(
          (List<LatLng> polygon) {
            return polygon.length >= 3;
          },
        );

        return !_isExcludedFromQuestions(
              country,
            ) &&
            difficulty <=
                maximumDifficulty &&
            hasUsableShape;
      },
    ).toList(
      growable: false,
    );

    return List<GeoCountry>.unmodifiable(
      result,
    );
  }

  List<GeoCountry> ultimateChallengeCountries({
    required String challengeId,
    required String difficultyId,
    required String regionId,
    Set<String>? allowedCountryIds,
    bool geoBrainPersonalizationAllowed = false,
    required int questionCount,
  }) {
    final Set<String>? normalizedAllowedIds = allowedCountryIds
        ?.map((String id) => id.trim().toUpperCase())
        .where((String id) => id.isNotEmpty)
        .toSet();
    final List<GeoCountry> eligible = ultimateCountriesForDifficulty(
      difficultyId,
    ).where((GeoCountry country) {
      final String countryId = country.id.trim().toUpperCase();
      return _matchesTrainingRegion(country, regionId) &&
          (normalizedAllowedIds == null ||
              normalizedAllowedIds.contains(countryId));
    }).toList(growable: false);

    if (geoBrainPersonalizationAllowed) {
      return _countrySelector.selectCountries(
        availableCountries: eligible,
        questionCount: questionCount,
        theme: GeoBrainTheme.silhouette,
      );
    }
    return List<GeoCountry>.unmodifiable(
      _deterministicChallengeCountries(
        eligible,
        questionCount,
        challengeId,
      ),
    );
  }

  int _maximumCountryDifficultyFor(
    String difficultyId,
  ) {
    switch (difficultyId) {
      case 'discovery':
        return 20;

      case 'easy':
        return 40;

      case 'intermediate':
        return 65;

      case 'hard':
        return 85;

      case 'expert':
        return 100;

      default:
        return 20;
    }
  }

  bool _isExcludedFromQuestions(
    GeoCountry country,
  ) {
    final String countryId =
        country.id
            .trim()
            .toUpperCase();

    return !PlayableCountryPolicy.isPlayableId(countryId);
  }

  ReferencePoint? _findReferenceOverride(
    GeoCountry country,
  ) {
    final String countryId =
        country.id
            .trim()
            .toUpperCase();

    if (countryId.isEmpty) {
      return null;
    }

    final ReferencePoint? directMatch =
        _referenceOverrides[countryId];

    if (directMatch != null) {
      return directMatch;
    }

    for (final ReferencePoint point
        in _referenceOverrides.values) {
      if (point.entityId
              .trim()
              .toUpperCase() ==
          countryId) {
        return point;
      }
    }

    return null;
  }

  Capital? _findCapital(
    GeoCountry country,
  ) {
    if (_findReferenceOverride(
          country,
        ) !=
        null) {
      return null;
    }

    final String countryId =
        country.id
            .trim()
            .toUpperCase();

    final Capital? byCountryId =
        _capitals[countryId];

    if (byCountryId != null) {
      return byCountryId;
    }

    final String isoA2 =
        country.isoA2
            .trim()
            .toUpperCase();

    if (isoA2.isEmpty) {
      return null;
    }

    for (final Capital capital
        in _capitals.values) {
      if (capital.isoA2 == isoA2) {
        return capital;
      }
    }

    return null;
  }

  GeoCountry? _findCountryById(
    String countryId,
  ) {
    final String normalizedId =
        countryId
            .trim()
            .toUpperCase();

    for (final GeoCountry country
        in _countries) {
      if (country.id
              .trim()
              .toUpperCase() ==
          normalizedId) {
        return country;
      }
    }

    return null;
  }

  LatLng _calculateCountryCenter(
    GeoCountry country,
  ) {
    final double latitude =
        (
          country.bounds.minLatitude +
          country.bounds.maxLatitude
        ) /
        2;

    final double longitude =
        (
          country.bounds.minLongitude +
          country.bounds.maxLongitude
        ) /
        2;

    return LatLng(
      latitude,
      longitude,
    );
  }

  void _clearAnswer() {
    _selectedPoint = null;
    _answerPoint = null;

    _selectedCountry = null;
    _answerCountry = null;

    _answerCapital = null;
    _answerReferencePoint = null;

    _distanceInKilometers = null;
  }

  void _recordEncounteredCountry(GeoCountry country) {
    final String countryId = country.id.trim().toUpperCase();

    if (countryId.isEmpty ||
        _encounteredCountries.any(
          (GeoCountry existing) =>
              existing.id.trim().toUpperCase() == countryId,
        )) {
      return;
    }

    _encounteredCountries.add(country);
  }

  void _recordValidatedCountry(GeoCountry country) {
    final String countryId = country.id.trim().toUpperCase();

    if (countryId.isEmpty ||
        _validatedCountries.any(
          (GeoCountry existing) =>
              existing.id.trim().toUpperCase() == countryId,
        )) {
      return;
    }

    _validatedCountries.add(country);
  }

  void _queueCompleteTrainingRetry(GeoCountry country) {
    final String countryId = country.id.trim().toUpperCase();

    if (countryId.isEmpty ||
        _validatedCountries.any(
          (GeoCountry existing) =>
              existing.id.trim().toUpperCase() == countryId,
        ) ||
        _completeTrainingQueue.any(
          (GeoCountry queued) =>
              queued.id.trim().toUpperCase() == countryId,
        )) {
      return;
    }

    _completeTrainingQueue.add(country);
    _session = _session.addRetryQuestion();
  }

  void _stopTimer() {
    _questionTimer?.cancel();
    _questionTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopTimer();
    super.dispose();
  }
}
