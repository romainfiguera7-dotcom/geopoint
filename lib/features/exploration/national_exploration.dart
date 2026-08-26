import 'package:latlong2/latlong.dart';

enum NationalFeatureType {
  river,
  mountain,
  monument,
  sea,
  historicSite,
  culturalSpecialty,
}

class NationalExplorationCatalog {
  const NationalExplorationCatalog({
    required this.schemaVersion,
    required this.lastVerified,
    required this.countries,
    required this.regions,
    required this.features,
  });

  final int schemaVersion;
  final DateTime lastVerified;
  final Map<String, NationalExplorationCountry> countries;
  final Map<String, NationalRegion> regions;
  final Map<String, NationalFeature> features;

  NationalExplorationCountry? country(String entityId) {
    return countries[entityId.trim().toUpperCase()];
  }

  List<NationalRegion> regionsForCountry(String entityId) {
    final NationalExplorationCountry? entry = country(entityId);
    if (entry == null) {
      return const <NationalRegion>[];
    }
    return entry.regionIds
        .map((String id) => regions[id])
        .whereType<NationalRegion>()
        .toList(growable: false);
  }

  List<NationalFeature> featuresForCountry(String entityId) {
    final NationalExplorationCountry? entry = country(entityId);
    if (entry == null) {
      return const <NationalFeature>[];
    }
    return entry.featureIds
        .map((String id) => features[id])
        .whereType<NationalFeature>()
        .toList(growable: false);
  }

  factory NationalExplorationCatalog.fromJson(Map<String, dynamic> json) {
    final int schemaVersion = _readInt(json['schemaVersion']) ?? 0;
    final DateTime? lastVerified =
        DateTime.tryParse(json['lastVerified']?.toString() ?? '');
    if (schemaVersion < 1 || lastVerified == null) {
      throw const FormatException('Catalogue national invalide.');
    }

    final List<NationalExplorationCountry> countryEntries =
        _readObjectList(json['countries'])
            .map(NationalExplorationCountry.fromJson)
            .toList(growable: false);
    final List<NationalRegion> regionEntries =
        _readObjectList(json['regions'])
            .map(NationalRegion.fromJson)
            .toList(growable: false);
    final List<NationalFeature> featureEntries =
        _readObjectList(json['features'])
            .map(NationalFeature.fromJson)
            .toList(growable: false);

    return NationalExplorationCatalog(
      schemaVersion: schemaVersion,
      lastVerified: lastVerified,
      countries: Map<String, NationalExplorationCountry>.unmodifiable(
        <String, NationalExplorationCountry>{
          for (final NationalExplorationCountry country in countryEntries)
            country.entityId: country,
        },
      ),
      regions: Map<String, NationalRegion>.unmodifiable(
        <String, NationalRegion>{
          for (final NationalRegion region in regionEntries) region.id: region,
        },
      ),
      features: Map<String, NationalFeature>.unmodifiable(
        <String, NationalFeature>{
          for (final NationalFeature feature in featureEntries)
            feature.id: feature,
        },
      ),
    );
  }
}

class NationalExplorationCountry {
  const NationalExplorationCountry({
    required this.entityId,
    required this.regionIds,
    required this.cityIds,
    required this.featureIds,
  });

  final String entityId;
  final List<String> regionIds;
  final List<String> cityIds;
  final List<String> featureIds;

  factory NationalExplorationCountry.fromJson(Map<String, dynamic> json) {
    final String entityId =
        (json['entityId']?.toString() ?? '').trim().toUpperCase();
    if (entityId.isEmpty) {
      throw const FormatException('Pays national sans entityId.');
    }
    return NationalExplorationCountry(
      entityId: entityId,
      regionIds: _readStringList(json['regionIds']),
      cityIds: _readStringList(json['cityIds']),
      featureIds: _readStringList(json['featureIds']),
    );
  }
}

class NationalRegion {
  const NationalRegion({
    required this.id,
    required this.countryId,
    required this.name,
    required this.kind,
    this.center,
  });

  final String id;
  final String countryId;
  final String name;
  final String kind;
  final LatLng? center;

