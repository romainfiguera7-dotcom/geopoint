import 'dart:convert';

import 'package:flutter/services.dart';

import 'passport_license.dart';

class PassportLicenseLoader {
  static const String _assetPath =
      'assets/data/passport_licenses.json';

  static Future<List<PassportLicense>>
      loadLicenses() async {
    final String source =
        await rootBundle.loadString(
      _assetPath,
    );

    final Object? decoded =
        jsonDecode(source);

    if (decoded is! List) {
      throw const FormatException(
        'passport_licenses.json doit contenir une liste.',
      );
    }

    final List<PassportLicense> licenses =
        <PassportLicense>[];

    final Set<int> usedIds =
        <int>{};

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

      final PassportLicense license =
          PassportLicense.fromJson(
        json,
      );

      if (!usedIds.add(license.id)) {
        throw FormatException(
          'Licence dupliquée : ${license.id}.',
        );
      }

      licenses.add(
        license,
      );
    }

    if (licenses.isEmpty) {
      throw const FormatException(
        'Aucune licence valide trouvée.',
      );
    }

    licenses.sort(
      (
        PassportLicense first,
        PassportLicense second,
      ) {
        return first.id.compareTo(
          second.id,
        );
      },
    );

    return List<PassportLicense>.unmodifiable(
      licenses,
    );
  }
}