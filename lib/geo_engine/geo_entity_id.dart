class GeoEntityId {
  GeoEntityId._();

  static String normalize(String value) {
    return value.trim().toUpperCase();
  }

  static String require(String value) {
    final String normalized = normalize(value);

    if (normalized.isEmpty) {
      throw ArgumentError(
        'L’identifiant géographique est obligatoire.',
      );
    }

    return normalized;
  }
}
