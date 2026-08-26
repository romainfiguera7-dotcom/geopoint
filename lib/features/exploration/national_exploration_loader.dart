import 'dart:convert';

import 'package:flutter/services.dart';

import 'national_exploration.dart';

class NationalExplorationLoader {
  NationalExplorationLoader._();

  static const String _assetPath =
      'assets/data/national_explorations.json';

  static Future<NationalExplorationCatalog>? _catalogFuture;

  static Future<NationalExplorationCatalog> loadCatalog() {
    return _catalogFuture ??= _readCatalog();
  }

  static Future<NationalExplorationCatalog> _readCatalog() async {
    final String source = await rootBundle.loadString(_assetPath);
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'national_explorations.json doit contenir un objet.',
      );
    }
    final Map<String, dynamic> json = decoded.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
    return NationalExplorationCatalog.fromJson(json);
  }
}
