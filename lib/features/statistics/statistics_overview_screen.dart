import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../passport/progress/passport_entity_progress.dart';
import '../../passport/progress/passport_progress_rules.dart';
import '../../player/player_profile.dart';
import '../../player/player_statistics.dart';
import '../design/geopoint_design.dart';
import 'statistics_screen.dart';

class StatisticsOverviewScreen extends StatefulWidget {
  const StatisticsOverviewScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<StatisticsOverviewScreen> createState() =>
      _StatisticsOverviewScreenState();
}

enum _StatisticsPeriod { sevenDays, thirtyDays, allTime }

class _StatisticsOverviewScreenState extends State<StatisticsOverviewScreen> {
  _StatisticsPeriod _period = _StatisticsPeriod.allTime;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openDetails() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return StatisticsScreen(controller: widget.controller);
        },
      ),
    );
  }

  PerformanceStatistics _recentStatistics(PlayerProfile profile) {
    switch (_period) {
      case _StatisticsPeriod.sevenDays:
        return profile.detailedStatistics.statisticsForRecentDays(7);
      case _StatisticsPeriod.thirtyDays:
        return profile.detailedStatistics.statisticsForRecentDays(30);
      case _StatisticsPeriod.allTime:
        return profile.detailedStatistics.allTime;
    }
  }

  List<_ThemeSummary> _themeSummaries() {
    const List<_ThemeDefinition> definitions = <_ThemeDefinition>[
      _ThemeDefinition(
        theme: PassportKnowledgeTheme.location,
        label: 'Pays',
        icon: Icons.public_rounded,
        color: GeoColors.mint,
      ),
      _ThemeDefinition(
        theme: PassportKnowledgeTheme.capital,
        label: 'Capitales',
        icon: Icons.location_city_rounded,
        color: GeoColors.gold,
      ),
      _ThemeDefinition(
        theme: PassportKnowledgeTheme.flag,
        label: 'Drapeaux',
        icon: Icons.flag_rounded,
        color: GeoColors.coral,
      ),
      _ThemeDefinition(
        theme: PassportKnowledgeTheme.silhouette,
        label: 'Silhouettes',
        icon: Icons.gesture_rounded,
        color: GeoColors.purple,
      ),
      _ThemeDefinition(
        theme: PassportKnowledgeTheme.cities,
        label: 'Villes',
        icon: Icons.apartment_rounded,
        color: GeoColors.sky,
      ),
      _ThemeDefinition(
        theme: PassportKnowledgeTheme.currency,
        label: 'Monnaies',
        icon: Icons.paid_rounded,
        color: Color(0xFF70D6B3),
      ),
      _ThemeDefinition(
        theme: PassportKnowledgeTheme.languages,
        label: 'Langues',
        icon: Icons.translate_rounded,
        color: Color(0xFFFFA75B),
      ),
    ];

    return definitions.map((_ThemeDefinition definition) {
      int attempts = 0;
      int correct = 0;
      int mastered = 0;
      for (final PassportEntityProgress entity
          in widget.controller.passportProgress.entities.values) {
        final PassportThemeProgress progress =
            entity.progressFor(definition.theme);
        attempts += progress.totalAttempts;
        correct += progress.correctAnswers;
        if (progress.isMastered) {
          mastered++;
        }
      }
      return _ThemeSummary(
        definition: definition,
        attempts: attempts,
        correct: correct,
        mastered: mastered,
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final PlayerProfile profile = widget.controller.playerProfile;
    final PerformanceStatistics detailed = _recentStatistics(profile);
    final bool allTime = _period == _StatisticsPeriod.allTime;
    final int questions = allTime ? profile.totalAnswers : detailed.questionsPlayed;
    final int correct = allTime ? profile.correctAnswers : detailed.correctAnswers;
    final double accuracy = questions == 0 ? 0 : correct / questions;
    final int elapsedSeconds =
        allTime ? profile.totalElapsedSeconds : detailed.totalElapsedSeconds;
    final double averageDistance = allTime
        ? profile.averageDistanceInKilometers
        : detailed.averageDistanceInKilometers;
    final PerformanceStatistics streaks = profile.detailedStatistics.allTime;
    final List<_ThemeSummary> themes = _themeSummaries();

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 38),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'STATISTIQUES',
                      subtitle: 'Ton évolution en un coup d’œil',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 28),
                    const GeoSectionHeading(
                      eyebrow: 'PERFORMANCES',
                      title: 'Mesure tes progrès',
                      description:
                          'Commence par l’essentiel, puis ouvre le détail quand tu veux.',
                    ),
                    const SizedBox(height: 18),
                    _PeriodSelector(
                      selected: _period,
                      onSelected: (_StatisticsPeriod value) {
                        setState(() => _period = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    _MainStatisticsCard(
                      questions: questions,
                      correct: correct,
                      accuracy: accuracy,
                      elapsedSeconds: elapsedSeconds,
                    ),
                    if (!allTime && questions == 0) ...<Widget>[
                      const SizedBox(height: 10),
                      const _RecentHistoryNotice(),
                    ],
                    const SizedBox(height: 14),
                    _PrecisionAndStreakCard(
                      averageDistance: averageDistance,
                      bestDistance: detailed.bestDistanceInKilometers,
                      currentStreak: streaks.currentStreak,
                      bestStreak: streaks.bestStreak,
                    ),
                    const SizedBox(height: 14),
                    _DetailButton(onPressed: _openDetails),
                    const SizedBox(height: 28),
                    const GeoSectionHeading(
                      eyebrow: 'THÈMES',
                      title: 'Toutes tes connaissances',
                      description:
                          'Pays, capitales et futurs thèmes restent bien séparés.',
                    ),
                    const SizedBox(height: 14),
                    _ThemeGrid(themes: themes),
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

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final _StatisticsPeriod selected;
  final ValueChanged<_StatisticsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    const List<(_StatisticsPeriod, String)> periods =
        <(_StatisticsPeriod, String)>[
      (_StatisticsPeriod.sevenDays, '7 jours'),
      (_StatisticsPeriod.thirtyDays, '30 jours'),
      (_StatisticsPeriod.allTime, 'Depuis le début'),
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          for (final (_StatisticsPeriod value, String label) in periods)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: selected == value ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: () => onSelected(value),
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(
                          color: selected == value
                              ? GeoColors.navy
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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

class _MainStatisticsCard extends StatelessWidget {
  const _MainStatisticsCard({
    required this.questions,
    required this.correct,
    required this.accuracy,
    required this.elapsedSeconds,
  });

  final int questions;
  final int correct;
  final double accuracy;
  final int elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MainMetric(
                width: width,
                icon: Icons.quiz_rounded,
                color: GeoColors.blue,
                value: '$questions',
                label: 'Questions jouées',
              ),
              _MainMetric(
                width: width,
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF1FA97A),
                value: '$correct',
                label: 'Bonnes réponses',
              ),
              _MainMetric(
                width: width,
                icon: Icons.track_changes_rounded,
                color: GeoColors.coral,
                value: questions == 0 ? '—' : '${(accuracy * 100).round()} %',
                label: 'Taux de réussite',
              ),
              _MainMetric(
                width: width,
                icon: Icons.schedule_rounded,
                color: GeoColors.purple,
                value: _formatDuration(elapsedSeconds),
                label: 'Temps de jeu',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MainMetric extends StatelessWidget {
  const _MainMetric({
    required this.width,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final double width;
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.navy.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
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

class _PrecisionAndStreakCard extends StatelessWidget {
  const _PrecisionAndStreakCard({
    required this.averageDistance,
    required this.bestDistance,
    required this.currentStreak,
    required this.bestStreak,
  });

  final double averageDistance;
  final double? bestDistance;
  final int currentStreak;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _CompactMetric(
                  label: 'Distance moyenne',
                  value: averageDistance > 0
                      ? _formatDistance(averageDistance)
                      : '—',
                ),
              ),
              Expanded(
                child: _CompactMetric(
                  label: 'Meilleur placement',
                  value: bestDistance == null
                      ? '—'
                      : _formatDistance(bestDistance!),
                ),
              ),
            ],
          ),
          const Divider(height: 25, color: Colors.white24),
          Row(
            children: <Widget>[
              Expanded(
                child: _CompactMetric(
                  label: 'Série actuelle',
                  value: '$currentStreak',
                ),
              ),
              Expanded(
                child: _CompactMetric(
                  label: 'Meilleure série',
                  value: '$bestStreak',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunitoSans(
            color: Colors.white.withValues(alpha: 0.64),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DetailButton extends StatelessWidget {
  const _DetailButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.analytics_rounded),
        label: const Text('OUVRIR LE DÉTAIL'),
        style: FilledButton.styleFrom(
          backgroundColor: GeoColors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.fredoka(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _RecentHistoryNotice extends StatelessWidget {
  const _RecentHistoryNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: GeoColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Tes totaux historiques sont conservés. Les vues 7 et 30 jours '
        'se rempliront dès ta prochaine partie.',
        style: GoogleFonts.nunitoSans(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.themes});

  final List<_ThemeSummary> themes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 520 ? 3 : 2;
        final double width =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final _ThemeSummary summary in themes)
              _ThemeCard(width: width, summary: summary),
          ],
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.width, required this.summary});

  final double width;
  final _ThemeSummary summary;

  @override
  Widget build(BuildContext context) {
    final int accuracy = summary.attempts == 0
        ? 0
        : ((summary.correct / summary.attempts) * 100).round();
    return Container(
      width: width,
      height: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: summary.definition.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(summary.definition.icon, color: GeoColors.navy, size: 25),
          const Spacer(),
          Text(
            summary.definition.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fredoka(
              color: GeoColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            summary.attempts == 0
                ? 'Pas encore joué'
                : '${summary.attempts} questions · $accuracy %',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.navy.withValues(alpha: 0.66),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${summary.mastered} maîtrisés',
            style: GoogleFonts.nunitoSans(
              color: GeoColors.navy,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeDefinition {
  const _ThemeDefinition({
    required this.theme,
    required this.label,
    required this.icon,
    required this.color,
  });

  final PassportKnowledgeTheme theme;
  final String label;
  final IconData icon;
  final Color color;
}

class _ThemeSummary {
  const _ThemeSummary({
    required this.definition,
    required this.attempts,
    required this.correct,
    required this.mastered,
  });

  final _ThemeDefinition definition;
  final int attempts;
  final int correct;
  final int mastered;
}

String _formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) {
    return '0 min';
  }
  final Duration duration = Duration(seconds: totalSeconds);
  if (duration.inHours > 0) {
    final int minutes = duration.inMinutes.remainder(60);
    return minutes == 0
        ? '${duration.inHours} h'
        : '${duration.inHours} h $minutes min';
  }
  return '${duration.inMinutes < 1 ? 1 : duration.inMinutes} min';
}

String _formatDistance(double kilometers) {
  if (kilometers < 1) {
    return '${(kilometers * 1000).round()} m';
  }
  if (kilometers < 10) {
    return '${kilometers.toStringAsFixed(1)} km';
  }
  return '${kilometers.round()} km';
}
