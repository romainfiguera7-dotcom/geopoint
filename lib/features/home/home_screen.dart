import 'dart:async';
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geo_engine/geo_country.dart';
import '../../geo_engine/geojson_loader.dart';
import '../atlas/atlas_hub_screen.dart';
import '../design/geopoint_design.dart';
import '../passport/passport_hub_screen.dart';
import '../play/play_hub_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameController? _gameController;
  Future<GameController>? _controllerFuture;
  bool _isPreparing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_preloadPlayer());
  }

  Future<void> _preloadPlayer() async {
    try {
      await _getGameController();

      if (mounted) {
        setState(() {});
      }
    } catch (error, stackTrace) {
      debugPrint('Préchargement du profil impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<GameController> _getGameController() async {
    final GameController? existing = _gameController;

    if (existing != null) {
      return existing;
    }

    final Future<GameController> future =
        _controllerFuture ??= _createGameController();

    try {
      return await future;
    } catch (_) {
      _controllerFuture = null;
      rethrow;
    }
  }

  Future<GameController> _createGameController() async {
    final GameController controller = GameController();
    final List<GeoCountry> countries = await GeoJsonLoader.loadCountries();

    await controller.initialize(countries);
    _gameController = controller;

    return controller;
  }

  Future<void> _openDestination({
    required String destinationName,
    required Widget Function(GameController controller) builder,
  }) async {
    if (_isPreparing) {
      return;
    }

    setState(() {
      _isPreparing = true;
    });

    try {
      final GameController controller = await _getGameController();

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => builder(controller),
        ),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (error, stackTrace) {
      debugPrint('Erreur pendant l’ouverture de $destinationName : $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible d’ouvrir $destinationName.\n$error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _openPlay() {
    return _openDestination(
      destinationName: 'Jouer',
      builder: (GameController controller) {
        return PlayHubScreen(controller: controller);
      },
    );
  }

  Future<void> _openAtlas() {
    return _openDestination(
      destinationName: 'l’Atlas',
      builder: (GameController controller) {
        return AtlasHubScreen(controller: controller);
      },
    );
  }

  Future<void> _openPassport() {
    return _openDestination(
      destinationName: 'le Passeport',
      builder: (GameController controller) {
        return PassportHubScreen(controller: controller);
      },
    );
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SettingsScreen(),
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
    final int stampCount = controller?.passport.validatedStampCount ?? 0;
    final int gameCount = controller?.passport.totalAttempts ?? 0;
    final String playerName = controller?.passport.displayName ?? 'Voyageur';

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: AbsorbPointer(
              absorbing: _isPreparing,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                    children: <Widget>[
                      _HomeTopBar(
                        playerName: playerName,
                        onSettings: _openSettings,
                      ),
                      const SizedBox(height: 25),
                      const _CompactLogo(),
                      const SizedBox(height: 19),
                      _PlayerSummary(
                        stampCount: stampCount,
                        gameCount: gameCount,
                      ),
                      const SizedBox(height: 22),
                      _PlayCard(onPressed: _openPlay),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _HomeDestinationCard(
                              icon: Icons.map_rounded,
                              title: 'ATLAS',
                              subtitle: 'Explore le monde',
                              color: GeoColors.mint,
                              onPressed: _openAtlas,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: _HomeDestinationCard(
                              icon: Icons.menu_book_rounded,
                              title: 'MON PASSEPORT',
                              subtitle: 'Ta collection',
                              color: GeoColors.purple,
                              onPressed: _openPassport,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'GEOPOINT • EXPLORE, JOUE, APPRENDS',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isPreparing)
            Positioned.fill(
              child: ColoredBox(
                color: GeoColors.navy.withValues(alpha: 0.70),
                child: const Center(child: _LoadingCard()),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.playerName,
    required this.onSettings,
  });

  final String playerName;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(7, 6, 13, 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const GeoCompassLogo(size: 35, showShadow: false),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GeoRoundAction(
          icon: Icons.settings_rounded,
          tooltip: 'Paramètres',
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _CompactLogo extends StatelessWidget {
  const _CompactLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const GeoCompassLogo(size: 92),
        const SizedBox(height: 13),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RichText(
            text: TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: 'GEO',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                TextSpan(
                  text: 'POINT',
                  style: GoogleFonts.fredoka(
                    color: GeoColors.sky,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerSummary extends StatelessWidget {
  const _PlayerSummary({
    required this.stampCount,
    required this.gameCount,
  });

  final int stampCount;
  final int gameCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _SummaryPill(
          icon: Icons.approval_rounded,
          value: '$stampCount',
          label: 'tampons',
          color: GeoColors.gold,
        ),
        const SizedBox(width: 9),
        _SummaryPill(
          icon: Icons.sports_esports_rounded,
          value: '$gameCount',
          label: 'parties',
          color: GeoColors.mint,
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: GoogleFonts.nunitoSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayCard extends StatefulWidget {
  const _PlayCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PlayCard> createState() => _PlayCardState();
}

class _PlayCardState extends State<_PlayCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (bool value) {
            setState(() {
              _isPressed = value;
            });
          },
          borderRadius: BorderRadius.circular(29),
          child: Ink(
            height: 174,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFFFD96A), Color(0xFFFFBE3D)],
              ),
              borderRadius: BorderRadius.circular(29),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.76),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: _isPressed ? 9 : 15,
                  offset: Offset(0, _isPressed ? 4 : 8),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _HomeRoutePainter()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(23),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'JOUER',
                        style: GoogleFonts.fredoka(
                          color: GeoColors.navy,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        width: 235,
                        child: Text(
                          'Expéditions, défis, entraînement et modes spéciaux',
                          style: GoogleFonts.nunitoSans(
                            color: const Color(0xFF674400),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: GeoColors.navy,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 25,
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
    );
  }
}

class _HomeDestinationCard extends StatefulWidget {
  const _HomeDestinationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_HomeDestinationCard> createState() =>
      _HomeDestinationCardState();
}

class _HomeDestinationCardState extends State<_HomeDestinationCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        ThemeData.estimateBrightnessForColor(widget.color) == Brightness.dark
            ? Colors.white
            : GeoColors.navy;

    return AnimatedScale(
      scale: _isPressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (bool value) {
            setState(() {
              _isPressed = value;
            });
          },
          borderRadius: BorderRadius.circular(25),
          child: Ink(
            height: 157,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: 0.14),
                    widget.color,
                  ),
                  widget.color,
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: _isPressed ? 8 : 14,
                  offset: Offset(0, _isPressed ? 3 : 7),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: 10,
                  bottom: 6,
                  child: Container(
                    width: 83,
                    height: 83,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: GeoCardArtwork(
                      primary: widget.icon,
                      secondary: widget.title == 'ATLAS'
                          ? Icons.location_on_rounded
                          : Icons.approval_rounded,
                      color: foreground.withValues(alpha: 0.90),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.fredoka(
                                color: foreground,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 31,
                            height: 31,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_outward_rounded,
                              color: foreground,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 94,
                        child: Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                            color: foreground.withValues(alpha: 0.70),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
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

class _HomeRoutePainter extends CustomPainter {
  const _HomeRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint contourPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int index = 0; index < 4; index++) {
      canvas.drawOval(
        Rect.fromLTWH(
          size.width * (0.46 + index * 0.05),
          size.height * (0.07 + index * 0.06),
          size.width * (0.52 - index * 0.06),
          size.height * (0.72 - index * 0.08),
        ),
        contourPaint,
      );
    }

    final Path route = Path()
      ..moveTo(size.width * 0.58, size.height * 0.73)
      ..cubicTo(
        size.width * 0.69,
        size.height * 0.52,
        size.width * 0.76,
        size.height * 0.82,
        size.width * 0.88,
        size.height * 0.36,
      );
    final Paint routePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;

    for (final PathMetric metric in route.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final Tangent? tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 2.6, routePaint);
        }
        distance += 13;
      }
    }

    final Offset destination = Offset(size.width * 0.88, size.height * 0.34);
    canvas.drawCircle(destination, 7, Paint()..color = Colors.white);
    canvas.drawCircle(destination, 4, Paint()..color = GeoColors.coral);
  }

  @override
  bool shouldRepaint(covariant _HomeRoutePainter oldDelegate) => false;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 21),
      decoration: BoxDecoration(
        color: GeoColors.cream,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: GeoColors.blue,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Préparation du voyage…',
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
