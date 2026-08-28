import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geo_engine/geo_country.dart';
import '../../passport/progress/passport_continent.dart';
import '../../passport/progress/passport_continent_snapshot.dart';
import '../../passport/progress/passport_entity_progress.dart';
import '../../passport/progress/passport_progress_rules.dart';
import '../../passport/progress/passport_progress_v2.dart';
import '../design/geopoint_design.dart';
import 'passport_country_stamp_view.dart';

class PassportContinentScreen extends StatefulWidget {
  const PassportContinentScreen({
    required this.controller,
    required this.continent,
    required this.color,
    super.key,
  });

  final GameController controller;
  final PassportContinent continent;
  final Color color;

  @override
  State<PassportContinentScreen> createState() =>
      _PassportContinentScreenState();
}

class _PassportContinentScreenState extends State<PassportContinentScreen> {
  _CountryFilter _filter = _CountryFilter.all;

  @override
  Widget build(BuildContext context) {
    final PassportProgressV2 progress = widget.controller.passportProgress;
    final PassportContinentSnapshot snapshot =
        PassportContinentSnapshot.build(
      continent: widget.continent,
      countries: widget.controller.countries,
      progress: progress,
    );
    final List<_CountryEntry> allEntries = snapshot.countries
        .map(
          (GeoCountry country) => _CountryEntry(
            country: country,
            progress: progress.progressFor(country.id),
          ),
        )
        .toList(growable: false);
    final List<_CountryEntry> visibleEntries = allEntries
        .where((_CountryEntry entry) => _filter.includes(entry.progress))
        .toList(growable: false);
    final _NextObjective objective = _buildNextObjective(allEntries);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(<Widget>[
                          GeoGameTopBar(
                            title: widget.continent.label.toUpperCase(),
                            subtitle: 'Découvertes, maîtrise et tampons',
                            onBack: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 22),
                          _ContinentHeroCard(
                            snapshot: snapshot,
                            objective: objective,
                            color: widget.color,
                          ),
                          const SizedBox(height: 24),
                          const GeoSectionHeading(
                            eyebrow: 'PROGRESSION DÉTAILLÉE',
                            title: 'Tes pays et territoires',
                            description:
                                'Retrouve l’état du pays, de sa capitale et de '
                                'son drapeau au même endroit.',
                          ),
                          const SizedBox(height: 14),
                          _FilterBar(
                            selectedFilter: _filter,
                            entries: allEntries,
                            onSelected: (_CountryFilter filter) {
                              setState(() {
                                _filter = filter;
                              });
                            },
                          ),
                          const SizedBox(height: 13),
                          _ResultsLabel(
                            visibleCount: visibleEntries.length,
                            totalCount: allEntries.length,
                          ),
                          const SizedBox(height: 10),
                        ]),
                      ),
                    ),
                    if (visibleEntries.isEmpty)
                      const SliverPadding(
                        padding: EdgeInsets.fromLTRB(18, 8, 18, 38),
                        sliver: SliverToBoxAdapter(
                          child: _EmptyFilterCard(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 38),
                        sliver: SliverLayoutBuilder(
                          builder: (
                            BuildContext context,
                            SliverConstraints constraints,
                          ) {
                            final int columnCount =
                                constraints.crossAxisExtent >= 720 ? 2 : 1;

                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columnCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 174,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  final _CountryEntry entry =
                                      visibleEntries[index];

                                  return _CountryProgressCard(
                                    entry: entry,
                                    accentColor: widget.color,
                                    onPressed: () {
                                      _showCountryProgress(
                                        context,
                                        entry: entry,
                                        accentColor: widget.color,
                                      );
                                    },
                                  );
                                },
                                childCount: visibleEntries.length,
                              ),
                            );
                          },
                        ),
                      ),
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

class _ContinentHeroCard extends StatelessWidget {
  const _ContinentHeroCard({
    required this.snapshot,
    required this.objective,
    required this.color,
  });

  final PassportContinentSnapshot snapshot;
  final _NextObjective objective;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  color: GeoColors.ink,
                  size: 32,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${snapshot.discoveredCount}/${snapshot.totalCount}',
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 29,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.discoveryPercentage}% du continent découvert',
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.ink.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _HeroProgressLine(
            label: 'Découverte',
            percentage: snapshot.discoveryPercentage,
            value: snapshot.discoveryProgress,
            color: GeoColors.blue,
          ),
          const SizedBox(height: 12),
          _HeroProgressLine(
            label: 'Maîtrise',
            percentage: snapshot.masteryPercentage,
            value: snapshot.masteryProgress,
            color: const Color(0xFF16815D),
          ),
          const SizedBox(height: 17),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeroMetric(
                  value: snapshot.discoveredCount,
                  label: 'Découverts',
                  icon: Icons.visibility_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroMetric(
                  value: snapshot.masteredCount,
                  label: 'Maîtrisés',
                  icon: Icons.school_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroMetric(
                  value: snapshot.stampCount,
                  label: 'Tampons',
                  icon: Icons.approval_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _ObjectiveCard(objective: objective),
        ],
      ),
    );
  }
}

