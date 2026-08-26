import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/geopoint_design.dart';
import 'france_expedition_catalog.dart';
import 'france_exploration_game_screen.dart';

class NationalTrainingScreen extends StatefulWidget {
  const NationalTrainingScreen({super.key});

  @override
  State<NationalTrainingScreen> createState() => _NationalTrainingScreenState();
}

class _NationalTrainingScreenState extends State<NationalTrainingScreen> {
  static const List<_NationalTopic> _topics = <_NationalTopic>[
    _NationalTopic('region', 'RÉGIONS', Icons.map_rounded, FranceQuestionKind.region),
    _NationalTopic('city', 'GRANDES VILLES', Icons.location_city_rounded, FranceQuestionKind.point),
    _NationalTopic('prefecture', 'PRÉFECTURES', Icons.account_balance_rounded, FranceQuestionKind.point),
    _NationalTopic('river', 'FLEUVES', Icons.water_rounded, FranceQuestionKind.point),
    _NationalTopic('mountain', 'RELIEFS', Icons.landscape_rounded, FranceQuestionKind.point),
    _NationalTopic('monument', 'MONUMENTS', Icons.account_balance_rounded, FranceQuestionKind.point),
    _NationalTopic('mixed', 'MIXTE', Icons.shuffle_rounded, FranceQuestionKind.mixed),
  ];
  static const List<_NationalDifficulty> _difficulties = <_NationalDifficulty>[
    _NationalDifficulty('easy', 'FACILE'),
    _NationalDifficulty('intermediate', 'NORMAL'),
    _NationalDifficulty('hard', 'DIFFICILE'),
    _NationalDifficulty('expert', 'EXPERT'),
  ];
  static const List<int> _counts = <int>[10, 20, 30, 50];

  String _topicId = 'region';
  String _difficultyId = 'easy';
  int _questionCount = 10;

  _NationalTopic get _topic =>
      _topics.firstWhere((_NationalTopic topic) => topic.id == _topicId);

  Future<void> _start() async {
    await Navigator.of(context).push<FranceExplorationGameResult>(
      MaterialPageRoute<FranceExplorationGameResult>(
        builder: (BuildContext context) => FranceExplorationGameScreen(
          title: _topic.label,
          kind: _topic.kind,
          category: _topic.id,
          difficulty: _difficultyId,
          questionCount: _questionCount,
          isTraining: true,
        ),
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'ENTRAÎNEMENT FRANCE',
                      subtitle: 'À l’intérieur d’un pays',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 24),
                    const GeoSectionHeading(
                      eyebrow: 'ENTRAÎNEMENT NATIONAL',
                      title: 'Configure ta partie',
                      description:
                          'Un pays, un thème, une difficulté et un nombre de questions.',
                    ),
                    const SizedBox(height: 18),
                    _TrainingPanel(
                      title: 'PAYS',
                      child: SizedBox(
                        height: 62,
                        child: _ChoiceTile(
                          label: '🇫🇷  FRANCE',
                          icon: Icons.flag_rounded,
                          selected: true,
                          onPressed: () {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    _TrainingPanel(
                      title: 'THÈME',
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 9,
                          mainAxisSpacing: 9,
                          childAspectRatio: 2.1,
                        ),
                        itemCount: _topics.length,
                        itemBuilder: (BuildContext context, int index) {
                          final _NationalTopic topic = _topics[index];
                          return _ChoiceTile(
                            label: topic.label,
                            icon: topic.icon,
                            selected: topic.id == _topicId,
                            onPressed: () => setState(() => _topicId = topic.id),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 13),
                    _TrainingPanel(
                      title: 'DIFFICULTÉ',
                      child: Column(
                        children: <Widget>[
                          for (final _NationalDifficulty difficulty
                              in _difficulties)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DifficultyTile(
                                label: difficulty.label,
                                selected: difficulty.id == _difficultyId,
                                onPressed: () => setState(
                                  () => _difficultyId = difficulty.id,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 13),
                    _TrainingPanel(
                      title: 'NOMBRE DE QUESTIONS',
                      child: Row(
                        children: <Widget>[
                          for (int index = 0; index < _counts.length; index++) ...<Widget>[
                            Expanded(
                              child: _CountButton(
                                value: _counts[index],
                                selected: _questionCount == _counts[index],
                                onPressed: () => setState(
                                  () => _questionCount = _counts[index],
                                ),
                              ),
                            ),
                            if (index < _counts.length - 1)
                              const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 58,
                      child: FilledButton.icon(
                        onPressed: _start,
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
                    const SizedBox(height: 10),
                    Text(
                      'Les données de la France sont chargées uniquement au lancement de la partie. Aucun XP, étoile ou déblocage.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white54,
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

class _TrainingPanel extends StatelessWidget {
  const _TrainingPanel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(21),
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
            ),
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? GeoColors.mint : const Color(0xFF12385F),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: <Widget>[
              Icon(icon, color: selected ? GeoColors.navy : Colors.white70, size: 21),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: GoogleFonts.fredoka(
                    color: selected ? GeoColors.navy : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? GeoColors.sky : const Color(0xFF12385F),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? GeoColors.navy : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.nunitoSans(
                  color: selected ? GeoColors.navy : Colors.white,
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

class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.value,
    required this.selected,
    required this.onPressed,
  });
  final int value;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: selected ? GeoColors.gold : const Color(0xFF12385F),
          foregroundColor: selected ? GeoColors.navy : Colors.white,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          '$value',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _NationalTopic {
  const _NationalTopic(this.id, this.label, this.icon, this.kind);
  final String id;
  final String label;
  final IconData icon;
  final FranceQuestionKind kind;
}

class _NationalDifficulty {
  const _NationalDifficulty(this.id, this.label);
  final String id;
  final String label;
}
