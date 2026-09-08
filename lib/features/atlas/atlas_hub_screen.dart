import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geo_engine/geo_country.dart';
import '../design/geopoint_design.dart';
import 'atlas_personal_list_screen.dart';
import 'atlas_personal_progress.dart';
import 'atlas_personal_storage.dart';
import 'atlas_screen.dart';

class AtlasHubScreen extends StatefulWidget {
  const AtlasHubScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<AtlasHubScreen> createState() => _AtlasHubScreenState();
}

class _AtlasHubScreenState extends State<AtlasHubScreen> {
  AtlasPersonalProgress _progress = AtlasPersonalProgress.initial();

  int get _worldCountryCount {
    return widget.controller.countries
        .map((GeoCountry country) => country.id.trim().toUpperCase())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .length;
  }

  int get _validVisitedCount {
    final Set<String> availableIds = widget.controller.countries
        .map((GeoCountry country) => country.id.trim().toUpperCase())
        .toSet();
    return _progress.visitedCountryIds
        .where(availableIds.contains)
        .length;
  }

  int get _visitedContinentCount {
    final Set<String> visited = _progress.visitedCountryIds;
    return widget.controller.countries
        .where((GeoCountry country) {
          return visited.contains(country.id.trim().toUpperCase());
        })
        .map((GeoCountry country) => _continentKey(country.continent))
        .where((String continent) => continent.isNotEmpty)
        .toSet()
        .length;
  }

  double get _worldDiscoveredPercentage {
    final int total = _worldCountryCount;
    return total == 0 ? 0 : (_validVisitedCount / total) * 100;
  }

  static String _continentKey(String value) {
    final String continent = value.trim().toLowerCase();

    if (continent.contains('africa') || continent.contains('afrique')) {
      return 'afrique';
    }
    if (continent.contains('asia') || continent.contains('asie')) {
      return 'asie';
    }
    if (continent.contains('europe')) {
      return 'europe';
    }
    if (continent.contains('america') || continent.contains('amérique')) {
      return 'ameriques';
    }
    if (continent.contains('oceania') || continent.contains('océanie')) {
      return 'oceanie';
    }
    if (continent.contains('antarct')) {
      return 'antarctique';
    }

    return continent;
  }

  @override
  void initState() {
    super.initState();
    _refreshProgress();
  }

