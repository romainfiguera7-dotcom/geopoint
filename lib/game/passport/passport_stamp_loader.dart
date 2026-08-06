import 'dart:convert';

import 'package:flutter/services.dart';

import 'passport_stamp.dart';

class PassportStampLoader {
  static const String _assetPath =
      'assets/data/passport_stamps.json';

  static Future<Map<String, PassportStamp>>
      loadStamps() async {
    final String source =
        await rootBundle.loadString(
      _assetPath,
    );

    final Object? decoded =
        jsonDecode(source);

    if (decoded is! List) {
      throw const FormatException(
        'passport_stamps.json doit contenir une liste.',
      );
    }

    final Map<String, PassportStamp> result =
        <String, PassportStamp>{};

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

      final PassportStamp stamp =
          PassportStamp.fromJson(
        json,
      );

      if (result.containsKey(stamp.id)) {
        throw FormatException(
          'Tampon dupliqué : ${stamp.id}.',
        );
      }

      result[stamp.id] = stamp;
    }

    if (result.isEmpty) {
      throw const FormatException(
        'Aucun tampon valide trouvé.',
      );
    }

    return Map<String, PassportStamp>.unmodifiable(
      result,
    );
  }
}