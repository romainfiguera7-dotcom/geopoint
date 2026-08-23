import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geo_engine/capital.dart';
import '../../geo_engine/country_info.dart';
import '../../geo_engine/country_info_loader.dart';
import '../../geo_engine/geo_country.dart';
import '../design/geopoint_design.dart';
import 'atlas_city.dart';
import 'atlas_city_loader.dart';
import 'atlas_personal_progress.dart';
import 'atlas_personal_storage.dart';
import 'country_atlas_sheet.dart';

enum AtlasPersonalListType {
  visited,
  wishlist,
}

class AtlasPersonalListScreen extends StatefulWidget {
  const AtlasPersonalListScreen({
    required this.controller,
    required this.type,
    super.key,
  });

  final GameController controller;
  final AtlasPersonalListType type;

  @override
  State<AtlasPersonalListScreen> createState() =>
      _AtlasPersonalListScreenState();
}

class _AtlasPersonalListScreenState
    extends State<AtlasPersonalListScreen> {
  late Future<_AtlasPersonalData> _dataFuture;
  AtlasPersonalProgress _progress = AtlasPersonalProgress.initial();

  bool get _showsVisited => widget.type == AtlasPersonalListType.visited;
  Color get _accentColor =>
      _showsVisited ? GeoColors.mint : GeoColors.coral;
  String get _title => _showsVisited ? 'MES VOYAGES' : 'À VISITER';
  String get _subtitle => _showsVisited
      ? 'Les pays que tu as déjà découverts'
      : 'Tes prochaines destinations rêvées';

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_AtlasPersonalData> _loadData() async {
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      CountryInfoLoader.loadCountryInfos(),
      AtlasCityLoader.loadCities(),
      AtlasPersonalStorage.load(),
    ]);

    _progress = loaded[2] as AtlasPersonalProgress;

    return _AtlasPersonalData(
      countries: List<GeoCountry>.unmodifiable(
        widget.controller.countries,
      ),
      countryInfos: loaded[0] as Map<String, CountryInfo>,
      capitals: Map<String, Capital>.unmodifiable(
        widget.controller.capitals,
      ),
      cities: loaded[1] as List<AtlasCity>,
    );
  }

  Future<AtlasCountryStatus> _toggleVisited(GeoCountry country) {
    return _saveProgress(
      _progress.toggleVisited(country.id),
      country.id,
    );
  }

  Future<AtlasCountryStatus> _toggleWishlist(GeoCountry country) {
    return _saveProgress(
      _progress.toggleWishlist(country.id),
      country.id,
    );
  }

  Future<AtlasCountryStatus> _saveProgress(
    AtlasPersonalProgress next,
    String countryId,
  ) async {
    final bool saved = await AtlasPersonalStorage.save(next);

    if (!mounted) {
      return saved
          ? next.statusFor(countryId)
          : _progress.statusFor(countryId);
    }

    if (saved) {
      setState(() {
        _progress = next;
      });
      return next.statusFor(countryId);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible de sauvegarder ce pays pour le moment.'),
      ),
    );
    return _progress.statusFor(countryId);
  }

  Future<void> _openCountry(
    _AtlasPersonalData data,
    GeoCountry country,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return CountryAtlasSheet(
          country: country,
          info: data.countryInfos[country.id],
          capital: data.capitals[country.id],
          cities: data.citiesForCountry(country),
          initialStatus: _progress.statusFor(country.id),
          onToggleVisited: () => _toggleVisited(country),
          onToggleWishlist: () => _toggleWishlist(country),
          onExploreCities: () => Navigator.of(context).pop(),
          showExploreCitiesButton: false,
        );
      },
    );
  }

  List<GeoCountry> _listedCountries(_AtlasPersonalData data) {
    final Set<String> ids = _showsVisited
        ? _progress.visitedCountryIds
        : _progress.wishlistCountryIds;
    final List<GeoCountry> countries = data.countries.where(
      (GeoCountry country) {
        return ids.contains(country.id.trim().toUpperCase());
      },
    ).toList();

    countries.sort((GeoCountry first, GeoCountry second) {
      final String firstName =
          data.countryInfos[first.id]?.title ?? first.name;
      final String secondName =
          data.countryInfos[second.id]?.title ?? second.name;
      return firstName.compareTo(secondName);
    });

    return countries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: FutureBuilder<_AtlasPersonalData>(
              future: _dataFuture,
              builder: (
                BuildContext context,
                AsyncSnapshot<_AtlasPersonalData> snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return _PersonalListError(
                    onRetry: () {
                      setState(() {
                        _dataFuture = _loadData();
                      });
                    },
                  );
                }

                final _AtlasPersonalData data = snapshot.data!;
                final List<GeoCountry> countries = _listedCountries(data);

                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                      children: <Widget>[
                        GeoGameTopBar(
                          title: _title,
                          subtitle: _subtitle,
                          onBack: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 24),
                        _ListSummary(
                          count: countries.length,
                          visited: _showsVisited,
                          color: _accentColor,
                        ),
                        const SizedBox(height: 16),
                        if (countries.isEmpty)
                          _EmptyPersonalList(visited: _showsVisited)
                        else
                          for (int index = 0;
                              index < countries.length;
                              index++) ...<Widget>[
                            _CountryTravelCard(
                              country: countries[index],
                              title: data.countryInfos[countries[index].id]
                                      ?.title ??
                                  countries[index].name,
                              visited: _showsVisited,
                              onPressed: () =>
                                  _openCountry(data, countries[index]),
                            ),
                            if (index < countries.length - 1)
                              const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSummary extends StatelessWidget {
  const _ListSummary({
    required this.count,
    required this.visited,
    required this.color,
  });

  final int count;
  final bool visited;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white54),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            visited
                ? Icons.flight_takeoff_rounded
                : Icons.favorite_rounded,
            color: GeoColors.navy,
            size: 31,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              count == 0
                  ? 'Aucun pays enregistré'
                  : '$count ${count > 1 ? 'pays enregistrés' : 'pays enregistré'}',
              style: GoogleFonts.fredoka(
                color: GeoColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryTravelCard extends StatelessWidget {
  const _CountryTravelCard({
    required this.country,
    required this.title,
    required this.visited,
    required this.onPressed,
  });

  final GeoCountry country;
  final String title;
  final bool visited;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color accent = visited ? GeoColors.mint : GeoColors.coral;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.70)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  country.flagEmoji.isEmpty ? '🌍' : country.flagEmoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fredoka(
                        color: GeoColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      country.continent,
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                visited
                    ? Icons.check_circle_rounded
                    : Icons.favorite_rounded,
                color: accent,
                size: 25,
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: GeoColors.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPersonalList extends StatelessWidget {
  const _EmptyPersonalList({required this.visited});

  final bool visited;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            visited
                ? Icons.flight_takeoff_rounded
                : Icons.favorite_border_rounded,
            color: Colors.white,
            size: 46,
          ),
          const SizedBox(height: 13),
          Text(
            visited
                ? 'Marque un pays comme visité depuis sa fiche Atlas.'
                : 'Ajoute tes destinations rêvées depuis une fiche pays.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalListError extends StatelessWidget {
  const _PersonalListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Réessayer'),
      ),
    );
  }
}

class _AtlasPersonalData {
  _AtlasPersonalData({
    required this.countries,
    required this.countryInfos,
    required this.capitals,
    required List<AtlasCity> cities,
  }) : citiesByCountryCode = _groupCities(cities);

  final List<GeoCountry> countries;
  final Map<String, CountryInfo> countryInfos;
  final Map<String, Capital> capitals;
  final Map<String, List<AtlasCity>> citiesByCountryCode;

  List<AtlasCity> citiesForCountry(GeoCountry country) {
    return citiesByCountryCode[country.isoA2.trim().toUpperCase()] ??
        const <AtlasCity>[];
  }

  static Map<String, List<AtlasCity>> _groupCities(
    List<AtlasCity> cities,
  ) {
    final Map<String, List<AtlasCity>> grouped =
        <String, List<AtlasCity>>{};

    for (final AtlasCity city in cities) {
      grouped
          .putIfAbsent(city.countryCode, () => <AtlasCity>[])
          .add(city);
    }

    return grouped;
  }
}
