import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geobrain/geobrain_dashboard.dart';
import '../../geobrain/geobrain_theme.dart';
import '../../geobrain/geobrain_training_suggestion.dart';
import '../../passport/progress/passport_continent.dart';
import '../design/geopoint_design.dart';
import '../training/training_screen.dart';

class GeoBrainScreen extends StatefulWidget {
  const GeoBrainScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<GeoBrainScreen> createState() => _GeoBrainScreenState();
}

class _GeoBrainScreenState extends State<GeoBrainScreen> {
  final Set<String> _ignoredSuggestionIds = <String>{};

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openTraining(GeoBrainTrainingSuggestion suggestion) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TrainingScreen(
          controller: controller,
          suggestion: suggestion,
        ),
      ),
    );
  }

  void _openReviewTraining() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TrainingScreen(
          controller: controller,
          reviewDifficultiesOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final GeoBrainDashboardSnapshot dashboard =
        const GeoBrainDashboardBuilder().build(
      profile: controller.geoBrainService.profile,
      countries: controller.countries,
      now: now,
    );
    final List<GeoBrainTrainingSuggestion> suggestions =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: controller.geoBrainService.profile,
      countries: controller.countries,
      now: now,
      ignoredSuggestionIds: _ignoredSuggestionIds,
      maximumSuggestions: 1,
    );
    final GeoBrainTrainingSuggestion? nextSuggestion =
        suggestions.isEmpty ? null : suggestions.first;

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
                      title: 'MON GEOBRAIN',
                      subtitle: 'Ce que tu sais vraiment du monde',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 22),
                    _GeoBrainSummaryCard(dashboard: dashboard),
                    const SizedBox(height: 24),
                    const GeoSectionHeading(
                      eyebrow: 'PROCHAINE ÉTAPE',
                      title: 'Ta séance conseillée',
                      description:
                          'GeoBrain choisit une séance courte à partir de tes réponses réelles.',
                    ),
                    const SizedBox(height: 13),
                    if (nextSuggestion != null)
                      _NextSessionCard(
                        suggestion: nextSuggestion,
                        onStart: () => _openTraining(nextSuggestion),
                        onIgnore: () {
                          setState(() {
                            _ignoredSuggestionIds.add(nextSuggestion.id);
                          });
                        },
                      )
                    else
                      const _PositiveEmptyCard(
                        icon: Icons.check_circle_rounded,
                        title: 'Tout est à jour',
                        message:
                            'Continue à jouer : GeoBrain préparera une séance dès qu’elle sera utile.',
                      ),
                    const SizedBox(height: 24),
                    const GeoSectionHeading(
                      eyebrow: 'FORCES ACTUELLES',
                      title: 'Tes meilleurs repères',
                      description:
                          'Les thèmes où tes réponses restent les plus solides aujourd’hui.',
                    ),
                    const SizedBox(height: 13),
                    if (dashboard.strengths.isEmpty)
                      const _PositiveEmptyCard(
                        icon: Icons.explore_rounded,
                        title: 'Ton aventure commence',
                        message:
                            'Quelques parties suffiront pour faire apparaître tes premières forces.',
                      )
                    else
                      _StrengthGrid(strengths: dashboard.strengths),
                    const SizedBox(height: 24),
                    _SectionTitleWithAction(
                      eyebrow: 'À RÉVISER',
                      title: 'Connaissances à consolider',
                      description:
                          'Une révision douce pour entretenir tes acquis sans effacer tes progrès.',
                      actionLabel: dashboard.reviewCountries.isEmpty
                          ? null
                          : 'RÉVISER',
                      onAction: dashboard.reviewCountries.isEmpty
                          ? null
                          : _openReviewTraining,
                    ),
                    const SizedBox(height: 13),
                    if (dashboard.reviewCountries.isEmpty)
                      const _PositiveEmptyCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Aucune urgence',
                        message:
                            'Tes connaissances suivies sont à jour pour le moment.',
                      )
                    else
                      _ReviewCountryList(
                        countries: dashboard.reviewCountries.take(4).toList(),
                        onCountryPressed: _openCountry,
                      ),
                    const SizedBox(height: 24),
                    const GeoSectionHeading(
                      eyebrow: 'PAR THÈME',
                      title: 'Sept connaissances indépendantes',
                      description:
                          'Un pays peut être acquis en drapeau et encore fragile en capitale.',
                    ),
                    const SizedBox(height: 13),
                    _ThemeProgressCard(themes: dashboard.themes),
                    const SizedBox(height: 24),
                    const GeoSectionHeading(
                      eyebrow: 'PAR CONTINENT',
                      title: 'Ton équilibre géographique',
                      description:
                          'Repère les zones déjà solides et celles qu’il reste à explorer.',
                    ),
                    const SizedBox(height: 13),
                    _ContinentProgressGrid(continents: dashboard.continents),
                    const SizedBox(height: 24),
                    _CountryAccessCard(
                      countryCount: dashboard.countries.length,
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                GeoBrainCountriesScreen(
                              countries: dashboard.countries,
                            ),
                          ),
                        );
                      },
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

  void _openCountry(GeoBrainCountrySnapshot country) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            GeoBrainCountryDetailScreen(country: country),
      ),
    );
  }
}

