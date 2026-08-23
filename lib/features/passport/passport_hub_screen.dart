import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../design/geopoint_design.dart';
import '../statistics/statistics_screen.dart';
import 'passport_screen.dart';

class PassportHubScreen extends StatelessWidget {
  const PassportHubScreen({required this.controller, super.key});

  final GameController controller;

  void _openStamps(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return PassportScreen(controller: controller);
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

  int get _totalStampCount {
    return controller.passportEngine.stamps.values
        .where((stamp) => stamp.isEnabled)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final int unlockedStamps = controller.passport.validatedStampCount;
    final int totalStamps = _totalStampCount;

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
                      title: 'MON PASSEPORT',
                      subtitle: 'Ton identité de cartographe',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 24),
                    _PlayerPassportCard(
                      displayName: controller.passport.displayName,
                      unlockedStamps: unlockedStamps,
                      totalStamps: totalStamps,
                      totalGames: controller.passport.totalAttempts,
                    ),
                    const SizedBox(height: 19),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.star_rounded,
                          color: GeoColors.gold,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Collectionne et progresse',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                              color: GeoColors.gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          color: GeoColors.gold,
                          size: 19,
                        ),
                      ],
                    ),
                    const SizedBox(height: 17),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: SizedBox(
                            height: 190,
                            child: GeoFeatureCard(
                              icon: Icons.query_stats_rounded,
                              title: 'STATISTIQUES',
                              subtitle: 'Analyse tes scores et les pays maîtrisés.',
                              color: GeoColors.sky,
                              artwork: const GeoCardArtwork(
                                primary: Icons.query_stats_rounded,
                                secondary: Icons.search_rounded,
                                color: GeoColors.navy,
                              ),
                              onPressed: () => _openStatistics(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 190,
                            child: GeoFeatureCard(
                              icon: Icons.approval_rounded,
                              title: 'MES TAMPONS',
                              subtitle: '$unlockedStamps sur $totalStamps débloqués.',
                              color: GeoColors.gold,
                              artwork: const GeoCardArtwork(
                                primary: Icons.approval_rounded,
                                secondary: Icons.star_rounded,
                                color: GeoColors.navy,
                              ),
                              onPressed: () => _openStamps(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: SizedBox(
                            height: 190,
                            child: GeoFeatureCard(
                              icon: Icons.face_retouching_natural_rounded,
                              title: 'MON AVATAR',
                              subtitle: 'Crée ton compagnon de voyage.',
                              color: GeoColors.purple,
                              badge: 'Bientôt',
                              artwork: const GeoCardArtwork(
                                primary: Icons.face_retouching_natural_rounded,
                                secondary: Icons.auto_awesome_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => showGeoComingSoon(
                                context,
                                title: 'Ton avatar',
                                message:
                                    'Tu pourras choisir ton personnage puis modifier '
                                    'son apparence avec les objets remportés.',
                                icon: Icons.face_retouching_natural_rounded,
                                color: GeoColors.purple,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 190,
                            child: GeoFeatureCard(
                              icon: Icons.inventory_2_rounded,
                              title: 'MON CASIER',
                              subtitle: 'Retrouve tous les éléments que tu as gagnés.',
                              color: GeoColors.purple,
                              badge: 'Bientôt',
                              artwork: const GeoCardArtwork(
                                primary: Icons.inventory_2_rounded,
                                secondary: Icons.key_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => showGeoComingSoon(
                                context,
                                title: 'Le casier',
                                message:
                                    'Chapeaux, accessoires, emblèmes et récompenses '
                                    'seront conservés dans ton casier.',
                                icon: Icons.inventory_2_rounded,
                                color: GeoColors.purple,
                              ),
                            ),
                          ),
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

class _PlayerPassportCard extends StatelessWidget {
  const _PlayerPassportCard({
    required this.displayName,
    required this.unlockedStamps,
    required this.totalStamps,
    required this.totalGames,
  });

  final String displayName;
  final int unlockedStamps;
  final int totalStamps;
  final int totalGames;

  @override
  Widget build(BuildContext context) {
    final double progress = totalStamps <= 0
        ? 0
        : (unlockedStamps / totalStamps).clamp(0, 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFF5D6),
            Color(0xFFFFD86D),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 15,
            offset: const Offset(0, 7),
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
          Column(
            children: <Widget>[
          Row(
            children: <Widget>[
              const GeoCompassLogo(size: 70, showShadow: false),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'CARTOGRAPHE GEOPOINT',
                      style: GoogleFonts.nunitoSans(
                        color: const Color(0xFF75570D),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const _MiniIdentityCard(),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.65),
              color: GeoColors.blue,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              Expanded(
                child: _PassportCounter(
                  value: '$unlockedStamps/$totalStamps',
                  label: 'Tampons',
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFD6B64F)),
              Expanded(
                child: _PassportCounter(
                  value: '$totalGames',
                  label: 'Parties',
                ),
              ),
            ],
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniIdentityCard extends StatelessWidget {
  const _MiniIdentityCard();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.05,
      child: Container(
        width: 54,
        height: 36,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFF9EE5F5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GeoColors.ink.withValues(alpha: 0.18)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 15,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: GeoColors.blue,
                size: 13,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int index = 0; index < 3; index++)
                    Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      decoration: BoxDecoration(
                        color: GeoColors.ink.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
      ..color = const Color(0xFFB98918).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Offset stampCenter = Offset(size.width * 0.82, size.height * 0.73);
    canvas.drawCircle(stampCenter, 34, line);
    canvas.drawCircle(stampCenter, 28, line);
    canvas.drawLine(
      Offset(size.width * 0.65, size.height * 0.86),
      Offset(size.width * 0.98, size.height * 0.58),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.92),
      Offset(size.width, size.height * 0.65),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _PassportPaperPainter oldDelegate) => false;
}

class _PassportCounter extends StatelessWidget {
  const _PassportCounter({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: GoogleFonts.fredoka(
            color: GeoColors.ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            color: const Color(0xFF75570D),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
