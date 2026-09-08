abstract final class PlayableCountryPolicy {
  static const Set<String> excludedEntityIds = <String>{
    'CYN',
    'PSX',
    'SAH',
    'SOL',
    'VAT',
  };

  static bool isPlayableId(String entityId) {
    return !excludedEntityIds.contains(entityId.trim().toUpperCase());
  }
}
