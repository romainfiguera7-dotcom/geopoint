import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../geo_engine/geo_country.dart';
import '../../passport/progress/passport_entity_progress.dart';
import '../../passport/progress/passport_progress_rules.dart';
import '../design/geopoint_design.dart';

class PassportCountryStampView extends StatelessWidget {
  const PassportCountryStampView({
    required this.country,
    required this.progress,
    this.size = 112,
    this.showStageLabel = true,
    super.key,
  });

  final GeoCountry country;
  final PassportEntityProgress progress;
  final double size;
  final bool showStageLabel;

  @override
  Widget build(BuildContext context) {
    final PassportCountryStampStage stage = progress.stampStage;
    final bool isLocked = stage == PassportCountryStampStage.locked;
    final _StampPalette palette = _paletteForStage(stage);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _CountryStampPainter(
                palette: palette,
                isTerritory: country.isTerritory,
                stage: stage,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size * 0.18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (isLocked)
                  Icon(
                    Icons.lock_rounded,
                    color: palette.foreground,
                    size: size * 0.25,
                  )
                else
                  Text(
                    country.flagEmoji.isEmpty ? '🌍' : country.flagEmoji,
                    style: TextStyle(fontSize: size * 0.25),
                  ),
                SizedBox(height: size * 0.015),
                Text(
                  country.id.toUpperCase(),
                  maxLines: 1,
                  style: GoogleFonts.fredoka(
                    color: palette.foreground,
                    fontSize: size * 0.105,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    height: 1,
                  ),
                ),
                if (showStageLabel) ...<Widget>[
                  SizedBox(height: size * 0.025),
                  Text(
                    passportStampStageLabel(stage).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      color: palette.foreground.withValues(alpha: 0.78),
                      fontSize: size * 0.054,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (country.isTerritory)
            Positioned(
              top: size * 0.12,
              right: size * 0.13,
              child: Container(
                width: size * 0.19,
                height: size * 0.19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.foreground.withValues(alpha: 0.55),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.outlined_flag_rounded,
                  color: GeoColors.ink,
                  size: size * 0.115,
                ),
              ),
            ),
          if (stage == PassportCountryStampStage.mastered)
            Positioned(
              left: size * 0.10,
              top: size * 0.11,
              child: Icon(
                Icons.star_rounded,
                color: palette.accent,
                size: size * 0.23,
              ),
            ),
        ],
      ),
    );
  }
}

class PassportStampUnlockOverlay extends StatelessWidget {
  const PassportStampUnlockOverlay({
    required this.country,
    required this.progress,
    super.key,
  });

  final GeoCountry country;
  final PassportEntityProgress progress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.54),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.45, end: 1),
          duration: const Duration(milliseconds: 620),
          curve: Curves.elasticOut,
          builder: (BuildContext context, double value, Widget? child) {
            return Transform.rotate(
              angle: (1 - value) * -0.18,
              child: Transform.scale(scale: value, child: child),
            );
          },
          child: Container(
            width: 250,
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 19),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FC),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: GeoColors.blue.withValues(alpha: 0.32),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'NOUVEAU TAMPON !',
                  style: GoogleFonts.fredoka(
                    color: GeoColors.blue,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                PassportCountryStampView(
                  country: country,
                  progress: progress,
                  size: 142,
                ),
                const SizedBox(height: 6),
                Text(
                  country.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  country.isTerritory
                      ? 'Tampon-territoire débloqué'
                      : 'Tampon-pays débloqué',
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.mutedInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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

String passportStampStageLabel(PassportCountryStampStage stage) {
  switch (stage) {
    case PassportCountryStampStage.locked:
      return 'Verrouillé';
    case PassportCountryStampStage.discovered:
      return 'Découvert';
    case PassportCountryStampStage.learned:
      return 'Appris';
    case PassportCountryStampStage.mastered:
      return 'Maîtrisé';
  }
}

class _CountryStampPainter extends CustomPainter {
  const _CountryStampPainter({
    required this.palette,
    required this.isTerritory,
    required this.stage,
  });

  final _StampPalette palette;
  final bool isTerritory;
  final PassportCountryStampStage stage;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide * 0.47;
    final Path shape = isTerritory
        ? _territoryPath(center, radius)
        : (Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    canvas.drawShadow(shape, Colors.black.withValues(alpha: 0.24), 5, true);
    canvas.drawPath(shape, Paint()..color = palette.background);
    canvas.drawPath(
      shape,
      Paint()
        ..color = palette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.045,
    );

    final double innerRadius = radius * 0.79;
    final Path innerShape = isTerritory
        ? _territoryPath(center, innerRadius)
        : (Path()
          ..addOval(Rect.fromCircle(center: center, radius: innerRadius)));

    canvas.drawPath(
      innerShape,
      Paint()
        ..color = palette.foreground.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.015,
    );

    final Paint dotPaint = Paint()..color = palette.accent;
    final int dotCount = isTerritory ? 12 : 16;

    for (int index = 0; index < dotCount; index++) {
      final double angle = math.pi * 2 * index / dotCount;
      final Offset dot = Offset(
        center.dx + math.cos(angle) * radius * 0.67,
        center.dy + math.sin(angle) * radius * 0.67,
      );
      canvas.drawCircle(dot, size.shortestSide * 0.014, dotPaint);
    }

    if (stage == PassportCountryStampStage.locked) {
      canvas.drawPath(
        shape,
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
    }
  }

  Path _territoryPath(Offset center, double radius) {
    const int sides = 12;
    final Path path = Path();

    for (int index = 0; index < sides; index++) {
      final double angle = -math.pi / 2 + math.pi * 2 * index / sides;
      final double pointRadius = index.isEven ? radius : radius * 0.91;
      final Offset point = Offset(
        center.dx + math.cos(angle) * pointRadius,
        center.dy + math.sin(angle) * pointRadius,
      );

      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    return path..close();
  }

  @override
  bool shouldRepaint(covariant _CountryStampPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.isTerritory != isTerritory ||
        oldDelegate.stage != stage;
  }
}

class _StampPalette {
  const _StampPalette({
    required this.background,
    required this.border,
    required this.foreground,
    required this.accent,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color accent;
}

_StampPalette _paletteForStage(PassportCountryStampStage stage) {
  switch (stage) {
    case PassportCountryStampStage.locked:
      return const _StampPalette(
        background: Color(0xFFDDE4EC),
        border: Color(0xFF9AA9BA),
        foreground: Color(0xFF66788D),
        accent: Color(0xFFB9C4D0),
      );
    case PassportCountryStampStage.discovered:
      return const _StampPalette(
        background: Color(0xFFDCEEFF),
        border: GeoColors.blue,
        foreground: GeoColors.deepBlue,
        accent: GeoColors.sky,
      );
    case PassportCountryStampStage.learned:
      return const _StampPalette(
        background: Color(0xFFEDE4FF),
        border: GeoColors.purple,
        foreground: Color(0xFF56339F),
        accent: GeoColors.gold,
      );
    case PassportCountryStampStage.mastered:
      return const _StampPalette(
        background: Color(0xFFDDF8EE),
        border: Color(0xFF16815D),
        foreground: Color(0xFF0C6245),
        accent: GeoColors.gold,
      );
  }
}
