import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/continent/africa_expedition.dart';
import '../../game/continent/americas_expedition.dart';
import '../../game/continent/asia_expedition.dart';
import '../../game/continent/continent_expedition.dart';
import '../../game/continent/continent_progress.dart';
import '../../game/continent/continent_storage.dart';
import '../../game/continent/europe_expedition.dart';
import '../../game/continent/oceania_expedition.dart';
import '../../game/continent/world_expedition.dart';
import '../../game/expedition/expedition_mission.dart';
import '../../game/expedition/expedition_progress.dart';
import '../../game/expedition/expedition_storage.dart';
import '../../game/game_controller.dart';
import '../../game/game_difficulty.dart';
import '../../game/game_screen.dart';
import '../../game/learning/guided_level.dart';
import '../../game/ultimate/ultimate_game_screen.dart';
import 'continent_expedition_screen.dart';
import '../exploration/national_explorations_screen.dart';

class ExpeditionsScreen extends StatefulWidget {
  const ExpeditionsScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<ExpeditionsScreen> createState() {
    return _ExpeditionsScreenState();
  }
}

class _ExpeditionsScreenState extends State<ExpeditionsScreen> {
  late Future<ContinentProgress> _continentProgressFuture;

  @override
  void initState() {
    super.initState();

    _continentProgressFuture = ContinentStorage.load();
  }

  void _reloadProgress() {
    setState(() {
      _continentProgressFuture = ContinentStorage.load();
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
          FutureBuilder<ContinentProgress>(
            future: _continentProgressFuture,
            builder: (
              BuildContext context,
              AsyncSnapshot<ContinentProgress> snapshot,
            ) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final ContinentProgress continentProgress =
                  snapshot.data ?? ContinentProgress.initial();

              return _ExpeditionList(
                controller: widget.controller,
                continentProgress: continentProgress,
                onProgressChanged: _reloadProgress,
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
    required this.continentProgress,
    required this.onProgressChanged,
  });

  final GameController controller;
  final ContinentProgress continentProgress;
  final VoidCallback onProgressChanged;

  static const List<ContinentExpedition>
      _continentExpeditions = <ContinentExpedition>[
    EuropeExpeditionCatalog.europe,
    AfricaExpeditionCatalog.africa,
    AsiaExpeditionCatalog.asia,
    AmericasExpeditionCatalog.americas,
    OceaniaExpeditionCatalog.oceania,
    WorldExpeditionCatalog.world,
  ];

  static const List<ContinentExpedition>
      _worldRequirements = <ContinentExpedition>[
    EuropeExpeditionCatalog.europe,
    AfricaExpeditionCatalog.africa,
    AsiaExpeditionCatalog.asia,
    AmericasExpeditionCatalog.americas,
    OceaniaExpeditionCatalog.oceania,
  ];

  int get _completedWorldRequirements {
    return _worldRequirements.where((ContinentExpedition expedition) {
      return continentProgress.isExpeditionCompleted(expedition);
    }).length;
  }

  bool get _isWorldUnlocked {
    return _completedWorldRequirements == _worldRequirements.length;
  }

  int get _completedLevelCount {
    return _worldRequirements.fold<int>(
      0,
      (int total, ContinentExpedition expedition) =>
          total + continentProgress.completedLevelsFor(expedition),
    );
  }

  int get _totalLevelCount {
    return _worldRequirements.fold<int>(
      0,
      (int total, ContinentExpedition expedition) =>
          total + expedition.levels.length,
    );
  }

  int get _totalStars {
    return _worldRequirements.fold<int>(
      0,
      (int total, ContinentExpedition expedition) =>
          total + continentProgress.totalStarsFor(expedition),
    );
  }

  Future<void> _openExpedition(
    BuildContext context,
    ContinentExpedition expedition,
  ) async {
    final bool isWorld = expedition.id == WorldExpeditionCatalog.world.id;
    final bool isUnlocked = !isWorld || _isWorldUnlocked;

    if (!isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Termine les cinq expéditions continentales '
            'pour débloquer l’expédition Monde.',
          ),
        ),
      );
      return;
    }

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

    onProgressChanged();
  }

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

