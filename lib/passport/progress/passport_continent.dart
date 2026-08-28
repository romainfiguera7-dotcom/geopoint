enum PassportContinent {
  africa('africa', 'Afrique'),
  americas('americas', 'Amérique'),
  asia('asia', 'Asie'),
  europe('europe', 'Europe'),
  oceania('oceania', 'Océanie'),
  polar('polar', 'Régions polaires');

  const PassportContinent(this.id, this.label);

  final String id;
  final String label;

  static const Map<String, PassportContinent> _entityOverrides =
      <String, PassportContinent>{
    'ATF': PassportContinent.polar,
    'SYC': PassportContinent.africa,
    'HMD': PassportContinent.polar,
    'SHN': PassportContinent.africa,
    'MUS': PassportContinent.africa,
    'IOT': PassportContinent.asia,
    'MDV': PassportContinent.asia,
    'SGS': PassportContinent.americas,
    'CLP': PassportContinent.americas,
  };

  static PassportContinent? forEntity({
    required String entityId,
    required String geoContinent,
  }) {
    final String normalizedEntityId = entityId.trim().toUpperCase();

    return _entityOverrides[normalizedEntityId] ??
        fromGeoValue(geoContinent);
  }

  static PassportContinent? fromGeoValue(String value) {
    final String normalized = _normalize(value);

    if (normalized.contains('afrique') || normalized == 'africa') {
      return PassportContinent.africa;
    }

    if (normalized.contains('amerique') || normalized.contains('america')) {
      return PassportContinent.americas;
    }

    if (normalized.contains('asie') || normalized == 'asia') {
      return PassportContinent.asia;
    }

    if (normalized.contains('europe')) {
      return PassportContinent.europe;
    }

    if (normalized.contains('oceanie') || normalized == 'oceania') {
      return PassportContinent.oceania;
    }

    if (normalized.contains('antarct') ||
        normalized.contains('arctique') ||
        normalized.contains('arctic')) {
      return PassportContinent.polar;
    }

    return null;
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
