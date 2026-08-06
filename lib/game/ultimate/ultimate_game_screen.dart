import 'dart:async';

import 'package:flutter/material.dart';

import '../../geo_engine/geo_country.dart';
import 'country_silhouette.dart';
import 'ultimate_question.dart';
import 'ultimate_question_generator.dart';

class UltimateGameScreen extends StatefulWidget {
  const UltimateGameScreen({
    required this.availableCountries,
    required this.countryDifficulties,
    required this.difficultyId,
    this.missionTitle = 'Défi Silhouettes',
    super.key,
  });

  final List<GeoCountry> availableCountries;
  final Map<String, int> countryDifficulties;
  final String difficultyId;
  final String missionTitle;

  @override
  State<UltimateGameScreen> createState() {
    return _UltimateGameScreenState();
  }
}

class _UltimateGameScreenState
    extends State<UltimateGameScreen> {
  late final UltimateQuestionGenerator
      _questionGenerator;

  Timer? _timer;

  UltimateQuestion? _currentQuestion;

  int _questionNumber = 0;
  int _totalScore = 0;
  int _correctAnswers = 0;
  int _secondsRemaining = 15;

  bool _hasAnswered = false;
  bool _isTimeUp = false;
  bool _showGameOver = false;

  String? _selectedCountryId;

  int get _totalQuestions {
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

    _questionGenerator =
        UltimateQuestionGenerator();

    _startNextQuestion();
  }

  void _startNextQuestion() {
    _stopTimer();

    if (_questionNumber >=
        _totalQuestions) {
      setState(() {
        _showGameOver = true;
      });

      return;
    }

    final UltimateQuestion? question =
        _questionGenerator.createQuestion(
      availableCountries:
          widget.availableCountries,
      countryDifficulties:
          widget.countryDifficulties,
    );

    if (question == null) {
      setState(() {
        _showGameOver = true;
      });

      return;
    }

    setState(() {
      _currentQuestion = question;
      _questionNumber++;
      _secondsRemaining =
          _questionDurationSeconds;
      _hasAnswered = false;
      _isTimeUp = false;
      _selectedCountryId = null;
    });

    _startTimer();
  }

  void _startTimer() {
    _stopTimer();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (!mounted ||
            _hasAnswered ||
            _showGameOver) {
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
      },
    );
  }

  void _handleTimeout() {
    if (_hasAnswered) {
      return;
    }

    _stopTimer();

    setState(() {
      _secondsRemaining = 0;
      _hasAnswered = true;
      _isTimeUp = true;
      _selectedCountryId = null;
    });
  }

  void _submitChoice(
    GeoCountry country,
  ) {
    final UltimateQuestion? question =
        _currentQuestion;

    if (question == null ||
        _hasAnswered) {
      return;
    }

    _stopTimer();

    final bool isCorrect =
        question.isCorrectChoice(
      country.id,
    );

    final int earnedScore =
        isCorrect
            ? 100 +
                _calculateTimeBonus()
            : 0;

    setState(() {
      _selectedCountryId =
          country.id;
      _hasAnswered = true;
      _isTimeUp = false;
      _totalScore += earnedScore;

      if (isCorrect) {
        _correctAnswers++;
      }
    });
  }

  int _calculateTimeBonus() {
    final int elapsedSeconds =
        _questionDurationSeconds -
            _secondsRemaining;

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

  bool _isSelected(
    GeoCountry country,
  ) {
    return _selectedCountryId
            ?.trim()
            .toUpperCase() ==
        country.id
            .trim()
            .toUpperCase();
  }

  bool _isCorrectChoice(
    GeoCountry country,
  ) {
    return _currentQuestion
            ?.isCorrectChoice(
          country.id,
        ) ??
        false;
  }

  Color _choiceColor(
    GeoCountry country,
  ) {
    if (!_hasAnswered) {
      return Colors.white.withValues(
        alpha: 0.09,
      );
    }

    if (_isCorrectChoice(
      country,
    )) {
      return const Color(
        0xFF28B67A,
      ).withValues(
        alpha: 0.45,
      );
    }

    if (_isSelected(
      country,
    )) {
      return const Color(
        0xFFFF5C5C,
      ).withValues(
        alpha: 0.40,
      );
    }

    return Colors.white.withValues(
      alpha: 0.05,
    );
  }

  Color _choiceBorderColor(
    GeoCountry country,
  ) {
    if (!_hasAnswered) {
      return Colors.white.withValues(
        alpha: 0.18,
      );
    }

    if (_isCorrectChoice(
      country,
    )) {
      return const Color(
        0xFF80ED99,
      );
    }

    if (_isSelected(
      country,
    )) {
      return const Color(
        0xFFFF5C5C,
      );
    }

    return Colors.white.withValues(
      alpha: 0.12,
    );
  }

  String _resultTitle() {
    if (_isTimeUp) {
      return 'Temps écoulé !';
    }

    final UltimateQuestion? question =
        _currentQuestion;

    if (question == null) {
      return '';
    }

    final String selectedId =
        _selectedCountryId ?? '';

    return question.isCorrectChoice(
      selectedId,
    )
        ? 'Bonne réponse !'
        : 'Mauvaise réponse';
  }

  Color _resultColor() {
    if (_isTimeUp) {
      return const Color(
        0xFFFFD166,
      );
    }

    final UltimateQuestion? question =
        _currentQuestion;

    final String selectedId =
        _selectedCountryId ?? '';

    if (question != null &&
        question.isCorrectChoice(
          selectedId,
        )) {
      return const Color(
        0xFF80ED99,
      );
    }

    return const Color(
      0xFFFF5C5C,
    );
  }

  int _calculateEarnedStars() {
    final int maximumScore =
        _totalQuestions * 120;

    if (maximumScore <= 0) {
      return 0;
    }

    final double ratio =
        _totalScore /
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

  String _starText(
    int stars,
  ) {
    final int normalized =
        stars.clamp(
      0,
      3,
    );

    return '${'★' * normalized}'
        '${'☆' * (3 - normalized)}';
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final UltimateQuestion? question =
        _currentQuestion;

    if (_showGameOver) {
      return _buildGameOverScreen();
    }

    if (question == null) {
      return const Scaffold(
        backgroundColor:
            Color(0xFF071B3A),
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFF071B3A),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF071B3A),
        foregroundColor:
            Colors.white,
        title: Text(
          widget.missionTitle
              .toUpperCase(),
          style:
              const TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(),

            Expanded(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  24,
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      'QUEL EST CE PAYS ?',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color: Colors.white
                            .withValues(
                          alpha: 0.78,
                        ),
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 250,
                      child:
                          CountrySilhouette(
                        country:
                            question
                                .answerCountry,
                        fillColor:
                            _hasAnswered
                                ? const Color(
                                    0xFF80ED99,
                                  )
                                : const Color(
                                    0xFF53D8FF,
                                  ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    for (
                      final GeoCountry country
                      in question.choices
                    ) ...<Widget>[
                      _buildChoiceButton(
                        country,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                    ],

                    if (_hasAnswered)
                      _buildResultPanel(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool urgent =
        _secondsRemaining <= 5;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: 0.20,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white
                .withValues(
              alpha: 0.10,
            ),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'QUESTION '
              '$_questionNumber / '
              '$_totalQuestions',
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
          Icon(
            Icons.timer_outlined,
            color: urgent
                ? const Color(
                    0xFFFFD166,
                  )
                : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            '$_secondsRemaining s',
            style: TextStyle(
              color: urgent
                  ? const Color(
                      0xFFFFD166,
                    )
                  : Colors.white,
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            '$_totalScore pts',
            style:
                const TextStyle(
              color: Color(
                0xFFFFD166,
              ),
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton(
    GeoCountry country,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: _choiceColor(
          country,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: InkWell(
          onTap: _hasAnswered
              ? null
              : () {
                  _submitChoice(
                    country,
                  );
                },
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              border: Border.all(
                color:
                    _choiceBorderColor(
                  country,
                ),
                width: 1.5,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    country
                        .displayNameWithFlag,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
                if (_hasAnswered &&
                    _isCorrectChoice(
                      country,
                    ))
                  const Icon(
                    Icons.check_circle,
                    color: Color(
                      0xFF80ED99,
                    ),
                  )
                else if (_hasAnswered &&
                    _isSelected(
                      country,
                    ))
                  const Icon(
                    Icons.cancel,
                    color: Color(
                      0xFFFF5C5C,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultPanel() {
    final UltimateQuestion? question =
        _currentQuestion;

    if (question == null) {
      return const SizedBox.shrink();
    }

    final String selectedId =
        _selectedCountryId ?? '';

    final bool isCorrect =
        question.isCorrectChoice(
      selectedId,
    );

    final int earnedScore =
        isCorrect
            ? 100 +
                _calculateTimeBonus()
            : 0;

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        top: 8,
      ),
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: 0.32,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: _resultColor()
              .withValues(
            alpha: 0.65,
          ),
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            _resultTitle(),
            style: TextStyle(
              color: _resultColor(),
              fontSize: 22,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            question.answerCountry
                .displayNameWithFlag,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '+$earnedScore points',
            style:
                const TextStyle(
              color: Color(
                0xFFFFD166,
              ),
              fontSize: 18,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child:
                FilledButton.icon(
              onPressed:
                  _startNextQuestion,
              icon: Icon(
                _questionNumber >=
                        _totalQuestions
                    ? Icons.emoji_events
                    : Icons.arrow_forward,
              ),
              label: Text(
                _questionNumber >=
                        _totalQuestions
                    ? 'VOIR LES RÉSULTATS'
                    : 'QUESTION SUIVANTE',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverScreen() {
    final int earnedStars =
        _calculateEarnedStars();

    return Scaffold(
      backgroundColor:
          const Color(0xFF071B3A),
      body: SafeArea(
        child: Center(
          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              22,
            ),
            child: Container(
              constraints:
                  const BoxConstraints(
                maxWidth: 520,
              ),
              padding:
                  const EdgeInsets.all(
                24,
              ),
              decoration:
                  BoxDecoration(
                color: const Color(
                  0xFF132A49,
                ),
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
                border: Border.all(
                  color: Colors.white
                      .withValues(
                    alpha: 0.18,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.extension_rounded,
                    color: Color(
                      0xFFFFD166,
                    ),
                    size: 60,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.missionTitle
                        .toUpperCase(),
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _starText(
                      earnedStars,
                    ),
                    style:
                        const TextStyle(
                      color: Color(
                        0xFFFFD166,
                      ),
                      fontSize: 36,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$_totalScore / '
                    '${_totalQuestions * 120}',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$_correctAnswers / '
                    '$_totalQuestions '
                    'bonnes réponses',
                    style:
                        TextStyle(
                      color: Colors.white
                          .withValues(
                        alpha: 0.78,
                      ),
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        FilledButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(
                          earnedStars,
                        );
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                      ),
                      label:
                          const Text(
                        'RETOUR À L’EXPÉDITION',
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