  Future<void> _openNationalExplorations(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            const NationalExplorationsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ContinentExpedition> continents =
        _continentExpeditions.take(5).toList(growable: false);
    final ContinentExpedition world = _continentExpeditions.last;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: <Widget>[
        _SelectionProgressSummary(
          completedLevels: _completedLevelCount,
          totalLevels: _totalLevelCount,
          totalStars: _totalStars,
        ),
        const SizedBox(height: 16),
        _TutorialCard(
          onPressed: () async {
            await _openTutorials(context);
          },
        ),
        const SizedBox(height: 16),
        _NationalExplorationCard(
          onPressed: () async {
            await _openNationalExplorations(context);
          },
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: continents.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.93,
          ),
          itemBuilder: (BuildContext context, int index) {
            final ContinentExpedition expedition = continents[index];
            return _ContinentExpeditionCard(
              expedition: expedition,
              completedLevels:
                  continentProgress.completedLevelsFor(expedition),
              isLocked: false,
              prerequisiteLabel: null,
              onPressed: () async {
                await _openExpedition(context, expedition);
              },
            );
          },
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 165,
          child: _ContinentExpeditionCard(
            expedition: world,
            completedLevels: continentProgress.completedLevelsFor(world),
            isLocked: !_isWorldUnlocked,
            prerequisiteLabel: '$_completedWorldRequirements/'
                '${_worldRequirements.length} continents terminés',
            onPressed: () async {
              await _openExpedition(context, world);
            },
          ),
        ),
      ],
    );
  }
}