class _GeoBrainSummaryCard extends StatelessWidget {
  const _GeoBrainSummaryCard({required this.dashboard});

  final GeoBrainDashboardSnapshot dashboard;

  @override
  Widget build(BuildContext context) {
    final int score = dashboard.globalRetainedScore.round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF6558D3), Color(0xFF40378D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: GeoColors.gold, width: 3),
                ),
                child: Text(
                  '$score%',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'MAÎTRISE CONSERVÉE',
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _summaryMessage(dashboard),
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              _SummaryMetric(
                value: '${dashboard.seenCountryCount}',
                label: 'découverts',
              ),
              _SummaryMetric(
                value: '${dashboard.masteredCountryCount}',
                label: 'maîtrisés',
              ),
              _SummaryMetric(
                value: '${dashboard.reviewCountryCount}',
                label: 'à réviser',
              ),
              _SummaryMetric(
                value: '${(dashboard.globalAccuracy * 100).round()}%',
                label: 'réussite',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _summaryMessage(GeoBrainDashboardSnapshot value) {
    if (value.totalAttempts == 0) {
      return 'Prêt à apprendre avec toi';
    }
    if (value.reviewCountryCount > 0) {
      return 'Tes acquis restent bien suivis';
    }
    return 'Tes connaissances sont à jour';
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({
    required this.suggestion,
    required this.onStart,
    required this.onIgnore,
  });

  final GeoBrainTrainingSuggestion suggestion;
  final VoidCallback onStart;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _RoundIcon(
                icon: Icons.psychology_alt_rounded,
                color: GeoColors.purple,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      suggestion.title,
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      suggestion.reason,
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _PillLabel(text: '${suggestion.questionCount} questions'),
              const Spacer(),
              TextButton(onPressed: onIgnore, child: const Text('IGNORER')),
              const SizedBox(width: 5),
              SizedBox(
                width: 124,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('LANCER'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StrengthGrid extends StatelessWidget {
  const _StrengthGrid({required this.strengths});

  final List<GeoBrainThemeProgress> strengths;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 680 ? 3 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: strengths.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 1 ? 3.5 : 1.5,
          ),
          itemBuilder: (BuildContext context, int index) {
            final GeoBrainThemeProgress progress = strengths[index];
            return _WhiteCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  _RoundIcon(
                    icon: _iconForTheme(progress.theme),
                    color: _colorForTheme(progress.theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          progress.theme.label,
                          style: GoogleFonts.fredoka(
                            color: GeoColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${progress.retainedScore.round()}% • ${progress.seenCountryCount} pays',
                          style: GoogleFonts.nunitoSans(
                            color: GeoColors.mutedInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ReviewCountryList extends StatelessWidget {
  const _ReviewCountryList({
    required this.countries,
    required this.onCountryPressed,
  });

  final List<GeoBrainCountrySnapshot> countries;
  final ValueChanged<GeoBrainCountrySnapshot> onCountryPressed;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < countries.length; index++) ...<Widget>[
            _CountryRow(
              country: countries[index],
              onPressed: () => onCountryPressed(countries[index]),
            ),
            if (index < countries.length - 1)
              const Divider(height: 1, indent: 64),
          ],
        ],
      ),
    );
  }
}

class _ThemeProgressCard extends StatelessWidget {
  const _ThemeProgressCard({required this.themes});

  final List<GeoBrainThemeProgress> themes;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        children: <Widget>[
          for (int index = 0; index < themes.length; index++) ...<Widget>[
            _ThemeProgressRow(progress: themes[index]),
            if (index < themes.length - 1) const SizedBox(height: 15),
          ],
        ],
      ),
    );
  }
}

class _ThemeProgressRow extends StatelessWidget {
  const _ThemeProgressRow({required this.progress});

  final GeoBrainThemeProgress progress;

  @override
  Widget build(BuildContext context) {
    final double value = (progress.retainedScore / 100).clamp(0, 1).toDouble();
    return Row(
      children: <Widget>[
        Icon(
          _iconForTheme(progress.theme),
          color: _colorForTheme(progress.theme),
          size: 23,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      progress.theme.label,
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${progress.retainedScore.round()}%',
                    style: GoogleFonts.fredoka(
                      color: GeoColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE8E8EF),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _colorForTheme(progress.theme),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                progress.seenCountryCount == 0
                    ? 'Pas encore exploré'
                    : '${progress.seenCountryCount} pays suivis'
                        '${progress.reviewCountryCount > 0 ? ' • ${progress.reviewCountryCount} à réviser' : ''}',
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
    );
  }
}

class _ContinentProgressGrid extends StatelessWidget {
  const _ContinentProgressGrid({required this.continents});

  final List<GeoBrainContinentProgress> continents;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 680 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: continents.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 2 ? 1.25 : 1.4,
          ),
          itemBuilder: (BuildContext context, int index) {
            return _ContinentProgressCard(progress: continents[index]);
          },
        );
      },
    );
  }
}

