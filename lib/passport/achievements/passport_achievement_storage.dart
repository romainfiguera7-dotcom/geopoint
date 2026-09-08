import 'package:flutter/foundation.dart';

import '../../storage/versioned_local_storage.dart';
import 'passport_achievement_progress.dart';

class PassportAchievementStorage {
  PassportAchievementStorage._();

  static const String _storageKey = 'geopoint_passport_achievements';
  static const String _recordType = 'passport_achievements';

  static Future<PassportAchievementProgress> load() async {
    try {
      final Map<String, dynamic>? json = await VersionedLocalStorage.loadData(
        storageKey: _storageKey,
      );
      return json == null
          ? PassportAchievementProgress.initial()
          : PassportAchievementProgress.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('GeoPoint : chargement des accomplissements impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
      return PassportAchievementProgress.initial();
    }
  }

  static Future<bool> save(PassportAchievementProgress progress) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: _storageKey,
        recordType: _recordType,
        data: progress.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint('GeoPoint : sauvegarde des accomplissements impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> clear() {
    return VersionedLocalStorage.clear(storageKey: _storageKey);
  }
}
