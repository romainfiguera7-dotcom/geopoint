import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'geobrain_profile.dart';

class GeoBrainStorage {
  GeoBrainStorage._();

  static const String _storageKey =
      'geopoint_geobrain_profile';

  static Future<GeoBrainProfile?> load() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String? source =
          preferences.getString(
        _storageKey,
      );

      if (source == null ||
          source.trim().isEmpty) {
        return null;
      }

      final Object? decoded =
          jsonDecode(source);

      if (decoded is! Map) {
        throw const FormatException(
          'La sauvegarde GeoBrain '
          'ne contient pas un objet JSON.',
        );
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

      return GeoBrainProfile.fromJson(
        json,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint GeoBrain : erreur de chargement : '
        '$error',
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
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String source =
          jsonEncode(
        profile.toJson(),
      );

      return preferences.setString(
        _storageKey,
        source,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint GeoBrain : erreur de sauvegarde : '
        '$error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  }

  static Future<bool> clear() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      return preferences.remove(
        _storageKey,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint GeoBrain : erreur de suppression : '
        '$error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  }
}