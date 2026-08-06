import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final File citiesFile = File(
    'tool/data/cities15000.txt',
  );

  final File countriesFile = File(
    'tool/data/countryInfo.txt',
  );

  if (!citiesFile.existsSync()) {
    stderr.writeln(
      'Fichier introuvable : '
      '${citiesFile.path}',
    );
    exitCode = 1;
    return;
  }

  if (!countriesFile.existsSync()) {
    stderr.writeln(
      'Fichier introuvable : '
      '${countriesFile.path}',
    );
    exitCode = 1;
    return;
  }

  final Map<String, String> isoA2ToIsoA3 =
      await _loadCountryCodes(
    countriesFile,
  );

  final Map<String, Map<String, Object>>
      capitals = await _loadCapitals(
    citiesFile,
    isoA2ToIsoA3,
  );

  /*
   * Entrées retirées du mode classique GeoPoint.
   * On les conserve hors de la base active afin
   * d'éviter les sujets territoriaux sensibles.
   */
  const Set<String> excludedIsoA3 = <String>{
    'PSE',
    'ESH',
  };

  capitals.removeWhere(
    (
      String isoA3,
      Map<String, Object> value,
    ) {
      return excludedIsoA3.contains(isoA3);
    },
  );

  final List<String> sortedCodes =
      capitals.keys.toList()
        ..sort();

  final Map<String, Object> sortedCapitals =
      <String, Object>{
    for (final String code in sortedCodes)
      code: capitals[code]!,
  };

  final Directory outputDirectory =
      Directory(
    'assets/data',
  );

  if (!outputDirectory.existsSync()) {
    outputDirectory.createSync(
      recursive: true,
    );
  }

  final File outputFile = File(
    'assets/data/capitals.json',
  );

  const JsonEncoder encoder =
      JsonEncoder.withIndent('  ');

  await outputFile.writeAsString(
    encoder.convert(
      sortedCapitals,
    ),
  );

  stdout.writeln(
    '${sortedCapitals.length} capitales '
    'enregistrées.',
  );

  stdout.writeln(
    'Fichier créé : ${outputFile.path}',
  );
}

Future<Map<String, String>> _loadCountryCodes(
  File file,
) async {
  final Map<String, String> result =
      <String, String>{};

  final List<String> lines =
      await file.readAsLines();

  for (final String line in lines) {
    if (line.trim().isEmpty ||
        line.startsWith('#')) {
      continue;
    }

    final List<String> columns =
        line.split('\t');

    /*
     * countryInfo.txt :
     * colonne 0 = ISO A2
     * colonne 1 = ISO A3
     */
    if (columns.length < 2) {
      continue;
    }

    final String isoA2 =
        columns[0].trim().toUpperCase();

    final String isoA3 =
        columns[1].trim().toUpperCase();

    if (!_isIsoA2(isoA2) ||
        !_isIsoA3(isoA3)) {
      continue;
    }

    result[isoA2] = isoA3;
  }

  return result;
}

Future<Map<String, Map<String, Object>>>
    _loadCapitals(
  File file,
  Map<String, String> isoA2ToIsoA3,
) async {
  final Map<String, Map<String, Object>>
      result =
      <String, Map<String, Object>>{};

  final List<String> lines =
      await file.readAsLines();

  for (final String line in lines) {
    if (line.trim().isEmpty) {
      continue;
    }

    final List<String> columns =
        line.split('\t');

    /*
     * Format GeoNames :
     *
     * 1  = nom
     * 4  = latitude
     * 5  = longitude
     * 7  = code de caractéristique
     * 8  = code pays ISO A2
     * 14 = population
     */
    if (columns.length < 15) {
      continue;
    }

    final String featureCode =
        columns[7].trim();

    /*
     * PPLC signifie :
     * capitale d'une entité politique.
     */
    if (featureCode != 'PPLC') {
      continue;
    }

    final String capitalName =
        columns[1].trim();

    final double? latitude =
        double.tryParse(
      columns[4].trim(),
    );

    final double? longitude =
        double.tryParse(
      columns[5].trim(),
    );

    final String isoA2 =
        columns[8].trim().toUpperCase();

    final String? isoA3 =
        isoA2ToIsoA3[isoA2];

    final int population =
        int.tryParse(
              columns[14].trim(),
            ) ??
            0;

    if (capitalName.isEmpty ||
        latitude == null ||
        longitude == null ||
        isoA3 == null) {
      continue;
    }

    final Map<String, Object>? existing =
        result[isoA3];

    /*
     * S'il existe plusieurs capitales PPLC
     * pour une même entrée, on conserve
     * celle qui possède la plus forte population.
     */
    if (existing != null) {
      final int existingPopulation =
          existing['population'] as int? ?? 0;

      if (existingPopulation >= population) {
        continue;
      }
    }

    result[isoA3] = <String, Object>{
      'isoA2': isoA2,
      'isoA3': isoA3,
      'capital': capitalName,
      'latitude': latitude,
      'longitude': longitude,
      'population': population,
    };
  }

  return result;
}

bool _isIsoA2(
  String value,
) {
  return RegExp(
    r'^[A-Z]{2}$',
  ).hasMatch(value);
}

bool _isIsoA3(
  String value,
) {
  return RegExp(
    r'^[A-Z]{3}$',
  ).hasMatch(value);
}