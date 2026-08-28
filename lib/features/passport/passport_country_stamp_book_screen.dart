import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geo_engine/geo_country.dart';
import '../../passport/progress/passport_entity_progress.dart';
import '../../passport/progress/passport_progress_rules.dart';
import '../../passport/progress/passport_progress_v2.dart';
import '../../passport/settings/passport_display_preferences.dart';
import '../../passport/settings/passport_display_preferences_storage.dart';
import '../design/geopoint_design.dart';
import 'passport_country_stamp_view.dart';

class PassportCountryStampBookScreen extends StatefulWidget {
  const PassportCountryStampBookScreen({
    required this.controller,
    super.key,
  });

  final GameController controller;

  @override
  State<PassportCountryStampBookScreen> createState() =>
      _PassportCountryStampBookScreenState();
}

class _PassportCountryStampBookScreenState
    extends State<PassportCountryStampBookScreen> {
  _StampFilter _filter = _StampFilter.all;
  PassportDisplayPreferences _preferences =
      PassportDisplayPreferences.initial();
  bool _savingPreferences = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final PassportDisplayPreferences preferences =
          await PassportDisplayPreferencesStorage.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = preferences;
      });
    } on Object catch (_) {
      // Les animations restent activées si le réglage est illisible.
    }
  }

  Future<void> _setStampAnimationsEnabled(bool value) async {
    if (_savingPreferences) {
      return;
    }

    final PassportDisplayPreferences previous = _preferences;
    final PassportDisplayPreferences updated = _preferences.copyWith(
      stampAnimationsEnabled: value,
    );

    setState(() {
      _preferences = updated;
      _savingPreferences = true;
    });

    final bool saved = await PassportDisplayPreferencesStorage.save(updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _savingPreferences = false;
      if (!saved) {
        _preferences = previous;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PassportProgressV2 passport = widget.controller.passportProgress;
    final List<_StampEntry> allEntries = widget.controller.countries
        .map(
          (GeoCountry country) => _StampEntry(
            country: country,
            progress: passport.progressFor(country.id),
          ),
        )
        .toList(growable: false)
      ..sort(
        (_StampEntry first, _StampEntry second) =>
            first.country.name.compareTo(second.country.name),
      );
    final List<_StampEntry> visibleEntries = allEntries
        .where((_StampEntry entry) => _filter.includes(entry))
        .toList(growable: false);
    final int learnedCount = allEntries
        .where(
          (_StampEntry entry) =>
              entry.progress.stampStage == PassportCountryStampStage.learned,
        )
        .length;
    final int masteredCount = allEntries
        .where(
          (_StampEntry entry) =>
              entry.progress.stampStage == PassportCountryStampStage.mastered,
        )
        .length;

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
                            title: 'MES TAMPONS',
                            subtitle: 'Ta collection du monde entier',
                            onBack: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 22),
                          _StampBookSummary(
                            unlockedCount: passport.unlockedCountryStampCount,
                            totalCount: allEntries.length,
                            learnedCount: learnedCount,
                            masteredCount: masteredCount,
                          ),
                          const SizedBox(height: 23),
                          const GeoSectionHeading(
                            eyebrow: 'CARNET DE VOYAGE',
                            title: 'Collectionne le monde',
                            description:
                                'Une première bonne réponse débloque le tampon. '
                                'Il évolue ensuite avec ta maîtrise du pays.',
                          ),
                          const SizedBox(height: 13),
                          _StampLegend(
                            animationsEnabled:
                                _preferences.stampAnimationsEnabled,
                            saving: _savingPreferences,
                            onAnimationsChanged: _setStampAnimationsEnabled,
                          ),
                          const SizedBox(height: 13),
                          _StampFilterBar(
                            selected: _filter,
                            entries: allEntries,
                            onSelected: (_StampFilter filter) {
                              setState(() {
                                _filter = filter;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${visibleEntries.length} tampon'
                            '${visibleEntries.length > 1 ? 's' : ''}',
                            style: GoogleFonts.nunitoSans(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 38),
                      sliver: SliverLayoutBuilder(
                        builder: (
                          BuildContext context,
                          SliverConstraints constraints,
                        ) {
                          final int columns = constraints.crossAxisExtent >= 760
                              ? 4
                              : constraints.crossAxisExtent >= 520
                                  ? 3
                                  : 2;

                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              mainAxisExtent: 196,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (BuildContext context, int index) {
                                final _StampEntry entry = visibleEntries[index];

                                return _CountryStampCard(
                                  entry: entry,
                                  onPressed: () {
                                    _showStampDetails(context, entry);
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

class _StampBookSummary extends StatelessWidget {
  const _StampBookSummary({
    required this.unlockedCount,
    required this.totalCount,
    required this.learnedCount,
    required this.masteredCount,
  });

  final int unlockedCount;
  final int totalCount;
  final int learnedCount;
  final int masteredCount;

  @override
  Widget build(BuildContext context) {
    final double progress = totalCount <= 0 ? 0 : unlockedCount / totalCount;

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
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.approval_rounded,
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
                      '$unlockedCount/$totalCount',
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 29,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'tampons obtenus',
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
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress.clamp(0, 1).toDouble(),
              backgroundColor: Colors.white,
              color: GeoColors.blue,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryCounter(
                  value: unlockedCount,
                  label: 'Débloqués',
                  color: GeoColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCounter(
                  value: learnedCount,
                  label: 'Appris',
                  color: GeoColors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCounter(
                  value: masteredCount,
                  label: 'Maîtrisés',
                  color: GeoColors.mint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCounter extends StatelessWidget {
  const _SummaryCounter({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '$value',
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
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
    );
  }
}

class _StampLegend extends StatelessWidget {
  const _StampLegend({
    required this.animationsEnabled,
    required this.saving,
    required this.onAnimationsChanged,
  });

  final bool animationsEnabled;
  final bool saving;
  final ValueChanged<bool> onAnimationsChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 7,
            children: <Widget>[
              _LegendDot('Découvert', GeoColors.blue),
              _LegendDot('Appris', GeoColors.purple),
              _LegendDot('Maîtrisé', GeoColors.mint),
              _LegendDot('Territoire', GeoColors.gold),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: <Widget>[
              const Icon(
                Icons.animation_rounded,
                color: GeoColors.ink,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Animation des nouveaux tampons',
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Switch.adaptive(
                value: animationsEnabled,
                onChanged: saving ? null : onAnimationsChanged,
                activeTrackColor: GeoColors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            color: GeoColors.mutedInk,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _StampFilterBar extends StatelessWidget {
  const _StampFilterBar({
    required this.selected,
    required this.entries,
    required this.onSelected,
  });

  final _StampFilter selected;
  final List<_StampEntry> entries;
  final ValueChanged<_StampFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _StampFilter.values.map<Widget>((_StampFilter filter) {
          final int count = entries.where(filter.includes).length;
          final bool isSelected = filter == selected;

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

class _CountryStampCard extends StatelessWidget {
  const _CountryStampCard({
    required this.entry,
    required this.onPressed,
  });

  final _StampEntry entry;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool locked =
        entry.progress.stampStage == PassportCountryStampStage.locked;

    return Material(
      color: const Color(0xFFF4F8FC),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            children: <Widget>[
              Expanded(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: PassportCountryStampView(
                    country: entry.country,
                    progress: entry.progress,
                    size: 126,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                locked ? '???' : entry.country.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (entry.country.isTerritory)
                Text(
                  'TERRITOIRE',
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.mutedInk,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showStampDetails(BuildContext context, _StampEntry entry) {
  final DateTime? unlockedAt = entry.progress.stampUnlockedAt;
  final bool unlocked = unlockedAt != null;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: Color(0xFFF4F8FC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF9BAABD),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 15),
              PassportCountryStampView(
                country: entry.country,
                progress: entry.progress,
                size: 176,
              ),
              const SizedBox(height: 9),
              Text(
                unlocked ? entry.country.name : 'Tampon à découvrir',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: GeoColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                unlocked
                    ? '${passportStampStageLabel(entry.progress.stampStage)} • '
                        '${_formatDate(unlockedAt)} • '
                        '${_sourceLabel(entry.progress.stampUnlockSource)}'
                    : 'Réussis une première réponse sur cette entité pour '
                        'débloquer son tampon.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.mutedInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              if (unlocked && entry.country.isTerritory) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: GeoColors.gold.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    entry.country.sovereignName.isEmpty
                        ? 'Territoire'
                        : 'Territoire rattaché à '
                            '${entry.country.sovereignName}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

enum _StampFilter {
  all('Tous'),
  unlocked('Obtenus'),
  learned('Appris'),
  mastered('Maîtrisés'),
  territories('Territoires');

  const _StampFilter(this.label);

  final String label;

  bool includes(_StampEntry entry) {
    switch (this) {
      case _StampFilter.all:
        return true;
      case _StampFilter.unlocked:
        return entry.progress.stampUnlockedAt != null;
      case _StampFilter.learned:
        return entry.progress.stampStage == PassportCountryStampStage.learned;
      case _StampFilter.mastered:
        return entry.progress.stampStage ==
            PassportCountryStampStage.mastered;
      case _StampFilter.territories:
        return entry.country.isTerritory;
    }
  }
}

class _StampEntry {
  const _StampEntry({
    required this.country,
    required this.progress,
  });

  final GeoCountry country;
  final PassportEntityProgress progress;
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
