import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../geo_engine/capital.dart';
import '../../geo_engine/country_info.dart';
import '../../geo_engine/geo_country.dart';
import 'atlas_city.dart';
import 'atlas_personal_progress.dart';

class CountryAtlasSheet extends StatefulWidget {
  const CountryAtlasSheet({
    required this.country,
    required this.info,
    required this.capital,
    required this.cities,
    required this.initialStatus,
    required this.initialFavorite,
    required this.onToggleVisited,
    required this.onToggleWishlist,
    required this.onToggleFavorite,
    required this.onExploreCities,
    this.showExploreCitiesButton = true,
    super.key,
  });

  final GeoCountry country;
  final CountryInfo? info;
  final Capital? capital;
  final List<AtlasCity> cities;
  final AtlasCountryStatus initialStatus;
  final bool initialFavorite;
  final Future<AtlasCountryStatus> Function() onToggleVisited;
  final Future<AtlasCountryStatus> Function() onToggleWishlist;
  final Future<bool> Function() onToggleFavorite;
  final VoidCallback onExploreCities;
  final bool showExploreCitiesButton;

  @override
  State<CountryAtlasSheet> createState() => _CountryAtlasSheetState();
}

class _CountryAtlasSheetState extends State<CountryAtlasSheet> {
  late AtlasCountryStatus _status;
  late bool _favorite;
  bool _savingStatus = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _favorite = widget.initialFavorite;
  }

  @override
  void didUpdateWidget(covariant CountryAtlasSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_savingStatus && oldWidget.initialStatus != widget.initialStatus) {
      _status = widget.initialStatus;
    }

    if (!_savingStatus && oldWidget.initialFavorite != widget.initialFavorite) {
      _favorite = widget.initialFavorite;
    }
  }

  Future<void> _toggleVisited() async {
    await _changeStatus(widget.onToggleVisited);
  }

  Future<void> _toggleWishlist() async {
    await _changeStatus(widget.onToggleWishlist);
  }

  Future<void> _toggleFavorite() async {
    if (_savingStatus) {
      return;
    }

    setState(() {
      _savingStatus = true;
    });

    final bool favorite = await widget.onToggleFavorite();

    if (!mounted) {
      return;
    }

    setState(() {
      _favorite = favorite;
      _savingStatus = false;
    });
  }

  Future<void> _changeStatus(
    Future<AtlasCountryStatus> Function() action,
  ) async {
    if (_savingStatus) {
      return;
    }

    setState(() {
      _savingStatus = true;
    });

    final AtlasCountryStatus status = await action();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = status;
      _savingStatus = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final GeoCountry country = widget.country;
    final CountryInfo? countryInfo = widget.info;
    final Capital? capital = widget.capital;
    final List<AtlasCity> cities = widget.cities;
    final VoidCallback onExploreCities = widget.onExploreCities;
    final String title = countryInfo?.title ?? country.name;
    final List<AtlasCity> sortedMainCities = List<AtlasCity>.of(cities)
      ..sort((AtlasCity first, AtlasCity second) {
        if (first.isCapital != second.isCapital) {
          return first.isCapital ? -1 : 1;
        }

        return second.population.compareTo(first.population);
      });
    final List<AtlasCity> mainCities =
        sortedMainCities.take(8).toList(growable: false);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      expand: false,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F8FC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFF176BFF),
                          Color(0xFF0C3C8C),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: Text(
                      country.flagEmoji.isEmpty ? '🌍' : country.flagEmoji,
                      style: const TextStyle(fontSize: 37),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: GoogleFonts.fredoka(
                            color: const Color(0xFF071B3A),
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          countryInfo?.continent ?? country.continent,
                          style: GoogleFonts.nunitoSans(
                            color: const Color(0xFF52708F),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF52708F),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _TravelActions(
                status: _status,
                favorite: _favorite,
                busy: _savingStatus,
                onToggleVisited: _toggleVisited,
                onToggleWishlist: _toggleWishlist,
                onToggleFavorite: _toggleFavorite,
              ),
              const SizedBox(height: 22),
              if (cities.isNotEmpty &&
                  widget.showExploreCitiesButton) ...<Widget>[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onExploreCities,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF176BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.map_rounded),
                    label: Text(
                      'Explorer ${cities.length} villes sur la carte',
                      style: GoogleFonts.nunitoSans(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
              ],
              _SectionTitle(title: 'EN UN COUP D’ŒIL'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.95,
                children: <Widget>[
                  _InformationCard(
                    icon: Icons.location_city_rounded,
                    label: 'Capitale',
                    value: capital?.name ?? 'Non renseignée',
                  ),
                  _InformationCard(
                    icon: Icons.people_alt_rounded,
                    label: 'Population',
                    value: _populationLabel(countryInfo?.population),
                  ),
                  _InformationCard(
                    icon: Icons.straighten_rounded,
                    label: 'Superficie',
                    value: countryInfo?.formattedArea.isNotEmpty == true
                        ? countryInfo!.formattedArea
                        : 'Non renseignée',
                  ),
                  _InformationCard(
                    icon: Icons.payments_rounded,
                    label: 'Monnaie',
                    value: countryInfo?.currency ?? 'Non renseignée',
                  ),
                ],
              ),
              if (countryInfo != null && countryInfo.languages.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _WideInformationCard(
                  icon: Icons.translate_rounded,
                  label: 'Langues principales',
                  value: countryInfo.languages.join(', '),
                ),
              ],
              if (countryInfo?.hasShortFact == true) ...<Widget>[
                const SizedBox(height: 24),
                _SectionTitle(title: 'LE SAVAIS-TU ?'),
                const SizedBox(height: 10),
                _FactCard(
                  icon: Icons.lightbulb_rounded,
                  text: countryInfo!.shortFact!,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SmallFactCard(
                      icon: Icons.location_on_rounded,
                      value: '${cities.length}',
                      label: cities.length > 1
                          ? 'grandes villes référencées'
                          : 'grande ville référencée',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmallFactCard(
                      icon: Icons.groups_rounded,
                      value: _densityLabel(countryInfo),
                      label: 'densité moyenne',
                    ),
                  ),
                ],
              ),
              if (countryInfo?.hasHistory == true) ...<Widget>[
                const SizedBox(height: 24),
                _SectionTitle(title: 'UN PEU D’HISTOIRE'),
                const SizedBox(height: 10),
                _TextSection(text: countryInfo!.history!),
              ],
              if (mainCities.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                _SectionTitle(title: 'PRINCIPALES VILLES'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDCE6F0)),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (int index = 0;
                          index < mainCities.length;
                          index++) ...<Widget>[
                        _CityRow(
                          city: mainCities[index],
                          rank: index + 1,
                        ),
                        if (index < mainCities.length - 1)
                          const Divider(height: 1, indent: 54),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Données urbaines : GeoNames et sélection PointGeo',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  color: const Color(0xFF7C8FA5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _populationLabel(int? population) {
    if (population == null) {
      return 'Non renseignée';
    }

    return '${_groupDigits(population)} hab.';
  }

  static String _densityLabel(CountryInfo? info) {
    final int? population = info?.population;
    final double? area = info?.areaSquareKilometers;

    if (population == null || area == null || area <= 0) {
      return '—';
    }

    return '${(population / area).round()} hab./km²';
  }

  static String _groupDigits(int value) {
    final String source = value.toString();
    final StringBuffer result = StringBuffer();

    for (int index = 0; index < source.length; index++) {
      if (index > 0 && (source.length - index) % 3 == 0) {
        result.write(' ');
      }

      result.write(source[index]);
    }

    return result.toString();
  }
}

class _TravelActions extends StatelessWidget {
  const _TravelActions({
    required this.status,
    required this.favorite,
    required this.busy,
    required this.onToggleVisited,
    required this.onToggleWishlist,
    required this.onToggleFavorite,
  });

  final AtlasCountryStatus status;
  final bool favorite;
  final bool busy;
  final VoidCallback onToggleVisited;
  final VoidCallback onToggleWishlist;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final bool visited = status == AtlasCountryStatus.visited;
    final bool wishlist = status == AtlasCountryStatus.wishlist;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _TravelButton(
                label: visited ? 'VISITÉ' : 'DÉJÀ VISITÉ',
                icon: visited
                    ? Icons.check_circle_rounded
                    : Icons.flight_takeoff_rounded,
                active: visited,
                activeColor: const Color(0xFF43CFA0),
                busy: busy,
                onPressed: onToggleVisited,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TravelButton(
                label: wishlist ? 'À VISITER ✓' : 'À VISITER',
                icon: wishlist
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                active: wishlist,
                activeColor: const Color(0xFFFF756B),
                busy: busy,
                onPressed: onToggleWishlist,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          width: double.infinity,
          child: _TravelButton(
            label: favorite ? 'PAYS FAVORI ✓' : 'AJOUTER AUX FAVORIS',
            icon: favorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            active: favorite,
            activeColor: const Color(0xFFFFCE59),
            busy: busy,
            onPressed: onToggleFavorite,
          ),
        ),
      ],
    );
  }
}