class _NationalExplorationCard extends StatelessWidget {
  const _NationalExplorationCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF4C75D8), Color(0xFF253C89)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF4C75D8).withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'NOUVEAU • FRANCE PILOTE',
                      style: GoogleFonts.nunitoSans(
                        color: const Color(0xFFFFCE59),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    Text(
                      'Explorations nationales',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explore un pays en profondeur avec une carte et une progression dédiées.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionProgressSummary extends StatelessWidget {
  const _SelectionProgressSummary({
    required this.completedLevels,
    required this.totalLevels,
    required this.totalStars,
  });

  final int completedLevels;
  final int totalLevels;
  final int totalStars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.flag_rounded, color: Color(0xFF55D6A6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$completedLevels / $totalLevels niveaux',
              style: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(width: 1, height: 25, color: Colors.white12),
          const SizedBox(width: 13),
          const Icon(Icons.star_rounded, color: Color(0xFFFFCE59)),
          const SizedBox(width: 6),
          Text(
            '$totalStars étoiles',
            style: GoogleFonts.nunitoSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
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
    required this.completedLevels,
    required this.isLocked,
    required this.prerequisiteLabel,
    required this.onPressed,
  });

  final ContinentExpedition expedition;
  final int completedLevels;
  final bool isLocked;
  final String? prerequisiteLabel;
  final VoidCallback onPressed;

  List<Color> get _colors {
    switch (expedition.id) {
      case 'world':
        return const <Color>[
          Color(0xFF102F62),
          Color(0xFF071B3A),
        ];
      case 'oceania':
        return const <Color>[
          Color(0xFF29A9E8),
          Color(0xFF1674B7),
        ];
      case 'americas':
        return const <Color>[
          Color(0xFF43C7B0),
          Color(0xFF15927F),
        ];
      case 'asia':
        return const <Color>[
          Color(0xFFFF756B),
          Color(0xFFD94E4B),
        ];
      case 'africa':
        return const <Color>[
          Color(0xFFFFBE3D),
          Color(0xFFE59122),
        ];
      case 'europe':
      default:
        return const <Color>[
          Color(0xFF55D6A6),
          Color(0xFF279D7B),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWorld = expedition.id == 'world';

    return Opacity(
      opacity: isLocked ? 0.72 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _colors,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isWorld
                    ? const Color(0xFFFFCE59).withValues(alpha: 0.70)
                    : Colors.white.withValues(alpha: 0.30),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 13,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -22,
                  bottom: -20,
                  child: _ContinentArt(
                    id: expedition.id,
                    size: 145,
                    color: Colors.white.withValues(alpha: 0.11),
                  ),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth > 330;

                final Widget symbol = Container(
                  width: wide ? 76 : 58,
                  height: wide ? 76 : 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(wide ? 22 : 17),
                  ),
                  child: isLocked
                      ? Icon(
                          Icons.lock_rounded,
                          color: isWorld
                              ? const Color(0xFFFFCE59)
                              : Colors.white,
                          size: wide ? 39 : 31,
                        )
                      : Padding(
                          padding: EdgeInsets.all(wide ? 14 : 11),
                          child: _ContinentArt(
                            id: expedition.id,
                            size: wide ? 48 : 37,
                            color: isWorld
                                ? const Color(0xFFFFCE59)
                                : Colors.white,
                          ),
                        ),
                );

                final Widget information = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      expedition.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fredoka(
                        color: isWorld
                            ? const Color(0xFFFFCE59)
                            : Colors.white,
                        fontSize: wide ? 25 : 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (wide) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        expedition.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isLocked && prerequisiteLabel != null
                            ? prerequisiteLabel!
                            : '$completedLevels/${expedition.levels.length}',
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white,
                          fontSize: wide ? 11 : 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                );

                return Padding(
                  padding: EdgeInsets.all(wide ? 18 : 15),
                  child: wide
                      ? Row(
                          children: <Widget>[
                            symbol,
                            const SizedBox(width: 16),
                            Expanded(child: information),
                            Icon(
                              isLocked
                                  ? Icons.lock_outline_rounded
                                  : Icons.chevron_right_rounded,
                              color: Colors.white70,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                symbol,
                                const Spacer(),
                                Icon(
                                  isLocked
                                      ? Icons.lock_outline_rounded
                                      : Icons.arrow_outward_rounded,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                            const Spacer(),
                            information,
                          ],
                        ),
                );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinentArt extends StatelessWidget {
  const _ContinentArt({
    required this.id,
    required this.size,
    required this.color,
  });

  final String id;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ContinentArtPainter(id: id, color: color),
      ),
    );
  }
}

class _ContinentArtPainter extends CustomPainter {
  const _ContinentArtPainter({required this.id, required this.color});

  final String id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.045
      ..strokeCap = StrokeCap.round;

    if (id == 'world') {
      final Offset center = size.center(Offset.zero);
      final double radius = size.shortestSide * 0.40;
      canvas.drawCircle(center, radius, stroke);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 0.92,
          height: radius * 2,
        ),
        stroke,
      );
      canvas.drawLine(
        Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy),
        stroke,
      );
      return;
    }

    final Path path = Path();
    switch (id) {
      case 'africa':
        path
          ..moveTo(0.24, 0.18)
          ..lineTo(0.55, 0.08)
          ..lineTo(0.82, 0.25)
          ..lineTo(0.73, 0.52)
          ..lineTo(0.56, 0.70)
          ..lineTo(0.46, 0.94)
          ..lineTo(0.30, 0.68)
          ..lineTo(0.18, 0.42)
          ..close();
        break;
      case 'americas':
        path
          ..moveTo(0.20, 0.08)
          ..lineTo(0.55, 0.13)
          ..lineTo(0.68, 0.30)
          ..lineTo(0.48, 0.43)
          ..lineTo(0.55, 0.56)
          ..lineTo(0.43, 0.64)
          ..lineTo(0.52, 0.78)
          ..lineTo(0.36, 0.96)
          ..lineTo(0.24, 0.71)
          ..lineTo(0.31, 0.51)
          ..lineTo(0.12, 0.34)
          ..close();
        break;
      case 'asia':
        path
          ..moveTo(0.08, 0.34)
          ..lineTo(0.24, 0.13)
          ..lineTo(0.50, 0.18)
          ..lineTo(0.66, 0.08)
          ..lineTo(0.92, 0.24)
          ..lineTo(0.80, 0.45)
          ..lineTo(0.91, 0.58)
          ..lineTo(0.66, 0.63)
          ..lineTo(0.54, 0.86)
          ..lineTo(0.39, 0.65)
          ..lineTo(0.20, 0.58)
          ..close();
        break;
      case 'oceania':
        path
          ..moveTo(0.12, 0.43)
          ..lineTo(0.33, 0.25)
          ..lineTo(0.62, 0.31)
          ..lineTo(0.79, 0.51)
          ..lineTo(0.67, 0.74)
          ..lineTo(0.35, 0.80)
          ..lineTo(0.16, 0.63)
          ..close();
        canvas.drawCircle(
          Offset(size.width * 0.87, size.height * 0.72),
          size.shortestSide * 0.065,
          fill,
        );
        break;
      case 'europe':
      default:
        path
          ..moveTo(0.15, 0.34)
          ..lineTo(0.31, 0.16)
          ..lineTo(0.46, 0.27)
          ..lineTo(0.58, 0.10)
          ..lineTo(0.80, 0.23)
          ..lineTo(0.89, 0.43)
          ..lineTo(0.70, 0.48)
          ..lineTo(0.63, 0.68)
          ..lineTo(0.46, 0.58)
          ..lineTo(0.33, 0.80)
          ..lineTo(0.22, 0.59)
          ..close();
        break;
    }

    final Matrix4 transform = Matrix4.identity()
      ..scaleByDouble(size.width, size.height, 1.0, 1.0);
    canvas.drawPath(path.transform(transform.storage), fill);
  }

  @override
  bool shouldRepaint(covariant _ContinentArtPainter oldDelegate) {
    return oldDelegate.id != id || oldDelegate.color != color;
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
