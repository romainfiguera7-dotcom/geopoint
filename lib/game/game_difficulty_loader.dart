import 'dart:convert';

import 'package:flutter/services.dart';

import 'game_difficulty.dart';

class GameDifficultyLoader {
  GameDifficultyLoader._();

  static const String _assetPath =
      'assets/data/game_difficulties.json';

  static Future<List<GameDifficulty>>
      loadDifficulties() async {
    final String source =
        await rootBundle.loadString(
      _assetPath,
    );

    final Object? decoded =
        jsonDecode(source);

    if (decoded is! List) {
      throw const FormatException(
        'Le fichier game_difficulties.json doit contenir une liste.',
      );
    }

    final List<GameDifficulty> difficulties =
        decoded
            .map<GameDifficulty>(
              (dynamic item) =>
                  GameDifficulty.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .where(
              (difficulty) =>
                  difficulty.isEnabled,
            )
            .toList();

    difficulties.sort(
      (a, b) =>
          a.order.compareTo(
        b.order,
      ),
    );

    return List.unmodifiable(
      difficulties,
    );
  }
}