import 'package:flutter/foundation.dart';

import '../storage/versioned_local_storage.dart';
import 'player_online_identity.dart';

class PlayerIdentityStorage {
  PlayerIdentityStorage._();

  static const String _identityKey = 'geopoint_player_online_identity';
  static const String _recordType = 'player_online_identity';

  static Future<PlayerOnlineIdentity?> load() async {
    try {
      final Map<String, dynamic>? json = await VersionedLocalStorage.loadData(
        storageKey: _identityKey,
      );
      return json == null ? null : PlayerOnlineIdentity.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('GeoPoint : erreur de chargement de l’identité : $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<bool> save(PlayerOnlineIdentity identity) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: _identityKey,
        recordType: _recordType,
        data: identity.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint('GeoPoint : erreur de sauvegarde de l’identité : $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<void> clear() async {
    await VersionedLocalStorage.clear(storageKey: _identityKey);
  }
}
