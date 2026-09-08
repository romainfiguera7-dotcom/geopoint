enum GeoBrainTheme {
  location('location', 'Localisation'),
  capital('capital', 'Capitales'),
  flag('flag', 'Drapeaux'),
  silhouette('silhouette', 'Silhouettes'),
  cities('cities', 'Villes'),
  currency('currency', 'Monnaies'),
  languages('languages', 'Langues');

  const GeoBrainTheme(this.id, this.label);

  final String id;
  final String label;

  static GeoBrainTheme? fromId(String value) {
    final String normalized = value.trim().toLowerCase();
    for (final GeoBrainTheme theme in values) {
      if (theme.id == normalized) {
        return theme;
      }
    }
    return null;
  }

  static GeoBrainTheme? fromModeId(String modeId) {
    switch (modeId.trim().toLowerCase()) {
      case 'find_country':
        return GeoBrainTheme.location;
      case 'find_capital':
        return GeoBrainTheme.capital;
      case 'find_flag':
        return GeoBrainTheme.flag;
      case 'ultimate':
      case 'find_silhouette':
        return GeoBrainTheme.silhouette;
      case 'place_city':
      case 'city_country':
        return GeoBrainTheme.cities;
      case 'currency':
        return GeoBrainTheme.currency;
      case 'language':
      case 'languages':
        return GeoBrainTheme.languages;
      default:
        return null;
    }
  }
}

enum GeoBrainMasteryStatus {
  unknown('unknown', 'Inconnu'),
  discovered('discovered', 'Découvert'),
  fragile('fragile', 'Fragile'),
  progressing('progressing', 'En progression'),
  acquired('acquired', 'Acquis'),
  mastered('mastered', 'Maîtrisé');

  const GeoBrainMasteryStatus(this.id, this.label);

  final String id;
  final String label;
}
