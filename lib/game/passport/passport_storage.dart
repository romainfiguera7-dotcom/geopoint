import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_passport.dart';

class PassportStorage {
  PassportStorage._();

  static const String _passportKey =
      'geopoint_player_passport';

  static Future<PlayerPassport?> load() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String? source =
          preferences.getString(
        _passportKey,
      );

      if (source == null ||
          source.trim().isEmpty) {
        return null;
      }

      final Object? decoded =
          jsonDecode(source);

      if (decoded is! Map) {
        throw const FormatException(
          'La sauvegarde du Passeport '
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

      return PlayerPassport.fromJson(
        json,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : erreur pendant le '
        'chargement du Passeport : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  static Future<bool> save(
    PlayerPassport passport,
  ) async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String source =
          jsonEncode(
        passport.toJson(),
      );

      return preferences.setString(
        _passportKey,
        source,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : erreur pendant la '
        'sauvegarde du Passeport : $error',
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
      _passportKey,
    );
  }
}