import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/geopoint_design.dart';
import 'france_expedition_catalog.dart';
import 'france_exploration_game_screen.dart';
import 'national_expedition_progress.dart';
import 'national_expedition_storage.dart';

class FranceExpeditionScreen extends StatefulWidget {
  const FranceExpeditionScreen({super.key});

  @override
  State<FranceExpeditionScreen> createState() => _FranceExpeditionScreenState();
}

class _FranceExpeditionScreenState extends State<FranceExpeditionScreen> {
  late Future<NationalExpeditionProgress> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = NationalExpeditionStorage.load();
  }

  void _reload() {
    setState(() {
      _progressFuture = NationalExpeditionStorage.load();
    });
  }

  Future<void> _openLevel(
    FranceExpeditionLevel level,
    NationalExpeditionProgress progress,
  ) async {
    final FranceExplorationGameResult? result =
        await Navigator.of(context).push<FranceExplorationGameResult>(
      MaterialPageRoute<FranceExplorationGameResult>(
        builder: (BuildContext context) {
          return FranceExplorationGameScreen(
            title: level.title,
            kind: level.kind,
            category: level.category,
            difficulty: level.difficulty,
            questionCount: level.questionCount,
            isTraining: false,
          );
        },
      ),
    );
    if (result == null) {
      return;
    }
    await NationalExpeditionStorage.save(
      progress.register(
        levelId: level.id,
        stars: result.stars,
        score: result.score,
        correctAnswers: result.correctAnswers,
        totalAnswers: result.questionCount,
      ),
    );
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: FutureBuilder<NationalExpeditionProgress>(
              future: _progressFuture,
              builder: (
                BuildContext context,
                AsyncSnapshot<NationalExpeditionProgress> snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final NationalExpeditionProgress progress =
                    snapshot.data ?? NationalExpeditionProgress.initial();
                final int completed = FranceExpeditionCatalog.levels
                    .where((FranceExpeditionLevel level) =>
                        progress.starsFor(level.id) > 0)
                    .length;
                final int stars = FranceExpeditionCatalog.levels.fold<int>(
                  0,
                  (int total, FranceExpeditionLevel level) =>
                      total + progress.starsFor(level.id),
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'EXPÉDITION FRANCE',
                      subtitle: 'Exploration nationale pilote',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 24),
                    const _FranceHeader(),
                    const SizedBox(height: 14),
                    _ProgressCard(
                      completed: completed,
                      total: FranceExpeditionCatalog.levels.length,
                      stars: stars,
                    ),
                    const SizedBox(height: 14),
                    _NationalStatisticsCard(progress: progress),
                    const SizedBox(height: 18),
                    Text(
                      'PARCOURS NATIONAL',
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (int index = 0;
                        index < FranceExpeditionCatalog.levels.length;
                        index++) ...<Widget>[
                      _FranceLevelCard(
                        index: index,
                        level: FranceExpeditionCatalog.levels[index],
                        stars: progress.starsFor(
                          FranceExpeditionCatalog.levels[index].id,
                        ),
                        bestScore: progress.bestScoreFor(
                          FranceExpeditionCatalog.levels[index].id,
                        ),
                        locked: index > 0 &&
                            progress.starsFor(
                                  FranceExpeditionCatalog.levels[index - 1].id,
                                ) ==
                                0,
                        onPressed: () async {
                          final bool locked = index > 0 &&
                              progress.starsFor(
                                    FranceExpeditionCatalog
                                        .levels[index - 1].id,
                                  ) ==
                                  0;
                          if (locked) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Obtiens au moins une étoile à l’étape précédente.',
                                ),
                              ),
                            );
                            return;
                          }
                          await _openLevel(
                            FranceExpeditionCatalog.levels[index],
                            progress,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FranceHeader extends StatelessWidget {
  const _FranceHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1E5AA8), Color(0xFFB72B3B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Center(
              child: Text('🇫🇷', style: TextStyle(fontSize: 42)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'TOUR DE FRANCE',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Régions, villes et monuments.',
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white70,
                    fontSize: 12,
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.stars,
  });

  final int completed;
  final int total;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.route_rounded, color: GeoColors.mint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$completed / $total étapes',
              style: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(Icons.star_rounded, color: GeoColors.gold),
          const SizedBox(width: 5),
          Text(
            '$stars',
            style: GoogleFonts.nunitoSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NationalStatisticsCard extends StatelessWidget {
  const _NationalStatisticsCard({required this.progress});

  final NationalExpeditionProgress progress;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'STATISTIQUES FRANCE',
              style: GoogleFonts.nunitoSans(
                color: GeoColors.blue,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _NationalStat(
                  icon: Icons.sports_esports_rounded,
                  value: '${progress.gamesPlayed}',
                  label: 'Parties',
                ),
                _NationalStat(
                  icon: Icons.track_changes_rounded,
                  value: '${progress.accuracyPercent} %',
                  label: 'Précision',
                ),
                _NationalStat(
                  icon: Icons.emoji_events_rounded,
                  value: '${progress.bestScore}',
                  label: 'Record',
                ),
              ],
            ),
          ],
        ),
      );
}

class _NationalStat extends StatelessWidget {
  const _NationalStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: <Widget>[
            Icon(icon, color: GeoColors.coral, size: 22),
            const SizedBox(height: 5),
            Text(
              value,
              style: GoogleFonts.fredoka(
                color: GeoColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF58708D),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _FranceLevelCard extends StatelessWidget {
  const _FranceLevelCard({
    required this.index,
    required this.level,
    required this.stars,
    required this.bestScore,
    required this.locked,
    required this.onPressed,
  });

  final int index;
  final FranceExpeditionLevel level;
  final int stars;
  final int bestScore;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.62 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: locked
                        ? Colors.white10
                        : GeoColors.mint.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    locked ? Icons.lock_rounded : level.icon,
                    color: locked ? Colors.white54 : GeoColors.mint,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${index + 1}. ${level.title}',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        level.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (bestScore > 0) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Meilleur score : $bestScore',
                          style: GoogleFonts.nunitoSans(
                            color: GeoColors.sky,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!locked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int star = 0; star < 3; star++)
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: star < stars ? GeoColors.gold : Colors.white24,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
