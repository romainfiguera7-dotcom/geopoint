import '../../geo_engine/geo_entity_id.dart';

enum AtlasCountryStatus {
  none,
  visited,
  wishlist,
}

class AtlasPersonalProgress {
  const AtlasPersonalProgress._({
    required this.visitedCountryIds,
    required this.wishlistCountryIds,
    required this.favoriteCountryIds,
  });

  factory AtlasPersonalProgress.initial() {
    return const AtlasPersonalProgress._(
      visitedCountryIds: <String>{},
      wishlistCountryIds: <String>{},
      favoriteCountryIds: <String>{},
    );
  }

  factory AtlasPersonalProgress.fromJson(Map<String, dynamic> json) {
    final Set<String> visited = _readIds(json['visitedCountryIds']);
    final Set<String> wishlist = _readIds(json['wishlistCountryIds'])
      ..removeAll(visited);
    final Set<String> favorites = _readIds(json['favoriteCountryIds']);

    return AtlasPersonalProgress._(
      visitedCountryIds: Set<String>.unmodifiable(visited),
      wishlistCountryIds: Set<String>.unmodifiable(wishlist),
      favoriteCountryIds: Set<String>.unmodifiable(favorites),
    );
  }

  final Set<String> visitedCountryIds;
  final Set<String> wishlistCountryIds;
  final Set<String> favoriteCountryIds;

  int get visitedCount => visitedCountryIds.length;
  int get wishlistCount => wishlistCountryIds.length;
  int get favoriteCount => favoriteCountryIds.length;

  AtlasCountryStatus statusFor(String countryId) {
    final String id = _normalizeId(countryId);

    if (visitedCountryIds.contains(id)) {
      return AtlasCountryStatus.visited;
    }

    if (wishlistCountryIds.contains(id)) {
      return AtlasCountryStatus.wishlist;
    }

    return AtlasCountryStatus.none;
  }

  AtlasPersonalProgress toggleVisited(String countryId) {
    final String id = _normalizeId(countryId);

    if (id.isEmpty) {
      return this;
    }

    if (visitedCountryIds.contains(id)) {
      return _withStatus(id, AtlasCountryStatus.none);
    }

    return _withStatus(id, AtlasCountryStatus.visited);
  }

  AtlasPersonalProgress toggleWishlist(String countryId) {
    final String id = _normalizeId(countryId);

    if (id.isEmpty) {
      return this;
    }

    if (wishlistCountryIds.contains(id)) {
      return _withStatus(id, AtlasCountryStatus.none);
    }

    return _withStatus(id, AtlasCountryStatus.wishlist);
  }

  bool isFavorite(String countryId) {
    final String id = _normalizeId(countryId);

    return id.isNotEmpty && favoriteCountryIds.contains(id);
  }

  AtlasPersonalProgress toggleFavorite(String countryId) {
    final String id = _normalizeId(countryId);

    if (id.isEmpty) {
      return this;
    }

    final Set<String> favorites = <String>{...favoriteCountryIds};

    if (!favorites.remove(id)) {
      favorites.add(id);
    }

    return AtlasPersonalProgress._(
      visitedCountryIds: visitedCountryIds,
      wishlistCountryIds: wishlistCountryIds,
      favoriteCountryIds: Set<String>.unmodifiable(favorites),
    );
  }

  AtlasPersonalProgress _withStatus(
    String countryId,
    AtlasCountryStatus status,
  ) {
    final Set<String> visited = <String>{...visitedCountryIds}
      ..remove(countryId);
    final Set<String> wishlist = <String>{...wishlistCountryIds}
      ..remove(countryId);

    if (status == AtlasCountryStatus.visited) {
      visited.add(countryId);
    } else if (status == AtlasCountryStatus.wishlist) {
      wishlist.add(countryId);
    }

    return AtlasPersonalProgress._(
      visitedCountryIds: Set<String>.unmodifiable(visited),
      wishlistCountryIds: Set<String>.unmodifiable(wishlist),
      favoriteCountryIds: favoriteCountryIds,
    );
  }

  Map<String, dynamic> toJson() {
    final List<String> visited = visitedCountryIds.toList()..sort();
    final List<String> wishlist = wishlistCountryIds.toList()..sort();
    final List<String> favorites = favoriteCountryIds.toList()..sort();

    return <String, dynamic>{
      'visitedCountryIds': visited,
      'wishlistCountryIds': wishlist,
      'favoriteCountryIds': favorites,
    };
  }

  static Set<String> _readIds(Object? value) {
    if (value is! List) {
      return <String>{};
    }

    return value
        .map((Object? item) => _normalizeId(item?.toString() ?? ''))
        .where((String id) => id.isNotEmpty)
        .toSet();
  }

  static String _normalizeId(String value) {
    return GeoEntityId.normalize(value);
  }
}
