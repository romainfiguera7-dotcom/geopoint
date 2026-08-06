import 'dart:convert';

import 'package:flutter/services.dart';

class CountryDifficultyLoader {
  CountryDifficultyLoader._();

  static const String _assetPath =
      'assets/data/country_difficulties.json';

  static Future<Map<String, int>>
      loadDifficulties() async {
    final String source =
        await rootBundle.loadString(
      _assetPath,
    );

    final Object? decoded =
        jsonDecode(source);

    if (decoded is! Map) {
      throw const FormatException(
        'country_difficulties.json doit '
        'contenir un objet JSON.',
      );
    }

    final Map<String, int> result =
        <String, int>{};

    for (
      final MapEntry<dynamic, dynamic> entry
      in decoded.entries
    ) {
      final String countryId =
          entry.key
              .toString()
              .trim()
              .toUpperCase();

      if (countryId.isEmpty) {
        continue;
      }

      final Object? rawValue =
          entry.value;

      final int? difficulty =
          rawValue is int
              ? rawValue
              : int.tryParse(
                  rawValue.toString(),
                );

      if (difficulty == null) {
        continue;
      }

      result[countryId] =
          difficulty.clamp(1, 100);
    }

    if (result.isEmpty) {
      throw const FormatException(
        'Aucune difficulté de pays valide '
        'n’a été trouvée.',
      );
    }

    return Map<String, int>.unmodifiable(
      result,
    );
  }
}
