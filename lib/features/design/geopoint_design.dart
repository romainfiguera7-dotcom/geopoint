import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class GeoColors {
  static const Color navy = Color(0xFF071B3A);
  static const Color deepBlue = Color(0xFF0D3B78);
  static const Color blue = Color(0xFF2477FF);
  static const Color sky = Color(0xFF5AD7FF);
  static const Color mint = Color(0xFF55D6A6);
  static const Color gold = Color(0xFFFFCE59);
  static const Color coral = Color(0xFFFF756B);
  static const Color purple = Color(0xFFA985F8);
  static const Color cream = Color(0xFFFFF8E8);
  static const Color ink = Color(0xFF102A4C);
  static const Color surface = Color(0xFFF8FAFE);
  static const Color mutedInk = Color(0xFF5E7390);
}

class GeoAdventureBackground extends StatelessWidget {
  const GeoAdventureBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            GeoColors.navy,
            GeoColors.deepBlue,
            Color(0xFF155BC2),
          ],
          stops: <double>[0, 0.58, 1],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _AdventureRoutePainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class GeoCompassLogo extends StatelessWidget {
  const GeoCompassLogo({
    this.size = 88,
    this.showShadow = true,
    super.key,
  });

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: showShadow
              ? <BoxShadow>[
                  BoxShadow(
                    color: GeoColors.blue.withValues(alpha: 0.28),
                    blurRadius: size * 0.24,
                    offset: Offset(0, size * 0.08),
                  ),
                ]
              : null,
        ),
        child: CustomPaint(
          painter: const _GeoCompassLogoPainter(),
        ),
      ),
    );
  }
}

class _GeoCompassLogoPainter extends CustomPainter {
  const _GeoCompassLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      radius * 0.98,
      Paint()..color = GeoColors.gold,
    );
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()..color = const Color(0xFF073D91),
    );
    canvas.drawCircle(
      center,
      radius * 0.80,
      Paint()..color = const Color(0xFF1166D8),
    );
    canvas.drawCircle(
      center,
      radius * 0.69,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.025,
    );

    final Paint routeDot = Paint()..color = Colors.white;
    const int dotCount = 17;
    const double startAngle = math.pi * 0.30;
    const double sweep = math.pi * 1.55;
    for (int index = 0; index < dotCount; index++) {
      final double angle = startAngle + sweep * index / (dotCount - 1);
      final Offset point = Offset(
        center.dx + math.cos(angle) * radius * 0.56,
        center.dy + math.sin(angle) * radius * 0.56,
      );
      canvas.drawCircle(point, radius * 0.055, routeDot);
    }
    for (int index = 0; index < 4; index++) {
      canvas.drawCircle(
        Offset(
          center.dx + radius * (0.54 - index * 0.12),
          center.dy + radius * 0.10,
        ),
        radius * 0.055,
        routeDot,
      );
    }
    canvas.drawCircle(
      Offset(center.dx + radius * 0.18, center.dy + radius * 0.22),
      radius * 0.055,
      routeDot,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.18, center.dy + radius * 0.34),
      radius * 0.055,
      routeDot,
    );

    final Path needle = Path()
      ..moveTo(center.dx - radius * 0.29, center.dy + radius * 0.33)
      ..lineTo(center.dx - radius * 0.07, center.dy - radius * 0.08)
      ..lineTo(center.dx + radius * 0.32, center.dy - radius * 0.30)
      ..lineTo(center.dx + radius * 0.09, center.dy + radius * 0.10)
      ..close();
    canvas.drawPath(needle, Paint()..color = const Color(0xFFFFBF2F));
    canvas.drawCircle(
      center,
      radius * 0.10,
      Paint()..color = GeoColors.navy,
    );

    final Offset destination = Offset(
      center.dx + radius * 0.52,
      center.dy - radius * 0.47,
    );
    canvas.drawCircle(
      destination,
      radius * 0.16,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      destination,
      radius * 0.09,
      Paint()..color = const Color(0xFFF05B45),
    );
  }

  @override
  bool shouldRepaint(covariant _GeoCompassLogoPainter oldDelegate) => false;
}