class _TravelButton extends StatelessWidget {
  const _TravelButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: active ? activeColor : Colors.white,
        foregroundColor:
            active ? const Color(0xFF071B3A) : const Color(0xFF243C57),
        disabledBackgroundColor:
            active ? activeColor.withValues(alpha: 0.60) : Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: active ? activeColor : const Color(0xFFD3DFEB),
            width: active ? 1.5 : 1,
          ),
        ),
        elevation: active ? 2 : 0,
      ),
      icon: busy
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunitoSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.nunitoSans(
        color: const Color(0xFF176BFF),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F0)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFF176BFF), size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF7C8FA5),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF071B3A),
                    fontSize: 12,
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

class _WideInformationCard extends StatelessWidget {
  const _WideInformationCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF176BFF), size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF7C8FA5),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF071B3A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _FactCard extends StatelessWidget {
  const _FactCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFE19A), Color(0xFFFFC857)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF5C3B00), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunitoSans(
                color: const Color(0xFF3E2B08),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallFactCard extends StatelessWidget {
  const _SmallFactCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF176BFF), size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.fredoka(
              color: const Color(0xFF071B3A),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              color: const Color(0xFF52708F),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6F0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunitoSans(
          color: const Color(0xFF243C57),
          fontSize: 13,
          height: 1.55,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({required this.city, required this.rank});

  final AtlasCity city;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: city.isCapital
                  ? const Color(0xFFFFC857)
                  : const Color(0xFFE8F2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$rank',
              style: GoogleFonts.nunitoSans(
                color: const Color(0xFF071B3A),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  city.name,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF071B3A),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  city.primaryCategoryLabel,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF52708F),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            city.formattedPopulation,
            style: GoogleFonts.nunitoSans(
              color: const Color(0xFF52708F),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
