import 'package:flutter/foundation.dart';

import '../../storage/versioned_local_storage.dart';
import 'expedition_progress.dart';

class ExpeditionStorage {
  ExpeditionStorage._();

  static const String _storageKey = 'geopoint_expedition_progress';
  static const String _recordType = 'expedition_progress';

  static Future<ExpeditionProgress> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(
        storageKey: _storageKey,
      );

      if (json == null) {
        return ExpeditionProgress.initial();
      }

      return ExpeditionProgress.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : erreur de chargement '
        'des expéditions : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return ExpeditionProgress.initial();
    }
  }

  static Future<bool> save(
    ExpeditionProgress progress,
  ) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: _storageKey,
        recordType: _recordType,
        data: progress.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : erreur de sauvegarde '
        'des expéditions : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  }

  static Future<bool> clear() async {
    return VersionedLocalStorage.clear(
      storageKey: _storageKey,
    );
  }
}
