import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/social/geopoint_friends.dart';

void main() {
  test('décode le tableau de bord privé des amis', () {
    final GeoPointFriendDashboard dashboard =
        GeoPointFriendDashboard.fromJson(<String, dynamic>{
      'apiVersion': 1,
      'serverNowUtc': '2026-09-07T12:00:00.000Z',
      'friendCode': 'GP-ABCD-2345',
      'limits': <String, dynamic>{
        'maximumFriends': 50,
        'maximumPendingRequests': 20,
      },
      'friends': <Map<String, dynamic>>[
        <String, dynamic>{
          'playerId': 'uid_friend',
          'displayName': 'Explorateur 1234',
          'avatarId': 'default',
          'friendsSinceUtc': '2026-09-06T12:00:00.000Z',
        },
      ],
      'receivedRequests': <Map<String, dynamic>>[
        <String, dynamic>{
          'requestId': 'request_1',
          'playerId': 'uid_sender',
          'displayName': 'Explorateur 5678',
          'avatarId': 'atlas',
          'createdAtUtc': '2026-09-07T11:00:00.000Z',
        },
      ],
      'sentRequests': <Map<String, dynamic>>[],
      'blockedPlayers': <Map<String, dynamic>>[],
    });

    expect(dashboard.friendCode, 'GP-ABCD-2345');
    expect(dashboard.maximumFriends, 50);
    expect(dashboard.friends.single.playerId, 'uid_friend');
    expect(dashboard.receivedRequests.single.requestId, 'request_1');
  });

  test('associe chaque action sociale à son identifiant Firebase', () {
    expect(GeoPointFriendRelationAction.accept.id, 'accept');
    expect(GeoPointFriendRelationAction.block.id, 'block');
    expect(GeoPointFriendRelationAction.unblock.id, 'unblock');
  });
}
