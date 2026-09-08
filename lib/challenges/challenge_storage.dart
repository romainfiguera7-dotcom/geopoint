import 'package:flutter/foundation.dart';

import '../storage/versioned_local_storage.dart';
import 'challenge_player_state.dart';

class ChallengeStorage {
  ChallengeStorage._();

  static const String storageKey = 'geopoint_challenge_player_state';
  static const String _recordType = 'challenge_player_state';

  static Future<ChallengePlayerState?> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(storageKey: storageKey);
      if (json == null) {
        return null;
      }
      return ChallengePlayerState.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('GeoPoint Défis : erreur de chargement : $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<bool> save(ChallengePlayerState state) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: storageKey,
        recordType: _recordType,
        data: state.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint('GeoPoint Défis : erreur de sauvegarde : $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> clear() {
    return VersionedLocalStorage.clear(storageKey: storageKey);
  }
}
