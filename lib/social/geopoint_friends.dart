enum GeoPointFriendRelationAction {
  accept,
  decline,
  cancel,
  remove,
  block,
  unblock,
}

extension GeoPointFriendRelationActionRules on GeoPointFriendRelationAction {
  String get id {
    switch (this) {
      case GeoPointFriendRelationAction.accept:
        return 'accept';
      case GeoPointFriendRelationAction.decline:
        return 'decline';
      case GeoPointFriendRelationAction.cancel:
        return 'cancel';
      case GeoPointFriendRelationAction.remove:
        return 'remove';
      case GeoPointFriendRelationAction.block:
        return 'block';
      case GeoPointFriendRelationAction.unblock:
        return 'unblock';
    }
  }
}

class GeoPointFriend {
  const GeoPointFriend({
    required this.playerId,
    required this.displayName,
    required this.avatarId,
    this.friendsSinceUtc,
  });

  final String playerId;
  final String displayName;
  final String avatarId;
  final DateTime? friendsSinceUtc;

  factory GeoPointFriend.fromJson(Map<String, dynamic> json) {
    return GeoPointFriend(
      playerId: _requiredText(json['playerId'], 'playerId'),
      displayName: _requiredText(json['displayName'], 'displayName'),
      avatarId: _requiredText(json['avatarId'], 'avatarId'),
      friendsSinceUtc: _optionalDate(json['friendsSinceUtc']),
    );
  }
}

class GeoPointFriendRequest {
  const GeoPointFriendRequest({
    required this.requestId,
    required this.playerId,
    required this.displayName,
    required this.avatarId,
    required this.createdAtUtc,
  });

  final String requestId;
  final String playerId;
  final String displayName;
  final String avatarId;
  final DateTime createdAtUtc;

  factory GeoPointFriendRequest.fromJson(Map<String, dynamic> json) {
    return GeoPointFriendRequest(
      requestId: _requiredText(json['requestId'], 'requestId'),
      playerId: _requiredText(json['playerId'], 'playerId'),
      displayName: _requiredText(json['displayName'], 'displayName'),
      avatarId: _requiredText(json['avatarId'], 'avatarId'),
      createdAtUtc: _requiredDate(json['createdAtUtc'], 'createdAtUtc'),
    );
  }
}

class GeoPointBlockedPlayer {
  const GeoPointBlockedPlayer({
    required this.playerId,
    required this.displayName,
    required this.avatarId,
  });

  final String playerId;
  final String displayName;
  final String avatarId;

  factory GeoPointBlockedPlayer.fromJson(Map<String, dynamic> json) {
    return GeoPointBlockedPlayer(
      playerId: _requiredText(json['playerId'], 'playerId'),
      displayName: _requiredText(json['displayName'], 'displayName'),
      avatarId: _requiredText(json['avatarId'], 'avatarId'),
    );
  }
}

class GeoPointFriendDashboard {
  const GeoPointFriendDashboard({
    required this.serverNowUtc,
    required this.friendCode,
    required this.maximumFriends,
    required this.maximumPendingRequests,
    required this.friends,
    required this.receivedRequests,
    required this.sentRequests,
    required this.blockedPlayers,
  });

  final DateTime serverNowUtc;
  final String friendCode;
  final int maximumFriends;
  final int maximumPendingRequests;
  final List<GeoPointFriend> friends;
  final List<GeoPointFriendRequest> receivedRequests;
  final List<GeoPointFriendRequest> sentRequests;
  final List<GeoPointBlockedPlayer> blockedPlayers;

  factory GeoPointFriendDashboard.fromJson(Map<String, dynamic> json) {
    if (_positiveInt(json['apiVersion'], 'apiVersion') != 1) {
      throw const FormatException('Version des amis non prise en charge.');
    }
    final Map<String, dynamic> limits = _requiredMap(json['limits'], 'limits');
    return GeoPointFriendDashboard(
      serverNowUtc: _requiredDate(json['serverNowUtc'], 'serverNowUtc'),
      friendCode: _requiredText(json['friendCode'], 'friendCode'),
      maximumFriends: _positiveInt(limits['maximumFriends'], 'maximumFriends'),
      maximumPendingRequests: _positiveInt(
        limits['maximumPendingRequests'],
        'maximumPendingRequests',
      ),
      friends: _readList(json['friends'], 'friends', GeoPointFriend.fromJson),
      receivedRequests: _readList(
        json['receivedRequests'],
        'receivedRequests',
        GeoPointFriendRequest.fromJson,
      ),
      sentRequests: _readList(
        json['sentRequests'],
        'sentRequests',
        GeoPointFriendRequest.fromJson,
      ),
      blockedPlayers: _readList(
        json['blockedPlayers'],
        'blockedPlayers',
        GeoPointBlockedPlayer.fromJson,
      ),
    );
  }
}

abstract interface class GeoPointFriendGateway {
  Future<GeoPointFriendDashboard> fetchFriendDashboard();

  Future<void> sendFriendRequest(String friendCode);

  Future<void> updateFriendRelation({
    required GeoPointFriendRelationAction action,
    String? requestId,
    String? playerId,
  });
}

List<T> _readList<T>(
  Object? value,
  String fieldName,
  T Function(Map<String, dynamic>) decoder,
) {
  if (value is! List) {
    throw FormatException('$fieldName est invalide.');
  }
  return List<T>.unmodifiable(
    value.map<T>((Object? item) => decoder(_requiredMap(item, fieldName))),
  );
}

Map<String, dynamic> _requiredMap(Object? value, String fieldName) {
  if (value is! Map) {
    throw FormatException('$fieldName est invalide.');
  }
  return value.map<String, dynamic>(
    (dynamic key, dynamic item) => MapEntry<String, dynamic>(key.toString(), item),
  );
}

String _requiredText(Object? value, String fieldName) {
  final String normalized = value?.toString().trim() ?? '';
  if (normalized.isEmpty) {
    throw FormatException('$fieldName est manquant.');
  }
  return normalized;
}

DateTime _requiredDate(Object? value, String fieldName) {
  final DateTime? parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('$fieldName est invalide.');
  }
  return parsed.toUtc();
}

DateTime? _optionalDate(Object? value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  final DateTime? parsed = DateTime.tryParse(value.toString());
  if (parsed == null) throw const FormatException('Date ami invalide.');
  return parsed.toUtc();
}

int _positiveInt(Object? value, String fieldName) {
  final int? parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed <= 0) {
    throw FormatException('$fieldName est invalide.');
  }
  return parsed;
}
