import 'package:flutter/foundation.dart';

import '../../storage/versioned_local_storage.dart';
import 'continent_progress.dart';

class ContinentStorage {
  ContinentStorage._();

  static const String _storageKey =
      'geopoint_continent_expedition_progress';

  static const String _recordType =
      'continent_expedition_progress';

  static Future<ContinentProgress> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(
        storageKey: _storageKey,
      );

      if (json == null) {
        return ContinentProgress.initial();
      }

      return ContinentProgress.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : chargement de la progression continentale impossible : '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      return ContinentProgress.initial();
    }
  }

  static Future<bool> save(ContinentProgress progress) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: _storageKey,
        recordType: _recordType,
        data: progress.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : sauvegarde de la progression continentale impossible : '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      return false;
    }
  }

  static Future<bool> clear() async {
    return VersionedLocalStorage.clear(
      storageKey: _storageKey,
    );
  }
}
