import 'dart:convert';

import 'package:flutter/services.dart';

import 'capital.dart';

class CapitalLoader {
  static const String _assetPath =
      'assets/data/capitals.json';

  static Future<Map<String, Capital>>? _capitalsFuture;

  static Future<Map<String, Capital>>
      loadCapitals() async {
    final Map<String, Capital> capitals =
        await (_capitalsFuture ??= _readCapitals());

    return Map<String, Capital>.of(capitals);
  }

  static Future<Map<String, Capital>>
      _readCapitals() async {
    final String source =
        await rootBundle.loadString(
      _assetPath,
    );

    final Object? decoded =
        jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Le fichier capitals.json est invalide.',
      );
    }

    final Map<String, Capital> capitals =
        <String, Capital>{};

    decoded.forEach(
      (
        String countryId,
        dynamic value,
      ) {
        if (value is! Map) {
          return;
        }

        final Map<String, dynamic> json =
            value.map<String, dynamic>(
          (
            dynamic key,
            dynamic item,
          ) {
            return MapEntry<String, dynamic>(
              key.toString(),
              item,
            );
          },
        );

        capitals[countryId] =
            Capital.fromJson(json);
      },
    );

    return capitals;
  }
}
