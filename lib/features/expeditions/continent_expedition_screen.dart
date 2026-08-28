import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/continent/continent_expedition.dart';
import '../../game/continent/continent_progress.dart';
import '../../game/continent/continent_storage.dart';
import '../../game/game_controller.dart';
import '../../game/game_screen.dart';
import '../../game/ultimate/ultimate_game_screen.dart';
import '../design/geopoint_design.dart';

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
          SnackBar(
            content: Text(
              'Aucun pays disponible pour les silhouettes de '
              '${widget.expedition.name}.',
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
              onAnswer: ({
                required String countryId,
                required bool isCorrect,
              }) {
                return widget.controller.registerPassportSilhouetteAnswer(
                  countryId: countryId,
                  isCorrect: isCorrect,
                );
              },
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
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          FutureBuilder<ContinentProgress>(
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
        ],
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
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
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
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -22,
            top: -18,
            child: Icon(
              Icons.route_rounded,
              color: Colors.white.withValues(alpha: 0.09),
              size: 145,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.explore_rounded,
                      color: Colors.white,
                      size: 27,
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
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          expedition.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 11),
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
              const SizedBox(height: 10),
              Text(
                '${isCompleted ? 'RÉCOMPENSE OBTENUE' : 'RÉCOMPENSE FINALE'} '
                '• ${expedition.completionReward}',
                style: GoogleFonts.nunitoSans(
                  color: const Color(0xFFFFD166),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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
    final bool isCompleted = normalizedStars > 0;
    final bool isCurrent = isUnlocked && !isCompleted;
    final Color nodeColor = isCompleted
        ? GeoColors.mint
        : isCurrent
            ? GeoColors.blue
            : const Color(0xFF405472);

    if (level.order > 0) {
      return _ContinentPathLevelLayout(
        level: level,
        stars: normalizedStars,
        bestScore: bestScore,
        isUnlocked: isUnlocked,
        isCompleted: isCompleted,
        isCurrent: isCurrent,
        nodeColor: nodeColor,
        icon: _icon,
        modeLabel: _modeLabel,
        onPressed: onPressed,
      );
    }

    return IntrinsicHeight(
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 30,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 63,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent ? GeoColors.sky : Colors.white54,
                      width: isCurrent ? 3 : 2,
                    ),
                    boxShadow: isCurrent
                        ? <BoxShadow>[
                            BoxShadow(
                              color: GeoColors.blue.withValues(alpha: 0.38),
                              blurRadius: 15,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isUnlocked
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${level.order}',
                                style: GoogleFonts.fredoka(
                                  color: GeoColors.navy,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                              if (isCompleted)
                                Text(
                                  '${'★' * normalizedStars}'
                                  '${'☆' * (3 - normalizedStars)}',
                                  style: const TextStyle(
                                    color: GeoColors.gold,
                                    fontSize: 8,
                                  ),
                                ),
                            ],
                          )
                        : const Icon(
                            Icons.lock_rounded,
                            color: Colors.white54,
                            size: 24,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isUnlocked ? 0.10 : 0.045,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCurrent
                              ? GeoColors.blue.withValues(alpha: 0.62)
                              : Colors.white.withValues(
                                  alpha: isUnlocked ? 0.15 : 0.06,
                                ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      _icon,
                                      color: isUnlocked
                                          ? GeoColors.sky
                                          : Colors.white24,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        level.title,
                                        style: GoogleFonts.fredoka(
                                          color: isUnlocked
                                              ? Colors.white
                                              : Colors.white38,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  level.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunitoSans(
                                    color: isUnlocked
                                        ? Colors.white60
                                        : Colors.white24,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 7,
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
                                        label:
                                            '${level.questionDurationSeconds} SEC.',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isUnlocked
                                      ? bestScore > 0
                                          ? 'Record : $bestScore pts'
                                          : isCurrent
                                              ? 'Niveau actuel'
                                              : level.rewardLabel
                                      : 'Obtiens une étoile au niveau précédent',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunitoSans(
                                    color: isUnlocked
                                        ? GeoColors.gold
                                        : Colors.white30,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
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
                ),
              ),
            ],
          ),
        ],
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

class _ContinentPathLevelLayout extends StatelessWidget {
  const _ContinentPathLevelLayout({
    required this.level,
    required this.stars,
    required this.bestScore,
    required this.isUnlocked,
    required this.isCompleted,
    required this.isCurrent,
    required this.nodeColor,
    required this.icon,
    required this.modeLabel,
    required this.onPressed,
  });

  final ContinentLevel level;
  final int stars;
  final int bestScore;
  final bool isUnlocked;
  final bool isCompleted;
  final bool isCurrent;
  final Color nodeColor;
  final IconData icon;
  final String modeLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool nodeOnLeft = level.order.isOdd;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double nodeLeft = width * (nodeOnLeft ? 0.07 : 0.72);
        final double cardInset = width * 0.30;

        return SizedBox(
          height: 132,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ExpeditionPathPainter(
                      nodeOnLeft: nodeOnLeft,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: nodeLeft,
                top: 27,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent ? GeoColors.gold : Colors.white54,
                      width: isCurrent ? 4 : 2.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: nodeColor.withValues(alpha: 0.34),
                        blurRadius: isCurrent ? 22 : 11,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isUnlocked
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                level.isMaster
                                    ? Icons.workspace_premium_rounded
                                    : level.isExam
                                        ? Icons.school_rounded
                                        : icon,
                                color: GeoColors.navy,
                                size: 24,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${level.order}',
                                style: GoogleFonts.fredoka(
                                  color: GeoColors.navy,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ],
                          )
                        : const Icon(
                            Icons.lock_rounded,
                            color: Colors.white54,
                            size: 25,
                          ),
                  ),
                ),
              ),
              Positioned(
                left: nodeOnLeft ? cardInset : 0,
                right: nodeOnLeft ? 0 : cardInset,
                top: 20,
                bottom: 18,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(21),
                    child: Ink(
                      padding: const EdgeInsets.fromLTRB(15, 12, 11, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: nodeOnLeft
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          end: nodeOnLeft
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          colors: <Color>[
                            (isUnlocked
                                    ? const Color(0xFF163E76)
                                    : const Color(0xFF142C50))
                                .withValues(alpha: 0.94),
                            const Color(0xFF0A2852).withValues(alpha: 0.68),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(
                          color: isCurrent
                              ? GeoColors.gold.withValues(alpha: 0.82)
                              : Colors.white.withValues(
                                  alpha: isUnlocked ? 0.11 : 0.05,
                                ),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  level.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.fredoka(
                                    color: isUnlocked
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.04,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: <Widget>[
                                    _PathInfoPill(
                                      text: modeLabel,
                                      enabled: isUnlocked,
                                    ),
                                    if (isCompleted) ...<Widget>[
                                      const SizedBox(width: 5),
                                      Text(
                                        '${'★' * stars}${'☆' * (3 - stars)}',
                                        style: const TextStyle(
                                          color: GeoColors.gold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (isUnlocked && bestScore > 0) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Record $bestScore pts',
                                    style: GoogleFonts.nunitoSans(
                                      color: GeoColors.gold,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
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
                            color: isUnlocked ? GeoColors.gold : Colors.white24,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PathInfoPill extends StatelessWidget {
  const _PathInfoPill({required this.text, required this.enabled});

  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: enabled ? Colors.white60 : Colors.white24,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ExpeditionPathPainter extends CustomPainter {
  const _ExpeditionPathPainter({required this.nodeOnLeft});

  final bool nodeOnLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final double leftX = size.width * 0.07 + 37;
    final double rightX = size.width * 0.72 + 37;
    final double currentX = nodeOnLeft ? leftX : rightX;
    final double oppositeX = nodeOnLeft ? rightX : leftX;

    final Path route = Path()
      ..moveTo(oppositeX, 0)
      ..cubicTo(
        oppositeX,
        size.height * 0.30,
        currentX,
        size.height * 0.30,
        currentX,
        size.height * 0.50,
      )
      ..cubicTo(
        currentX,
        size.height * 0.72,
        oppositeX,
        size.height * 0.72,
        oppositeX,
        size.height,
      );

    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.065)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    final Paint dotPaint = Paint()
      ..color = GeoColors.gold.withValues(alpha: 0.46)
      ..style = PaintingStyle.fill;

    for (final PathMetric metric in route.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final Tangent? tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 2.45, dotPaint);
        }
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExpeditionPathPainter oldDelegate) {
    return oldDelegate.nodeOnLeft != nodeOnLeft;
  }
}
