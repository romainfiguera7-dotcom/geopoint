import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geo_engine/geo_country.dart';
import '../../geo_engine/geojson_loader.dart';
import '../expeditions/expeditions_screen.dart';
import '../passport/passport_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  GameController? _gameController;

  bool _isPreparingGame = false;
  bool _hasOpenedAdventure = false;

  Future<GameController> _getGameController() async {
    final GameController? existingController = _gameController;

    if (existingController != null) {
      return existingController;
    }

    final GameController controller = GameController();

    final List<GeoCountry> countries = await GeoJsonLoader.loadCountries();

    await controller.initialize(countries);

    _gameController = controller;

    return controller;
  }

  Future<void> _openAdventure() async {
    if (_isPreparingGame) {
      return;
    }

    setState(() {
      _isPreparingGame = true;
    });

    try {
      /*
       * On initialise le contrôleur avant d’ouvrir
       * les expéditions afin de charger le profil,
       * le Passeport et la progression sauvegardée.
       */
      await _getGameController();

      if (!mounted) {
        return;
      }

      setState(() {
        _hasOpenedAdventure = true;
      });

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return ExpeditionsScreen(controller: _gameController!);
          },
        ),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur pendant l’ouverture '
        'des expéditions : $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’ouvrir les expéditions.\n'
            '$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingGame = false;
        });
      }
    }
  }

  void _openPassport() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return PassportScreen(controller: _gameController);
        },
      ),
    );
  }

  void _openDiscovery() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Découverte du monde sera '
          'disponible prochainement.',
        ),
      ),
    );
  }

  void _openChildMode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Le mode enfant sera '
          'disponible prochainement.',
        ),
      ),
    );
  }

  Future<void> _openStatistics() async {
    if (_isPreparingGame) {
      return;
    }

    setState(() {
      _isPreparingGame = true;
    });

    try {
      final GameController controller = await _getGameController();

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return StatisticsScreen(controller: controller);
          },
        ),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur pendant l’ouverture '
        'des statistiques : $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’ouvrir les statistiques.\n'
            '$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingGame = false;
        });
      }
    }
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const SettingsScreen();
        },
      ),
    );
  }

  @override
  void dispose() {
    _gameController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GameController? controller = _gameController;

    final bool hasStarted =
        _hasOpenedAdventure || controller?.passport.hasStarted == true;

    final String adventureTitle = hasStarted
        ? 'CONTINUER L’AVENTURE'
        : 'COMMENCER L’AVENTURE';

    final String adventureSubtitle = hasStarted
        ? 'Reprends ton exploration'
        : 'Obtiens ton premier tampon';

    final int validatedStamps = controller?.passport.validatedStampCount ?? 0;

    final int totalStamps =
        controller?.passportEngine.stamps.values
            .where((stamp) => stamp.isEnabled)
            .length ??
        4;

    final double progress = totalStamps <= 0
        ? 0
        : validatedStamps / totalStamps;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _GameBackground()),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const _PlayerBadge(),

                          const Spacer(),

                          IconButton(
                            onPressed: _openSettings,
                            tooltip: 'Paramètres',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(46, 46),
                            ),
                            icon: const Icon(Icons.settings_outlined),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      const _GeoPointLogo(),

                      const SizedBox(height: 28),

                      _AdventureCard(
                        title: adventureTitle,
                        subtitle: adventureSubtitle,
                        progress: progress,
                        validatedStamps: validatedStamps,
                        totalStamps: totalStamps,
                        isLoading: _isPreparingGame,
                        hasStarted: hasStarted,
                        onPressed: _isPreparingGame ? null : _openAdventure,
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _GameModeCard(
                              icon: Icons.badge_outlined,
                              iconColor: const Color(0xFFFFC857),
                              title: 'Passeport',
                              subtitle: controller == null
                                  ? 'Ton aventure'
                                  : '$validatedStamps '
                                        'tampon(s)',
                              onPressed: _openPassport,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: _GameModeCard(
                              icon: Icons.travel_explore,
                              iconColor: const Color(0xFF57E389),
                              title: 'Découverte',
                              subtitle: 'Explore librement',
                              onPressed: _openDiscovery,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      _WideModeCard(
                        icon: Icons.query_stats_rounded,
                        title: 'Statistiques',
                        subtitle: 'Suis tes progrès par mode',
                        badgeText: 'NOUVEAU',
                        onPressed: _openStatistics,
                      ),

                      const SizedBox(height: 14),

                      _WideModeCard(
                        icon: Icons.child_care,
                        title: 'Mode enfant',
                        subtitle: 'Apprendre sans chronomètre',
                        badgeText: 'BIENTÔT',
                        onPressed: _openChildMode,
                      ),

                      const SizedBox(height: 22),

                      const _DailyChallengeCard(),

                      const SizedBox(height: 22),

                      Text(
                        'GEOPOINT • VERSION 1.0.0',
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
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
  }
}

class _GameBackground extends StatelessWidget {
  const _GameBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF071B3A),
            Color(0xFF0D3B78),
            Color(0xFF176BFF),
          ],
          stops: <double>[0, 0.60, 1],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 76,
            left: -50,
            child: _GlowCircle(size: 190, color: Color(0xFF28C2FF)),
          ),

          Positioned(
            right: -70,
            top: 250,
            child: _GlowCircle(size: 210, color: Color(0xFF57E389)),
          ),

          Positioned(
            left: 32,
            bottom: 120,
            child: Icon(Icons.location_on, size: 54, color: Colors.white24),
          ),

          Positioned(
            right: 32,
            top: 126,
            child: Transform.rotate(
              angle: 0.20,
              child: Icon(Icons.explore, size: 54, color: Colors.white24),
            ),
          ),

          Positioned(
            left: 24,
            top: 280,
            child: Text(
              '✦',
              style: TextStyle(color: Colors.white30, fontSize: 30),
            ),
          ),

          Positioned(
            right: 80,
            bottom: 250,
            child: Text(
              '✦',
              style: TextStyle(color: Colors.white30, fontSize: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.10),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 80,
            spreadRadius: 25,
          ),
        ],
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.explore, color: Color(0xFFFFC857), size: 21),
          const SizedBox(width: 7),
          Text(
            'VOYAGEUR',
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeoPointLogo extends StatelessWidget {
  const _GeoPointLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _GeoPointLogoMark(),

        const SizedBox(height: 17),

        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'GEO',
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 43,
                  fontWeight: FontWeight.w700,
                  height: 0.95,
                  letterSpacing: 1.2,
                  shadows: <Shadow>[
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
              Text(
                'POINT',
                style: GoogleFonts.fredoka(
                  color: const Color(0xFF53D8FF),
                  fontSize: 43,
                  fontWeight: FontWeight.w700,
                  height: 0.95,
                  letterSpacing: 1.2,
                  shadows: <Shadow>[
                    Shadow(
                      color: const Color(0xFF28C2FF).withValues(alpha: 0.38),
                      blurRadius: 16,
                    ),
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 9),

        Text(
          'EXPLORE • JOUE • APPRENDS',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunitoSans(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _GeoPointLogoMark extends StatelessWidget {
  const _GeoPointLogoMark();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 136,
          height: 136,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                const Color(0xFF28C2FF).withValues(alpha: 0.25),
                const Color(0xFF176BFF).withValues(alpha: 0.04),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF28C2FF).withValues(alpha: 0.28),
                blurRadius: 36,
                spreadRadius: 5,
              ),
            ],
          ),
        ),

        Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF38D4FF),
                Color(0xFF176BFF),
                Color(0xFF0A3A91),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.68),
              width: 3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: CustomPaint(painter: _GeoPointGlobePainter()),
          ),
        ),

        Positioned(
          right: -2,
          bottom: -1,
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFFF8A73), Color(0xFFFF4F64)],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFFF4F64).withValues(alpha: 0.44),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
        ),

        Positioned(
          left: -7,
          top: 12,
          child: Transform.rotate(
            angle: -0.18,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC857),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: Color(0xFF4A2B00),
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GeoPointGlobePainter extends CustomPainter {
  const _GeoPointGlobePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double radius = size.shortestSide / 2;

    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final Paint continentPaint = Paint()
      ..color = const Color(0xFF71EDA7).withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius - 2, linePaint);

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 0.92,
        height: radius * 1.90,
      ),
      linePaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 1.48,
        height: radius * 1.90,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 1.86,
        height: radius * 0.66,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.66)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 1.62,
        height: radius * 1.20,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final Path leftContinent = Path()
      ..moveTo(size.width * 0.18, size.height * 0.32)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.18,
        size.width * 0.42,
        size.height * 0.28,
      )
      ..quadraticBezierTo(
        size.width * 0.49,
        size.height * 0.38,
        size.width * 0.38,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.29,
        size.height * 0.51,
        size.width * 0.32,
        size.height * 0.64,
      )
      ..quadraticBezierTo(
        size.width * 0.27,
        size.height * 0.73,
        size.width * 0.20,
        size.height * 0.59,
      )
      ..quadraticBezierTo(
        size.width * 0.10,
        size.height * 0.47,
        size.width * 0.18,
        size.height * 0.32,
      )
      ..close();

    canvas.drawPath(leftContinent, continentPaint);

    final Path rightContinent = Path()
      ..moveTo(size.width * 0.54, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.13,
        size.width * 0.84,
        size.height * 0.30,
      )
      ..quadraticBezierTo(
        size.width * 0.91,
        size.height * 0.42,
        size.width * 0.75,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.67,
        size.height * 0.48,
        size.width * 0.70,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.77,
        size.width * 0.56,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.47,
        size.height * 0.54,
        size.width * 0.57,
        size.height * 0.43,
      )
      ..quadraticBezierTo(
        size.width * 0.46,
        size.height * 0.33,
        size.width * 0.54,
        size.height * 0.22,
      )
      ..close();

    canvas.drawPath(rightContinent, continentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _AdventureCard extends StatelessWidget {
  const _AdventureCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.validatedStamps,
    required this.totalStamps,
    required this.isLoading,
    required this.hasStarted,
    required this.onPressed,
  });

  final String title;
  final String subtitle;

  final double progress;
  final int validatedStamps;
  final int totalStamps;

  final bool isLoading;
  final bool hasStarted;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFFFD166), Color(0xFFFF8A4C)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFF8A4C).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(17),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            hasStarted
                                ? Icons.play_arrow_rounded
                                : Icons.explore_rounded,
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
                          isLoading ? 'CHARGEMENT...' : title,
                          style: GoogleFonts.fredoka(
                            color: const Color(0xFF392108),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: GoogleFonts.nunitoSans(
                            color: const Color(
                              0xFF392108,
                            ).withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF392108),
                    size: 32,
                  ),
                ],
              ),

              const SizedBox(height: 17),

              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9,
                        backgroundColor: Colors.white.withValues(alpha: 0.28),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Text(
                    '$validatedStamps / '
                    '$totalStamps tampons',
                    style: GoogleFonts.nunitoSans(
                      color: const Color(0xFF392108),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameModeCard extends StatelessWidget {
  const _GameModeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),

              const Spacer(),

              Text(
                title,
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideModeCard extends StatelessWidget {
  const _WideModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFB983FF), Color(0xFFFF6BCE)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 29),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFFFFC857),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
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

class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071B3A).withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Color(0xFFFF6B6B),
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'DÉFI DU JOUR',
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFFFF6B6B),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Trouve 10 pays '
                  'sans erreur',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'Disponible prochainement',
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white.withValues(alpha: 0.53),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.45)),
        ],
      ),
    );
  }
}
