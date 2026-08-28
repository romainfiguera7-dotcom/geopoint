import '../../storage/versioned_local_storage.dart';
import 'passport_display_preferences.dart';

class PassportDisplayPreferencesStorage {
  PassportDisplayPreferencesStorage._();

  static const String _storageKey =
      'geopoint_passport_display_preferences';
  static const String _recordType = 'passport_display_preferences';

  static Future<PassportDisplayPreferences> load() async {
    final Map<String, dynamic>? json = await VersionedLocalStorage.loadData(
      storageKey: _storageKey,
    );

    if (json == null) {
      return PassportDisplayPreferences.initial();
    }

    return PassportDisplayPreferences.fromJson(json);
  }

  static Future<bool> save(PassportDisplayPreferences preferences) {
    return VersionedLocalStorage.saveData(
      storageKey: _storageKey,
      recordType: _recordType,
      data: preferences.toJson(),
    );
  }
}
