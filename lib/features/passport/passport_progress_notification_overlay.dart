import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../passport/notifications/passport_progress_notification.dart';
import '../design/geopoint_design.dart';

class PassportProgressNotificationOverlay extends StatelessWidget {
  const PassportProgressNotificationOverlay({
    required this.batch,
    required this.onContinue,
    super.key,
  });

  final PassportProgressNotificationBatch batch;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: GeoColors.navy.withValues(alpha: 0.88),
      child: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            tween: Tween<double>(begin: 0.82, end: 1),
            builder: (BuildContext context, double value, Widget? child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0, 1).toDouble(),
                  child: child,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.sizeOf(context).height * 0.84,
              ),
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FF),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: GeoColors.gold.withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: GeoColors.ink,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'BELLE PROGRESSION !',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(
                      color: GeoColors.ink,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    batch.items.length == 1
                        ? 'Une nouveauté rejoint ton Passeport.'
                        : '${batch.items.length} nouveautés réunies dans ton Passeport.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 17),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: batch.items.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 9);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return _ProgressNotificationRow(
                          item: batch.items[index],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 17),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onContinue,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('VOIR MES RÉSULTATS'),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressNotificationRow extends StatelessWidget {
  const _ProgressNotificationRow({required this.item});

  final PassportProgressNotification item;

  @override
  Widget build(BuildContext context) {
    final Color color = _notificationColor(item.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _notificationIcon(item.type),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title.toUpperCase(),
                  style: GoogleFonts.nunitoSans(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 16,
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

Color _notificationColor(PassportProgressNotificationType type) {
  switch (type) {
    case PassportProgressNotificationType.stamp:
      return GeoColors.blue;
    case PassportProgressNotificationType.mastery:
      return const Color(0xFF18A879);
    case PassportProgressNotificationType.level:
      return GeoColors.gold;
    case PassportProgressNotificationType.title:
      return GeoColors.purple;
    case PassportProgressNotificationType.collection:
      return GeoColors.coral;
    case PassportProgressNotificationType.achievement:
      return const Color(0xFFDD7B14);
  }
}

IconData _notificationIcon(PassportProgressNotificationType type) {
  switch (type) {
    case PassportProgressNotificationType.stamp:
      return Icons.approval_rounded;
    case PassportProgressNotificationType.mastery:
      return Icons.school_rounded;
    case PassportProgressNotificationType.level:
      return Icons.trending_up_rounded;
    case PassportProgressNotificationType.title:
      return Icons.workspace_premium_rounded;
    case PassportProgressNotificationType.collection:
      return Icons.redeem_rounded;
    case PassportProgressNotificationType.achievement:
      return Icons.emoji_events_rounded;
  }
}
