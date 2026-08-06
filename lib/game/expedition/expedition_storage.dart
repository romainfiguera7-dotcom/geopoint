import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'expedition_progress.dart';

class ExpeditionStorage {
  ExpeditionStorage._();

  static const String _storageKey =
      'geopoint_expedition_progress';

  static Future<ExpeditionProgress>
      load() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String? source =
          preferences.getString(
        _storageKey,
      );

      if (source == null ||
          source.trim().isEmpty) {
        return ExpeditionProgress.initial();
      }

      final Object? decoded =
          jsonDecode(source);

      if (decoded is! Map) {
        return ExpeditionProgress.initial();
      }

      final Map<String, dynamic> json =
          decoded.map<String, dynamic>(
        (
          dynamic key,
          dynamic value,
        ) {
          return MapEntry<String, dynamic>(
            key.toString(),
            value,
          );
        },
      );

      return ExpeditionProgress.fromJson(
        json,
      );
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
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      return preferences.setString(
        _storageKey,
        jsonEncode(
          progress.toJson(),
        ),
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
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();

    return preferences.remove(
      _storageKey,
    );
  }
}
