import 'package:flutter/foundation.dart';

import '../storage/versioned_local_storage.dart';
import 'geobrain_profile.dart';

class GeoBrainStorage {
  GeoBrainStorage._();

  static const String _storageKey = 'geopoint_geobrain_profile';
  static const String _recordType = 'geobrain_profile';

  static Future<GeoBrainProfile?> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(
        storageKey: _storageKey,
      );

      if (json == null) {
        return null;
      }

      return GeoBrainProfile.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint GeoBrain : erreur de chargement : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  static Future<bool> save(
    GeoBrainProfile profile,
  ) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: _storageKey,
        recordType: _recordType,
        data: profile.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint GeoBrain : erreur de sauvegarde : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  }

  static Future<bool> clear() async {
    try {
      return await VersionedLocalStorage.clear(
        storageKey: _storageKey,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint GeoBrain : erreur de suppression : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  }
}
