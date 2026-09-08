import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../game/game_controller.dart';
import '../../geobrain/geobrain_attempt.dart';
import '../../monetization/interstitial_ad_service.dart';
import '../../geobrain/geobrain_theme.dart';
import '../../geo_engine/country_info.dart';
import '../../geo_engine/country_info_loader.dart';
import '../../geo_engine/geo_country.dart';
import '../../geo_engine/geopoint_map.dart';
import '../atlas/atlas_city.dart';
import '../atlas/atlas_city_loader.dart';
import '../design/geopoint_design.dart';
import '../settings/gameplay_feedback.dart';
import 'world_quiz_engine.dart';

class WorldQuizGameResult {
  const WorldQuizGameResult({
    required this.totalScore,
    required this.correctAnswers,
    required this.totalQuestions,
  });

  final int totalScore;
  final int correctAnswers;
  final int totalQuestions;
}

class WorldQuizGameScreen extends StatefulWidget {
  const WorldQuizGameScreen({
    required this.controller,
    required this.mode,
    required this.modeTitle,
    required this.questionCount,
    this.regionId = 'world',
    this.difficultyId = 'easy',
    this.attemptContext = GeoBrainAttemptContext.classicGame,
    this.returnExpeditionResult = false,
    this.onExpeditionCompleted,
    super.key,
  });

  final GameController controller;
  final WorldQuizMode mode;
  final String modeTitle;
  final int questionCount;
  final String regionId;
  final String difficultyId;
  final GeoBrainAttemptContext attemptContext;
  final bool returnExpeditionResult;
  final Future<void> Function(WorldQuizGameResult result)?
      onExpeditionCompleted;

  @override
  State<WorldQuizGameScreen> createState() => _WorldQuizGameScreenState();
}

class _WorldQuizGameScreenState extends State<WorldQuizGameScreen> {
  final Set<String> _usedQuestionIds = <String>{};
  final Set<String> _selectedCountryIds = <String>{};

  WorldQuizEngine? _engine;
  WorldQuizQuestion? _question;
  Object? _loadError;

