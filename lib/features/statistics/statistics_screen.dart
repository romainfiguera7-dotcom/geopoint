import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/expedition/expedition_progress.dart';
import '../../game/expedition/expedition_storage.dart';
import '../../game/game_controller.dart';
import '../../geo_engine/flag_emoji.dart';
import '../../geo_engine/geo_country.dart';
import '../../geobrain/country_mastery.dart';
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

  static const List<_DifficultyDefinition> _difficulties =
      <_DifficultyDefinition>[
        _DifficultyDefinition(
          id: 'discovery',
          label: 'Initiation',
          color: Color(0xFF63D6FF),
        ),
        _DifficultyDefinition(
          id: 'easy',
          label: 'Voyageur',
          color: Color(0xFF57E389),
        ),
        _DifficultyDefinition(
          id: 'intermediate',
          label: 'Explorateur',
          color: Color(0xFFFFC857),
        ),
        _DifficultyDefinition(
          id: 'hard',
          label: 'Aventurier',
          color: Color(0xFFFF8A73),
        ),
        _DifficultyDefinition(
          id: 'expert',
          label: 'Maître cartographe',
          color: Color(0xFFB983FF),
        ),
      ];

  String _selectedModeId = 'find_country';
  ExpeditionProgress _expeditionProgress = ExpeditionProgress.initial();
  bool _isLoadingProgress = true;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_handleControllerChanged);

    unawaited(_loadExpeditionProgress());
  }

  Future<void> _loadExpeditionProgress() async {
    final ExpeditionProgress progress = await ExpeditionStorage.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _expeditionProgress = progress;
      _isLoadingProgress = false;
    });
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

  int _bestScoreForMode(ModeStatistics statistics) {
    int bestScore = statistics.bestScore;

    for (final _DifficultyDefinition difficulty in _difficulties) {
      final int expeditionRecord = _expeditionProgress.bestScoreFor(
        difficultyId: difficulty.id,
        missionId: _selectedModeId,
      );

      if (expeditionRecord > bestScore) {
        bestScore = expeditionRecord;
      }
    }

    return bestScore;
  }

  int _bestScoreForDifficulty({
    required DifficultyStatistics statistics,
    required String difficultyId,
  }) {
    final int expeditionRecord = _expeditionProgress.bestScoreFor(
      difficultyId: difficultyId,
      missionId: _selectedModeId,
    );

    return expeditionRecord > statistics.bestScore
        ? expeditionRecord
        : statistics.bestScore;
  }

  List<CountryMastery> _countriesToReview() {
    final List<CountryMastery> result = <CountryMastery>[];
    final Set<String> addedIds = <String>{};

    for (final CountryMastery mastery
        in widget.controller.geoBrainService.countriesDueForReview) {
      if (addedIds.add(mastery.countryId)) {
        result.add(mastery);
      }

      if (result.length >= 6) {
        return result;
      }
    }

    for (final CountryMastery mastery
        in widget.controller.geoBrainService.weakestCountries) {
      if (mastery.isMastered) {
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
    final ModeStatistics modeStatistics = widget.controller.playerProfile
        .statisticsForMode(_selectedModeId);

    final int bestScore = _bestScoreForMode(modeStatistics);

    final Map<String, GeoCountry> countriesById = <String, GeoCountry>{
      for (final GeoCountry country in widget.controller.countries)
        country.id.trim().toUpperCase(): country,
    };

    final List<CountryMastery> masteredCountries = widget
        .controller
        .geoBrainService
        .strongestCountries
        .where((CountryMastery mastery) => mastery.isMastered)
        .take(6)
        .toList(growable: false);

    final List<CountryMastery> reviewCountries = _countriesToReview();

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
                if (!modeStatistics.hasPlayed && bestScore > 0) ...<Widget>[
                  const SizedBox(height: 10),
                  const _LegacyStatisticsNotice(),
                ],
                const SizedBox(height: 26),
                const _SectionTitle(
                  icon: Icons.route_rounded,
                  title: 'Progression par difficulté',
                  subtitle: 'Tes résultats dans chaque expédition',
                ),
                const SizedBox(height: 12),
                for (final _DifficultyDefinition difficulty
                    in _difficulties) ...<Widget>[
                  _DifficultyCard(
                    definition: difficulty,
                    statistics: modeStatistics.statisticsForDifficulty(
                      difficulty.id,
                    ),
                    bestScore: _bestScoreForDifficulty(
                      statistics: modeStatistics.statisticsForDifficulty(
                        difficulty.id,
                      ),
                      difficultyId: difficulty.id,
                    ),
                    stars: _expeditionProgress.starsFor(
                      difficultyId: difficulty.id,
                      missionId: _selectedModeId,
                    ),
                    isLoading: _isLoadingProgress,
                  ),
                  const SizedBox(height: 10),
                ],
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
                            .masteredCountryCount,
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
                  title: 'Pays à revoir',
                  emptyText: 'Aucun pays à revoir pour le moment.',
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

class _LegacyStatisticsNotice extends StatelessWidget {
  const _LegacyStatisticsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFFFC857),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Ton ancien record est conservé. '
              'Les moyennes commenceront avec '
              'ta prochaine partie.',
              style: GoogleFonts.nunitoSans(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
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

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.definition,
    required this.statistics,
    required this.bestScore,
    required this.stars,
    required this.isLoading,
  });

  final _DifficultyDefinition definition;
  final DifficultyStatistics statistics;
  final int bestScore;
  final int stars;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final int accuracyPercentage = (statistics.accuracy * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 12,
                height: 42,
                decoration: BoxDecoration(
                  color: definition.color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      definition.label,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${statistics.gamesPlayed} partie(s) '
                      '• ${statistics.questionsPlayed} question(s)',
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFC857),
                  ),
                )
              else
                Text(
                  '${'★' * stars}${'☆' * (3 - stars)}',
                  style: const TextStyle(
                    color: Color(0xFFFFC857),
                    fontSize: 17,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              Expanded(
                child: _DifficultyMetric(
                  label: 'Moyenne',
                  value: statistics.hasPlayed
                      ? statistics.averageScore.round().toString()
                      : '—',
                ),
              ),
              Expanded(
                child: _DifficultyMetric(
                  label: 'Record',
                  value: bestScore > 0 ? '$bestScore' : '—',
                ),
              ),
              Expanded(
                child: _DifficultyMetric(
                  label: 'Réussite',
                  value: statistics.questionsPlayed > 0
                      ? '$accuracyPercentage %'
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: statistics.questionsPlayed > 0 ? statistics.accuracy : 0,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(definition.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyMetric extends StatelessWidget {
  const _DifficultyMetric({required this.label, required this.value});

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
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 9,
            fontWeight: FontWeight.w800,
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

class _DifficultyDefinition {
  const _DifficultyDefinition({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}