  Future<void> _refreshProgress() async {
    final AtlasPersonalProgress progress =
        await AtlasPersonalStorage.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _progress = progress;
    });
  }

  Future<void> _openMap(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return AtlasScreen(controller: widget.controller);
        },
      ),
    );

    await _refreshProgress();
  }

  Future<void> _openPersonalList(
    BuildContext context, {
    required AtlasPersonalListType type,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return AtlasPersonalListScreen(
            controller: widget.controller,
            type: type,
          );
        },
      ),
    );

    await _refreshProgress();
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
                      title: 'ATLAS',
                      subtitle: 'Le monde à portée de main',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 28),
                    const GeoSectionHeading(
                      eyebrow: '',
                      title: 'Ton monde, tes voyages',
                      description:
                          'Découvre les pays, leurs villes et prépare tes voyages.',
                    ),
                    const SizedBox(height: 20),
                    _WorldMapCard(onPressed: () => _openMap(context)),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: SizedBox(
                            height: 190,
                            child: GeoFeatureCard(
                              icon: Icons.flight_takeoff_rounded,
                              title: 'MES VOYAGES',
                              subtitle:
                                  'Retrouve les pays que tu as déjà visités.',
                              color: GeoColors.mint,
                              badge: '${_progress.visitedCount} pays',
                              artwork: const GeoCardArtwork(
                                primary: Icons.flight_takeoff_rounded,
                                secondary: Icons.location_on_rounded,
                                color: GeoColors.navy,
                              ),
                              onPressed: () => _openPersonalList(
                                context,
                                type: AtlasPersonalListType.visited,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 190,
                            child: GeoFeatureCard(
                              icon: Icons.bookmark_rounded,
                              title: 'À VISITER',
                              subtitle: 'Prépare ta liste de destinations rêvées.',
                              color: GeoColors.coral,
                              badge: '${_progress.wishlistCount} pays',
                              artwork: const GeoCardArtwork(
                                primary: Icons.bookmark_rounded,
                                secondary: Icons.flag_rounded,
                                color: GeoColors.navy,
                              ),
                              onPressed: () => _openPersonalList(
                                context,
                                type: AtlasPersonalListType.wishlist,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 170,
                      child: GeoFeatureCard(
                        icon: Icons.favorite_rounded,
                        title: 'MES FAVORIS',
                        subtitle:
                            'Retrouve rapidement les pays que tu préfères.',
                        color: GeoColors.gold,
                        badge: '${_progress.favoriteCount} pays',
                        artwork: const GeoCardArtwork(
                          primary: Icons.favorite_rounded,
                          secondary: Icons.public_rounded,
                          color: GeoColors.navy,
                        ),
                        onPressed: () => _openPersonalList(
                          context,
                          type: AtlasPersonalListType.favorite,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TravelStatisticsCard(
                      visitedCount: _validVisitedCount,
                      wishlistCount: _progress.wishlistCount,
                      continentCount: _visitedContinentCount,
                      worldPercentage: _worldDiscoveredPercentage,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: GeoColors.gold,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'L’Atlas continuera de grandir avec ta progression.',
                              style: GoogleFonts.nunitoSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
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

class _TravelStatisticsCard extends StatelessWidget {
  const _TravelStatisticsCard({
    required this.visitedCount,
    required this.wishlistCount,
    required this.continentCount,
    required this.worldPercentage,
  });

  final int visitedCount;
  final int wishlistCount;
  final int continentCount;
  final double worldPercentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'MON MONDE EN CHIFFRES',
            style: GoogleFonts.nunitoSans(
              color: GeoColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _TravelStat(
                  icon: Icons.flight_takeoff_rounded,
                  value: '$visitedCount',
                  label: 'pays visités',
                  color: GeoColors.mint,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TravelStat(
                  icon: Icons.favorite_rounded,
                  value: '$wishlistCount',
                  label: 'à visiter',
                  color: GeoColors.coral,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TravelStat(
                  icon: Icons.public_rounded,
                  value: '$continentCount/6',
                  label: 'continents',
                  color: GeoColors.sky,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TravelStat(
                  icon: Icons.explore_rounded,
                  value: '${worldPercentage.toStringAsFixed(1)} %',
                  label: 'du monde',
                  color: GeoColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TravelStat extends StatelessWidget {
  const _TravelStat({
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
    return Column(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunitoSans(
            color: Colors.white.withValues(alpha: 0.66),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _WorldMapCard extends StatelessWidget {
  const _WorldMapCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(29),
        child: Ink(
          height: 230,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF3AAAF1),
                Color(0xFF277FEA),
                Color(0xFF2477FF),
              ],
            ),
            borderRadius: BorderRadius.circular(29),
            border: Border.all(color: Colors.white70),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const Positioned(
                right: -4,
                top: 18,
                child: _AtlasWorldArt(size: 190),
              ),
              Positioned(
                left: 22,
                top: 23,
                child: SizedBox(
                  width: 185,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'CARTE\nINTERACTIVE',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.02,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Pays, villes et fiches détaillées',
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 22,
                bottom: 20,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: GeoColors.gold,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    color: GeoColors.navy,
                    size: 30,
                  ),
                ),
              ),
              const Positioned(
                right: 22,
                bottom: 28,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtlasWorldArt extends StatelessWidget {
  const _AtlasWorldArt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _AtlasWorldPainter()),
    );
  }
}

class _AtlasWorldPainter extends CustomPainter {
  const _AtlasWorldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide * 0.40;
    final Paint globeFill = Paint()
      ..color = Colors.white.withValues(alpha: 0.10);
    final Paint grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final Paint land = Paint()
      ..color = const Color(0xFFBDEEFF).withValues(alpha: 0.62);

    canvas.drawCircle(center, radius, globeFill);
    canvas.drawCircle(center, radius, grid);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 0.92,
        height: radius * 2,
      ),
      grid,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      grid,
    );

    final Path west = Path()
      ..moveTo(center.dx - radius * 0.72, center.dy - radius * 0.50)
      ..lineTo(center.dx - radius * 0.22, center.dy - radius * 0.68)
      ..lineTo(center.dx - radius * 0.04, center.dy - radius * 0.30)
      ..lineTo(center.dx - radius * 0.30, center.dy - radius * 0.08)
      ..lineTo(center.dx - radius * 0.15, center.dy + radius * 0.28)
      ..lineTo(center.dx - radius * 0.43, center.dy + radius * 0.73)
      ..lineTo(center.dx - radius * 0.61, center.dy + radius * 0.21)
      ..lineTo(center.dx - radius * 0.83, center.dy - radius * 0.08)
      ..close();
    canvas.drawPath(west, land);

    final Path east = Path()
      ..moveTo(center.dx + radius * 0.02, center.dy - radius * 0.56)
      ..lineTo(center.dx + radius * 0.52, center.dy - radius * 0.72)
      ..lineTo(center.dx + radius * 0.83, center.dy - radius * 0.25)
      ..lineTo(center.dx + radius * 0.51, center.dy + radius * 0.03)
      ..lineTo(center.dx + radius * 0.39, center.dy + radius * 0.56)
      ..lineTo(center.dx + radius * 0.07, center.dy + radius * 0.32)
      ..lineTo(center.dx + radius * 0.20, center.dy - radius * 0.07)
      ..close();
    canvas.drawPath(east, land);

    final Path route = Path()
      ..moveTo(center.dx - radius * 0.64, center.dy + radius * 0.42)
      ..quadraticBezierTo(
        center.dx,
        center.dy + radius * 0.90,
        center.dx + radius * 0.72,
        center.dy + radius * 0.30,
      );
    final Paint dots = Paint()..color = GeoColors.gold;
    for (final metric in route.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 2.3, dots);
        }
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtlasWorldPainter oldDelegate) => false;
}
