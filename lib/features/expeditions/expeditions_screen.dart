import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/continent/africa_expedition.dart';
import '../../game/continent/continent_expedition.dart';
import '../../game/continent/europe_expedition.dart';
import '../../game/expedition/expedition_mission.dart';
import '../../game/expedition/expedition_progress.dart';
import '../../game/expedition/expedition_storage.dart';
import '../../game/game_controller.dart';
import '../../game/game_difficulty.dart';
import '../../game/game_difficulty_loader.dart';
import '../../game/game_screen.dart';
import '../../game/learning/guided_level.dart';
import '../../game/ultimate/ultimate_game_screen.dart';
import 'continent_expedition_screen.dart';

class ExpeditionsScreen extends StatefulWidget {
  const ExpeditionsScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<ExpeditionsScreen> createState() {
    return _ExpeditionsScreenState();
  }
}

class _ExpeditionsScreenState extends State<ExpeditionsScreen> {
  late Future<List<GameDifficulty>> _difficultiesFuture;

  late Future<ExpeditionProgress> _progressFuture;

  @override
  void initState() {
    super.initState();

    _difficultiesFuture = GameDifficultyLoader.loadDifficulties();

    _progressFuture = ExpeditionStorage.load();
  }

  void _reloadProgress() {
    setState(() {
      _progressFuture = ExpeditionStorage.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071B3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071B3A),
        foregroundColor: Colors.white,
        title: Text(
          'EXPÉDITIONS',
          style: GoogleFonts.fredoka(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ExpeditionBackground()),
          FutureBuilder<List<GameDifficulty>>(
            future: _difficultiesFuture,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<GameDifficulty>> difficultiesSnapshot,
                ) {
                  if (difficultiesSnapshot.connectionState !=
                      ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (difficultiesSnapshot.hasError) {
                    return _ExpeditionError(error: difficultiesSnapshot.error);
                  }

                  final List<GameDifficulty> difficulties =
                      difficultiesSnapshot.data ?? const <GameDifficulty>[];

                  return FutureBuilder<ExpeditionProgress>(
                    future: _progressFuture,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<ExpeditionProgress> progressSnapshot,
                        ) {
                          if (progressSnapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final ExpeditionProgress progress =
                              progressSnapshot.data ??
                              ExpeditionProgress.initial();

                          return _ExpeditionList(
                            controller: widget.controller,
                            difficulties: difficulties,
                            progress: progress,
                            onProgressChanged: _reloadProgress,
                          );
                        },
                  );
                },
          ),
        ],
      ),
    );
  }
}

class _ExpeditionList extends StatelessWidget {
  const _ExpeditionList({
    required this.controller,
    required this.difficulties,
    required this.progress,
    required this.onProgressChanged,
  });

  final GameController controller;
  final List<GameDifficulty> difficulties;
  final ExpeditionProgress progress;
  final VoidCallback onProgressChanged;

  static const List<ContinentExpedition>
      _continentExpeditions = <ContinentExpedition>[
    EuropeExpeditionCatalog.europe,
    AfricaExpeditionCatalog.africa,
  ];

