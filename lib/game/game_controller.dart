import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../geo_engine/capital.dart';
import '../geo_engine/capital_loader.dart';
import '../geo_engine/geo_country.dart';
import '../geo_engine/reference_point.dart';
import '../geo_engine/reference_point_loader.dart';
import '../geobrain/country_selector.dart';
import '../geobrain/geobrain_service.dart';
import '../player/level_result.dart';
import '../player/player_profile.dart';
import '../player/player_storage.dart';
import '../player/xp_system.dart';
import 'continent/continent_expedition.dart';
import 'country_difficulty_loader.dart';
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
import 'score_system.dart';

class GameController extends ChangeNotifier {
  static const Set<String>
      _excludedQuestionEntityIds =
      <String>{
    'CYN',
    'PSX',
    'SAH',
    'SOL',
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
  late GeoBrainService _geoBrainService;
  late CountrySelector _countrySelector;

  PassportResult? _lastPassportResult;
  LevelResult? _lastLevelResult;

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

  PlayerPassport get passport =>
      _passport;

  PassportEngine get passportEngine =>
      _passportEngine;

  PassportResult? get lastPassportResult =>
      _lastPassportResult;

  PlayerProfile get playerProfile =>
      _playerProfile;

  LevelResult? get lastLevelResult =>
      _lastLevelResult;

  GeoBrainService get geoBrainService =>
      _geoBrainService;

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

    _playerProfile =
        savedProfile ??
            PlayerProfile.initial();

    _geoBrainService =
        geoBrainService;

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

    _applyMissionConfiguration(
      'discovery',
    );

    _gameEngine.reset();
    _session = _createInitialSession();

    _clearAnswer();

    notifyListeners();
  }

  void startMission({
    required String difficultyId,
    String modeId = 'find_country',
  }) {
    _stopTimer();

    _currentGuidedLevel = null;
    _currentContinentLevel = null;
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
    _currentModeId = _normalizeModeId(
      level.modeId,
    );
    _currentDifficultyId = 'discovery';

    _applyGuidedConfiguration(level);

    _gameEngine.reset();
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
    _session = GameSession.initial(
      questionDurationSeconds:
          level.questionDurationSeconds,
      totalQuestions: level.questionCount,
    );

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

    final GameQuestion? question =
        _currentGuidedLevel == null
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

    if (_currentGuidedLevel == null &&
        (questionModeId ==
            'find_country' ||
        questionModeId ==
            'find_flag')) {
      unawaited(
        _registerGeoBrainAnswer(
          countryId:
              answerCountry.id,
          isCorrect:
              isCorrectCountry,
        ),
      );
    }

    _registerCompletedGame();

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
        PlayerPassport.initial();

    _lastPassportResult = null;

    _passportResultRegisteredForCurrentGame =
        false;

    debugPrint(
      'GeoPoint : Passeport réinitialisé.',
    );

    notifyListeners();
  }

  Future<void> clearSavedPlayerProfile() async {
    await PlayerStorage.clear();

    _playerProfile =
        PlayerProfile.initial();

    _lastLevelResult = null;

    debugPrint(
      'GeoPoint : profil joueur réinitialisé.',
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
    } else {
      _applyMissionConfiguration(
        _currentDifficultyId,
      );
    }

    debugPrint(
      'GeoPoint GeoBrain : progression réinitialisée.',
    );

    notifyListeners();
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

    if (_currentGuidedLevel == null &&
        answerCountry != null &&
        (
          questionModeId ==
                  'find_country' ||
              questionModeId ==
                  'find_flag'
        )) {
      unawaited(
        _registerGeoBrainAnswer(
          countryId:
              answerCountry.id,
          isCorrect: false,
        ),
      );
    }

    _registerCompletedGame();
  }

  void _registerCompletedGame() {
    if (!_session.isGameOver ||
        _passportResultRegisteredForCurrentGame) {
      return;
    }

    if (_currentGuidedLevel != null) {
      _passportResultRegisteredForCurrentGame =
          true;

      debugPrint(
        'GeoPoint : tutoriel terminé, '
        'progression joueur inchangée.',
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

    final LevelResult levelResult =
        _xpSystem.applyGameResult(
      profile: _playerProfile,
      correctAnswers:
          _session.correctAnswers,
      totalQuestions:
          _session.totalQuestions,
      averageDistanceKm:
          _session.averageDistanceInKilometers,
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
      gameScore:
          _session.totalScore,
      gameCorrectAnswers:
          _session.correctAnswers,
      gameTotalAnswers:
          _session.totalQuestions,
      gameDistanceInKilometers:
          totalGameDistance,
      gameElapsedSeconds:
          totalGameElapsedSeconds,
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
      '+${levelResult.earnedXp} XP, '
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
  }

  Future<void> _registerGeoBrainAnswer({
    required String countryId,
    required bool isCorrect,
  }) async {
    await _geoBrainService.registerAnswer(
      countryId:
          countryId,
      isCorrect:
          isCorrect,
    );

    notifyListeners();
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
          difficulty?.questionCount ??
              10,
    );
  }

  void _applyMissionConfiguration(
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

    _currentDifficultyId =
        resolvedId;

    final int maximumDifficulty =
        _maximumCountryDifficultyFor(
      resolvedId,
    );

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

        final int difficulty =
            _countryDifficulties[
              countryId
            ] ??
            100;

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

        return difficulty <=
                maximumDifficulty &&
            hasRequiredCapital &&
            hasRequiredFlag;
      },
    ).toList(
      growable: false,
    );

    final List<GeoCountry> eligibleCountries =
        filtered.isEmpty
            ? playableCountries
            : filtered;

    final int requestedQuestionCount =
        _difficulties[
              _currentDifficultyId
            ]?.questionCount ??
            10;

    final List<GeoCountry> selectedCountries =
        _countrySelector.selectCountries(
      availableCountries:
          eligibleCountries,
      questionCount:
          requestedQuestionCount,
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

    return _excludedQuestionEntityIds.contains(
      countryId,
    );
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

  void _stopTimer() {
    _questionTimer?.cancel();
    _questionTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
