import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/continent/continent_expedition.dart';
import '../../game/continent/continent_progress.dart';
import '../../game/continent/continent_storage.dart';
import '../../game/game_controller.dart';
import '../../game/game_screen.dart';
import '../../game/ultimate/ultimate_game_screen.dart';

class ContinentExpeditionScreen extends StatefulWidget {
  const ContinentExpeditionScreen({
    required this.controller,
    required this.expedition,
    super.key,
  });

  final GameController controller;
  final ContinentExpedition expedition;

  @override
  State<ContinentExpeditionScreen> createState() {
    return _ContinentExpeditionScreenState();
  }
}

class _ContinentExpeditionScreenState
    extends State<ContinentExpeditionScreen> {
  late Future<ContinentProgress> _progressFuture;

  @override
  void initState() {
    super.initState();
    _reloadProgress();
  }

  void _reloadProgress() {
    _progressFuture = ContinentStorage.load();
  }

  Future<void> _openLevel({
    required ContinentLevel level,
    required ContinentProgress progress,
  }) async {
    if (level.isSilhouette) {
      final Set<String> countryIds = level.countryIds
          .map<String>((String id) => id.trim().toUpperCase())
          .toSet();

      final availableCountries = widget.controller.countries.where((country) {
        return countryIds.contains(
          country.id.trim().toUpperCase(),
        );
      }).toList(growable: false);

      if (availableCountries.isEmpty) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun pays européen disponible pour les silhouettes.',
            ),
          ),
        );
        return;
      }

      final int previousBestScore = progress.bestScoreFor(
        expeditionId: widget.expedition.id,
        levelId: level.id,
      );

      if (!mounted) {
        return;
      }

      final UltimateGameResult? result =
          await Navigator.of(context).push<UltimateGameResult>(
        MaterialPageRoute<UltimateGameResult>(
          builder: (BuildContext context) {
            return UltimateGameScreen(
              availableCountries: availableCountries,
              countryDifficulties:
                  widget.controller.countryDifficulties,
              difficultyId: level.difficultyId,
              missionTitle: level.title,
              previousBestScore: previousBestScore,
            );
          },
        ),
      );

      if (result != null) {
        final ContinentProgress currentProgress =
            await ContinentStorage.load();

        final ContinentProgress updatedProgress =
            currentProgress.registerLevelResult(
          expeditionId: widget.expedition.id,
          levelId: level.id,
          stars: result.earnedStars,
          score: result.totalScore,
        );

        await ContinentStorage.save(updatedProgress);
      }
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return GameScreen(
              controller: widget.controller,
              modeId: level.modeId,
              difficultyId: level.difficultyId,
              missionTitle: level.title,
              continentExpeditionId: widget.expedition.id,
              continentExpeditionName: widget.expedition.name,
              continentLevel: level,
            );
          },
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(_reloadProgress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071B3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071B3A),
        foregroundColor: Colors.white,
        title: Text(
          'EXPÉDITION ${widget.expedition.name.toUpperCase()}',
          style: GoogleFonts.fredoka(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<ContinentProgress>(
        future: _progressFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<ContinentProgress> snapshot,
        ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final ContinentProgress progress =
              snapshot.data ?? ContinentProgress.initial();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 34),
            itemCount: widget.expedition.levels.length + 1,
            separatorBuilder: (
              BuildContext context,
              int index,
            ) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              if (index == 0) {
                return _ContinentHeader(
                  expedition: widget.expedition,
                  progress: progress,
                );
              }

              final int levelIndex = index - 1;
              final ContinentLevel level =
                  widget.expedition.levels[levelIndex];

              final bool isUnlocked = progress.isLevelUnlocked(
                expedition: widget.expedition,
                levelIndex: levelIndex,
              );

              return _ContinentLevelCard(
                level: level,
                stars: progress.starsFor(
                  expeditionId: widget.expedition.id,
                  levelId: level.id,
                ),
                bestScore: progress.bestScoreFor(
                  expeditionId: widget.expedition.id,
                  levelId: level.id,
                ),
                isUnlocked: isUnlocked,
                onPressed: isUnlocked
                    ? () async {
                        await _openLevel(
                          level: level,
                          progress: progress,
                        );
                      }
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _ContinentHeader extends StatelessWidget {
  const _ContinentHeader({
    required this.expedition,
    required this.progress,
  });

  final ContinentExpedition expedition;
  final ContinentProgress progress;

  @override
  Widget build(BuildContext context) {
    final int completedLevels =
        progress.completedLevelsFor(expedition);

    final int totalStars =
        progress.totalStarsFor(expedition);

    final bool isCompleted =
        progress.isExpeditionCompleted(expedition);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF176BFF),
            Color(0xFF0C3C8C),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 62,
                height: 62,
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      expedition.name.toUpperCase(),
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      expedition.subtitle,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderStat(
                  icon: Icons.route_rounded,
                  value: '$completedLevels/${expedition.levels.length}',
                  label: 'NIVEAUX',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderStat(
                  icon: Icons.star_rounded,
                  value: '$totalStars/${expedition.maximumStars}',
                  label: 'ÉTOILES',
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            '${isCompleted ? 'RÉCOMPENSE OBTENUE' : 'RÉCOMPENSE FINALE'} '
            '• ${expedition.completionReward}',
            style: GoogleFonts.nunitoSans(
              color: const Color(0xFFFFD166),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFFFFD166), size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContinentLevelCard extends StatelessWidget {
  const _ContinentLevelCard({
    required this.level,
    required this.stars,
    required this.bestScore,
    required this.isUnlocked,
    required this.onPressed,
  });

  final ContinentLevel level;
  final int stars;
  final int bestScore;
  final bool isUnlocked;
  final VoidCallback? onPressed;

  IconData get _icon {
    if (level.isMaster) {
      return Icons.workspace_premium_rounded;
    }

    if (level.isExam) {
      return Icons.school_rounded;
    }

    if (level.isSilhouette) {
      return Icons.extension_rounded;
    }

    switch (level.modeId) {
      case 'find_capital':
        return Icons.location_city_rounded;
      case 'find_flag':
        return Icons.flag_rounded;
      case 'mixed':
        return Icons.shuffle_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  String get _modeLabel {
    if (level.isSilhouette) {
      return 'SILHOUETTES';
    }

    switch (level.modeId) {
      case 'find_capital':
        return 'CAPITALES';
      case 'find_flag':
        return 'DRAPEAUX';
      case 'mixed':
        return 'MIXTE';
      default:
        return 'PAYS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final int normalizedStars = stars.clamp(0, 3);

    return Material(
      color: Colors.white.withValues(
        alpha: isUnlocked ? 0.10 : 0.05,
      ),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: isUnlocked ? 0.16 : 0.07,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFF28C2FF).withValues(alpha: 0.17)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: isUnlocked
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              _icon,
                              color: const Color(0xFF53D8FF),
                              size: 24,
                            ),
                            Text(
                              '${level.order}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        )
                      : const Icon(
                          Icons.lock_rounded,
                          color: Colors.white30,
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      level.title,
                      style: GoogleFonts.fredoka(
                        color: isUnlocked ? Colors.white : Colors.white38,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      level.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: isUnlocked ? Colors.white60 : Colors.white24,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Objectif : ${level.objective}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: isUnlocked ? Colors.white70 : Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: <Widget>[
                        _LevelBadge(label: _modeLabel),
                        _LevelBadge(
                          label: level.isSilhouette
                              ? 'DÉFI VISUEL'
                              : '${level.questionCount} QUESTIONS',
                        ),
                        if (!level.isSilhouette)
                          _LevelBadge(
                            label: '${level.questionDurationSeconds} SEC.',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUnlocked
                          ? '${'★' * normalizedStars}'
                              '${'☆' * (3 - normalizedStars)}'
                              '${bestScore > 0 ? '  •  Record : $bestScore pts' : ''}'
                          : 'Obtiens une étoile au niveau précédent',
                      style: GoogleFonts.nunitoSans(
                        color: isUnlocked
                            ? const Color(0xFFFFD166)
                            : Colors.white30,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (isUnlocked) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        level.rewardLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                isUnlocked
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: isUnlocked ? Colors.white54 : Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
