import 'dart:convert';

import 'package:flutter/services.dart';

import 'country_info.dart';

class CountryInfoLoader {
  static const String _assetPath =
      'assets/data/country_infos.json';

  static Future<Map<String, CountryInfo>>?
      _countryInfosFuture;

  static Future<Map<String, CountryInfo>>
      loadCountryInfos() async {
    final Map<String, CountryInfo> countryInfos =
        await (_countryInfosFuture ??=
            _readCountryInfos());

    return Map<String, CountryInfo>.of(countryInfos);
  }

  static Future<Map<String, CountryInfo>>
      _readCountryInfos() async {
    final String source =
        await rootBundle.loadString(
      _assetPath,
    );

    final Object? decoded =
        jsonDecode(source);

    if (decoded is! List) {
      throw const FormatException(
        'country_infos.json doit contenir une liste.',
      );
    }

    final Map<String, CountryInfo> result =
        <String, CountryInfo>{};

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

      final CountryInfo info =
          CountryInfo.fromJson(json);

      result[info.entityId] = info;
    }

    return result;
  }
}
