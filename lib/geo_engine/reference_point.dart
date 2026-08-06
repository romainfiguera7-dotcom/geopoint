import 'package:latlong2/latlong.dart';

enum ReferencePointType {
  capital,
  city,
  island,
  territory,
  region,
  archipelago,
  geographicCenter,
}

class ReferencePoint {
  const ReferencePoint({
    required this.entityId,
    required this.countryId,
    required this.countryIsoA2,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.parentCountryName,
    this.officialCapitalName,
    this.description,
  });

  /// Identifiant de l’entité demandée dans le jeu.
  ///
  /// Exemples :
  /// FRA, ATC, CLP, COR.
  final String entityId;

  /// Identifiant du pays de rattachement.
  ///
  /// Exemples :
  /// FRA pour la Corse et Clipperton ;
  /// AUS pour Ashmore-et-Cartier.
  final String countryId;

  /// Code à deux lettres utilisé pour le drapeau.
  ///
  /// Exemples :
  /// FR pour la Corse ;
  /// AU pour Ashmore-et-Cartier.
  final String countryIsoA2;

  /// Nom du lieu précis montré au joueur.
  ///
  /// Exemples :
  /// Paris, Ajaccio, Ashmore Reef.
  final String name;

  final double latitude;
  final double longitude;

  final ReferencePointType type;

  /// Pays de rattachement affiché dans la fiche.
  ///
  /// Exemple : France pour la Corse.
  final String? parentCountryName;

  /// Capitale officielle du pays de rattachement.
  ///
  /// Exemple : Paris pour la Corse ou Clipperton.
  final String? officialCapitalName;

  /// Courte explication pédagogique facultative.
  final String? description;

  LatLng get position {
    return LatLng(
      latitude,
      longitude,
    );
  }

  bool get isCapital {
    return type == ReferencePointType.capital;
  }

  bool get isTerritory {
    return type == ReferencePointType.territory ||
        type == ReferencePointType.island ||
        type == ReferencePointType.archipelago ||
        type == ReferencePointType.region;
  }

  String get typeLabel {
    switch (type) {
      case ReferencePointType.capital:
        return 'Capitale';

      case ReferencePointType.city:
        return 'Ville de référence';

      case ReferencePointType.island:
        return 'Île';

      case ReferencePointType.territory:
        return 'Territoire';

      case ReferencePointType.region:
        return 'Région';

      case ReferencePointType.archipelago:
        return 'Archipel';

      case ReferencePointType.geographicCenter:
        return 'Point géographique';
    }
  }

  factory ReferencePoint.fromJson(
    Map<String, dynamic> json,
  ) {
    final String entityId =
        _readRequiredString(
      json,
      'entityId',
    ).toUpperCase();

    final String countryId =
        _readRequiredString(
      json,
      'countryId',
    ).toUpperCase();

    final String countryIsoA2 =
        _readRequiredString(
      json,
      'countryIsoA2',
    ).toUpperCase();

    final String name =
        _readRequiredString(
      json,
      'name',
    );

    final double latitude =
        _readRequiredDouble(
      json,
      'latitude',
    );

    final double longitude =
        _readRequiredDouble(
      json,
      'longitude',
    );

    final ReferencePointType type =
        _readType(
      json['type'],
    );

    return ReferencePoint(
      entityId: entityId,
      countryId: countryId,
      countryIsoA2: countryIsoA2,
      name: name,
      latitude: latitude,
      longitude: longitude,
      type: type,
      parentCountryName:
          _readOptionalString(
        json['parentCountryName'],
      ),
      officialCapitalName:
          _readOptionalString(
        json['officialCapitalName'],
      ),
      description:
          _readOptionalString(
        json['description'],
      ),
    );
  }

  static String _readRequiredString(
    Map<String, dynamic> json,
    String key,
  ) {
    final String value =
        json[key]?.toString().trim() ?? '';

    if (value.isEmpty) {
      throw FormatException(
        'Champ obligatoire manquant : $key.',
      );
    }

    return value;
  }

  static String? _readOptionalString(
    Object? value,
  ) {
    final String text =
        value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  static double _readRequiredDouble(
    Map<String, dynamic> json,
    String key,
  ) {
    final Object? value = json[key];

    if (value is num) {
      return value.toDouble();
    }

    final double? parsed =
        double.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) {
      throw FormatException(
        'Coordonnée invalide : $key.',
      );
    }

    return parsed;
  }

  static ReferencePointType _readType(
    Object? value,
  ) {
    final String type =
        value?.toString().trim().toLowerCase() ??
            '';

    switch (type) {
      case 'capital':
        return ReferencePointType.capital;

      case 'city':
        return ReferencePointType.city;

      case 'island':
        return ReferencePointType.island;

      case 'territory':
        return ReferencePointType.territory;

      case 'region':
        return ReferencePointType.region;

      case 'archipelago':
        return ReferencePointType.archipelago;

      case 'geographiccenter':
      case 'geographic_center':
      case 'geographic-center':
        return ReferencePointType.geographicCenter;

      default:
        throw FormatException(
          'Type de point de référence inconnu : $type.',
        );
    }
  }

  @override
  String toString() {
    return 'ReferencePoint('
        'entityId: $entityId, '
        'countryId: $countryId, '
        'name: $name, '
        'type: $typeLabel'
        ')';
  }
}