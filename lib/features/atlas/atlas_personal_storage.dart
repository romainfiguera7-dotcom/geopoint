import 'package:flutter/foundation.dart';

import '../../storage/versioned_local_storage.dart';
import 'atlas_personal_progress.dart';

class AtlasPersonalStorage {
  AtlasPersonalStorage._();

  static const String _storageKey = 'geopoint_atlas_personal_progress';
  static const String _recordType = 'atlas_personal_progress';

  static Future<AtlasPersonalProgress> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(
        storageKey: _storageKey,
      );

      if (json == null) {
        return AtlasPersonalProgress.initial();
      }

      return AtlasPersonalProgress.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : chargement de l’Atlas personnel impossible : $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return AtlasPersonalProgress.initial();
    }
  }

  static Future<bool> save(AtlasPersonalProgress progress) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: _storageKey,
        recordType: _recordType,
        data: progress.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : sauvegarde de l’Atlas personnel impossible : $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> clear() {
    return VersionedLocalStorage.clear(storageKey: _storageKey);
  }
}
