import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../passport/progress/passport_progress_v2.dart';
import '../../player/player_profile.dart';
import '../design/geopoint_design.dart';
import '../statistics/statistics_screen.dart';
import 'passport_country_stamp_book_screen.dart';
import 'passport_world_screen.dart';

class PassportHubScreen extends StatelessWidget {
  const PassportHubScreen({required this.controller, super.key});

  final GameController controller;

  void _openCollections(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return PassportCountryStampBookScreen(controller: controller);
        },
      ),
    );
  }

  void _openStatistics(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return StatisticsScreen(controller: controller);
        },
      ),
    );
  }

  void _openWorld(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return PassportWorldScreen(controller: controller);
        },
      ),
    );
  }

  void _openContinents(BuildContext context) {
    _openWorld(context);
  }

  void _openAchievements(BuildContext context) {
    showGeoComingSoon(
      context,
      title: 'Tes accomplissements',
      message:
          'Découverte, maîtrise, précision et régularité seront regroupées ici.',
      icon: Icons.emoji_events_rounded,
      color: GeoColors.coral,
    );
  }

  int get _worldEntityCount {
    return controller.countries
        .map((country) => country.id.trim().toUpperCase())
        .where((String entityId) => entityId.isNotEmpty)
        .toSet()
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final PassportProgressV2 progress = controller.passportProgress;
    final PlayerProfile profile = controller.playerProfile;
    final int worldEntityCount = _worldEntityCount;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 38),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'MON PASSEPORT',
                      subtitle: 'Toute ta progression GeoPoint',
                      onBack: () => Navigator.of(context).pop(),
                      trailing: _HeaderLevelBadge(
                        level: profile.currentLevel,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _PlayerProgressCard(
                      displayName: controller.passport.displayName,
                      profile: profile,
                      discoveredCount: progress.discoveredEntityCount,
                      masteredCount: progress.masteredEntityCount,
                      countryStampCount: progress.unlockedCountryStampCount,
                      visitedCount: progress.visitedEntityCount,
                    ),
                    const SizedBox(height: 22),
                    const GeoSectionHeading(
                      eyebrow: 'PROGRESSION',
                      title: 'Ton aventure en un coup d’œil',
                      description:
                          'Découvre le monde, consolide tes connaissances et '
                          'complète tes collections.',
                    ),
                    const SizedBox(height: 15),
                    _WorldProgressCard(
                      discoveredCount: progress.discoveredEntityCount,
                      masteredCount: progress.masteredEntityCount,
                      totalEntityCount: worldEntityCount,
                      onPressed: () => _openWorld(context),
                    ),
                    const SizedBox(height: 14),
                    _PassportDestinationGrid(
                      items: <_PassportDestination>[
                        _PassportDestination(
                          icon: Icons.travel_explore_rounded,
                          title: 'CONTINENTS',
                          subtitle: 'Suis ta progression zone par zone.',
                          color: GeoColors.sky,
                          badge: '6 zones',
                          onPressed: () => _openContinents(context),
                        ),
                        _PassportDestination(
                          icon: Icons.collections_bookmark_rounded,
                          title: 'COLLECTIONS',
                          subtitle: 'Collectionne les tampons du monde.',
                          color: GeoColors.gold,
                          badge:
                              '${progress.unlockedCountryStampCount}/$worldEntityCount',
                          onPressed: () => _openCollections(context),
                        ),
                        _PassportDestination(
                          icon: Icons.emoji_events_rounded,
                          title: 'ACCOMPLISSEMENTS',
                          subtitle: 'Relève des objectifs de progression.',
                          color: GeoColors.coral,
                          badge: 'Bientôt',
                          onPressed: () => _openAchievements(context),
                        ),
                        _PassportDestination(
                          icon: Icons.query_stats_rounded,
                          title: 'STATISTIQUES',
                          subtitle: 'Analyse tes parties et tes résultats.',
                          color: GeoColors.purple,
                          badge: '${profile.gamesPlayed} parties',
                          onPressed: () => _openStatistics(context),
                        ),
                      ],
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

class _HeaderLevelBadge extends StatelessWidget {
  const _HeaderLevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GeoColors.gold,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'NIV. $level',
        style: GoogleFonts.fredoka(
          color: GeoColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlayerProgressCard extends StatelessWidget {
  const _PlayerProgressCard({
    required this.displayName,
    required this.profile,
    required this.discoveredCount,
    required this.masteredCount,
    required this.countryStampCount,
    required this.visitedCount,
  });

  final String displayName;
  final PlayerProfile profile;
  final int discoveredCount;
  final int masteredCount;
  final int countryStampCount;
  final int visitedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PassportPaperPainter()),
            ),
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isWide = constraints.maxWidth >= 650;
              final Widget identity = _PlayerIdentity(
                displayName: displayName,
                profile: profile,
              );
              final Widget counters = _PlayerCounters(
                discoveredCount: discoveredCount,
                masteredCount: masteredCount,
                countryStampCount: countryStampCount,
                visitedCount: visitedCount,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(flex: 6, child: identity),
                    Container(
                      width: 1,
                      height: 108,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      color: const Color(0xFFB8D5ED),
                    ),
                    Expanded(flex: 5, child: counters),
                  ],
                );
              }

              return Column(
                children: <Widget>[
                  identity,
                  const SizedBox(height: 18),
                  Container(height: 1, color: const Color(0xFFB8D5ED)),
                  const SizedBox(height: 15),
                  counters,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlayerIdentity extends StatelessWidget {
  const _PlayerIdentity({
    required this.displayName,
    required this.profile,
  });

  final String displayName;
  final PlayerProfile profile;

  String get _xpLabel {
    if (profile.isMaximumLevel) {
      return 'Niveau maximum atteint';
    }

    return '${profile.xpIntoCurrentLevel}/${profile.xpForNextLevel} XP';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 82,
          height: 82,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const GeoCompassLogo(size: 76, showShadow: false),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: GeoColors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '${profile.currentLevel}',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fredoka(
                  color: GeoColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: GeoColors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      profile.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: profile.levelProgress,
                  backgroundColor: Colors.white.withValues(alpha: 0.72),
                  color: GeoColors.blue,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _xpLabel,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.mutedInk,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerCounters extends StatelessWidget {
  const _PlayerCounters({
    required this.discoveredCount,
    required this.masteredCount,
    required this.countryStampCount,
    required this.visitedCount,
  });

  final int discoveredCount;
  final int masteredCount;
  final int countryStampCount;
  final int visitedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              _ProgressCounter(
                icon: Icons.visibility_rounded,
                value: '$discoveredCount',
                label: 'Découverts',
                color: GeoColors.blue,
              ),
              const SizedBox(height: 13),
              _ProgressCounter(
                icon: Icons.approval_rounded,
                value: '$countryStampCount',
                label: 'Tampons-pays',
                color: GeoColors.purple,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: <Widget>[
              _ProgressCounter(
                icon: Icons.school_rounded,
                value: '$masteredCount',
                label: 'Maîtrisés',
                color: const Color(0xFF147D59),
              ),
              const SizedBox(height: 13),
              _ProgressCounter(
                icon: Icons.flight_takeoff_rounded,
                value: '$visitedCount',
                label: 'Visités',
                color: const Color(0xFFB7433A),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressCounter extends StatelessWidget {
  const _ProgressCounter({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: GoogleFonts.fredoka(
                  color: GeoColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.mutedInk,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorldProgressCard extends StatelessWidget {
  const _WorldProgressCard({
    required this.discoveredCount,
    required this.masteredCount,
    required this.totalEntityCount,
    required this.onPressed,
  });

  final int discoveredCount;
  final int masteredCount;
  final int totalEntityCount;
  final VoidCallback onPressed;

  double get _discoveryProgress {
    if (totalEntityCount <= 0) {
      return 0;
    }

    return (discoveredCount / totalEntityCount).clamp(0, 1).toDouble();
  }

  int get _nextObjective {
    if (discoveredCount >= totalEntityCount) {
      return totalEntityCount;
    }

    final int nextStep = ((discoveredCount ~/ 5) + 1) * 5;
    return nextStep.clamp(0, totalEntityCount);
  }

  String get _objectiveLabel {
    if (totalEntityCount <= 0) {
      return 'Le monde est en cours de chargement.';
    }

    if (discoveredCount >= totalEntityCount) {
      return 'Tout le monde a été découvert !';
    }

    final int remaining = _nextObjective - discoveredCount;
    final String entityLabel = remaining > 1 ? 'entités' : 'entité';
    return 'Prochain objectif : découvre encore $remaining $entityLabel.';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(27),
        child: Ink(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFFBFF6DB),
                Color(0xFF69DEB5),
              ],
            ),
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isWide = constraints.maxWidth >= 620;
              final Widget information = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.public_rounded,
                          color: GeoColors.ink,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'MONDE',
                              style: GoogleFonts.fredoka(
                                color: GeoColors.ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$discoveredCount/$totalEntityCount découverts',
                              style: GoogleFonts.nunitoSans(
                                color: GeoColors.ink.withValues(alpha: 0.70),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: GeoColors.ink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: _discoveryProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.68),
                      color: GeoColors.blue,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _objectiveLabel,
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              );

              if (!isWide) {
                return information;
              }

              return Row(
                children: <Widget>[
                  Expanded(child: information),
                  const SizedBox(width: 28),
                  _WorldMasteryBadge(
                    masteredCount: masteredCount,
                    totalEntityCount: totalEntityCount,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorldMasteryBadge extends StatelessWidget {
  const _WorldMasteryBadge({
    required this.masteredCount,
    required this.totalEntityCount,
  });

  final int masteredCount;
  final int totalEntityCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.school_rounded,
            color: Color(0xFF147D59),
            size: 25,
          ),
          const SizedBox(height: 4),
          Text(
            '$masteredCount/$totalEntityCount',
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'maîtrisés',
            style: GoogleFonts.nunitoSans(
              color: GeoColors.ink.withValues(alpha: 0.66),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassportDestinationGrid extends StatelessWidget {
  const _PassportDestinationGrid({required this.items});

  final List<_PassportDestination> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = 12;
        final int columnCount = constraints.maxWidth >= 720 ? 4 : 2;
        final double cardWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map<Widget>((_PassportDestination item) {
            return SizedBox(
              width: cardWidth,
              height: 165,
              child: _PassportDestinationCard(item: item),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _PassportDestination {
  const _PassportDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.badge,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String badge;
  final VoidCallback onPressed;
}

class _PassportDestinationCard extends StatelessWidget {
  const _PassportDestinationCard({required this.item});

  final _PassportDestination item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 11,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.icon, color: GeoColors.ink, size: 23),
                  ),
                  const Spacer(),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 90),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      item.badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.ink,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  item.title,
                  maxLines: 1,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.ink.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassportPaperPainter extends CustomPainter {
  const _PassportPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = GeoColors.blue.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Offset stampCenter = Offset(
      size.width * 0.84,
      size.height * 0.70,
    );

    canvas.drawCircle(stampCenter, 42, line);
    canvas.drawCircle(stampCenter, 35, line);
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.90),
      Offset(size.width, size.height * 0.56),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.98),
      Offset(size.width, size.height * 0.68),
      line,
    );
  }

  @override
  bool shouldRepaint(
    covariant _PassportPaperPainter oldDelegate,
  ) {
    return false;
  }
}
