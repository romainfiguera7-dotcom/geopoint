import 'package:flutter/foundation.dart';

import '../storage/versioned_local_storage.dart';
import 'player_profile.dart';

class PlayerStorage {
  PlayerStorage._();

  static const String _profileKey = 'geopoint_player_profile';
  static const String _recordType = 'player_profile';

  static Future<PlayerProfile?> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(
        storageKey: _profileKey,
      );

      if (json == null) {
        return null;
      }

      return PlayerProfile.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur lors du chargement du profil : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  static Future<bool> save(
    PlayerProfile profile,
  ) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: _profileKey,
        recordType: _recordType,
        data: profile.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur lors de la sauvegarde du profil : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  }

  static Future<void> clear() async {
    await VersionedLocalStorage.clear(
      storageKey: _profileKey,
    );
  }
}