class _HeroProgressLine extends StatelessWidget {
  const _HeroProgressLine({
    required this.label,
    required this.percentage,
    required this.value,
    required this.color,
  });

  final String label;
  final int percentage;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '$percentage%',
              style: GoogleFonts.fredoka(
                color: GeoColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: value,
            backgroundColor: Colors.white.withValues(alpha: 0.68),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: GeoColors.ink, size: 17),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$value',
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.mutedInk,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
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

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({required this.objective});

  final _NextObjective objective;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: GeoColors.ink.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(objective.icon, color: GeoColors.gold, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PROCHAIN OBJECTIF',
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.gold,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  objective.title,
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  objective.detail,
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 9,
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedFilter,
    required this.entries,
    required this.onSelected,
  });

  final _CountryFilter selectedFilter;
  final List<_CountryEntry> entries;
  final ValueChanged<_CountryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _CountryFilter.values.map<Widget>((_CountryFilter filter) {
          final bool isSelected = filter == selectedFilter;
          final int count = entries
              .where(
                (_CountryEntry entry) => filter.includes(entry.progress),
              )
              .length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected ? GeoColors.blue : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onSelected(filter),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  child: Text(
                    '${filter.label}  $count',
                    style: GoogleFonts.nunitoSans(
                      color: isSelected ? Colors.white : GeoColors.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ResultsLabel extends StatelessWidget {
  const _ResultsLabel({
    required this.visibleCount,
    required this.totalCount,
  });

  final int visibleCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Text(
      visibleCount == totalCount
          ? '$totalCount pays et territoires'
          : '$visibleCount résultat${visibleCount > 1 ? 's' : ''}',
      style: GoogleFonts.nunitoSans(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CountryProgressCard extends StatelessWidget {
  const _CountryProgressCard({
    required this.entry,
    required this.accentColor,
    required this.onPressed,
  });

  final _CountryEntry entry;
  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final PassportLearningState state = entry.progress.learningState;
    final _StateStyle stateStyle = _styleForState(state);
    final int masteryLevel = entry.progress.locationProgress.masteryLevel;

    return Material(
      color: const Color(0xFFEAF5FF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.44),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      entry.country.flagEmoji.isEmpty
                          ? '🌍'
                          : entry.country.flagEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.country.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.fredoka(
                            color: GeoColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _StatePill(style: stateStyle),
                      ],
                    ),
                  ),
                  if (entry.progress.stampUnlockedAt != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 7),
                      child: Icon(
                        Icons.approval_rounded,
                        color: GeoColors.blue,
                        size: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ThemeBadge(
                      label: 'Pays',
                      state: _themeState(
                        entry.progress,
                        PassportKnowledgeTheme.location,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ThemeBadge(
                      label: 'Capitale',
                      state: _themeState(
                        entry.progress,
                        PassportKnowledgeTheme.capital,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ThemeBadge(
                      label: 'Drapeau',
                      state: _themeState(
                        entry.progress,
                        PassportKnowledgeTheme.flag,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: masteryLevel /
                            PassportProgressRules.masteredMasteryLevel,
                        backgroundColor: Colors.white,
                        color: stateStyle.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Maîtrise $masteryLevel/5',
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.mutedInk,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (entry.progress.isVisited ||
                      entry.progress.isWishlisted ||
                      entry.progress.isFavorite) ...<Widget>[
                    const SizedBox(width: 6),
                    Icon(
                      entry.progress.isVisited
                          ? Icons.flight_takeoff_rounded
                          : entry.progress.isWishlisted
                              ? Icons.bookmark_rounded
                              : Icons.favorite_rounded,
                      color: GeoColors.coral,
                      size: 15,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.style});

  final _StateStyle style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          style.label,
          style: GoogleFonts.nunitoSans(
            color: style.foregroundColor,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ThemeBadge extends StatelessWidget {
  const _ThemeBadge({
    required this.label,
    required this.state,
  });

  final String label;
  final PassportLearningState state;

  @override
  Widget build(BuildContext context) {
    final _StateStyle style = _styleForState(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: style.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                color: GeoColors.ink,
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFilterCard extends StatelessWidget {
  const _EmptyFilterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.search_off_rounded,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 9),
          Text(
            'Aucun pays dans cette catégorie.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

void _showCountryProgress(
  BuildContext context, {
  required _CountryEntry entry,
  required Color accentColor,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return _CountryProgressSheet(
        entry: entry,
        accentColor: accentColor,
      );
    },
  );
}

class _CountryProgressSheet extends StatelessWidget {
  const _CountryProgressSheet({
    required this.entry,
    required this.accentColor,
  });

  final _CountryEntry entry;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final PassportEntityProgress progress = entry.progress;
    final List<_ThemeDefinition> themes = <_ThemeDefinition>[
      const _ThemeDefinition('Pays', PassportKnowledgeTheme.location),
      const _ThemeDefinition('Capitale', PassportKnowledgeTheme.capital),
      const _ThemeDefinition('Drapeau', PassportKnowledgeTheme.flag),
      const _ThemeDefinition('Silhouette', PassportKnowledgeTheme.silhouette),
      const _ThemeDefinition('Villes', PassportKnowledgeTheme.cities),
      const _ThemeDefinition('Monnaie', PassportKnowledgeTheme.currency),
      const _ThemeDefinition('Langues', PassportKnowledgeTheme.languages),
    ];

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF4F8FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9BAABD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: <Widget>[
                  Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Text(
                      entry.country.flagEmoji.isEmpty
                          ? '🌍'
                          : entry.country.flagEmoji,
                      style: const TextStyle(fontSize: 34),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.country.name,
                          style: GoogleFonts.fredoka(
                            color: GeoColors.ink,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _StatePill(
                          style: _styleForState(progress.learningState),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: GeoColors.mutedInk,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: PassportCountryStampView(
                  country: entry.country,
                  progress: progress,
                  size: 138,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'CONNAISSANCES',
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 9),
              ...themes.map<Widget>((_ThemeDefinition definition) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ThemeProgressRow(
                    definition: definition,
                    entityProgress: progress,
                  ),
                );
              }),
              const SizedBox(height: 10),
              _StampInformation(progress: progress),
              if (progress.isVisited ||
                  progress.isWishlisted ||
                  progress.isFavorite) ...<Widget>[
                const SizedBox(height: 12),
                _PersonalInformation(progress: progress),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeProgressRow extends StatelessWidget {
  const _ThemeProgressRow({
    required this.definition,
    required this.entityProgress,
  });

  final _ThemeDefinition definition;
  final PassportEntityProgress entityProgress;

  @override
  Widget build(BuildContext context) {
    final PassportThemeProgress theme =
        entityProgress.progressFor(definition.theme);
    final PassportLearningState state =
        _themeState(entityProgress, definition.theme);
    final _StateStyle style = _styleForState(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: style.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              definition.label,
              style: GoogleFonts.nunitoSans(
                color: GeoColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                style.label,
                style: GoogleFonts.nunitoSans(
                  color: style.foregroundColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${theme.totalAttempts} réponse${theme.totalAttempts > 1 ? 's' : ''} '
                '• niveau ${theme.masteryLevel}/5',
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.mutedInk,
                  fontSize: 7.5,
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

class _StampInformation extends StatelessWidget {
  const _StampInformation({required this.progress});

  final PassportEntityProgress progress;

  @override
  Widget build(BuildContext context) {
    final DateTime? unlockedAt = progress.stampUnlockedAt;
    final bool isUnlocked = unlockedAt != null;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isUnlocked
            ? GeoColors.blue.withValues(alpha: 0.10)
            : const Color(0xFFE6EBF1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isUnlocked ? Icons.approval_rounded : Icons.lock_outline_rounded,
            color: isUnlocked ? GeoColors.blue : GeoColors.mutedInk,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isUnlocked ? 'Tampon obtenu' : 'Tampon verrouillé',
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  isUnlocked
                      ? '${_formatDate(unlockedAt)} • '
                          '${_sourceLabel(progress.stampUnlockSource)}'
                      : 'Réussis une première réponse pour le débloquer.',
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.mutedInk,
                    fontSize: 9,
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

class _PersonalInformation extends StatelessWidget {
  const _PersonalInformation({required this.progress});

  final PassportEntityProgress progress;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: <Widget>[
        if (progress.isVisited)
          const _PersonalBadge(
            label: 'Visité',
            icon: Icons.flight_takeoff_rounded,
            color: GeoColors.mint,
          ),
        if (progress.isWishlisted)
          const _PersonalBadge(
            label: 'À visiter',
            icon: Icons.bookmark_rounded,
            color: GeoColors.coral,
          ),
        if (progress.isFavorite)
          const _PersonalBadge(
            label: 'Favori',
            icon: Icons.favorite_rounded,
            color: GeoColors.gold,
          ),
      ],
    );
  }
}

class _PersonalBadge extends StatelessWidget {
  const _PersonalBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: GeoColors.ink, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.ink,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

enum _CountryFilter {
  all('Tous'),
  undiscovered('À découvrir'),
  learning('En cours'),
  mastered('Maîtrisés');

  const _CountryFilter(this.label);

  final String label;

  bool includes(PassportEntityProgress progress) {
    switch (this) {
      case _CountryFilter.all:
        return true;
      case _CountryFilter.undiscovered:
        return !progress.hasBeenDiscovered;
      case _CountryFilter.learning:
        return progress.hasBeenDiscovered && !progress.isMastered;
      case _CountryFilter.mastered:
        return progress.isMastered;
    }
  }
}

class _CountryEntry {
  const _CountryEntry({
    required this.country,
    required this.progress,
  });

  final GeoCountry country;
  final PassportEntityProgress progress;
}

class _ThemeDefinition {
  const _ThemeDefinition(this.label, this.theme);

  final String label;
  final PassportKnowledgeTheme theme;
}

class _StateStyle {
  const _StateStyle({
    required this.label,
    required this.color,
    required this.foregroundColor,
  });

  final String label;
  final Color color;
  final Color foregroundColor;
}

class _NextObjective {
  const _NextObjective({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;
}

PassportLearningState _themeState(
  PassportEntityProgress entity,
  PassportKnowledgeTheme theme,
) {
  if (theme == PassportKnowledgeTheme.location) {
    return entity.learningState;
  }

  final PassportThemeProgress progress = entity.progressFor(theme);

  return progress.learningState(
    entityHasBeenDiscovered: progress.hasBeenSeen,
  );
}

_StateStyle _styleForState(PassportLearningState state) {
  switch (state) {
    case PassportLearningState.undiscovered:
      return const _StateStyle(
        label: 'Non découvert',
        color: Color(0xFFAAB8C8),
        foregroundColor: Color(0xFF5E7390),
      );
    case PassportLearningState.discovered:
      return const _StateStyle(
        label: 'Découvert',
        color: Color(0xFF6FC6F2),
        foregroundColor: Color(0xFF17639A),
      );
    case PassportLearningState.learning:
      return const _StateStyle(
        label: 'En apprentissage',
        color: GeoColors.purple,
        foregroundColor: Color(0xFF6544B5),
      );
    case PassportLearningState.mastered:
      return const _StateStyle(
        label: 'Maîtrisé',
        color: GeoColors.mint,
        foregroundColor: Color(0xFF126D50),
      );
  }
}

_NextObjective _buildNextObjective(List<_CountryEntry> entries) {
  for (final _CountryEntry entry in entries) {
    if (!entry.progress.hasBeenDiscovered) {
      return _NextObjective(
        title: 'Découvre ${entry.country.name}',
        detail: 'Il reste un nouveau territoire à rencontrer.',
        icon: Icons.visibility_rounded,
      );
    }
  }

  final List<_CountryEntry> toMaster = entries
      .where((_CountryEntry entry) => !entry.progress.isMastered)
      .toList(growable: false)
    ..sort((_CountryEntry first, _CountryEntry second) {
      final int masteryComparison = first.progress.locationProgress.masteryLevel
          .compareTo(second.progress.locationProgress.masteryLevel);

      if (masteryComparison != 0) {
        return masteryComparison;
      }

      return first.country.name.compareTo(second.country.name);
    });

  if (toMaster.isNotEmpty) {
    final _CountryEntry target = toMaster.first;
    final int level = target.progress.locationProgress.masteryLevel;

    return _NextObjective(
      title: 'Fais progresser ${target.country.name}',
      detail: 'Maîtrise actuelle : niveau $level/5.',
      icon: Icons.school_rounded,
    );
  }

  return const _NextObjective(
    title: 'Continent entièrement maîtrisé !',
    detail: 'Tous les pays ont atteint le niveau maximal.',
    icon: Icons.emoji_events_rounded,
  );
}

String _formatDate(DateTime date) {
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String _sourceLabel(PassportDiscoverySource? source) {
  switch (source) {
    case PassportDiscoverySource.game:
      return 'Jeu';
    case PassportDiscoverySource.atlas:
      return 'Atlas';
    case PassportDiscoverySource.expedition:
      return 'Expédition';
    case PassportDiscoverySource.challenge:
      return 'Défi';
    case PassportDiscoverySource.migration:
      return 'Ancienne progression';
    case PassportDiscoverySource.unknown:
    case null:
      return 'Origine inconnue';
  }
}
