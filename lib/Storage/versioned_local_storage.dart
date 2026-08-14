import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VersionedLocalStorage {
  VersionedLocalStorage._();

  static const int currentSchemaVersion = 1;

  static Future<SharedPreferences>? _preferencesFuture;

  static Future<Map<String, dynamic>?> loadData({
    required String storageKey,
  }) async {
    final SharedPreferences preferences = await _preferences;
    final String? source = preferences.getString(storageKey);

    if (source == null || source.trim().isEmpty) {
      return null;
    }

    final Object? decoded = jsonDecode(source);

    if (decoded is! Map) {
      throw const FormatException(
        'La sauvegarde locale ne contient pas un objet JSON.',
      );
    }

    final Map<String, dynamic> json = _asStringMap(decoded);
    final Object? schemaVersion = json['schemaVersion'];
    final Object? data = json['data'];

    if (schemaVersion is num && data is Map) {
      return _asStringMap(data);
    }

    // Compatibilité avec les sauvegardes créées avant le format versionné.
    return json;
  }

  static Future<bool> saveData({
    required String storageKey,
    required String recordType,
    required Map<String, dynamic> data,
  }) async {
    final SharedPreferences preferences = await _preferences;
    final int currentRevision = _readCurrentRevision(
      preferences.getString(storageKey),
    );

    final Map<String, dynamic> document = <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'recordType': recordType,
      'revision': currentRevision + 1,
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };

    return preferences.setString(
      storageKey,
      jsonEncode(document),
    );
  }

  static Future<bool> clear({
    required String storageKey,
  }) async {
    final SharedPreferences preferences = await _preferences;
    return preferences.remove(storageKey);
  }

  static Future<SharedPreferences> get _preferences {
    return _preferencesFuture ??= SharedPreferences.getInstance();
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