  factory NationalRegion.fromJson(Map<String, dynamic> json) {
    final String id = (json['id']?.toString() ?? '').trim();
    final String countryId =
        (json['countryId']?.toString() ?? '').trim().toUpperCase();
    final String name = (json['name']?.toString() ?? '').trim();
    final String kind = (json['kind']?.toString() ?? '').trim();
    if (id.isEmpty || countryId.isEmpty || name.isEmpty || kind.isEmpty) {
      throw const FormatException('Région nationale invalide.');
    }
    return NationalRegion(
      id: id,
      countryId: countryId,
      name: name,
      kind: kind,
      center: _readPosition(json['position']),
    );
  }
}

class NationalFeature {
  const NationalFeature({
    required this.id,
    required this.type,
    required this.name,
    required this.countryIds,
    required this.regionIdsByCountry,
    required this.shortDescription,
    required this.difficulty,
    required this.aliases,
    required this.quizEligible,
    required this.sources,
    this.position,
  });

  final String id;
  final NationalFeatureType type;
  final String name;
  final List<String> countryIds;
  final Map<String, List<String>> regionIdsByCountry;
  final String shortDescription;
  final String difficulty;
  final List<String> aliases;
  final bool quizEligible;
  final List<String> sources;
  final LatLng? position;

  bool belongsToCountry(String entityId) {
    return countryIds.contains(entityId.trim().toUpperCase());
  }

  factory NationalFeature.fromJson(Map<String, dynamic> json) {
    final String id = (json['id']?.toString() ?? '').trim();
    final String name = (json['name']?.toString() ?? '').trim();
    final NationalFeatureType? type =
        _featureTypeFromJson(json['type']?.toString() ?? '');
    final String shortDescription =
        (json['shortDescription']?.toString() ?? '').trim();
    final String difficulty =
        (json['difficulty']?.toString() ?? '').trim().toLowerCase();
    final List<String> countryIds = _readStringList(json['countryIds'])
        .map((String value) => value.toUpperCase())
        .toList(growable: false);

    if (id.isEmpty ||
        name.isEmpty ||
        type == null ||
        shortDescription.isEmpty ||
        countryIds.isEmpty ||
        !const <String>{'easy', 'intermediate', 'hard', 'expert'}
            .contains(difficulty)) {
      throw const FormatException('Élément national invalide.');
    }

    final Map<String, List<String>> regionIdsByCountry =
        <String, List<String>>{};
    final Object? rawRegionMap = json['regionIdsByCountry'];
    if (rawRegionMap is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawRegionMap.entries) {
        regionIdsByCountry[entry.key.toString().trim().toUpperCase()] =
            _readStringList(entry.value);
      }
    }

    return NationalFeature(
      id: id,
      type: type,
      name: name,
      countryIds: List<String>.unmodifiable(countryIds),
      regionIdsByCountry:
          Map<String, List<String>>.unmodifiable(regionIdsByCountry),
      shortDescription: shortDescription,
      difficulty: difficulty,
      aliases: _readStringList(json['aliases']),
      quizEligible: json['quizEligible'] == true,
      sources: _readStringList(json['sources']),
      position: _readPosition(json['position']),
    );
  }
}

NationalFeatureType? _featureTypeFromJson(String value) {
  switch (value.trim().toLowerCase()) {
    case 'river':
      return NationalFeatureType.river;
    case 'mountain':
      return NationalFeatureType.mountain;
    case 'monument':
      return NationalFeatureType.monument;
    case 'sea':
      return NationalFeatureType.sea;
    case 'historic_site':
      return NationalFeatureType.historicSite;
    case 'cultural_specialty':
      return NationalFeatureType.culturalSpecialty;
  }
  return null;
}

List<Map<String, dynamic>> _readObjectList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value.whereType<Map>().map((Map item) {
    return item.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }).toList(growable: false);
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((Object? item) => item?.toString().trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

LatLng? _readPosition(Object? value) {
  if (value is! Map) {
    return null;
  }
  final double? latitude = _readDouble(value['latitude']);
  final double? longitude = _readDouble(value['longitude']);
  if (latitude == null || longitude == null) {
    return null;
  }
  return LatLng(latitude, longitude);
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}
