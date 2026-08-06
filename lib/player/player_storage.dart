import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_profile.dart';

class PlayerStorage {
  PlayerStorage._();

  static const String _profileKey =
      'geopoint_player_profile';

  static Future<PlayerProfile?> load() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String? source =
          preferences.getString(
        _profileKey,
      );

      if (source == null ||
          source.trim().isEmpty) {
        return null;
      }

      final Object? decoded =
          jsonDecode(source);

      if (decoded is! Map) {
        return null;
      }

      final Map<String, dynamic> json =
          decoded.map<String, dynamic>(
        (key, value) =>
            MapEntry<String, dynamic>(
          key.toString(),
          value,
        ),
      );

      return PlayerProfile.fromJson(
        json,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur lors du chargement du profil : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  static Future<bool> save(
    PlayerProfile profile,
  ) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String source =
          jsonEncode(
        profile.toJson(),
      );

      return preferences.setString(
        _profileKey,
        source,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur lors de la sauvegarde du profil : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  }

  static Future<void> clear() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(
      _profileKey,
    );
  }
}