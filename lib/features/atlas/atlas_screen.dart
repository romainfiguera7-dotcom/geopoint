import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geo_engine/capital.dart';
import '../../geo_engine/country_info.dart';
import '../../geo_engine/country_info_loader.dart';
import '../../geo_engine/geo_country.dart';
import 'atlas_city.dart';
import 'atlas_city_loader.dart';
import 'atlas_map.dart';
import 'country_atlas_sheet.dart';

class AtlasScreen extends StatefulWidget {
  const AtlasScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<AtlasScreen> createState() => _AtlasScreenState();
}

class _AtlasScreenState extends State<AtlasScreen> {
  static const List<String> _continentFilters = <String>[
    'Tous',
    'Europe',
    'Afrique',
    'Asie',
    'Amériques',
    'Océanie',
    'Antarctique',
  ];

  final GlobalKey<AtlasMapState> _mapKey = GlobalKey<AtlasMapState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late Future<_AtlasData> _dataFuture;

  String _selectedContinent = 'Tous';
  String _searchQuery = '';
  GeoCountry? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<_AtlasData> _loadData() async {
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      CountryInfoLoader.loadCountryInfos(),
      AtlasCityLoader.loadCities(),
    ]);

    return _AtlasData(
      countries: List<GeoCountry>.unmodifiable(widget.controller.countries),
      countryInfos: loaded[0] as Map<String, CountryInfo>,
      capitals: Map<String, Capital>.unmodifiable(widget.controller.capitals),
      cities: loaded[1] as List<AtlasCity>,
    );
  }

  Future<void> _openCountrySheet(
    _AtlasData data,
    GeoCountry country, {
    bool focusCountry = true,
  }) async {
    _searchFocusNode.unfocus();

    setState(() {
      _selectedCountry = country;
      _searchQuery = '';
      _searchController.clear();
    });

    if (focusCountry) {
      _mapKey.currentState?.focusCountry(country);
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    if (!mounted) {
      return;
    }

    final List<AtlasCity> countryCities = data.citiesForCountry(country);

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
          cities: countryCities,
          onExploreCities: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  Future<void> _openCitySheet(_AtlasData data, AtlasCity city) async {
    _searchFocusNode.unfocus();
    final GeoCountry? country = data.countryForCode(city.countryCode);

    if (country != null) {
      setState(() {
        _selectedCountry = country;
      });
    }

    _mapKey.currentState?.focusCity(city);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF176BFF),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        city.isCapital
                            ? Icons.account_balance_rounded
                            : Icons.location_city_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            city.name,
                            style: GoogleFonts.fredoka(
                              color: const Color(0xFF071B3A),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            city.formattedPopulation,
                            style: GoogleFonts.nunitoSans(
                              color: const Color(0xFF52708F),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (country != null) ...<Widget>[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openCountrySheet(data, country, focusCountry: false);
                      },
                      icon: const Icon(Icons.public_rounded),
                      label: Text('Voir la fiche de ${country.name}'),
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

  void _selectContinent(String continent) {
    _searchFocusNode.unfocus();

    setState(() {
      _selectedContinent = continent;
      _selectedCountry = null;
      _searchQuery = '';
      _searchController.clear();
    });

    _mapKey.currentState?.resetView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071B3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071B3A),
        foregroundColor: Colors.white,
        title: Text(
          'ATLAS DU MONDE',
          style: GoogleFonts.fredoka(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              setState(() {
                _selectedCountry = null;
                _selectedContinent = 'Tous';
              });
              _mapKey.currentState?.resetView();
            },
            tooltip: 'Recentrer le monde',
            icon: const Icon(Icons.public_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_AtlasData>(
        future: _dataFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<_AtlasData> snapshot,
        ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _AtlasError(
              error: snapshot.error,
              onRetry: () {
                setState(() {
                  _dataFuture = _loadData();
                });
              },
            );
          }

          final _AtlasData data = snapshot.data!;
          final List<_AtlasSearchResult> searchResults =
              _buildSearchResults(data);

          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: AtlasMap(
                  key: _mapKey,
                  countries: data.countries,
                  selectedCountryCities: data.citiesForCountry(
                    _selectedCountry,
                  ),
                  countryInfos: data.countryInfos,
                  selectedContinent: _selectedContinent,
                  selectedCountry: _selectedCountry,
                  onCountrySelected: (GeoCountry country) {
                    _openCountrySheet(data, country, focusCountry: true);
                  },
                  onCitySelected: (AtlasCity city) {
                    _openCitySheet(data, city);
                  },
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Column(
                  children: <Widget>[
                    _SearchField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (String value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      onClear: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    ),
                    if (searchResults.isNotEmpty)
                      _SearchResults(
                        results: searchResults,
                        onSelected: (_AtlasSearchResult result) {
                          if (result.country != null) {
                            _openCountrySheet(
                              data,
                              result.country!,
                              focusCountry: true,
                            );
                          } else if (result.city != null) {
                            _openCitySheet(data, result.city!);
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          }
                        },
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 39,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _continentFilters.length,
                        separatorBuilder: (
                          BuildContext context,
                          int index,
                        ) {
                          return const SizedBox(width: 7);
                        },
                        itemBuilder: (BuildContext context, int index) {
                          final String continent = _continentFilters[index];
                          final bool selected =
                              continent == _selectedContinent;

                          return ChoiceChip(
                            selected: selected,
                            onSelected: (bool value) {
                              if (value) {
                                _selectContinent(continent);
                              }
                            },
                            label: Text(continent),
                            labelStyle: GoogleFonts.nunitoSans(
                              color: selected
                                  ? const Color(0xFF071B3A)
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                            selectedColor: const Color(0xFFFFD166),
                            backgroundColor:
                                const Color(0xFF071B3A).withValues(alpha: 0.88),
                            side: BorderSide(
                              color: selected ? Colors.white : Colors.white24,
                            ),
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_AtlasSearchResult> _buildSearchResults(_AtlasData data) {
    final String query = _normalize(_searchQuery);

    if (query.length < 2) {
      return const <_AtlasSearchResult>[];
    }

    final List<_AtlasSearchResult> results = <_AtlasSearchResult>[];

    for (final GeoCountry country in data.countries) {
      if (!_matchesSelectedContinent(country)) {
        continue;
      }

      final String name = data.countryInfos[country.id]?.title ?? country.name;

      if (_normalize(name).contains(query)) {
        results.add(_AtlasSearchResult.country(country, name));
      }
    }

    results.sort((_AtlasSearchResult first, _AtlasSearchResult second) {
      final bool firstStarts = _normalize(first.label).startsWith(query);
      final bool secondStarts = _normalize(second.label).startsWith(query);

      if (firstStarts != secondStarts) {
        return firstStarts ? -1 : 1;
      }

      return first.label.compareTo(second.label);
    });

    if (results.length < 10) {
      for (final AtlasCity city in data.cities) {
        if (!_normalize(city.name).contains(query)) {
          continue;
        }

        final GeoCountry? country = data.countryForCode(city.countryCode);

        if (country == null || !_matchesSelectedContinent(country)) {
          continue;
        }

        results.add(
          _AtlasSearchResult.city(
            city,
            city.name,
            data.countryInfos[country.id]?.title ?? country.name,
          ),
        );

        if (results.length >= 10) {
          break;
        }
      }
    }

    return results.take(10).toList(growable: false);
  }

  bool _matchesSelectedContinent(GeoCountry country) {
    final String filter = _normalize(_selectedContinent);

    if (filter == 'tous') {
      return true;
    }

    final String continent = _normalize(country.continent);

    if (filter == 'ameriques') {
      return continent.contains('amerique du nord') ||
          continent.contains('amerique du sud') ||
          continent == 'north america' ||
          continent == 'south america';
    }

    return continent == filter;
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }
}

class _AtlasData {
  _AtlasData({
    required this.countries,
    required this.countryInfos,
    required this.capitals,
    required this.cities,
  })  : countriesByIsoA2 = _buildCountriesByIsoA2(
          countries,
          countryInfos,
        ),
        citiesByCountryCode = _groupCitiesByCountry(cities);

  final List<GeoCountry> countries;
  final Map<String, CountryInfo> countryInfos;
  final Map<String, Capital> capitals;
  final List<AtlasCity> cities;
  final Map<String, GeoCountry> countriesByIsoA2;
  final Map<String, List<AtlasCity>> citiesByCountryCode;

  GeoCountry? countryForCode(String isoA2) {
    return countriesByIsoA2[isoA2.trim().toUpperCase()];
  }

  List<AtlasCity> citiesForCountry(GeoCountry? country) {
    if (country == null) {
      return const <AtlasCity>[];
    }

    return citiesByCountryCode[country.isoA2.trim().toUpperCase()] ??
        const <AtlasCity>[];
  }

  static Map<String, List<AtlasCity>> _groupCitiesByCountry(
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

  static Map<String, GeoCountry> _buildCountriesByIsoA2(
    List<GeoCountry> countries,
    Map<String, CountryInfo> countryInfos,
  ) {
    final Map<String, GeoCountry> result = <String, GeoCountry>{};

    for (final GeoCountry country in countries) {
      final String code = country.isoA2.trim().toUpperCase();

      if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
        continue;
      }

      final GeoCountry? current = result[code];

      if (current == null ||
          _countryPriority(country, countryInfos) >
              _countryPriority(current, countryInfos)) {
        result[code] = country;
      }
    }

    return result;
  }

  static double _countryPriority(
    GeoCountry country,
    Map<String, CountryInfo> countryInfos,
  ) {
    final double? officialArea =
        countryInfos[country.id]?.areaSquareKilometers;

    if (officialArea != null && officialArea > 0) {
      return officialArea;
    }

    return (country.bounds.maxLatitude - country.bounds.minLatitude).abs() *
        (country.bounds.maxLongitude - country.bounds.minLongitude).abs();
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 7,
      shadowColor: Colors.black38,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.nunitoSans(
          color: const Color(0xFF071B3A),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher un pays ou une ville',
          hintStyle: GoogleFonts.nunitoSans(
            color: const Color(0xFF7C8FA5),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF176BFF),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.onSelected,
  });

  final List<_AtlasSearchResult> results;
  final ValueChanged<_AtlasSearchResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      constraints: const BoxConstraints(maxHeight: 310),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 12),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        shrinkWrap: true,
        itemCount: results.length,
        separatorBuilder: (BuildContext context, int index) {
          return const Divider(height: 1, indent: 48);
        },
        itemBuilder: (BuildContext context, int index) {
          final _AtlasSearchResult result = results[index];

          return ListTile(
            dense: true,
            leading: Icon(
              result.country != null
                  ? Icons.public_rounded
                  : Icons.location_city_rounded,
              color: const Color(0xFF176BFF),
            ),
            title: Text(
              result.label,
              style: GoogleFonts.nunitoSans(
                color: const Color(0xFF071B3A),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: result.subtitle == null
                ? null
                : Text(
                    result.subtitle!,
                    style: GoogleFonts.nunitoSans(fontSize: 11),
                  ),
            onTap: () => onSelected(result),
          );
        },
      ),
    );
  }
}

class _AtlasSearchResult {
  const _AtlasSearchResult._({
    required this.label,
    this.subtitle,
    this.country,
    this.city,
  });

  factory _AtlasSearchResult.country(GeoCountry country, String label) {
    return _AtlasSearchResult._(
      label: label,
      subtitle: country.continent,
      country: country,
    );
  }

  factory _AtlasSearchResult.city(
    AtlasCity city,
    String label,
    String countryName,
  ) {
    return _AtlasSearchResult._(
      label: label,
      subtitle: '$countryName • ${city.formattedPopulation}',
      city: city,
    );
  }

  final String label;
  final String? subtitle;
  final GeoCountry? country;
  final AtlasCity? city;
}

class _AtlasError extends StatelessWidget {
  const _AtlasError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Impossible de charger l’Atlas.\n$error',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