  int _questionNumber = 1;
  int _score = 0;
  int _correctAnswers = 0;
  int _lastScore = 0;
  int? _selectedAnswerIndex;
  double? _lastDistanceKilometers;
  bool _answered = false;
  bool _finished = false;
  bool _isCompleting = false;
  DateTime _questionStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
        CountryInfoLoader.loadCountryInfos(),
        AtlasCityLoader.loadCities(),
      ]);

      final WorldQuizEngine engine = WorldQuizEngine(
        countries: widget.controller.countries,
        countryInfos:
            (loaded[0] as Map<String, CountryInfo>).values,
        cities: loaded[1] as List<AtlasCity>,
        regionId: widget.regionId,
        difficultyId: widget.difficultyId,
      );

      if (!engine.hasEnoughData) {
        throw StateError(
          'Aucune donnée compatible avec cette zone.',
        );
      }

      final WorldQuizQuestion question = engine.nextQuestion(
        mode: widget.mode,
        usedQuestionIds: _usedQuestionIds,
      );
      _usedQuestionIds.add(question.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _engine = engine;
        _question = question;
        _questionStartedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
      });
    }
  }

  void _answerChoice(int index) {
    final WorldQuizQuestion? question = _question;
    if (_answered || question == null) {
      return;
    }

    final bool correct = index == question.correctAnswerIndex;
    final String proposedAnswer = question.answers[index];
    setState(() {
      _selectedAnswerIndex = index;
      _answered = true;
      _lastScore = correct ? 100 : 0;
      _score += _lastScore;
      if (correct) {
        _correctAnswers++;
      }
    });
    GameplayFeedback.answer(isCorrect: correct);
    _recordSingleCountryAttempt(
      question: question,
      isCorrect: correct,
      proposedAnswerId: proposedAnswer,
    );
  }

  void _answerPlacement(LatLng point) {
    final WorldQuizQuestion? question = _question;
    final LatLng? target = question?.targetPoint;
    if (_answered || question == null || target == null) {
      return;
    }

    final double distance = const Distance().as(
      LengthUnit.Kilometer,
      point,
      target,
    );
    final int placementScore = _placementScore(distance);
    final bool correct = distance <= _placementValidationRadius;

    setState(() {
      _answered = true;
      _lastDistanceKilometers = distance;
      _lastScore = placementScore;
      _score += placementScore;
      if (correct) {
        _correctAnswers++;
      }
    });
    GameplayFeedback.answer(isCorrect: correct);
    _recordSingleCountryAttempt(
      question: question,
      isCorrect: correct,
      distanceInKilometers: distance,
    );
  }

  int _placementScore(double distance) {
    final double radius = _placementValidationRadius;
    if (distance <= radius * 0.20) return 120;
    if (distance <= radius * 0.50) return 100;
    if (distance <= radius) return 75;
    if (distance <= radius * 2) return 40;
    if (distance <= radius * 3.5) return 20;
    return 0;
  }

  double get _placementValidationRadius {
    switch (widget.difficultyId) {
      case 'easy':
        return 450;
      case 'intermediate':
        return 300;
      case 'hard':
        return 180;
      case 'expert':
        return 90;
      default:
        return 300;
    }
  }

  void _toggleCountrySelection(String? countryId) {
    if (_answered || countryId == null) {
      return;
    }
    final String normalizedId = countryId.trim().toUpperCase();
    if (normalizedId.isEmpty) {
      return;
    }
    setState(() {
      if (!_selectedCountryIds.remove(normalizedId)) {
        _selectedCountryIds.add(normalizedId);
      }
    });
  }

  void _validateCountrySelection() {
    final WorldQuizQuestion? question = _question;
    if (_answered || question == null || !question.usesMultiSelectMap) {
      return;
    }

    final Set<String> expected = question.correctCountryIds
        .map((String id) => id.trim().toUpperCase())
        .toSet();
    final Set<String> correctSelected =
        _selectedCountryIds.intersection(expected);
    final Set<String> wrongSelected =
        _selectedCountryIds.difference(expected);
    final bool exact =
        wrongSelected.isEmpty && correctSelected.length == expected.length;
    final double rawRatio = expected.isEmpty
        ? 0
        : (correctSelected.length - wrongSelected.length) / expected.length;
    final int selectionScore =
        (rawRatio.clamp(0.0, 1.0) * 100).round();

    setState(() {
      _answered = true;
      _lastScore = selectionScore;
      _score += selectionScore;
      if (exact) {
        _correctAnswers++;
      }
    });
    GameplayFeedback.answer(isCorrect: exact);
    _recordMultiCountryAttempts(
      question: question,
      expectedCountryIds: expected,
      selectedCountryIds: Set<String>.from(_selectedCountryIds),
    );
  }

  Future<void> _nextQuestion() async {
    final WorldQuizEngine? engine = _engine;
    if (!_answered || engine == null) {
      return;
    }

    if (_questionNumber >= widget.questionCount) {
      if (_isCompleting) {
        return;
      }
      _isCompleting = true;
      try {
        await widget.onExpeditionCompleted?.call(
          WorldQuizGameResult(
            totalScore: _score,
            correctAnswers: _correctAnswers,
            totalQuestions: widget.questionCount,
          ),
        );
      } finally {
        _isCompleting = false;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _finished = true;
      });
      return;
    }

    final WorldQuizQuestion question = engine.nextQuestion(
      mode: widget.mode,
      usedQuestionIds: _usedQuestionIds,
    );
    _usedQuestionIds.add(question.id);

    setState(() {
      _questionNumber++;
      _question = question;
      _selectedAnswerIndex = null;
      _lastDistanceKilometers = null;
      _lastScore = 0;
      _answered = false;
      _selectedCountryIds.clear();
      _questionStartedAt = DateTime.now();
    });
  }

  void _restart() {
    final WorldQuizEngine? engine = _engine;
    if (engine == null) {
      return;
    }

    _usedQuestionIds.clear();
    final WorldQuizQuestion question = engine.nextQuestion(
      mode: widget.mode,
      usedQuestionIds: _usedQuestionIds,
    );
    _usedQuestionIds.add(question.id);

    setState(() {
      _questionNumber = 1;
      _score = 0;
      _correctAnswers = 0;
      _lastScore = 0;
      _selectedAnswerIndex = null;
      _lastDistanceKilometers = null;
      _answered = false;
      _finished = false;
      _isCompleting = false;
      _question = question;
      _selectedCountryIds.clear();
      _questionStartedAt = DateTime.now();
    });
  }

  Future<void> _leaveResults() async {
    if (_finished &&
        (widget.attemptContext == GeoBrainAttemptContext.training ||
            widget.attemptContext == GeoBrainAttemptContext.expedition)) {
      await InterstitialAdService.instance.registerCompletedGame();
      if (!mounted) return;
    }
    Navigator.of(context).pop();
  }

  void _recordSingleCountryAttempt({
    required WorldQuizQuestion question,
    required bool isCorrect,
    double? distanceInKilometers,
    String? proposedAnswerId,
  }) {
    final GeoCountry? country = question.answerCountry;
    final GeoBrainTheme? theme = _geoBrainThemeFor(question.kind);
    if (country == null || theme == null) {
      return;
    }
    unawaited(
      widget.controller.registerGeoBrainAttempt(
        GeoBrainAttempt(
          countryId: country.id,
          theme: theme,
          answeredAt: DateTime.now(),
          modeId: _modeIdFor(question.kind),
          difficultyId: widget.difficultyId,
          isCorrect: isCorrect,
          distanceInKilometers: distanceInKilometers,
          responseTimeMilliseconds:
              DateTime.now().difference(_questionStartedAt).inMilliseconds,
          proposedAnswerId: proposedAnswerId,
          context: widget.attemptContext,
        ),
      ),
    );
  }

  void _recordMultiCountryAttempts({
    required WorldQuizQuestion question,
    required Set<String> expectedCountryIds,
    required Set<String> selectedCountryIds,
  }) {
    final GeoBrainTheme? theme = _geoBrainThemeFor(question.kind);
    if (theme == null) {
      return;
    }
    final DateTime answeredAt = DateTime.now();
    final int responseTime =
        answeredAt.difference(_questionStartedAt).inMilliseconds;
    final String proposedAnswer = (selectedCountryIds.toList()..sort()).join(',');
    final Set<String> evaluatedIds = <String>{
      ...expectedCountryIds,
      ...selectedCountryIds,
    };
    for (final String countryId in evaluatedIds) {
      final bool isExpected = expectedCountryIds.contains(countryId);
      final bool wasSelected = selectedCountryIds.contains(countryId);
      unawaited(
        widget.controller.registerGeoBrainAttempt(
          GeoBrainAttempt(
            countryId: countryId,
            theme: theme,
            answeredAt: answeredAt,
            modeId: _modeIdFor(question.kind),
            difficultyId: widget.difficultyId,
            isCorrect: isExpected && wasSelected,
            responseTimeMilliseconds: responseTime,
            proposedAnswerId: proposedAnswer,
            context: widget.attemptContext,
          ),
        ),
      );
    }
  }

  GeoBrainTheme? _geoBrainThemeFor(WorldQuizKind kind) {
    switch (kind) {
      case WorldQuizKind.placeCity:
      case WorldQuizKind.cityCountry:
        return GeoBrainTheme.cities;
      case WorldQuizKind.currency:
        return GeoBrainTheme.currency;
      case WorldQuizKind.language:
        return GeoBrainTheme.languages;
      case WorldQuizKind.populationRange:
      case WorldQuizKind.populationCompare:
      case WorldQuizKind.ranking:
      case WorldQuizKind.area:
        return null;
    }
  }

  String _modeIdFor(WorldQuizKind kind) {
    switch (kind) {
      case WorldQuizKind.placeCity:
        return 'place_city';
      case WorldQuizKind.cityCountry:
        return 'city_country';
      case WorldQuizKind.currency:
        return 'currency';
      case WorldQuizKind.language:
        return 'language';
      case WorldQuizKind.populationRange:
        return 'population_range';
      case WorldQuizKind.populationCompare:
        return 'population_compare';
      case WorldQuizKind.ranking:
        return 'ranking';
      case WorldQuizKind.area:
        return 'area';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: _loadError != null
                ? _QuizLoadError(
                    error: _loadError!,
                    onBack: () => Navigator.of(context).pop(),
                  )
                : _question == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: GeoColors.gold,
                        ),
                      )
                    : _finished
                        ? _buildResults()
                        : _buildQuestion(_question!),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(WorldQuizQuestion question) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: GeoGameTopBar(
                title: widget.modeTitle,
                subtitle: 'Question $_questionNumber / ${widget.questionCount}',
                onBack: () => Navigator.of(context).pop(),
                trailing: _ScoreBadge(score: _score),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: _questionNumber / widget.questionCount,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  color: GeoColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _QuestionHeader(question: question),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: question.usesMap
                  ? _buildMapQuestion(question)
                  : _buildChoiceQuestion(question),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapQuestion(WorldQuizQuestion question) {
    final bool multiSelect = question.usesMultiSelectMap;
    final Set<String> expected = question.correctCountryIds
        .map((String id) => id.trim().toUpperCase())
        .toSet();
    final Map<String, Color> fillColors = <String, Color>{};
    final Map<String, Color> borderColors = <String, Color>{};

    if (multiSelect) {
      if (_answered) {
        for (final String id in expected) {
          final bool wasSelected = _selectedCountryIds.contains(id);
          fillColors[id] = wasSelected ? GeoColors.mint : const Color(0xFFFFB347);
          borderColors[id] = wasSelected
              ? const Color(0xFF056F27)
              : const Color(0xFFB85C00);
        }
        for (final String id in _selectedCountryIds.difference(expected)) {
          fillColors[id] = GeoColors.coral;
          borderColors[id] = const Color(0xFF8F1710);
        }
      } else {
        for (final String id in _selectedCountryIds) {
          fillColors[id] = GeoColors.sky;
          borderColors[id] = const Color(0xFF064FAD);
        }
      }
    }

    final bool exactSelection = multiSelect &&
        _selectedCountryIds.difference(expected).isEmpty &&
        expected.difference(_selectedCountryIds).isEmpty;

    if (!multiSelect && _answered && question.answerCountry != null) {
      final String answerId =
          question.answerCountry!.id.trim().toUpperCase();
      fillColors[answerId] = GeoColors.mint;
      borderColors[answerId] = const Color(0xFF056F27);
    }

    final Widget map = GeoPointMap(
      key: ValueKey<String>('${question.id}-$_questionNumber'),
      initialCenter: _initialMapCenter,
      initialZoom: _initialMapZoom,
      maximumZoom: multiSelect ? 10 : _maximumMapZoom,
      answerPoint:
          !multiSelect && _answered ? question.targetPoint : null,
      answerCountry:
          !multiSelect && _answered ? question.answerCountry : null,
      preferProvidedAnswerCountry: true,
      resultRadiusInKilometers:
          !multiSelect ? _placementValidationRadius : null,
      countryFillColors: fillColors,
      countryBorderColors: borderColors,
      labelledCountryIds: multiSelect && _answered
          ? expected
          : const <String>{},
      showTapSelection: !multiSelect,
      showInformationPanel: false,
      allowInteraction: !_answered,
      onCountrySelected: multiSelect
          ? (GeoCountry? country) => _toggleCountrySelection(country?.id)
          : null,
      onTap: multiSelect ? null : _answerPlacement,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: map,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xE6071B3A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _mapZoneLabel,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),
          if (multiSelect && !_answered)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _MultiSelectionBar(
                selectedCount: _selectedCountryIds.length,
                onValidate: _selectedCountryIds.isEmpty
                    ? null
                    : _validateCountrySelection,
              ),
            ),
          if (_answered)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _AnswerExplanation(
                correct: multiSelect
                    ? exactSelection
                    : (_lastDistanceKilometers ?? double.infinity) <=
                        _placementValidationRadius,
                score: _lastScore,
                explanation: question.explanation,
                distanceKilometers: _lastDistanceKilometers,
                onNext: _nextQuestion,
                lastQuestion: _questionNumber >= widget.questionCount,
              ),
            ),
        ],
      ),
    );
  }

  String get _mapZoneLabel {
    switch (widget.regionId) {
      case 'europe':
        return 'EUROPE';
      case 'africa':
        return 'AFRIQUE';
      case 'asia':
        return 'ASIE';
      case 'americas':
        return 'AMÉRIQUES';
      case 'oceania':
        return 'OCÉANIE';
      case 'antarctica':
        return 'ANTARCTIQUE';
      default:
        return 'CARTE DU MONDE';
    }
  }

  LatLng get _initialMapCenter {
    switch (widget.regionId) {
      case 'europe':
        return const LatLng(52, 10);
      case 'africa':
        return const LatLng(2, 20);
      case 'asia':
        return const LatLng(34, 100);
      case 'americas':
        return const LatLng(10, -90);
      case 'oceania':
        return const LatLng(-22, 140);
      case 'antarctica':
        return const LatLng(-72, 0);
      default:
        return const LatLng(20, 0);
    }
  }

  double get _initialMapZoom {
    switch (widget.regionId) {
      case 'europe':
        return 3.0;
      case 'africa':
      case 'oceania':
        return 2.7;
      case 'asia':
        return 2.4;
      case 'americas':
        return 2.2;
      default:
        return 2.0;
    }
  }

  double get _maximumMapZoom {
    switch (widget.difficultyId) {
      case 'easy':
        return 8.5;
      case 'intermediate':
        return 7.5;
      case 'hard':
        return 6.8;
      case 'expert':
        return 6.0;
      default:
        return 7.5;
    }
  }

  Widget _buildChoiceQuestion(WorldQuizQuestion question) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: <Widget>[
        for (int index = 0; index < question.answers.length; index++) ...<Widget>[
          _AnswerButton(
            label: question.answers[index],
            indexLabel: String.fromCharCode(65 + index),
            state: _answerState(question, index),
            onPressed: _answered ? null : () => _answerChoice(index),
          ),
          const SizedBox(height: 10),
        ],
        if (_answered) ...<Widget>[
          const SizedBox(height: 4),
          _AnswerExplanation(
            correct: _selectedAnswerIndex == question.correctAnswerIndex,
            score: _lastScore,
            explanation: question.explanation,
            onNext: _nextQuestion,
            lastQuestion: _questionNumber >= widget.questionCount,
          ),
        ],
      ],
    );
  }

  _AnswerState _answerState(WorldQuizQuestion question, int index) {
    if (!_answered) {
      return _AnswerState.idle;
    }
    if (index == question.correctAnswerIndex) {
      return _AnswerState.correct;
    }
    if (index == _selectedAnswerIndex) {
      return _AnswerState.wrong;
    }
    return _AnswerState.disabled;
  }

  Widget _buildResults() {
    final int percentage = widget.questionCount == 0
        ? 0
        : ((_correctAnswers / widget.questionCount) * 100).round();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFE),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  color: GeoColors.gold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: GeoColors.navy,
                  size: 46,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.returnExpeditionResult
                    ? 'ÉTAPE TERMINÉE'
                    : 'SESSION TERMINÉE',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: GeoColors.navy,
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '$percentage % de bonnes réponses',
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.mutedInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ResultStat(
                      value: '$_correctAnswers/${widget.questionCount}',
                      label: 'Bonnes réponses',
                      color: GeoColors.mint,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStat(
                      value: '$_score',
                      label: 'Points quiz',
                      color: GeoColors.sky,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('REJOUER'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: GeoColors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _leaveResults,
                icon: Icon(
                  widget.returnExpeditionResult
                      ? Icons.flag_rounded
                      : Icons.tune_rounded,
                ),
                label: Text(
                  widget.returnExpeditionResult
                      ? 'TERMINER L’ÉTAPE'
                      : 'CHANGER DE QUIZ',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: GeoColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiSelectionBar extends StatelessWidget {
  const _MultiSelectionBar({
    required this.selectedCount,
    required this.onValidate,
  });

  final int selectedCount;
  final VoidCallback? onValidate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GeoColors.sky, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              selectedCount == 0
                  ? 'Touche un ou plusieurs pays'
                  : '$selectedCount pays sélectionné${selectedCount > 1 ? 's' : ''}',
              style: GoogleFonts.nunitoSans(
                color: GeoColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onValidate,
            icon: const Icon(Icons.check_rounded),
            label: const Text('VALIDER'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(112, 48),
              maximumSize: const Size(132, 48),
              backgroundColor: GeoColors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({required this.question});

  final WorldQuizQuestion question;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GeoColors.navy.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.19)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            question.subtitle.toUpperCase(),
            style: GoogleFonts.nunitoSans(
              color: GeoColors.sky,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            question.prompt,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

enum _AnswerState { idle, correct, wrong, disabled }

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.indexLabel,
    required this.state,
    required this.onPressed,
  });

  final String label;
  final String indexLabel;
  final _AnswerState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final IconData? trailing;

    switch (state) {
      case _AnswerState.correct:
        background = GeoColors.mint;
        foreground = GeoColors.navy;
        trailing = Icons.check_circle_rounded;
        break;
      case _AnswerState.wrong:
        background = GeoColors.coral;
        foreground = GeoColors.navy;
        trailing = Icons.cancel_rounded;
        break;
      case _AnswerState.disabled:
        background = Colors.white.withValues(alpha: 0.07);
        foreground = Colors.white.withValues(alpha: 0.42);
        trailing = null;
        break;
      case _AnswerState.idle:
        background = Colors.white.withValues(alpha: 0.12);
        foreground = Colors.white;
        trailing = null;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: state == _AnswerState.idle
                  ? Colors.white.withValues(alpha: 0.18)
                  : background,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  indexLabel,
                  style: GoogleFonts.fredoka(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunitoSans(
                    color: foreground,
                    fontSize: label.length > 55 ? 11 : 13,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                Icon(trailing, color: foreground, size: 23),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerExplanation extends StatelessWidget {
  const _AnswerExplanation({
    required this.correct,
    required this.score,
    required this.explanation,
    required this.onNext,
    required this.lastQuestion,
    this.distanceKilometers,
  });

  final bool correct;
  final int score;
  final String explanation;
  final VoidCallback onNext;
  final bool lastQuestion;
  final double? distanceKilometers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: correct ? GeoColors.mint : GeoColors.coral,
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                correct ? Icons.check_circle_rounded : Icons.info_rounded,
                color: correct ? const Color(0xFF159A65) : GeoColors.coral,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correct ? 'Bonne réponse !' : 'À retenir',
                  style: GoogleFonts.fredoka(
                    color: GeoColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '+$score pts',
                style: GoogleFonts.fredoka(
                  color: GeoColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (distanceKilometers != null) ...<Widget>[
            const SizedBox(height: 7),
            Text(
              'Écart : ${distanceKilometers!.round()} km',
              style: GoogleFonts.nunitoSans(
                color: GeoColors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            explanation,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.mutedInk,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 13),
          FilledButton.icon(
            onPressed: onNext,
            icon: Icon(
              lastQuestion ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
            ),
            label: Text(lastQuestion ? 'VOIR LE RÉSULTAT' : 'QUESTION SUIVANTE'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: GeoColors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: GeoColors.gold,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        '$score pts',
        style: GoogleFonts.fredoka(
          color: GeoColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: GoogleFonts.fredoka(
              color: GeoColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.mutedInk,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizLoadError extends StatelessWidget {
  const _QuizLoadError({required this.error, required this.onBack});

  final Object error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFE),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, color: GeoColors.coral, size: 45),
              const SizedBox(height: 12),
              Text(
                'Impossible de charger les quiz',
                style: GoogleFonts.fredoka(
                  color: GeoColors.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.mutedInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 17),
              FilledButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('RETOUR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
