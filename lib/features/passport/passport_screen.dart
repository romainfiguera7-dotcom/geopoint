import 'package:flutter/material.dart';

import '../../game/game_controller.dart';
import '../../game/passport/passport_license.dart';
import '../../game/passport/passport_stamp.dart';
import '../../game/passport/player_passport.dart';
import '../../game/passport/player_stamp_progress.dart';

class PassportScreen extends StatelessWidget {
  const PassportScreen({
    required this.controller,
    super.key,
  });

  final GameController? controller;

  @override
  Widget build(BuildContext context) {
    final GameController? gameController =
        controller;

    if (gameController == null) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text('Passeport'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: <Widget>[
                Text(
                  '🪪',
                  style:
                      TextStyle(fontSize: 74),
                ),
                SizedBox(height: 18),
                Text(
                  'Ton Passeport est vide',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Termine une première partie '
                  'pour obtenir ton premier tampon.',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final PlayerPassport passport =
        gameController.passport;

    final PassportLicense? currentLicense =
        gameController.passportEngine
            .licenseById(
      passport.currentLicenseId,
    );

    final List<PassportStamp> stamps =
        gameController.passportEngine
            .stamps.values
            .where(
              (PassportStamp stamp) =>
                  stamp.isEnabled,
            )
            .toList(
              growable: false,
            );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Passeport',
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(18),
        child: Center(
          child: Container(
            constraints:
                const BoxConstraints(
              maxWidth: 560,
            ),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF123B73),
              borderRadius:
                  BorderRadius.circular(26),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black
                      .withValues(
                    alpha: 0.24,
                  ),
                  blurRadius: 20,
                  offset:
                      const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(22),
              child: Column(
                children: <Widget>[
                  const Text(
                    '🪪',
                    style:
                        TextStyle(fontSize: 54),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'PASSEPORT GEOPOINT',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 22),

                  _PassportIdentity(
                    passport: passport,
                    license: currentLicense,
                  ),

                  const SizedBox(height: 24),

                  Align(
                    alignment:
                        Alignment.centerLeft,
                    child: Text(
                      'TAMPONS',
                      style: TextStyle(
                        color: Colors.white
                            .withValues(
                          alpha: 0.75,
                        ),
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount: stamps.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemBuilder: (
                      BuildContext context,
                      int index,
                    ) {
                      final PassportStamp stamp =
                          stamps[index];

                      final PlayerStampProgress
                          progress =
                          passport.progressFor(
                        stamp.id,
                      );

                      return _StampCard(
                        stamp: stamp,
                        progress: progress,
                      );
                    },
                  ),

                  const SizedBox(height: 22),

                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _PassportStat(
                          label: 'PARTIES',
                          value:
                              '${passport.totalAttempts}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PassportStat(
                          label: 'TAMPONS',
                          value:
                              '${passport.validatedStampCount}'
                              ' / ${stamps.length}',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Membre depuis le '
                    '${_formatDate(passport.createdAt)}',
                    style: TextStyle(
                      color: Colors.white
                          .withValues(
                        alpha: 0.58,
                      ),
                      fontSize: 12,
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

  static String _formatDate(
    DateTime date,
  ) {
    final String day =
        date.day.toString().padLeft(
              2,
              '0',
            );

    final String month =
        date.month.toString().padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year}';
  }
}

class _PassportIdentity
    extends StatelessWidget {
  const _PassportIdentity({
    required this.passport,
    required this.license,
  });

  final PlayerPassport passport;
  final PassportLicense? license;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 32,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  passport.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Licence : '
                  '${license?.title ?? 'Débutant'}',
                  style: const TextStyle(
                    color:
                        Color(0xFFFFD166),
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
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

class _StampCard extends StatelessWidget {
  const _StampCard({
    required this.stamp,
    required this.progress,
  });

  final PassportStamp stamp;
  final PlayerStampProgress progress;

  @override
  Widget build(BuildContext context) {
    final PassportMedal medal =
        progress.medal;

    final Color medalColor =
        _medalColor(medal);

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: medalColor.withValues(
            alpha: medal.isValidated
                ? 0.90
                : 0.25,
          ),
          width: medal.isValidated
              ? 2
              : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: medalColor,
                width: 3,
              ),
              color: medalColor.withValues(
                alpha: 0.13,
              ),
            ),
            child: Icon(
              _stampIcon(stamp.iconName),
              color: medalColor,
              size: 30,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            stamp.name,
            textAlign:
                TextAlign.center,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            medal.label,
            style: TextStyle(
              color: medalColor,
              fontSize: 13,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            progress.hasPlayed
                ? '${progress.bestScore} pts'
                : 'Pas encore joué',
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.60,
              ),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static Color _medalColor(
    PassportMedal medal,
  ) {
    switch (medal) {
      case PassportMedal.none:
        return const Color(0xFFB0BEC5);

      case PassportMedal.bronze:
        return const Color(0xFFCD7F32);

      case PassportMedal.silver:
        return const Color(0xFFC0C0C0);

      case PassportMedal.gold:
        return const Color(0xFFFFD700);
    }
  }

  static IconData _stampIcon(
    String iconName,
  ) {
    switch (iconName) {
      case 'location_city':
        return Icons.location_city;

      case 'flag':
        return Icons.flag;

      case 'shuffle':
        return Icons.shuffle;

      case 'public':
      default:
        return Icons.public;
    }
  }
}

class _PassportStat extends StatelessWidget {
  const _PassportStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.09,
        ),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white
                  .withValues(
                alpha: 0.58,
              ),
              fontSize: 10,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}