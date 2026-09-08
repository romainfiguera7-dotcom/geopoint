import 'package:flutter/foundation.dart';

import '../../../storage/versioned_local_storage.dart';
import 'national_expedition_progress.dart';

class NationalExpeditionStorage {
  NationalExpeditionStorage._();

  static const String _storageKey = 'geopoint_national_expedition_progress';
  static const String _recordType = 'national_expedition_progress';

  static Future<NationalExpeditionProgress> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(storageKey: _storageKey);
      return json == null
          ? NationalExpeditionProgress.initial()
          : NationalExpeditionProgress.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('GeoPoint : progression nationale illisible : $error');
      debugPrintStack(stackTrace: stackTrace);
      return NationalExpeditionProgress.initial();
    }
  }

  static Future<bool> save(NationalExpeditionProgress progress) {
    return VersionedLocalStorage.saveData(
      storageKey: _storageKey,
      recordType: _recordType,
      data: progress.toJson(),
    );
  }

  static Future<bool> clear() {
    return VersionedLocalStorage.clear(storageKey: _storageKey);
  }
}
