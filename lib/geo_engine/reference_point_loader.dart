import 'dart:convert';

import 'package:flutter/services.dart';

import 'reference_point.dart';

class ReferencePointLoader {
  static const String _assetPath =
      'assets/data/reference_overrides.json';

  static Future<Map<String, ReferencePoint>>
      loadOverrides() async {
    final String source =
        await rootBundle.loadString(
      _assetPath,
    );

    final Object? decoded =
        jsonDecode(source);

    if (decoded is! List) {
      throw const FormatException(
        'reference_overrides.json doit contenir une liste.',
      );
    }

    final Map<String, ReferencePoint>
        result = <String, ReferencePoint>{};

    for (final Object? item in decoded) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final ReferencePoint point =
          ReferencePoint.fromJson(item);

      result[point.entityId] = point;
    }

    return result;
  }
}