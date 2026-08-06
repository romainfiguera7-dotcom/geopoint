import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../geo_engine/flag_emoji.dart';
import '../geo_engine/geo_country.dart';
import '../geo_engine/geopoint_map.dart';
import 'expedition/expedition_progress.dart';
import 'expedition/expedition_storage.dart';
import 'game_controller.dart';
import 'game_question.dart';
import 'passport/passport_result.dart';
import 'passport/passport_stamp.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.controller,
    this.modeId = 'find_country',
    this.difficultyId = 'discovery',
    this.missionTitle = 'Trouver le pays',
    super.key,
  });

  final GameController controller;

  /// Identifiant technique de l’épreuve.
  final String modeId;

  /// Identifiant technique de l’expédition.
  final String difficultyId;

  /// Nom visible de la mission.
  final String missionTitle;

  @override
  State<GameScreen> createState() {
    return _GameScreenState();
  }
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;

  bool _showGameOverPanel = false;
  bool _missionProgressSaved = false;
  int _previousMissionRecord = 0;
  bool _missionRecordLoaded = false;

  LatLng? _pendingSelectedPoint;

  @override
  void initState() {
    super.initState();

    _controller = widget.controller;

    _controller.startMission(
      difficultyId:
          widget.difficultyId,
      modeId:
          widget.modeId,
    );

    _showGameOverPanel = false;
    _missionProgressSaved = false;

    unawaited(
      _loadMissionRecord(),
    );

    _controller.addListener(
      _handleControllerChanged,
    );
  }

  Future<void> _loadMissionRecord() async {
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

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
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

    _controller.submitAnswer(
      selectedPoint: selectedPoint,
      selectedCountry: selectedCountry,
    );

    _pendingSelectedPoint = null;
  }

  Future<void> _handleNextQuestion() async {
    _pendingSelectedPoint = null;

    if (_controller.session.isLastQuestion &&
        _controller.hasAnswered) {
      await _saveMissionProgress();

      if (!mounted) {
        return;
      }

      setState(() {
        _showGameOverPanel = true;
      });

      return;
    }

    _controller.startNextQuestion();
  }

  int _calculateEarnedStars() {
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

    final ExpeditionProgress currentProgress =
        await ExpeditionStorage.load();

    final int previousRecord =
        currentProgress.bestScoreFor(
      difficultyId: widget.difficultyId,
      missionId: widget.modeId,
    );

    final ExpeditionProgress updatedProgress =
        currentProgress.registerMissionResult(
      difficultyId:
          widget.difficultyId,
      missionId:
          widget.modeId,
      stars:
          _calculateEarnedStars(),
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

    if (mounted) {
      setState(() {
        _previousMissionRecord =
            previousRecord;
        _missionRecordLoaded = true;
      });
    }
  }

  void _handleBackToHome() {
    Navigator.of(context).pop();
  }

  String _expeditionLabel(
    String difficultyId,
  ) {
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

  @override
  void dispose() {
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

    final int questionNumber =
        _controller.session.questionNumber;

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GeoPointMap(
                key: ValueKey<int>(
                  questionNumber,
                ),
                answerPoint:
                    _controller.answerPoint,
                answerCountry:
                    _controller.answerCountry,
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
                onClose:
                    _handleBackToHome,
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
                child: _ResultPanel(
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
                  isLastQuestion:
                      _controller
                          .session
                          .isLastQuestion,
                  onNext:
                      _handleNextQuestion,
                ),
              ),

            if (_showGameOverPanel)
              Positioned.fill(
                child: _GameOverPanel(
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
                  playerLevel:
                      _controller
                          .playerProfile
                          .currentLevel,
                  playerTitle:
                      _controller
                          .playerProfile
                          .title,
                  levelProgress:
                      _controller
                          .playerProfile
                          .levelProgress,
                  onBackToHome:
                      _handleBackToHome,
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
    required this.onClose,
  });

  final String missionTitle;
  final String expeditionLabel;

  final GameQuestion? question;
  final int questionNumber;
  final int totalQuestions;
  final int totalScore;
  final int secondsRemaining;

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
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: 0.76,
          ),
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.28,
            ),
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
                  tooltip:
                      'Retour à l’accueil',
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 4),

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
                        style: TextStyle(
                          color: Colors.white
                              .withValues(
                            alpha: 0.66,
                          ),
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        'QUESTION '
                        '$questionNumber / '
                        '$totalQuestions',
                        style: TextStyle(
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
                      style: TextStyle(
                        color: timerColor,
                        fontSize: 23,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    Text(
                      'SEC.',
                      style: TextStyle(
                        color: timerColor
                            .withValues(
                          alpha: 0.78,
                        ),
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '$totalScore',
                      style: const TextStyle(
                        color:
                            Color(0xFFFFD166),
                        fontSize: 21,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    Text(
                      'POINTS',
                      style: TextStyle(
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
                      style: const TextStyle(
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
                  style: const TextStyle(
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
    required this.answerCapitalName,
    required this.answerReferencePointName,
    required this.answerReferencePointTypeLabel,
    required this.answerOfficialCapitalName,
    required this.usesReferenceOverride,
    required this.isLastQuestion,
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

  final String? answerCapitalName;
  final String? answerReferencePointName;
  final String? answerReferencePointTypeLabel;
  final String? answerOfficialCapitalName;

  final bool usesReferenceOverride;
  final bool isLastQuestion;

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

    final String answerName =
        answerCountry?.displayNameWithFlag ??
            'Pays inconnu';

    final String selectedCountryName =
        selectedCountry?.displayNameWithFlag ??
            '🌊 Océan';

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

    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: 0.86,
          ),
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.30,
            ),
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
            Text(
              resultTitle,
              style: TextStyle(
                color: resultColor,
                fontSize: 22,
                fontWeight:
                    FontWeight.w900,
              ),
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

                const SizedBox(height: 2),

                Text(
                  selectedCountryName,
                  textAlign:
                      TextAlign.center,
                  style: const TextStyle(
                    color:
                        Color(0xFFFFD166),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 9),
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

            const SizedBox(height: 2),

            if (isFlagMode)
              ...<Widget>[
                Text(
                  FlagEmoji.fromIsoA2(
                    answerCountry?.isoA2 ??
                        '',
                  ),
                  style:
                      const TextStyle(
                    fontSize: 48,
                  ),
                ),
                const SizedBox(height: 2),
              ],

            Text(
              isCapitalMode &&
                      capitalName.isNotEmpty
                  ? capitalName
                  : answerName,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            if (isCapitalMode)
              ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  answerName,
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors.white
                        .withValues(
                      alpha: 0.70,
                    ),
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],

            if (usesReferenceOverride &&
                referencePointName.isNotEmpty)
              ...<Widget>[
                const SizedBox(height: 8),

                _ResultInformationRow(
                  icon:
                      Icons.location_on_outlined,
                  label: referenceType,
                  value: referencePointName,
                ),
              ],

            if (!isCapitalMode &&
                capitalName.isNotEmpty)
              ...<Widget>[
                const SizedBox(height: 7),

                _ResultInformationRow(
                  icon:
                      Icons.location_city,
                  label: usesReferenceOverride
                      ? 'Capitale officielle'
                      : 'Capitale',
                  value: capitalName,
                ),
              ],

            if (distanceText.isNotEmpty &&
                !((isCountryMode || isFlagMode) && isCorrect))
              ...<Widget>[
                const SizedBox(height: 7),

                _ResultInformationRow(
                  icon:
                      Icons.straighten,
                  label: 'Distance',
                  value: distanceText,
                ),
              ],

            if (capitalToleranceText.isNotEmpty)
              ...<Widget>[
                const SizedBox(height: 7),

                _ResultInformationRow(
                  icon:
                      Icons.adjust_rounded,
                  label: 'Niveau',
                  value: capitalToleranceText,
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
    required this.playerLevel,
    required this.playerTitle,
    required this.levelProgress,
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
  final int playerLevel;
  final String playerTitle;
  final double levelProgress;

  final VoidCallback onBackToHome;

  String _getRank() {
    if (totalScore >= 1151) {
      return 'Légende GeoPoint';
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

  IconData _getRankIcon() {
    if (totalScore >= 1151) {
      return Icons.workspace_premium;
    }

    if (totalScore >= 801) {
      return Icons.emoji_events;
    }

    if (totalScore >= 401) {
      return Icons.public;
    }

    return Icons.explore;
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
                  Icon(
                    _getRankIcon(),
                    color: const Color(
                      0xFFFFD166,
                    ),
                    size: 58,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'PARTIE TERMINÉE',
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
                    style: const TextStyle(
                      color: Color(
                        0xFF80ED99,
                      ),
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 12),

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

                  if (hasMedalUpgrade &&
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
                              style:
                                  const TextStyle(
                                color: Color(
                                  0xFF80ED99,
                                ),
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w900,
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
                      ],
                    ),
                  ),

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
