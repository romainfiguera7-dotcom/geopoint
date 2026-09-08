import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../game/game_screen.dart';
import '../../geobrain/geobrain_attempt.dart';
import '../../geobrain/geobrain_difficulty_adapter.dart';
import '../../geobrain/geobrain_theme.dart';
import '../../geobrain/geobrain_training_suggestion.dart';
import '../design/geopoint_design.dart';
import '../exploration/france/national_training_screen.dart';
import '../quiz/world_quiz_engine.dart';
import '../quiz/world_quiz_game_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    required this.controller,
    this.reviewDifficultiesOnly = false,
    this.suggestion,
    super.key,
  });

  final GameController controller;
  final bool reviewDifficultiesOnly;
  final GeoBrainTrainingSuggestion? suggestion;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  static const List<_TrainingChoice> _scales = <_TrainingChoice>[
    _TrainingChoice(
      id: 'world_scale',
      label: 'MONDE ET CONTINENTS',
      description: 'Pays, capitales et connaissances mondiales',
      icon: Icons.public_rounded,
    ),
    _TrainingChoice(
      id: 'national_scale',
      label: 'À L’INTÉRIEUR D’UN PAYS',
      description: 'Régions, villes et repères nationaux',
      icon: Icons.flag_rounded,
    ),
  ];

  static const List<_TrainingChoice> _formats = <_TrainingChoice>[
    _TrainingChoice(
      id: 'free',
      label: 'SESSION LIBRE',
      description: 'Choisis 10, 20, 30 ou 50 questions',
      icon: Icons.tune_rounded,
    ),
    _TrainingChoice(
      id: 'complete',
      label: 'PARCOURS COMPLET',
      description: 'Valide tous les pays de la zone',
      icon: Icons.route_rounded,
    ),
  ];

  static const List<_TrainingChoice> _regions = <_TrainingChoice>[
    _TrainingChoice(
      id: 'world',
      label: 'MONDE',
      description: 'Monde entier',
      icon: Icons.public_rounded,
    ),
    _TrainingChoice(
      id: 'europe',
      label: 'EUROPE',
      description: 'Europe',
      icon: Icons.account_balance_rounded,
    ),
    _TrainingChoice(
      id: 'africa',
      label: 'AFRIQUE',
      description: 'Afrique',
      icon: Icons.wb_sunny_rounded,
    ),
    _TrainingChoice(
      id: 'asia',
      label: 'ASIE',
      description: 'Asie',
      icon: Icons.temple_buddhist_rounded,
    ),
    _TrainingChoice(
      id: 'americas',
      label: 'AMÉRIQUES',
      description: 'Amérique du Nord et du Sud',
      icon: Icons.travel_explore_rounded,
    ),
    _TrainingChoice(
      id: 'oceania',
      label: 'OCÉANIE',
      description: 'Océanie',
      icon: Icons.sailing_rounded,
    ),
    _TrainingChoice(
      id: 'antarctica',
      label: 'ANTARCTIQUE',
      description: 'Antarctique',
      icon: Icons.ac_unit_rounded,
    ),
  ];

  static const List<_TrainingChoice> _modes = <_TrainingChoice>[
    _TrainingChoice(
      id: 'find_country',
      label: 'PAYS',
      description: 'Retrouver un pays',
      icon: Icons.public_rounded,
    ),
    _TrainingChoice(
      id: 'find_capital',
      label: 'CAPITALES',
      description: 'Placer une capitale',
      icon: Icons.location_city_rounded,
    ),
    _TrainingChoice(
      id: 'find_flag',
      label: 'DRAPEAUX',
      description: 'Reconnaître un drapeau',
      icon: Icons.flag_rounded,
    ),
    _TrainingChoice(
      id: 'mixed',
      label: 'MIXTE',
      description: 'Alterner les épreuves',
      icon: Icons.shuffle_rounded,
    ),
    _TrainingChoice(
      id: 'place_city',
      label: 'GRANDES VILLES',
      description: 'Placer une grande ville sur la carte',
      icon: Icons.location_city_rounded,
    ),
    _TrainingChoice(
      id: 'city_country',
      label: 'VILLE → PAYS',
      description: 'Associer une ville à son pays',
      icon: Icons.travel_explore_rounded,
    ),
    _TrainingChoice(
      id: 'currency',
      label: 'MONNAIES',
      description: 'Sélectionner tous les pays concernés',
      icon: Icons.payments_rounded,
    ),
    _TrainingChoice(
      id: 'language',
      label: 'LANGUES',
      description: 'Retrouver les langues officielles',
      icon: Icons.translate_rounded,
    ),
  ];

  static const List<_TrainingChoice> _difficulties = <_TrainingChoice>[
    _TrainingChoice(
      id: 'adaptive',
      label: 'ADAPTATIVE',
      description: 'GeoBrain choisit un niveau fixe pour toute la séance',
      icon: Icons.auto_awesome_rounded,
    ),
    _TrainingChoice(
      id: 'easy',
      label: 'FACILE',
      description: 'Repères connus et davantage d’aide',
      icon: Icons.sentiment_satisfied_alt_rounded,
    ),
    _TrainingChoice(
      id: 'intermediate',
      label: 'NORMAL',
      description: 'Connaissances essentielles',
      icon: Icons.explore_rounded,
    ),
    _TrainingChoice(
      id: 'hard',
      label: 'DIFFICILE',
      description: 'Choix moins évidents et plus précis',
      icon: Icons.local_fire_department_rounded,
    ),
    _TrainingChoice(
      id: 'expert',
      label: 'EXPERT',
      description: 'Base complète et aide minimale',
      icon: Icons.workspace_premium_rounded,
    ),
  ];

  static const List<int> _questionCounts = <int>[10, 20, 30, 50];

  String _selectedFormatId = 'free';
  String _selectedRegionId = 'world';
  String _selectedModeId = 'find_country';
  String _selectedDifficultyId = 'adaptive';
  int _selectedQuestionCount = 10;

  @override
  void initState() {
    super.initState();
    final GeoBrainTrainingSuggestion? suggestion = widget.suggestion;
    if (suggestion != null) {
      _selectedFormatId = 'free';
      _selectedRegionId = suggestion.regionId;
      _selectedModeId = suggestion.modeId;
      _selectedQuestionCount = suggestion.questionCount;
    }
  }

  _TrainingChoice get _selectedMode {
    return _modes.firstWhere(
      (_TrainingChoice choice) => choice.id == _selectedModeId,
    );
  }

  _TrainingChoice get _selectedDifficulty {
    return _difficulties.firstWhere(
      (_TrainingChoice choice) => choice.id == _selectedDifficultyId,
    );
  }

  _TrainingChoice get _selectedRegion {
    return _regions.firstWhere(
      (_TrainingChoice choice) => choice.id == _selectedRegionId,
    );
  }

  bool get _isCompleteTraining => _selectedFormatId == 'complete';

  bool get _reviewDifficulties {
    return widget.reviewDifficultiesOnly ||
        (widget.suggestion?.reviewDifficultiesOnly ?? false);
  }

  bool get _usesKnowledgeEngine => const <String>{
        'place_city',
        'city_country',
        'currency',
        'language',
      }.contains(_selectedModeId);

  GeoBrainDifficultyRecommendation get _adaptiveRecommendation {
    return widget.controller.recommendedTrainingDifficulty(
      modeId: _selectedModeId,
      regionId: _selectedRegionId,
      allowedCountryIds: widget.suggestion?.countryIds,
    );
  }

  bool get _usesAdaptiveDifficulty {
    return !_isCompleteTraining && _selectedDifficultyId == 'adaptive';
  }

  String get _effectiveDifficultyId {
    if (_isCompleteTraining) {
      return 'intermediate';
    }
    return _selectedDifficultyId == 'adaptive'
        ? _adaptiveRecommendation.difficultyId
        : _selectedDifficultyId;
  }

  String get _effectiveDifficultyLabel {
    if (_isCompleteTraining) {
      return 'NORMAL';
    }
    if (_usesAdaptiveDifficulty) {
      return 'AUTO → ${_adaptiveRecommendation.difficultyLabel.toUpperCase()}';
    }
    return _selectedDifficulty.label;
  }

  int get _availableCountryCount {
    if (_usesKnowledgeEngine) {
      return _selectedQuestionCount;
    }
    return widget.controller.availableTrainingCountryCount(
      difficultyId: _effectiveDifficultyId,
      modeId: _selectedModeId,
      regionId: _selectedRegionId,
      completeRegion: _isCompleteTraining,
      allowedCountryIds: widget.suggestion?.countryIds,
    );
  }

  int get _effectiveQuestionCount {
    if (_isCompleteTraining) {
      return _availableCountryCount;
    }

    return _selectedQuestionCount > _availableCountryCount
        ? _availableCountryCount
        : _selectedQuestionCount;
  }

  Future<void> _startTraining() async {
    final GeoBrainDifficultyRecommendation? adaptiveRecommendation =
        _usesAdaptiveDifficulty ? _adaptiveRecommendation : null;
    final bool adaptiveConfirmed = await _confirmAdaptiveDifficulty(
      adaptiveRecommendation,
    );
    if (!mounted || !adaptiveConfirmed) {
      return;
    }
    final String resolvedDifficultyId =
        adaptiveRecommendation?.difficultyId ?? _effectiveDifficultyId;

    if (_usesKnowledgeEngine) {
      if (_selectedRegionId == 'antarctica') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ce mode ne possède pas encore de données pour l’Antarctique.',
            ),
          ),
        );
        return;
      }

      final WorldQuizMode quizMode;
      switch (_selectedModeId) {
        case 'place_city':
          quizMode = WorldQuizMode.placeCity;
          break;
        case 'city_country':
          quizMode = WorldQuizMode.cityCountry;
          break;
        case 'currency':
          quizMode = WorldQuizMode.currency;
          break;
        case 'language':
          quizMode = WorldQuizMode.language;
          break;
        default:
          quizMode = WorldQuizMode.cityCountry;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return WorldQuizGameScreen(
              controller: widget.controller,
              mode: quizMode,
              modeTitle: _selectedMode.label,
              questionCount: _selectedQuestionCount,
              regionId: _selectedRegionId,
              difficultyId: resolvedDifficultyId,
              attemptContext: GeoBrainAttemptContext.training,
            );
          },
        ),
      );
      return;
    }

    final int availableCountryCount =
        widget.controller.availableTrainingCountryCount(
      difficultyId: resolvedDifficultyId,
      modeId: _selectedModeId,
      regionId: _selectedRegionId,
      completeRegion: _isCompleteTraining,
      allowedCountryIds: widget.suggestion?.countryIds,
    );

    if (availableCountryCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun pays compatible avec cette zone et ce mode de jeu.',
          ),
        ),
      );
      return;
    }

    final int resolvedQuestionCount = _isCompleteTraining
        ? availableCountryCount
        : _selectedQuestionCount > availableCountryCount
            ? availableCountryCount
            : _selectedQuestionCount;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return GameScreen(
            controller: widget.controller,
            modeId: _selectedModeId,
            difficultyId: resolvedDifficultyId,
            missionTitle: _isCompleteTraining
                ? 'Parcours ${_selectedRegion.label}'
                : widget.suggestion != null
                    ? widget.suggestion!.title
                    : _reviewDifficulties
                    ? 'Réviser mes difficultés • ${_selectedRegion.label}'
                    : 'Entraînement • ${_selectedRegion.label}',
            isTraining: true,
            trainingQuestionCount: resolvedQuestionCount,
            trainingRegionId: _selectedRegionId,
            completeTraining: _isCompleteTraining,
            reviewDifficultiesOnly: _reviewDifficulties,
            trainingCountryIds: widget.suggestion?.countryIds,
          );
        },
      ),
    );
  }

  Future<bool> _confirmAdaptiveDifficulty(
    GeoBrainDifficultyRecommendation? recommendation,
  ) async {
    if (recommendation == null) {
      return true;
    }
    final GeoBrainTheme? theme = _selectedModeId == 'mixed'
        ? GeoBrainTheme.capital
        : GeoBrainTheme.fromModeId(_selectedModeId);
    final bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: GeoColors.cream,
              title: Row(
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: GeoColors.purple,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'NIVEAU ${recommendation.difficultyLabel.toUpperCase()}',
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recommendation.reasonLabel,
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GeoColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      recommendation.rulesSummary(
                        theme: theme,
                        standardMapMode: !_usesKnowledgeEngine,
                      ),
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ces règles resteront fixes jusqu’à la fin de la séance.',
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('MODIFIER'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('COMMENCER'),
                ),
              ],
            );
          },
        );
    return confirmed ?? false;
  }

  void _selectMode(String modeId) {
    setState(() {
      _selectedModeId = modeId;
      if (_usesKnowledgeEngine) {
        _selectedFormatId = 'free';
        if (_selectedRegionId == 'antarctica') {
          _selectedRegionId = 'world';
        }
      }
    });
  }

  Widget _buildModeGrid(List<_TrainingChoice> choices) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.75,
      ),
      itemCount: choices.length,
      itemBuilder: (BuildContext context, int index) {
        final _TrainingChoice choice = choices[index];
        return _TrainingChoiceCard(
          choice: choice,
          selected: choice.id == _selectedModeId,
          onPressed: () => _selectMode(choice.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: widget.suggestion != null
                          ? 'SÉANCE CONSEILLÉE'
                          : _reviewDifficulties
                          ? 'MES DIFFICULTÉS'
                          : 'ENTRAÎNEMENT',
                      subtitle: widget.suggestion?.title ??
                          (_reviewDifficulties
                          ? 'Une séance choisie par ton GeoBrain'
                          : 'Choisis ta zone et ton rythme'),
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 26),
                    GeoSectionHeading(
                      eyebrow: widget.suggestion != null
                          ? 'PROPOSÉ PAR GEOBRAIN'
                          : _reviewDifficulties
                          ? 'SÉANCE PERSONNALISÉE'
                          : 'À TOI DE JOUER',
                      title: widget.suggestion?.title ??
                          (_reviewDifficulties
                          ? 'Réviser au bon moment'
                          : 'Configure ta partie'),
                      description: widget.suggestion?.reason ??
                          (_reviewDifficulties
                          ? 'GeoBrain privilégie les connaissances fragiles ou oubliées, puis ajoute quelques vérifications et nouveautés.'
                          : 'Choisis une zone puis entraîne-toi librement ou valide-la entièrement.'),
                    ),
                    const SizedBox(height: 20),
                    if (widget.suggestion == null) ...<Widget>[
                      _TrainingSection(
                        title: 'ÉCHELLE',
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.40,
                          ),
                          itemCount: _scales.length,
                          itemBuilder: (BuildContext context, int index) {
                            final _TrainingChoice choice = _scales[index];
                            return _TrainingChoiceCard(
                              choice: choice,
                              selected: choice.id == 'world_scale',
                              onPressed: () {
                                if (choice.id == 'national_scale') {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (BuildContext context) =>
                                          const NationalTrainingScreen(),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _TrainingSection(
                      title: 'FORMAT',
                      child: _usesKnowledgeEngine ||
                              _reviewDifficulties ||
                              widget.suggestion != null
                          ? Column(
                              children: <Widget>[
                                SizedBox(
                                  height: 92,
                                  child: _TrainingChoiceCard(
                                    choice: widget.suggestion == null
                                        ? _formats.first
                                        : _TrainingChoice(
                                            id: 'free',
                                            label: 'SÉANCE CIBLÉE',
                                            description:
                                                '${widget.suggestion!.questionCount} questions choisies par GeoBrain',
                                            icon: Icons.center_focus_strong_rounded,
                                          ),
                                    selected: true,
                                    onPressed: () {},
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.suggestion != null
                                      ? 'Cette séance utilise uniquement les pays sélectionnés par GeoBrain.'
                                      : _reviewDifficulties
                                      ? 'La séance personnalisée reste libre pour respecter le nombre de questions choisi.'
                                      : 'Ce mode se joue en session libre. Le Parcours complet reste réservé aux Pays, Capitales, Drapeaux et Mixte.',
                                  style: GoogleFonts.nunitoSans(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.48,
                              ),
                              itemCount: _formats.length,
                              itemBuilder: (BuildContext context, int index) {
                                final _TrainingChoice choice = _formats[index];
                                return _TrainingChoiceCard(
                                  choice: choice,
                                  selected: choice.id == _selectedFormatId,
                                  onPressed: () {
                                    setState(() {
                                      _selectedFormatId = choice.id;
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 14),
                    _TrainingSection(
                      title: 'ZONE GÉOGRAPHIQUE',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final _TrainingChoice region in _regions.where(
                            (_TrainingChoice region) =>
                                widget.suggestion == null ||
                                region.id == _selectedRegionId,
                          ))
                            _RegionChoiceChip(
                              region: region,
                              selected: region.id == _selectedRegionId,
                              onPressed: () {
                                setState(() {
                                  _selectedRegionId = region.id;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TrainingSection(
                      title: 'MODE DE JEU',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'LOCALISER ET ASSOCIER',
                            style: GoogleFonts.nunitoSans(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildModeGrid(
                            widget.suggestion == null
                                ? _modes
                                    .take(_reviewDifficulties ? 4 : 6)
                                    .toList(growable: false)
                                : _modes
                                    .where(
                                      (_TrainingChoice mode) =>
                                          mode.id == _selectedModeId,
                                    )
                                    .toList(growable: false),
                          ),
                          if (!_reviewDifficulties &&
                              widget.suggestion == null) ...<Widget>[
                            const SizedBox(height: 15),
                            Text(
                              'DÉCOUVRIR PLUSIEURS PAYS',
                              style: GoogleFonts.nunitoSans(
                                color: Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildModeGrid(
                              _modes.skip(6).toList(growable: false),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!_isCompleteTraining) ...<Widget>[
                      const SizedBox(height: 14),
                      _TrainingSection(
                        title: 'DIFFICULTÉ',
                        child: Column(
                          children: <Widget>[
                            for (final _TrainingChoice choice in _difficulties)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _DifficultyChoice(
                                  choice: choice,
                                  selected:
                                      choice.id == _selectedDifficultyId,
                                  onPressed: () {
                                    setState(() {
                                      _selectedDifficultyId = choice.id;
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.suggestion == null) ...<Widget>[
                        const SizedBox(height: 14),
                        _TrainingSection(
                          title: 'NOMBRE DE QUESTIONS',
                          child: Row(
                            children: <Widget>[
                              for (int index = 0;
                                  index < _questionCounts.length;
                                  index++) ...<Widget>[
                                Expanded(
                                  child: _QuestionCountButton(
                                    value: _questionCounts[index],
                                    selected: _questionCounts[index] ==
                                        _selectedQuestionCount,
                                    onPressed: () {
                                      setState(() {
                                        _selectedQuestionCount =
                                            _questionCounts[index];
                                      });
                                    },
                                  ),
                                ),
                                if (index < _questionCounts.length - 1)
                                  const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),
                    _TrainingSummary(
                      mode: _selectedMode.label,
                      difficulty: _effectiveDifficultyLabel,
                      region: _selectedRegion.label,
                      questionCount: _effectiveQuestionCount,
                      complete: _isCompleteTraining,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 58,
                      child: FilledButton.icon(
                        onPressed: _startTraining,
                        style: FilledButton.styleFrom(
                          backgroundColor: GeoColors.gold,
                          foregroundColor: GeoColors.navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: Text(
                          'COMMENCER',
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isCompleteTraining
                          ? 'Chaque erreur remet le pays plus loin dans le parcours. '
                              'La session se termine lorsque toute la zone est verte. '
                              'Les pays impossibles à toucher sont écartés.'
                          : 'Les pays correctement trouvés restent verts et nommés '
                              'jusqu’à la fin de la session.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'L’entraînement ne donne ni étoile, ni tampon, ni XP.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingSection extends StatelessWidget {
  const _TrainingSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _TrainingChoiceCard extends StatelessWidget {
  const _TrainingChoiceCard({
    required this.choice,
    required this.selected,
    required this.onPressed,
  });

  final _TrainingChoice choice;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected
                ? GeoColors.mint
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.white70 : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                choice.icon,
                color: selected ? GeoColors.navy : Colors.white70,
                size: 25,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      choice.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fredoka(
                        color: selected ? GeoColors.navy : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      choice.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: selected
                            ? GeoColors.navy.withValues(alpha: 0.70)
                            : Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionChoiceChip extends StatelessWidget {
  const _RegionChoiceChip({
    required this.region,
    required this.selected,
    required this.onPressed,
  });

  final _TrainingChoice region;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? GeoColors.sky
                : const Color(0xFF12385F).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.white70 : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                region.icon,
                size: 17,
                color: selected ? GeoColors.navy : Colors.white70,
              ),
              const SizedBox(width: 7),
              Text(
                region.label,
                style: GoogleFonts.nunitoSans(
                  color: selected ? GeoColors.navy : Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyChoice extends StatelessWidget {
  const _DifficultyChoice({
    required this.choice,
    required this.selected,
    required this.onPressed,
  });

  final _TrainingChoice choice;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? GeoColors.gold
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? Colors.white70 : Colors.white12,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                choice.icon,
                color: selected ? GeoColors.navy : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      choice.label,
                      style: GoogleFonts.fredoka(
                        color: selected ? GeoColors.navy : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      choice.description,
                      style: GoogleFonts.nunitoSans(
                        color: selected
                            ? GeoColors.navy.withValues(alpha: 0.68)
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: GeoColors.navy,
                  size: 21,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCountButton extends StatelessWidget {
  const _QuestionCountButton({
    required this.value,
    required this.selected,
    required this.onPressed,
  });

  final int value;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? GeoColors.sky
            : Colors.white.withValues(alpha: 0.08),
        foregroundColor: selected ? GeoColors.navy : Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? Colors.white70 : Colors.white12,
          ),
        ),
        elevation: 0,
      ),
      child: Text(
        '$value',
        style: GoogleFonts.fredoka(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrainingSummary extends StatelessWidget {
  const _TrainingSummary({
    required this.mode,
    required this.difficulty,
    required this.region,
    required this.questionCount,
    required this.complete,
  });

  final String mode;
  final String difficulty;
  final String region;
  final int questionCount;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: GeoColors.mint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: GeoColors.mint.withValues(alpha: 0.48),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            complete ? Icons.route_rounded : Icons.tune_rounded,
            color: GeoColors.mint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              complete
                  ? '$region • $mode\n'
                      '$questionCount PAYS À VALIDER'
                  : '$region • $mode • $difficulty\n'
                      '$questionCount QUESTIONS',
              style: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingChoice {
  const _TrainingChoice({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}
