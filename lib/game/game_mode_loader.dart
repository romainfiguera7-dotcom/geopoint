import 'dart:convert';

import 'package:flutter/services.dart';

import 'game_mode.dart';

class GameModeLoader {
  static const String _assetPath =
      'assets/data/game_modes.json';

  static Future<Map<String, GameMode>>
      loadGameModes() async {
    final String source =
        await rootBundle.loadString(
      _assetPath,
    );

    final Object? decoded =
        jsonDecode(source);

    if (decoded is! List) {
      throw const FormatException(
        'game_modes.json doit contenir une liste.',
      );
    }

    final Map<String, GameMode> result =
        <String, GameMode>{};

    for (final Object? item in decoded) {
      if (item is! Map) {
        continue;
      }

      final Map<String, dynamic> json =
          item.map<String, dynamic>(
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

      final GameMode mode =
          GameMode.fromJson(json);

      if (result.containsKey(mode.id)) {
        throw FormatException(
          'Mode de jeu dupliqué : ${mode.id}.',
        );
      }

      result[mode.id] = mode;
    }

    if (result.isEmpty) {
      throw const FormatException(
        'Aucun mode de jeu valide trouvé.',
      );
    }

    return Map<String, GameMode>.unmodifiable(
      result,
    );
  }
}