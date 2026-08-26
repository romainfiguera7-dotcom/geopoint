import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../design/geopoint_design.dart';
import 'world_quiz_engine.dart';
import 'world_quiz_game_screen.dart';

class WorldQuizScreen extends StatefulWidget {
  const WorldQuizScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<WorldQuizScreen> createState() => _WorldQuizScreenState();
}

class _WorldQuizScreenState extends State<WorldQuizScreen> {
  static const List<_QuizModeDefinition> _modes = <_QuizModeDefinition>[
    _QuizModeDefinition(
      mode: WorldQuizMode.mixed,
      title: 'MIXTE',
      description: 'Toutes les connaissances dans une même session',
      icon: Icons.shuffle_rounded,
      color: GeoColors.gold,
      wide: true,
    ),
    _QuizModeDefinition(
      mode: WorldQuizMode.placeCity,
      title: 'PLACER UNE VILLE',
      description: 'Retrouve une grande ville sur la carte',
      icon: Icons.location_city_rounded,
      color: GeoColors.blue,
    ),
    _QuizModeDefinition(
      mode: WorldQuizMode.cityCountry,
      title: 'VILLE ET PAYS',
      description: 'Associe les grandes villes à leur pays',
      icon: Icons.travel_explore_rounded,
      color: GeoColors.mint,
    ),
    _QuizModeDefinition(
      mode: WorldQuizMode.currency,
      title: 'MONNAIES',
      description: 'Relie chaque pays à sa monnaie',
      icon: Icons.payments_rounded,
      color: GeoColors.gold,
    ),
    _QuizModeDefinition(
      mode: WorldQuizMode.language,
      title: 'LANGUES',
      description: 'Découvre les langues officielles',
      icon: Icons.translate_rounded,
      color: GeoColors.purple,
    ),
    _QuizModeDefinition(
      mode: WorldQuizMode.populationRange,
      title: 'POPULATIONS',
      description: 'Retrouve la bonne tranche',
      icon: Icons.groups_rounded,
      color: GeoColors.coral,
    ),
    _QuizModeDefinition(
      mode: WorldQuizMode.populationCompare,
      title: 'COMPARAISONS',
      description: 'Compare la population de deux pays',
      icon: Icons.compare_arrows_rounded,
      color: GeoColors.sky,
    ),
    _QuizModeDefinition(
      mode: WorldQuizMode.ranking,
      title: 'CLASSEMENTS',
      description: 'Remets quatre pays dans le bon ordre',
      icon: Icons.format_list_numbered_rounded,
      color: GeoColors.mint,
    ),
    _QuizModeDefinition(
      mode: WorldQuizMode.area,
      title: 'SUPERFICIES',
      description: 'Compare la taille des territoires',
      icon: Icons.straighten_rounded,
      color: GeoColors.blue,
    ),
  ];

  static const List<int> _questionCounts = <int>[10, 20, 30];

  WorldQuizMode _selectedMode = WorldQuizMode.mixed;
  int _selectedQuestionCount = 10;

  _QuizModeDefinition get _selectedDefinition {
    return _modes.firstWhere(
      (_QuizModeDefinition item) => item.mode == _selectedMode,
    );
  }

  void _startQuiz() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return WorldQuizGameScreen(
            controller: widget.controller,
            mode: _selectedMode,
            modeTitle: _selectedDefinition.title,
            questionCount: _selectedQuestionCount,
          );
        },
      ),
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
                      title: 'QUIZ DU MONDE',
                      subtitle: 'Teste toutes tes connaissances',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 28),
                    const GeoSectionHeading(
                      eyebrow: 'NOUVEAUX QUIZ',
                      title: 'Que veux-tu apprendre ?',
                      description:
                          'Les questions classiques et inversées sont mélangées '
                          'pour éviter d’apprendre les réponses dans un seul sens.',
                    ),
                    const SizedBox(height: 18),
                    _QuizModeCard(
                      definition: _modes.first,
                      selected: _selectedMode == _modes.first.mode,
                      onPressed: () {
                        setState(() => _selectedMode = _modes.first.mode);
                      },
                    ),
                    const SizedBox(height: 11),
                    for (int index = 1; index < _modes.length; index += 2) ...<Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _QuizModeCard(
                              definition: _modes[index],
                              selected: _selectedMode == _modes[index].mode,
                              onPressed: () {
                                setState(
                                  () => _selectedMode = _modes[index].mode,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: _QuizModeCard(
                              definition: _modes[index + 1],
                              selected: _selectedMode == _modes[index + 1].mode,
                              onPressed: () {
                                setState(
                                  () => _selectedMode = _modes[index + 1].mode,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'NOMBRE DE QUESTIONS',
                            style: GoogleFonts.nunitoSans(
                              color: GeoColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              for (final int count in _questionCounts) ...<Widget>[
                                Expanded(
                                  child: _QuestionCountButton(
                                    count: count,
                                    selected: count == _selectedQuestionCount,
                                    onPressed: () {
                                      setState(
                                        () => _selectedQuestionCount = count,
                                      );
                                    },
                                  ),
                                ),
                                if (count != _questionCounts.last)
                                  const SizedBox(width: 9),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _startQuiz,
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: Text(
                        'COMMENCER • $_selectedQuestionCount QUESTIONS',
                        style: GoogleFonts.fredoka(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(62),
                        backgroundColor: GeoColors.gold,
                        foregroundColor: GeoColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ces quiz n’accordent pas encore d’étoile ni de tampon. '
                      'Ils servent à enrichir tes connaissances du monde.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11,
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

class _QuizModeDefinition {
  const _QuizModeDefinition({
    required this.mode,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  final WorldQuizMode mode;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool wide;
}

class _QuizModeCard extends StatelessWidget {
  const _QuizModeCard({
    required this.definition,
    required this.selected,
    required this.onPressed,
  });

  final _QuizModeDefinition definition;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          height: definition.wide ? 118 : 142,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected
                ? definition.color
                : Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.18),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.27)
                      : Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  definition.icon,
                  color: selected ? GeoColors.navy : Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      definition.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fredoka(
                        color: selected ? GeoColors.navy : Colors.white,
                        fontSize: definition.wide ? 19 : 15,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      definition.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: selected
                            ? GeoColors.navy.withValues(alpha: 0.72)
                            : Colors.white.withValues(alpha: 0.62),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: GeoColors.navy,
                  size: 22,
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
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? GeoColors.sky : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          '$count',
          style: GoogleFonts.fredoka(
            color: selected ? GeoColors.navy : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
