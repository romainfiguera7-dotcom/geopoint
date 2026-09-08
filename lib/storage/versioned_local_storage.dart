import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VersionedLocalStorage {
  VersionedLocalStorage._();

  static const int currentSchemaVersion = 2;

  static Future<Map<String, dynamic>?> loadData({
    required String storageKey,
  }) async {
    final SharedPreferences preferences = await _preferences;
    final String? source = preferences.getString(storageKey);
    final String? backup = preferences.getString(_backupKey(storageKey));

    if (source != null && source.trim().isNotEmpty) {
      try {
        return _decodeData(source);
      } on FormatException {
        if (backup == null || backup.trim().isEmpty) {
          rethrow;
        }
      }
    }
    if (backup != null && backup.trim().isNotEmpty) {
      return _decodeData(backup);
    }
    return null;
  }

  static Future<bool> saveData({
    required String storageKey,
    required String recordType,
    required Map<String, dynamic> data,
  }) async {
    final SharedPreferences preferences = await _preferences;
    final String? currentSource = preferences.getString(storageKey);
    final String? backupSource = preferences.getString(_backupKey(storageKey));
    final int currentRevision = _readCurrentRevision(
      currentSource,
    ).clamp(
      0,
      1 << 30,
    );

    final Map<String, dynamic> document = <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'recordType': recordType,
      'revision': currentRevision + 1,
      'dataSchemaVersion': data['schemaVersion'],
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };

    if (_isValidSource(currentSource)) {
      await preferences.setString(_backupKey(storageKey), currentSource!);
    } else if (currentRevision == 0 && _isValidSource(backupSource)) {
      document['revision'] = _readCurrentRevision(backupSource) + 1;
    }

    return preferences.setString(
      storageKey,
      jsonEncode(document),
    );
  }

  static Future<bool> clear({
    required String storageKey,
  }) async {
    final SharedPreferences preferences = await _preferences;
    final bool removedPrimary = await preferences.remove(storageKey);
    final bool removedBackup = await preferences.remove(_backupKey(storageKey));
    return removedPrimary || removedBackup;
  }

  static Future<SharedPreferences> get _preferences {
    // SharedPreferences conserve déjà son propre cache. Ne pas mémoriser ici
    // le Future permet aussi aux redémarrages simulés par les tests de repartir
    // avec une instance réellement rechargée.
    return SharedPreferences.getInstance();
  }

  static int _readCurrentRevision(String? source) {
    if (source == null || source.trim().isEmpty) {
      return 0;
    }

    try {
      final Object? decoded = jsonDecode(source);

      if (decoded is! Map) {
        return 0;
      }

      final Object? revision = decoded['revision'];

      if (revision is num && revision >= 0) {
        return revision.toInt();
      }
    } on FormatException {
      return 0;
    }

    return 0;
  }

  static Map<String, dynamic> _decodeData(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'La sauvegarde locale ne contient pas un objet JSON.',
      );
    }
    final Map<String, dynamic> json = _asStringMap(decoded);
    final Object? schemaVersion = json['schemaVersion'];
    final Object? data = json['data'];
    if (schemaVersion is num && json.containsKey('data')) {
      if (data is! Map) {
        throw const FormatException(
          'La sauvegarde versionnée ne contient pas de données valides.',
        );
      }
      return _asStringMap(data);
    }
    // Compatibilité avec les sauvegardes créées avant le format versionné.
    return json;
  }

  static bool _isValidSource(String? source) {
    if (source == null || source.trim().isEmpty) {
      return false;
    }
    try {
      _decodeData(source);
      return true;
    } on FormatException {
      return false;
    }
  }

  static String _backupKey(String storageKey) {
    return '${storageKey}_backup';
  }

  static Map<String, dynamic> _asStringMap(Map<dynamic, dynamic> source) {
    return source.map<String, dynamic>(
      (dynamic key, dynamic value) {
        return MapEntry<String, dynamic>(
          key.toString(),
          value,
        );
      },
    );
  }
}