class GeoGameTopBar extends StatelessWidget {
  const GeoGameTopBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (onBack != null)
          _RoundButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Retour',
            onPressed: onBack!,
          ),
        if (onBack != null) const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class GeoRoundAction extends StatelessWidget {
  const GeoRoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _RoundButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class GeoSectionHeading extends StatelessWidget {
  const GeoSectionHeading({
    required this.eyebrow,
    required this.title,
    this.description,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (eyebrow.isNotEmpty) ...<Widget>[
          Text(
            eyebrow.toUpperCase(),
            style: GoogleFonts.nunitoSans(
              color: GeoColors.gold,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Text(
          title,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.08,
          ),
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 7),
          Text(
            description!,
            style: GoogleFonts.nunitoSans(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class GeoCardArtwork extends StatelessWidget {
  const GeoCardArtwork({
    required this.primary,
    required this.secondary,
    required this.color,
    super.key,
  });

  final IconData primary;
  final IconData secondary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: 5,
            bottom: 6,
            child: Icon(primary, color: color, size: 47),
          ),
          Positioned(
            right: 2,
            top: 3,
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.70),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.20)),
              ),
              child: Icon(secondary, color: color, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class GeoFeatureCard extends StatefulWidget {
  const GeoFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onPressed,
    this.badge,
    this.large = false,
    this.artwork,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onPressed;
  final String? badge;
  final bool large;
  final Widget? artwork;

  @override
  State<GeoFeatureCard> createState() => _GeoFeatureCardState();
}

class _GeoFeatureCardState extends State<GeoFeatureCard> {
  bool _isPressed = false;

  Widget _title(Color foreground) {
    final bool compactSingleLine =
        !widget.title.contains(' ') && widget.title.length > 10;

    if (compactSingleLine) {
      return SizedBox(
        height: widget.large ? 34 : 25,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.title,
            maxLines: 1,
            style: GoogleFonts.fredoka(
              color: foreground,
              fontSize: widget.large ? 25 : 19,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      );
    }

    return Text(
      widget.title,
      maxLines: 2,
      overflow: TextOverflow.fade,
      style: GoogleFonts.fredoka(
        color: foreground,
        fontSize: widget.large ? 25 : 19,
        fontWeight: FontWeight.w700,
        height: 1.02,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color foreground =
        ThemeData.estimateBrightnessForColor(widget.color) == Brightness.dark
            ? Colors.white
            : GeoColors.navy;
    final Color secondary = foreground.withValues(alpha: 0.70);

    return AnimatedScale(
      scale: _isPressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: enabled
              ? (bool value) {
                  setState(() {
                    _isPressed = value;
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(25),
          child: Ink(
            height: widget.large ? 225 : null,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: 0.16),
                    widget.color,
                  ),
                  widget.color,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
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
                if (widget.large)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _FeatureRoutePainter(
                          color: foreground,
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 7,
                    bottom: 5,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: widget.artwork ??
                            Icon(
                              widget.icon,
                              color: foreground.withValues(alpha: 0.88),
                              size: 49,
                            ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: widget.badge != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.34),
                            ),
                          ),
                          child: Text(
                            widget.badge!.toUpperCase(),
                            style: GoogleFonts.nunitoSans(
                              color: foreground,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      : Container(
                          width: 31,
                          height: 31,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            enabled
                                ? Icons.arrow_outward_rounded
                                : Icons.lock_outline_rounded,
                            color: enabled ? foreground : secondary,
                            size: 19,
                          ),
                        ),
                ),
                Padding(
                  padding: EdgeInsets.all(widget.large ? 19 : 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (widget.badge != null && !widget.large)
                        const SizedBox(height: 32),
                      Padding(
                        padding: EdgeInsets.only(
                          right: widget.badge == null && !widget.large ? 34 : 0,
                        ),
                        child: _title(foreground),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        width: widget.large ? 230 : 120,
                        child: Text(
                          widget.subtitle,
                          maxLines: widget.large ? 3 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                            color: secondary,
                            fontSize: widget.large ? 13 : 11.5,
                            fontWeight: FontWeight.w800,
                            height: 1.24,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: foreground.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(99),
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

class _FeatureRoutePainter extends CustomPainter {
  const _FeatureRoutePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.78)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.91,
        size.width * 0.48,
        size.height * 0.55,
        size.width * 0.62,
        size.height * 0.71,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.82,
        size.width * 0.80,
        size.height * 0.55,
        size.width * 0.87,
        size.height * 0.38,
      );

    final Paint dotPaint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final Tangent? tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 3, dotPaint);
        }
        distance += 13;
      }
    }

    final Paint ringPaint = Paint()
      ..color = color.withValues(alpha: 0.94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.78),
      12,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.71),
      9,
      ringPaint,
    );

    final double poleX = size.width * 0.87;
    final double poleY = size.height * 0.20;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(poleX, poleY, 5, size.height * 0.24),
        const Radius.circular(3),
      ),
      Paint()..color = GeoColors.navy,
    );
    final Path flag = Path()
      ..moveTo(poleX + 5, poleY + 2)
      ..lineTo(poleX + 39, poleY + 10)
      ..lineTo(poleX + 5, poleY + 25)
      ..close();
    canvas.drawPath(flag, Paint()..color = GeoColors.coral);
  }

  @override
  bool shouldRepaint(covariant _FeatureRoutePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class GeoPill extends StatelessWidget {
  const GeoPill({
    required this.text,
    required this.color,
    super.key,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.nunitoSans(
          color: GeoColors.ink,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

void showGeoComingSoon(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  required Color color,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: GeoColors.cream,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: GeoColors.navy, size: 35),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: GeoColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  color: const Color(0xFF58708D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: GeoColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'J’ai compris',
                    style: GoogleFonts.nunitoSans(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        minimumSize: const Size(46, 46),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      icon: Icon(icon),
    );
  }
}

class _AdventureRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint contourPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int index = 0; index < 7; index++) {
      final double inset = 18.0 + index * 33;
      final Rect contourRect = Rect.fromLTWH(
        -size.width * 0.24 + inset,
        size.height * 0.10 + inset * 0.7,
        size.width * 0.92 - inset,
        size.height * 0.58 - inset * 0.6,
      );
      canvas.drawOval(contourRect, contourPaint);
    }

    final Paint routePaint = Paint()
      ..color = GeoColors.blue.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;

    final Path route = Path()
      ..moveTo(size.width * 0.05, size.height * 0.72)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.56,
        size.width * 0.32,
        size.height * 0.83,
        size.width * 0.53,
        size.height * 0.61,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.42,
        size.width * 0.78,
        size.height * 0.62,
        size.width * 0.96,
        size.height * 0.38,
      );

    for (final PathMetric metric in route.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final Tangent? tangent = metric.getTangentForOffset(distance);

        if (tangent != null) {
          canvas.drawCircle(tangent.position, 2.0, routePaint);
        }

        distance += 15;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AdventureRoutePainter oldDelegate) => false;
}
