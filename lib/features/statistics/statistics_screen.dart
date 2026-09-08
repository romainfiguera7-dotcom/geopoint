import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geo_engine/flag_emoji.dart';
import '../../geo_engine/geo_country.dart';
import '../../geobrain/country_mastery.dart';
import '../../geobrain/geobrain_theme.dart';
import '../../player/player_statistics.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<StatisticsScreen> createState() {
    return _StatisticsScreenState();
  }
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const List<_ModeDefinition> _modes = <_ModeDefinition>[
    _ModeDefinition(
      id: 'find_country',
      label: 'Pays',
      icon: Icons.public_rounded,
      color: Color(0xFF57E389),
    ),
    _ModeDefinition(
      id: 'find_capital',
      label: 'Capitales',
      icon: Icons.location_city_rounded,
      color: Color(0xFFFFC857),
    ),
    _ModeDefinition(
      id: 'find_flag',
      label: 'Drapeaux',
      icon: Icons.flag_rounded,
      color: Color(0xFFFF7A8A),
    ),
    _ModeDefinition(
      id: 'mixed',
      label: 'Mixte',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFB983FF),
    ),
  ];

  String _selectedModeId = 'find_country';

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_handleControllerChanged);

  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);

    super.dispose();
  }

  List<CountryMastery> _countriesToReview(DateTime now) {
    final List<CountryMastery> result = <CountryMastery>[];
    final Set<String> addedIds = <String>{};

    for (final CountryMastery mastery
        in widget.controller.geoBrainService.countriesDueForReviewAt(now)) {
      if (addedIds.add(mastery.countryId)) {
        result.add(mastery);
      }

      if (result.length >= 6) {
        return result;
      }
    }

    for (final CountryMastery mastery
        in widget.controller.geoBrainService.weakestCountries) {
      if (mastery.statusAt(now) == GeoBrainMasteryStatus.mastered) {
        continue;
      }

      if (addedIds.add(mastery.countryId)) {
        result.add(mastery);
      }

      if (result.length >= 6) {
        break;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final ModeStatistics modeStatistics = widget.controller.playerProfile
        .statisticsForMode(_selectedModeId);

    final int bestScore = modeStatistics.bestScore;

    final Map<String, GeoCountry> countriesById = <String, GeoCountry>{
      for (final GeoCountry country in widget.controller.countries)
        country.id.trim().toUpperCase(): country,
    };

    final List<CountryMastery> masteredCountries = widget
        .controller
        .geoBrainService
        .strongestCountries
        .where(
          (CountryMastery mastery) =>
              mastery.statusAt(now) == GeoBrainMasteryStatus.mastered,
        )
        .take(6)
        .toList(growable: false);

    final List<CountryMastery> reviewCountries = _countriesToReview(now);
    final DetailedPlayerStatistics detailedStatistics =
        widget.controller.playerProfile.detailedStatistics;

    return Scaffold(
      backgroundColor: const Color(0xFF071B3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071B3A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'STATISTIQUES',
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _StatisticsBackground()),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
              children: <Widget>[
                Text(
                  'TES PERFORMANCES',
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF63D6FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Suis tes progrès mode par mode',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                _ModeSelector(
                  modes: _modes,
                  selectedModeId: _selectedModeId,
                  onSelected: (String modeId) {
                    setState(() {
                      _selectedModeId = modeId;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _OverviewCard(statistics: modeStatistics, bestScore: bestScore),
                const SizedBox(height: 18),
                const _SectionTitle(
                  icon: Icons.language_rounded,
                  title: 'Résultats par continent',
                  subtitle: 'Réussite et questions jouées dans chaque zone',
                ),
                const SizedBox(height: 12),
                _GeographicBreakdown(
                  statistics: detailedStatistics,
                  countriesById: countriesById,
                ),
                const SizedBox(height: 18),
                const _SectionTitle(
                  icon: Icons.psychology_rounded,
                  title: 'Maîtrise des pays',
                  subtitle: 'Calculée par ton GeoBrain',
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MasteryCounter(
                        icon: Icons.verified_rounded,
                        color: const Color(0xFF57E389),
                        value: widget
                            .controller
                            .geoBrainService
                            .profile
                            .masteredCountryCountAt(now),
                        label: 'Maîtrisés',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MasteryCounter(
                        icon: Icons.visibility_rounded,
                        color: const Color(0xFF63D6FF),
                        value: widget
                            .controller
                            .geoBrainService
                            .profile
                            .seenCountryCount,
                        label: 'Déjà vus',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _CountryMasterySection(
                  title: 'Pays maîtrisés',
                  emptyText:
                      'Continue à jouer pour maîtriser '
                      'tes premiers pays.',
                  accentColor: const Color(0xFF57E389),
                  countries: masteredCountries,
                  countriesById: countriesById,
                ),
                const SizedBox(height: 14),
                _CountryMasterySection(
                  title: 'À réviser',
                  emptyText: 'Aucune révision nécessaire pour le moment.',
                  accentColor: const Color(0xFFFFC857),
                  countries: reviewCountries,
                  countriesById: countriesById,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsBackground extends StatelessWidget {
  const _StatisticsBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF071B3A),
            Color(0xFF0B3268),
            Color(0xFF0E4E9E),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.modes,
    required this.selectedModeId,
    required this.onSelected,
  });

  final List<_ModeDefinition> modes;
  final String selectedModeId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final _ModeDefinition mode in modes) ...<Widget>[
            _ModeChip(
              definition: mode,
              isSelected: selectedModeId == mode.id,
              onPressed: () {
                onSelected(mode.id);
              },
            ),
            const SizedBox(width: 9),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.definition,
    required this.isSelected,
    required this.onPressed,
  });

  final _ModeDefinition definition;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? definition.color
          : Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                definition.icon,
                size: 19,
                color: isSelected ? const Color(0xFF071B3A) : definition.color,
              ),
              const SizedBox(width: 7),
              Text(
                definition.label,
                style: GoogleFonts.nunitoSans(
                  color: isSelected ? const Color(0xFF071B3A) : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.statistics, required this.bestScore});

  final ModeStatistics statistics;
  final int bestScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double tileWidth = (constraints.maxWidth - 10) / 2;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _SummaryTile(
                width: tileWidth,
                icon: Icons.sports_esports_rounded,
                color: const Color(0xFF63D6FF),
                value: '${statistics.gamesPlayed}',
                label: 'Parties jouées',
              ),
              _SummaryTile(
                width: tileWidth,
                icon: Icons.help_rounded,
                color: const Color(0xFFB983FF),
                value: '${statistics.questionsPlayed}',
                label: 'Questions jouées',
              ),
              _SummaryTile(
                width: tileWidth,
                icon: Icons.analytics_rounded,
                color: const Color(0xFFFFC857),
                value: statistics.hasPlayed
                    ? statistics.averageScore.round().toString()
                    : '—',
                label: 'Score moyen',
              ),
              _SummaryTile(
                width: tileWidth,
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFFF8A73),
                value: bestScore > 0 ? '$bestScore' : '—',
                label: 'Meilleur score',
              ),
              _SummaryTile(
                width: constraints.maxWidth,
                icon: Icons.task_alt_rounded,
                color: const Color(0xFF57E389),
                value: statistics.questionsPlayed > 0
                    ? '${(statistics.accuracy * 100).round()} %'
                    : '—',
                label: 'Taux de bonnes réponses',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
        color: const Color(0xFF071B3A).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: const Color(0xFF63D6FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFF63D6FF), size: 24),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GeographicBreakdown extends StatelessWidget {
  const _GeographicBreakdown({
    required this.statistics,
    required this.countriesById,
  });

  final DetailedPlayerStatistics statistics;
  final Map<String, GeoCountry> countriesById;

  static const List<({String id, String label, Color color})> _continents =
      <({String id, String label, Color color})>[
    (id: 'africa', label: 'Afrique', color: Color(0xFFFFA75B)),
    (id: 'americas', label: 'Amérique', color: Color(0xFF55D6A6)),
    (id: 'asia', label: 'Asie', color: Color(0xFFFF8178)),
    (id: 'europe', label: 'Europe', color: Color(0xFF69C4ED)),
    (id: 'oceania', label: 'Océanie', color: Color(0xFFA985F8)),
    (id: 'polar', label: 'Régions polaires', color: Color(0xFFDCEFF5)),
  ];

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, PerformanceStatistics>> countries =
        statistics.byCountry.entries
            .where((entry) {
              return entry.key != 'UNKNOWN' &&
                  entry.value.questionsPlayed > 0 &&
                  countriesById.containsKey(entry.key);
            })
            .toList(growable: false)
          ..sort((a, b) {
            return b.value.questionsPlayed.compareTo(a.value.questionsPlayed);
          });
    final bool hasGeographicHistory = statistics.byContinent.values.any(
      (PerformanceStatistics value) => value.questionsPlayed > 0,
    );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: <Widget>[
          if (!hasGeographicHistory)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tes anciennes données sont conservées. Cette répartition '
                'commencera avec ta prochaine partie.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            for (int index = 0; index < _continents.length; index++) ...<Widget>[
              _GeographicRow(
                label: _continents[index].label,
                color: _continents[index].color,
                statistics: statistics.statisticsForContinent(
                  _continents[index].id,
                ),
              ),
              if (index != _continents.length - 1)
                const Divider(height: 17, color: Colors.white12),
            ],
          if (countries.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PAYS LES PLUS JOUÉS',
                style: GoogleFonts.nunitoSans(
                  color: const Color(0xFF63D6FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final MapEntry<String, PerformanceStatistics> entry
                in countries.take(5)) ...<Widget>[
              _GeographicRow(
                label: countriesById[entry.key]?.displayNameWithFlag ?? entry.key,
                color: const Color(0xFF63D6FF),
                statistics: entry.value,
              ),
              if (entry.key != countries.take(5).last.key)
                const Divider(height: 17, color: Colors.white12),
            ],
          ],
        ],
      ),
    );
  }
}

class _GeographicRow extends StatelessWidget {
  const _GeographicRow({
    required this.label,
    required this.color,
    required this.statistics,
  });

  final String label;
  final Color color;
  final PerformanceStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final int percentage = (statistics.accuracy * 100).round();
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '${statistics.questionsPlayed} questions',
          style: GoogleFonts.nunitoSans(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 43,
          child: Text(
            statistics.questionsPlayed == 0 ? '—' : '$percentage %',
            textAlign: TextAlign.right,
            style: GoogleFonts.fredoka(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MasteryCounter extends StatelessWidget {
  const _MasteryCounter({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$value',
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountryMasterySection extends StatelessWidget {
  const _CountryMasterySection({
    required this.title,
    required this.emptyText,
    required this.accentColor,
    required this.countries,
    required this.countriesById,
  });

  final String title;
  final String emptyText;
  final Color accentColor;
  final List<CountryMastery> countries;
  final Map<String, GeoCountry> countriesById;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.fredoka(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          if (countries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                emptyText,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            for (int index = 0; index < countries.length; index++) ...<Widget>[
              _CountryMasteryRow(
                mastery: countries[index],
                country: countriesById[countries[index].countryId],
              ),
              if (index < countries.length - 1)
                Divider(
                  height: 15,
                  color: Colors.white.withValues(alpha: 0.09),
                ),
            ],
        ],
      ),
    );
  }
}

class _CountryMasteryRow extends StatelessWidget {
  const _CountryMasteryRow({required this.mastery, required this.country});

  final CountryMastery mastery;
  final GeoCountry? country;

  @override
  Widget build(BuildContext context) {
    final String flag = FlagEmoji.fromIsoA2(country?.isoA2 ?? '');

    final int accuracyPercentage = (mastery.accuracy * 100).round();

    return Row(
      children: <Widget>[
        Text(flag.isEmpty ? '🌍' : flag, style: const TextStyle(fontSize: 25)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                country?.name ?? mastery.countryId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${mastery.totalAttempts} tentative(s) '
                '• $accuracyPercentage %',
                style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          mastery.starsLabel,
          style: const TextStyle(
            color: Color(0xFFFFC857),
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ModeDefinition {
  const _ModeDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}
