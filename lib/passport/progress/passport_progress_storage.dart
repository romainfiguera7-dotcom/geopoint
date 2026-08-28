import 'package:flutter/foundation.dart';

import '../../storage/versioned_local_storage.dart';
import 'passport_progress_v2.dart';

class PassportProgressStorage {
  PassportProgressStorage._();

  static const String _storageKey = 'geopoint_passport_progress_v2';
  static const String _recordType = 'passport_progress_v2';

  static Future<PassportProgressV2?> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(
        storageKey: _storageKey,
      );

      if (json == null) {
        return null;
      }

      return PassportProgressV2.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint Passeport 2.0 : erreur de chargement : $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<bool> save(
    PassportProgressV2 progress,
  ) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: _storageKey,
        recordType: _recordType,
        data: progress.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint Passeport 2.0 : erreur de sauvegarde : $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> clear() {
    return VersionedLocalStorage.clear(storageKey: _storageKey);
  }
}