class _ContinentProgressCard extends StatelessWidget {
  const _ContinentProgressCard({required this.progress});

  final GeoBrainContinentProgress progress;

  @override
  Widget build(BuildContext context) {
    final Color color = _colorForContinent(progress.continent);
    return _WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.public_rounded, color: color, size: 23),
              const Spacer(),
              Text(
                '${progress.retainedScore.round()}%',
                style: GoogleFonts.fredoka(
                  color: GeoColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            progress.continent.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${progress.seenCountryCount}/${progress.totalCountryCount} découverts',
            style: GoogleFonts.nunitoSans(
              color: GeoColors.mutedInk,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (progress.reviewCountryCount > 0)
            Text(
              '${progress.reviewCountryCount} à réviser',
              style: GoogleFonts.nunitoSans(
                color: GeoColors.coral,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _CountryAccessCard extends StatelessWidget {
  const _CountryAccessCard({
    required this.countryCount,
    required this.onPressed,
  });

  final int countryCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: <Widget>[
              const _RoundIcon(
                icon: Icons.menu_book_rounded,
                color: GeoColors.mint,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Détail pays par pays',
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$countryCount fiches • 7 thèmes par territoire',
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: GeoColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class GeoBrainCountriesScreen extends StatefulWidget {
  const GeoBrainCountriesScreen({required this.countries, super.key});

  final List<GeoBrainCountrySnapshot> countries;

  @override
  State<GeoBrainCountriesScreen> createState() =>
      _GeoBrainCountriesScreenState();
}

class _GeoBrainCountriesScreenState extends State<GeoBrainCountriesScreen> {
  String _query = '';
  bool _reviewOnly = false;

  @override
  Widget build(BuildContext context) {
    final String normalizedQuery = _query.trim().toLowerCase();
    final List<GeoBrainCountrySnapshot> visible = widget.countries
        .where(
          (GeoBrainCountrySnapshot country) =>
              (!_reviewOnly || country.needsReview) &&
              (normalizedQuery.isEmpty ||
                  country.countryName.toLowerCase().contains(normalizedQuery)),
        )
        .toList(growable: false);
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: GeoGameTopBar(
                        title: 'FICHES GEOBRAIN',
                        subtitle: '${visible.length} pays et territoires',
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                      child: Column(
                        children: <Widget>[
                          TextField(
                            onChanged: (String value) {
                              setState(() {
                                _query = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Rechercher un pays',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilterChip(
                              selected: _reviewOnly,
                              label: const Text('À réviser seulement'),
                              avatar: const Icon(Icons.refresh_rounded, size: 18),
                              onSelected: (bool value) {
                                setState(() {
                                  _reviewOnly = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: _PositiveEmptyCard(
                                icon: Icons.search_off_rounded,
                                title: 'Aucun résultat',
                                message: 'Essaie un autre nom ou retire le filtre.',
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                              itemCount: visible.length,
                              separatorBuilder:
                                  (BuildContext context, int index) =>
                                      const SizedBox(height: 9),
                              itemBuilder: (BuildContext context, int index) {
                                final GeoBrainCountrySnapshot country =
                                    visible[index];
                                return _WhiteCard(
                                  padding: EdgeInsets.zero,
                                  child: _CountryRow(
                                    country: country,
                                    onPressed: () {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (BuildContext context) =>
                                              GeoBrainCountryDetailScreen(
                                            country: country,
                                          ),
                                        ),
                                      );
                                    },
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

class GeoBrainCountryDetailScreen extends StatelessWidget {
  const GeoBrainCountryDetailScreen({required this.country, super.key});

  final GeoBrainCountrySnapshot country;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 38),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: country.countryName.toUpperCase(),
                      subtitle: country.continent?.label ?? 'Monde',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 22),
                    _CountryHero(country: country),
                    const SizedBox(height: 22),
                    const GeoSectionHeading(
                      eyebrow: 'DÉTAIL DE LA MAÎTRISE',
                      title: 'Thème par thème',
                      description:
                          'Chaque connaissance progresse à son propre rythme.',
                    ),
                    const SizedBox(height: 13),
                    _WhiteCard(
                      child: Column(
                        children: <Widget>[
                          for (int index = 0;
                              index < country.themeProgress.length;
                              index++) ...<Widget>[
                            _CountryThemeRow(
                              progress: country.themeProgress[index],
                            ),
                            if (index < country.themeProgress.length - 1)
                              const Divider(height: 22),
                          ],
                        ],
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

class _CountryHero extends StatelessWidget {
  const _CountryHero({required this.country});

  final GeoBrainCountrySnapshot country;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _colorForStatus(country.status);
    return _WhiteCard(
      child: Column(
        children: <Widget>[
          Text(country.flagEmoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 7),
          Text(
            country.countryName,
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          _StatusBadge(status: country.status),
          const SizedBox(height: 17),
          Row(
            children: <Widget>[
              _DarkMetric(
                value: '${country.retainedScore.round()}%',
                label: 'maîtrise',
              ),
              _DarkMetric(
                value: '${country.totalAttempts}',
                label: 'tentatives',
              ),
              _DarkMetric(
                value: '${(country.accuracy * 100).round()}%',
                label: 'réussite',
              ),
            ],
          ),
          if (country.needsReview) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'À réviser • Une courte vérification aidera à consolider cet acquis.',
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
    );
  }
}

class _CountryThemeRow extends StatelessWidget {
  const _CountryThemeRow({required this.progress});

  final GeoBrainCountryThemeSnapshot progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _RoundIcon(
          icon: _iconForTheme(progress.theme),
          color: _colorForTheme(progress.theme),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                progress.theme.label,
                style: GoogleFonts.fredoka(
                  color: GeoColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                progress.totalAttempts == 0
                    ? 'Pas encore rencontré'
                    : '${progress.totalAttempts} tentatives • ${progress.retainedScore.round()}%',
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.mutedInk,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _StatusBadge(status: progress.status, compact: true),
            if (progress.needsReview)
              Text(
                'À réviser',
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.coral,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({required this.country, required this.onPressed});

  final GeoBrainCountrySnapshot country;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 38,
              child: Text(
                country.flagEmoji,
                style: const TextStyle(fontSize: 25),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    country.countryName,
                    style: GoogleFonts.fredoka(
                      color: GeoColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${country.retainedScore.round()}% • ${country.totalAttempts} tentatives',
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.mutedInk,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _StatusBadge(status: country.status, compact: true),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: GeoColors.mutedInk),
          ],
        ),
      ),
    );
  }
}

class _SectionTitleWithAction extends StatelessWidget {
  const _SectionTitleWithAction({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: GeoSectionHeading(
            eyebrow: eyebrow,
            title: title,
            description: description,
          ),
        ),
        if (actionLabel != null) ...<Widget>[
          const SizedBox(width: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

class _PositiveEmptyCard extends StatelessWidget {
  const _PositiveEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Row(
        children: <Widget>[
          _RoundIcon(icon: icon, color: GeoColors.mint),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  message,
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.mutedInk,
                    fontSize: 11,
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

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(17),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GeoColors.purple.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunitoSans(
          color: GeoColors.ink,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.compact = false});

  final GeoBrainMasteryStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color color = _colorForStatus(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.nunitoSans(
          color: GeoColors.ink,
          fontSize: compact ? 8 : 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
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
            style: GoogleFonts.nunitoSans(
              color: GeoColors.mutedInk,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForTheme(GeoBrainTheme theme) {
  switch (theme) {
    case GeoBrainTheme.location:
      return Icons.location_on_rounded;
    case GeoBrainTheme.capital:
      return Icons.account_balance_rounded;
    case GeoBrainTheme.flag:
      return Icons.flag_rounded;
    case GeoBrainTheme.silhouette:
      return Icons.gesture_rounded;
    case GeoBrainTheme.cities:
      return Icons.location_city_rounded;
    case GeoBrainTheme.currency:
      return Icons.payments_rounded;
    case GeoBrainTheme.languages:
      return Icons.translate_rounded;
  }
}

Color _colorForTheme(GeoBrainTheme theme) {
  switch (theme) {
    case GeoBrainTheme.location:
      return GeoColors.coral;
    case GeoBrainTheme.capital:
      return GeoColors.purple;
    case GeoBrainTheme.flag:
      return GeoColors.sky;
    case GeoBrainTheme.silhouette:
      return GeoColors.mint;
    case GeoBrainTheme.cities:
      return const Color(0xFFEE8A36);
    case GeoBrainTheme.currency:
      return const Color(0xFF2B9B72);
    case GeoBrainTheme.languages:
      return const Color(0xFF526BD6);
  }
}

Color _colorForStatus(GeoBrainMasteryStatus status) {
  switch (status) {
    case GeoBrainMasteryStatus.unknown:
      return const Color(0xFF9A9AA6);
    case GeoBrainMasteryStatus.discovered:
      return GeoColors.sky;
    case GeoBrainMasteryStatus.fragile:
      return GeoColors.coral;
    case GeoBrainMasteryStatus.progressing:
      return GeoColors.gold;
    case GeoBrainMasteryStatus.acquired:
      return GeoColors.mint;
    case GeoBrainMasteryStatus.mastered:
      return const Color(0xFF2B9B72);
  }
}

Color _colorForContinent(PassportContinent continent) {
  switch (continent) {
    case PassportContinent.africa:
      return const Color(0xFFE88B3F);
    case PassportContinent.americas:
      return GeoColors.coral;
    case PassportContinent.asia:
      return const Color(0xFFDEB545);
    case PassportContinent.europe:
      return GeoColors.sky;
    case PassportContinent.oceania:
      return GeoColors.mint;
    case PassportContinent.polar:
      return const Color(0xFF7896C7);
  }
}