  Future<void> _openTutorials(
    BuildContext context,
  ) async {
    final GuidedLevel? selectedTutorial =
        await showModalBottomSheet<GuidedLevel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return const _TutorialSelectorSheet();
      },
    );

    if (selectedTutorial == null ||
        !context.mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return GameScreen(
            controller: controller,
            modeId: selectedTutorial.modeId,
            difficultyId: 'discovery',
            missionTitle: selectedTutorial.title,
            guidedLevel: selectedTutorial,
          );
        },
      ),
    );

    onProgressChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (difficulties.isEmpty) {
      return const _ExpeditionError(error: 'Aucune expédition disponible.');
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      itemCount:
          difficulties.length + 1 + _continentExpeditions.length,
      separatorBuilder: (BuildContext context, int index) {
        return const SizedBox(height: 15);
      },
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _TutorialCard(
            onPressed: () async {
              await _openTutorials(context);
            },
          );
        }

        if (index <= _continentExpeditions.length) {
          final ContinentExpedition expedition =
              _continentExpeditions[index - 1];

          return _ContinentExpeditionCard(
            expedition: expedition,
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) {
                    return ContinentExpeditionScreen(
                      controller: controller,
                      expedition: expedition,
                    );
                  },
                ),
              );
            },
          );
        }

        final int difficultyIndex =
            index - 1 - _continentExpeditions.length;

        final GameDifficulty difficulty =
            difficulties[difficultyIndex];

        final String? previousDifficultyId =
            difficultyIndex == 0
            ? null
            : difficulties[
                difficultyIndex - 1
              ].id;

        final bool isUnlocked = progress.isExpeditionUnlocked(
          difficultyId: difficulty.id,
          previousDifficultyId: previousDifficultyId,
        );

        final int earnedStars = progress.totalStarsFor(difficulty.id);

        return _ExpeditionCard(
          difficulty: difficulty,
          isUnlocked: isUnlocked,
          earnedStars: earnedStars,
          maximumStars: 15,
          onPressed: isUnlocked
              ? () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return ExpeditionDetailScreen(
                          controller: controller,
                          difficulty: difficulty,
                        );
                      },
                    ),
                  );

                  onProgressChanged();
                }
              : null,
        );
      },
    );
  }
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF20C997),
                Color(0xFF087A67),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.28,
              ),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF20C997)
                    .withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.18,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 35,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'RECOMMANDÉ',
                          style: GoogleFonts.nunitoSans(
                            color: const Color(0xFFFFD166),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Tutoriels de jeu',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Une courte session sans chronomètre '
                      'pour chaque mode de jeu.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(
                          alpha: 0.75,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '4 MODES • 3 QUESTIONS CHACUN',
                      style: GoogleFonts.nunitoSans(
                        color: const Color(0xFFFFD166),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinentExpeditionCard extends StatelessWidget {
  const _ContinentExpeditionCard({
    required this.expedition,
    required this.onPressed,
  });

  final ContinentExpedition expedition;
  final VoidCallback onPressed;

  List<Color> get _colors {
    switch (expedition.id) {
      case 'africa':
        return const <Color>[
          Color(0xFFF39C3D),
          Color(0xFF9A4E16),
        ];
      case 'europe':
      default:
        return const <Color>[
          Color(0xFF176BFF),
          Color(0xFF0C3C8C),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _colors,
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.26),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _colors.first.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Colors.white,
                  size: 35,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'EXPÉDITION CONTINENTALE',
                      style: GoogleFonts.nunitoSans(
                        color: const Color(0xFFFFD166),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      expedition.name,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expedition.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${expedition.levels.length} NIVEAUX '
                      '• ${expedition.maximumStars} ÉTOILES',
                      style: GoogleFonts.nunitoSans(
                        color: const Color(0xFFFFD166),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialSelectorSheet extends StatelessWidget {
  const _TutorialSelectorSheet();

  IconData _iconForMode(String modeId) {
    switch (modeId) {
      case 'find_capital':
        return Icons.location_city_rounded;
      case 'find_flag':
        return Icons.flag_rounded;
      case 'mixed':
        return Icons.shuffle_rounded;
      case 'find_country':
      default:
        return Icons.public_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        decoration: const BoxDecoration(
          color: Color(0xFF102A50),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'CHOISIS UN TUTORIEL',
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chaque tutoriel contient seulement trois questions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: GuidedLevelCatalog.tutorials.length,
                separatorBuilder: (
                  BuildContext context,
                  int index,
                ) {
                  return const SizedBox(height: 10);
                },
                itemBuilder: (
                  BuildContext context,
                  int index,
                ) {
                  final GuidedLevel tutorial =
                      GuidedLevelCatalog.tutorials[index];

                  return Material(
                    color: Colors.white.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop(tutorial);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF28C2FF)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                _iconForMode(tutorial.modeId),
                                color: const Color(0xFF53D8FF),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    tutorial.title,
                                    style: GoogleFonts.fredoka(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tutorial.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunitoSans(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpeditionDetailScreen extends StatefulWidget {
  const ExpeditionDetailScreen({
    required this.controller,
    required this.difficulty,
    super.key,
  });

  final GameController controller;
  final GameDifficulty difficulty;

  @override
  State<ExpeditionDetailScreen> createState() {
    return _ExpeditionDetailScreenState();
  }
}

class _ExpeditionDetailScreenState extends State<ExpeditionDetailScreen> {
  late Future<ExpeditionProgress> _progressFuture;

  @override
  void initState() {
    super.initState();

    _progressFuture = ExpeditionStorage.load();
  }

  void _reloadProgress() {
    setState(() {
      _progressFuture = ExpeditionStorage.load();
    });
  }

  Future<void> _openMission(ExpeditionMission mission) async {
    if (mission.isUltimate) {
      final ExpeditionProgress progress = await ExpeditionStorage.load();

      final int previousBestScore = progress.bestScoreFor(
        difficultyId: widget.difficulty.id,
        missionId: mission.id,
      );

      if (!mounted) {
        return;
      }

      final UltimateGameResult? result = await Navigator.of(context)
          .push<UltimateGameResult>(
            MaterialPageRoute<UltimateGameResult>(
              builder: (BuildContext context) {
                return UltimateGameScreen(
                  availableCountries: widget.controller
                      .ultimateCountriesForDifficulty(widget.difficulty.id),
                  countryDifficulties: widget.controller.countryDifficulties,
                  difficultyId: widget.difficulty.id,
                  missionTitle: mission.title,
                  previousBestScore: previousBestScore,
                );
              },
            ),
          );

      if (result != null) {
        final ExpeditionProgress currentProgress =
            await ExpeditionStorage.load();

        final ExpeditionProgress updatedProgress = currentProgress
            .registerMissionResult(
              difficultyId: widget.difficulty.id,
              missionId: mission.id,
              stars: result.earnedStars,
              score: result.totalScore,
            );

        await ExpeditionStorage.save(updatedProgress);
      }

      if (mounted) {
        _reloadProgress();
      }

      return;
    }

    final bool isPlayable =
        mission.modeId == 'find_country' ||
        mission.modeId == 'find_capital' ||
        mission.modeId == 'find_flag' ||
        mission.modeId == 'mixed';

    if (!isPlayable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${mission.title} sera disponible '
            'prochainement.',
          ),
        ),
      );

      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return GameScreen(
            controller: widget.controller,
            modeId: mission.modeId,
            difficultyId: widget.difficulty.id,
            missionTitle: mission.title,
          );
        },
      ),
    );

    if (mounted) {
      _reloadProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071B3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071B3A),
        foregroundColor: Colors.white,
        title: Text(
          'EXPÉDITION '
          '${_expeditionName(widget.difficulty).toUpperCase()}',
          style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ExpeditionBackground()),
          FutureBuilder<ExpeditionProgress>(
            future: _progressFuture,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<ExpeditionProgress> snapshot,
                ) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final ExpeditionProgress progress =
                      snapshot.data ?? ExpeditionProgress.initial();

                  final bool ultimateUnlocked = progress.isUltimateUnlocked(
                    widget.difficulty.id,
                  );

                  const List<ExpeditionMission> missions =
                      ExpeditionMission.defaultMissions;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                    children: <Widget>[
                      _ExpeditionHeader(
                        difficulty: widget.difficulty,
                        earnedStars: progress.totalStarsFor(
                          widget.difficulty.id,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'CHOISIS TON ÉPREUVE',
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (
                        int index = 0;
                        index < missions.length;
                        index++
                      ) ...<Widget>[
                        _TrialCard(
                          mission: missions[index],
                          bestScore: progress.bestScoreFor(
                            difficultyId: widget.difficulty.id,
                            missionId: missions[index].id,
                          ),
                          stars: progress.starsFor(
                            difficultyId: widget.difficulty.id,
                            missionId: missions[index].id,
                          ),
                          isLocked:
                              missions[index].isUltimate && !ultimateUnlocked,
                          isAvailable:
                              missions[index].isUltimate ||
                              missions[index].modeId == 'find_country' ||
                              missions[index].modeId == 'find_capital' ||
                              missions[index].modeId == 'find_flag' ||
                              missions[index].modeId == 'mixed',
                          onPressed:
                              missions[index].isUltimate && !ultimateUnlocked
                              ? null
                              : () {
                                  _openMission(missions[index]);
                                },
                        ),
                        if (index < missions.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }
}

class _ExpeditionCard extends StatelessWidget {
  const _ExpeditionCard({
    required this.difficulty,
    required this.isUnlocked,
    required this.earnedStars,
    required this.maximumStars,
    required this.onPressed,
  });

  final GameDifficulty difficulty;
  final bool isUnlocked;
  final int earnedStars;
  final int maximumStars;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = _colorsForDifficulty(difficulty.id);

    final double progress = maximumStars <= 0 ? 0 : earnedStars / maximumStars;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isUnlocked
                  ? colors
                  : const <Color>[Color(0xFF27364A), Color(0xFF152235)],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withValues(alpha: isUnlocked ? 0.25 : 0.10),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: isUnlocked ? 0.18 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isUnlocked
                      ? _iconForDifficulty(difficulty.id)
                      : Icons.lock_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _expeditionName(difficulty),
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUnlocked
                          ? difficulty.description
                          : 'Termine l’expédition '
                                'précédente pour la débloquer.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: isUnlocked ? progress : 0,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFFD166),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isUnlocked
                              ? '$earnedStars / '
                                    '$maximumStars ⭐'
                              : 'VERROUILLÉE',
                          style: GoogleFonts.nunitoSans(
                            color: isUnlocked
                                ? const Color(0xFFFFD166)
                                : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isUnlocked
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpeditionHeader extends StatelessWidget {
  const _ExpeditionHeader({
    required this.difficulty,
    required this.earnedStars,
  });

  final GameDifficulty difficulty;
  final int earnedStars;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = _colorsForDifficulty(difficulty.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            _iconForDifficulty(difficulty.id),
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 10),
          Text(
            _expeditionName(difficulty).toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            difficulty.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$earnedStars / 15 étoiles',
            style: GoogleFonts.nunitoSans(
              color: const Color(0xFFFFD166),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialCard extends StatelessWidget {
  const _TrialCard({
    required this.mission,
    required this.bestScore,
    required this.stars,
    required this.isLocked,
    required this.isAvailable,
    required this.onPressed,
  });

  final ExpeditionMission mission;
  final int bestScore;
  final int stars;
  final bool isLocked;
  final bool isAvailable;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool disabled = isLocked || !isAvailable;

    return Material(
      color: Colors.white.withValues(alpha: disabled ? 0.06 : 0.11),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: Colors.white.withValues(alpha: disabled ? 0.08 : 0.15),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 53,
                height: 53,
                decoration: BoxDecoration(
                  color: disabled
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFF28C2FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  isLocked ? Icons.lock_rounded : mission.icon,
                  color: disabled ? Colors.white38 : const Color(0xFF53D8FF),
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      mission.title,
                      style: GoogleFonts.fredoka(
                        color: disabled ? Colors.white54 : Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.emoji_events_rounded,
                          color: disabled
                              ? Colors.white38
                              : const Color(0xFFFFD166),
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          bestScore > 0
                              ? 'Record : '
                                    '$bestScore pts'
                              : 'Record : —',
                          style: GoogleFonts.nunitoSans(
                            color: disabled
                                ? Colors.white38
                                : const Color(0xFFFFD166),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mission.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(
                          alpha: disabled ? 0.36 : 0.62,
                        ),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      isLocked
                          ? 'VERROUILLÉE'
                          : isAvailable
                          ? _starText(stars)
                          : 'BIENTÔT',
                      style: GoogleFonts.nunitoSans(
                        color: isLocked
                            ? Colors.white38
                            : isAvailable
                            ? const Color(0xFFFFD166)
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isLocked
                    ? Icons.lock_outline
                    : isAvailable
                    ? Icons.chevron_right_rounded
                    : Icons.schedule_rounded,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _starText(int stars) {
    final int normalizedStars = stars.clamp(0, 3);

    return '${'★' * normalizedStars}'
        '${'☆' * (3 - normalizedStars)}';
  }
}

class _ExpeditionBackground extends StatelessWidget {
  const _ExpeditionBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF071B3A), Color(0xFF0D3B78)],
        ),
      ),
    );
  }
}

class _ExpeditionError extends StatelessWidget {
  const _ExpeditionError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Impossible de charger '
          'les expéditions.\n$error',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunitoSans(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }
}

String _expeditionName(GameDifficulty difficulty) {
  switch (difficulty.id) {
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
      return difficulty.name;
  }
}

IconData _iconForDifficulty(String id) {
  switch (id) {
    case 'discovery':
      return Icons.eco_rounded;
    case 'easy':
      return Icons.public_rounded;
    case 'intermediate':
      return Icons.travel_explore_rounded;
    case 'hard':
      return Icons.explore_rounded;
    case 'expert':
      return Icons.workspace_premium_rounded;
    default:
      return Icons.map_rounded;
  }
}

List<Color> _colorsForDifficulty(String id) {
  switch (id) {
    case 'discovery':
      return const <Color>[Color(0xFF28B67A), Color(0xFF087A5A)];
    case 'easy':
      return const <Color>[Color(0xFF28C2FF), Color(0xFF176BFF)];
    case 'intermediate':
      return const <Color>[Color(0xFF9B6DFF), Color(0xFF5D39B8)];
    case 'hard':
      return const <Color>[Color(0xFFFF8A4C), Color(0xFFE64B45)];
    case 'expert':
      return const <Color>[Color(0xFFFFD166), Color(0xFFB77900)];
    default:
      return const <Color>[Color(0xFF176BFF), Color(0xFF071B3A)];
  }
}
