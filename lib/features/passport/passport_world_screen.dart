import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geo_engine/geo_country.dart';
import '../../passport/progress/passport_continent.dart';
import '../../passport/progress/passport_continent_snapshot.dart';
import '../../passport/progress/passport_progress_v2.dart';
import '../atlas/atlas_personal_list_screen.dart';
import '../design/geopoint_design.dart';
import 'passport_continent_screen.dart';
import 'passport_world_map.dart';

class PassportWorldScreen extends StatefulWidget {
  const PassportWorldScreen({
    required this.controller,
    super.key,
  });

  final GameController controller;

  @override
  State<PassportWorldScreen> createState() => _PassportWorldScreenState();
}

class _PassportWorldScreenState extends State<PassportWorldScreen> {
  PassportWorldMapMode _mapMode = PassportWorldMapMode.knowledge;

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

  @override
  Widget build(BuildContext context) {
    final PassportProgressV2 progress = widget.controller.passportProgress;
    final List<GeoCountry> countries = widget.controller.countries;
    final List<_ContinentSummary> continents = _buildContinentSummaries(
      countries: countries,
      progress: progress,
    );
    final int totalEntityCount = countries
        .map((GeoCountry country) => country.id.trim().toUpperCase())
        .where((String entityId) => entityId.isNotEmpty)
        .toSet()
        .length;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 38),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'MON MONDE',
                      subtitle: 'Découvertes, maîtrise et voyages',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 22),
                    _WorldSummaryCard(
                      progress: progress,
                      totalEntityCount: totalEntityCount,
                    ),
                    const SizedBox(height: 24),
                    const GeoSectionHeading(
                      eyebrow: 'CARTE MONDIALE',
                      title: 'Visualise ta progression',
                      description:
                          'Déplace et zoome la carte, puis change de vue pour '
                          'retrouver tes voyages personnels.',
                    ),
                    const SizedBox(height: 14),
                    _WorldMapCard(
                      countries: countries,
                      progress: progress,
                      mode: _mapMode,
                      onModeChanged: (PassportWorldMapMode mode) {
                        setState(() {
                          _mapMode = mode;
                        });
                      },
                    ),
                    const SizedBox(height: 25),
                    const GeoSectionHeading(
                      eyebrow: 'CONTINENTS',
                      title: 'Progresse zone par zone',
                      description:
                          'Chaque zone possède son propre taux de découverte et '
                          'de maîtrise.',
                    ),
                    const SizedBox(height: 14),
                    _ContinentGrid(
                      summaries: continents,
                      onPressed: (_ContinentSummary summary) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return PassportContinentScreen(
                                controller: widget.controller,
                                continent: summary.continent,
                                color: summary.color,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _PersonalWorldCard(
                      controller: widget.controller,
                      progress: progress,
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

class _WorldSummaryCard extends StatelessWidget {
  const _WorldSummaryCard({
    required this.progress,
    required this.totalEntityCount,
  });

  final PassportProgressV2 progress;
  final int totalEntityCount;

  double get _discoveryProgress {
    if (totalEntityCount <= 0) {
      return 0;
    }

    return (progress.discoveredEntityCount / totalEntityCount)
        .clamp(0, 1)
        .toDouble();
  }

  double get _masteryProgress {
    if (totalEntityCount <= 0) {
      return 0;
    }

    return (progress.masteredEntityCount / totalEntityCount)
        .clamp(0, 1)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
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
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isWide = constraints.maxWidth >= 620;
          final Widget title = Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: GeoColors.blue,
                  size: 34,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${progress.discoveredEntityCount}/$totalEntityCount',
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'entités découvertes',
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final Widget bars = Column(
            children: <Widget>[
              _SummaryProgressBar(
                label: 'Découverte',
                value: _discoveryProgress,
                count: progress.discoveredEntityCount,
                color: GeoColors.blue,
              ),
              const SizedBox(height: 13),
              _SummaryProgressBar(
                label: 'Maîtrise',
                value: _masteryProgress,
                count: progress.masteredEntityCount,
                color: GeoColors.mint,
              ),
            ],
          );

          if (isWide) {
            return Row(
              children: <Widget>[
                Expanded(flex: 4, child: title),
                const SizedBox(width: 30),
                Expanded(flex: 6, child: bars),
              ],
            );
          }

          return Column(
            children: <Widget>[
              title,
              const SizedBox(height: 18),
              bars,
              const SizedBox(height: 17),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CompactSummary(
                      value: '${progress.unlockedCountryStampCount}',
                      label: 'Tampons-pays',
                      icon: Icons.approval_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompactSummary(
                      value: '${progress.learningEntityCount}',
                      label: 'En apprentissage',
                      icon: Icons.auto_stories_rounded,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryProgressBar extends StatelessWidget {
  const _SummaryProgressBar({
    required this.label,
    required this.value,
    required this.count,
    required this.color,
  });

  final String label;
  final double value;
  final int count;
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
              '$count',
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
            backgroundColor: Colors.white,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CompactSummary extends StatelessWidget {
  const _CompactSummary({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: GeoColors.blue, size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
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
                    fontSize: 8,
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

class _WorldMapCard extends StatelessWidget {
  const _WorldMapCard({
    required this.countries,
    required this.progress,
    required this.mode,
    required this.onModeChanged,
  });

  final List<GeoCountry> countries;
  final PassportProgressV2 progress;
  final PassportWorldMapMode mode;
  final ValueChanged<PassportWorldMapMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _MapModeButton(
                  label: 'Apprentissage',
                  icon: Icons.school_rounded,
                  isSelected: mode == PassportWorldMapMode.knowledge,
                  onPressed: () {
                    onModeChanged(PassportWorldMapMode.knowledge);
                  },
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _MapModeButton(
                  label: 'Mes voyages',
                  icon: Icons.flight_takeoff_rounded,
                  isSelected: mode == PassportWorldMapMode.travel,
                  onPressed: () {
                    onModeChanged(PassportWorldMapMode.travel);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: SizedBox(
              height: 285,
              child: PassportWorldMap(
                countries: countries,
                progress: progress,
                mode: mode,
              ),
            ),
          ),
          const SizedBox(height: 11),
          _MapLegend(mode: mode),
        ],
      ),
    );
  }
}

class _MapModeButton extends StatelessWidget {
  const _MapModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? GeoColors.blue : const Color(0xFFEAF1F8),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                color: isSelected ? Colors.white : GeoColors.ink,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: isSelected ? Colors.white : GeoColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.mode});

  final PassportWorldMapMode mode;

  @override
  Widget build(BuildContext context) {
    final List<_LegendItem> items = mode == PassportWorldMapMode.knowledge
        ? const <_LegendItem>[
            _LegendItem('Non découvert', Color(0xFFAAB8C8)),
            _LegendItem('Découvert', Color(0xFF6FC6F2)),
            _LegendItem('Apprentissage', Color(0xFFA985F8)),
            _LegendItem('Maîtrisé', Color(0xFF55D6A6)),
          ]
        : const <_LegendItem>[
            _LegendItem('Aucun', Color(0xFFD1D9E3)),
            _LegendItem('Visité', Color(0xFF55D6A6)),
            _LegendItem('À visiter', Color(0xFFFF756B)),
            _LegendItem('Favori', Color(0xFFFFCE59)),
          ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 7,
      children: items.map<Widget>((_LegendItem item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              item.label,
              style: GoogleFonts.nunitoSans(
                color: GeoColors.mutedInk,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }
}

class _LegendItem {
  const _LegendItem(this.label, this.color);

  final String label;
  final Color color;
}

class _ContinentGrid extends StatelessWidget {
  const _ContinentGrid({
    required this.summaries,
    required this.onPressed,
  });

  final List<_ContinentSummary> summaries;
  final ValueChanged<_ContinentSummary> onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = 12;
        final int columnCount = constraints.maxWidth >= 720 ? 3 : 2;
        final double width =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: summaries.map<Widget>((_ContinentSummary summary) {
            return SizedBox(
              width: width,
              height: 176,
              child: _ContinentCard(
                summary: summary,
                onPressed: () => onPressed(summary),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _ContinentCard extends StatelessWidget {
  const _ContinentCard({
    required this.summary,
    required this.onPressed,
  });

  final _ContinentSummary summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: summary.color,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 22,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          summary.continent.label.toUpperCase(),
                          maxLines: 1,
                          style: GoogleFonts.fredoka(
                            color: GeoColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: GeoColors.ink,
                    size: 19,
                  ),
                ],
              ),
              const Spacer(),
              _ContinentProgressLine(
                label: 'Découverts',
                count: summary.discoveredCount,
                total: summary.totalCount,
                progress: summary.discoveryProgress,
                color: GeoColors.blue,
              ),
              const SizedBox(height: 10),
              _ContinentProgressLine(
                label: 'Maîtrisés',
                count: summary.masteredCount,
                total: summary.totalCount,
                progress: summary.masteryProgress,
                color: const Color(0xFF16815D),
              ),
              const SizedBox(height: 8),
              Text(
                '${summary.stampCount} '
                '${summary.stampCount > 1 ? "tampons-pays" : "tampon-pays"}',
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.ink.withValues(alpha: 0.72),
                  fontSize: 9,
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

class _ContinentProgressLine extends StatelessWidget {
  const _ContinentProgressLine({
    required this.label,
    required this.count,
    required this.total,
    required this.progress,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final double progress;
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
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '$count/$total',
              style: GoogleFonts.fredoka(
                color: GeoColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.66),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PersonalWorldCard extends StatelessWidget {
  const _PersonalWorldCard({
    required this.controller,
    required this.progress,
  });

  final GameController controller;
  final PassportProgressV2 progress;

  void _openList(BuildContext context, AtlasPersonalListType type) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return AtlasPersonalListScreen(
            controller: controller,
            type: type,
          );
        },
      ),
    );
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'MON MONDE PERSONNEL',
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _PersonalCounter(
                  value: progress.visitedEntityCount,
                  label: 'Visités',
                  color: GeoColors.mint,
                  onPressed: () {
                    _openList(context, AtlasPersonalListType.visited);
                  },
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _PersonalCounter(
                  value: progress.wishlistedEntityCount,
                  label: 'À visiter',
                  color: GeoColors.coral,
                  onPressed: () {
                    _openList(context, AtlasPersonalListType.wishlist);
                  },
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _PersonalCounter(
                  value: progress.favoriteEntityCount,
                  label: 'Favoris',
                  color: GeoColors.gold,
                  onPressed: () {
                    _openList(context, AtlasPersonalListType.favorite);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonalCounter extends StatelessWidget {
  const _PersonalCounter({
    required this.value,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final int value;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 7),
          child: Column(
            children: <Widget>[
              Text(
                '$value',
                style: GoogleFonts.fredoka(
                  color: GeoColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.ink,
                  fontSize: 9,
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

class _ContinentSummary {
  const _ContinentSummary({
    required this.continent,
    required this.color,
    required this.totalCount,
    required this.discoveredCount,
    required this.masteredCount,
    required this.stampCount,
  });

  final PassportContinent continent;
  final Color color;
  final int totalCount;
  final int discoveredCount;
  final int masteredCount;
  final int stampCount;

  double get discoveryProgress {
    if (totalCount <= 0) {
      return 0;
    }

    return (discoveredCount / totalCount).clamp(0, 1).toDouble();
  }

  double get masteryProgress {
    if (totalCount <= 0) {
      return 0;
    }

    return (masteredCount / totalCount).clamp(0, 1).toDouble();
  }
}

List<_ContinentSummary> _buildContinentSummaries({
  required List<GeoCountry> countries,
  required PassportProgressV2 progress,
}) {
  return PassportContinentSnapshot.buildAll(
    countries: countries,
    progress: progress,
  ).map<_ContinentSummary>(
    (PassportContinentSnapshot snapshot) {
      return _ContinentSummary(
        continent: snapshot.continent,
        color: _colorForContinent(snapshot.continent),
        totalCount: snapshot.totalCount,
        discoveredCount: snapshot.discoveredCount,
        masteredCount: snapshot.masteredCount,
        stampCount: snapshot.stampCount,
      );
    },
  ).toList(growable: false);
}

Color _colorForContinent(PassportContinent continent) {
  switch (continent) {
    case PassportContinent.africa:
      return const Color(0xFFF2A65A);
    case PassportContinent.americas:
      return const Color(0xFF69DEB5);
    case PassportContinent.asia:
      return const Color(0xFFFF8A80);
    case PassportContinent.europe:
      return const Color(0xFF6FC6F2);
    case PassportContinent.oceania:
      return const Color(0xFFB59AF4);
    case PassportContinent.polar:
      return const Color(0xFFDCEFF7);
  }
}
