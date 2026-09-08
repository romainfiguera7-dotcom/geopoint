import 'package:flutter/foundation.dart';

import '../storage/versioned_local_storage.dart';
import 'challenge_pack_cache.dart';

class ChallengePackCacheStorage {
  ChallengePackCacheStorage._();

  static const String storageKey = 'geopoint_challenge_pack_cache';
  static const String _recordType = 'challenge_pack_cache';

  static Future<ChallengePackCache?> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(storageKey: storageKey);
      return json == null ? null : ChallengePackCache.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('GeoPoint Défis : cache distant illisible : $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<bool> save(ChallengePackCache cache) {
    return VersionedLocalStorage.saveData(
      storageKey: storageKey,
      recordType: _recordType,
      data: cache.toJson(),
    );
  }

  static Future<bool> clear() {
    return VersionedLocalStorage.clear(storageKey: storageKey);
  }
}
