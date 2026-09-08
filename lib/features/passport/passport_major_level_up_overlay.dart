import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../passport/collections/passport_collection_item.dart';
import '../../passport/progression/passport_major_level_up.dart';
import '../design/geopoint_design.dart';

class PassportMajorLevelUpOverlay extends StatelessWidget {
  const PassportMajorLevelUpOverlay({
    required this.transition,
    required this.animationsEnabled,
    required this.onContinue,
    super.key,
  });

  final PassportMajorLevelUp transition;
  final bool animationsEnabled;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Widget card = _MajorLevelCard(
      transition: transition,
      onContinue: onContinue,
    );

    return ColoredBox(
      color: GeoColors.navy.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: animationsEnabled && !reduceMotion
              ? TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  tween: Tween<double>(begin: 0.82, end: 1),
                  builder: (
                    BuildContext context,
                    double value,
                    Widget? child,
                  ) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity:
                            ((value - 0.82) / 0.18).clamp(0, 1).toDouble(),
                        child: child,
                      ),
                    );
                  },
                  child: card,
                )
              : card,
        ),
      ),
    );
  }
}

class _MajorLevelCard extends StatelessWidget {
  const _MajorLevelCard({
    required this.transition,
    required this.onContinue,
  });

  final PassportMajorLevelUp transition;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFFBEC), Color(0xFFEAF4FF)],
        ),
        borderRadius: BorderRadius.circular(31),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: GeoColors.gold.withValues(alpha: 0.34),
              shape: BoxShape.circle,
              border: Border.all(color: GeoColors.gold, width: 2),
            ),
            child: const Icon(
              Icons.celebration_rounded,
              color: GeoColors.ink,
              size: 38,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            'NOUVEAU GRAND NIVEAU !',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ton activité dans PointGeo fait grandir ton aventure.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: <Widget>[
              Expanded(
                child: _LevelCard(
                  label: 'AVANT',
                  level: transition.previousLevel.displayTitle,
                  color: GeoColors.mutedInk,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: GeoColors.blue,
                  size: 25,
                ),
              ),
              Expanded(
                child: _LevelCard(
                  label: 'MAINTENANT',
                  level: transition.newLevel.displayTitle,
                  color: GeoColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'RÉCOMPENSES OBTENUES',
              style: GoogleFonts.fredoka(
                color: GeoColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: transition.rewards.length,
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(height: 7);
              },
              itemBuilder: (BuildContext context, int index) {
                return _RewardRow(item: transition.rewards[index]);
              },
            ),
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: GeoColors.blue.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: GeoColors.blue.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.flag_rounded,
                  color: GeoColors.blue,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'PROCHAIN OBJECTIF',
                        style: GoogleFonts.fredoka(
                          color: GeoColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transition.nextObjective,
                        style: GoogleFonts.nunitoSans(
                          color: GeoColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('CONTINUER'),
              style: FilledButton.styleFrom(
                backgroundColor: GeoColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: GoogleFonts.fredoka(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.label,
    required this.level,
    required this.color,
  });

  final String label;
  final String level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.fredoka(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            level,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.item});

  final PassportCollectionItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GeoColors.gold.withValues(alpha: 0.46)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: GeoColors.gold.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _categoryIcon(item.category),
              color: GeoColors.ink,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.category.label.toUpperCase(),
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.mutedInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(PassportCollectionCategory category) {
  switch (category) {
    case PassportCollectionCategory.emblem:
      return Icons.military_tech_rounded;
    case PassportCollectionCategory.title:
      return Icons.workspace_premium_rounded;
    case PassportCollectionCategory.avatar:
      return Icons.face_retouching_natural_rounded;
    case PassportCollectionCategory.passportFrame:
      return Icons.crop_square_rounded;
    case PassportCollectionCategory.passportBackground:
      return Icons.wallpaper_rounded;
    case PassportCollectionCategory.event:
      return Icons.auto_awesome_rounded;
  }
}
