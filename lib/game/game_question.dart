import '../geo_engine/flag_emoji.dart';

class GameQuestion {
  const GameQuestion({
    required this.modeId,
    required this.countryId,
    required this.countryName,
    required this.isoA2,
    required this.continent,
  });

  /// Épreuve concernée :
  ///
  /// find_country
  /// find_capital
  /// find_flag
  /// mixed
  final String modeId;

  final String countryId;
  final String countryName;
  final String isoA2;
  final String continent;

  bool get isFindCountry {
    return modeId == 'find_country';
  }

  bool get isFindCapital {
    return modeId == 'find_capital';
  }

  bool get isFindFlag {
    return modeId == 'find_flag';
  }

  bool get isMixed {
    return modeId == 'mixed';
  }

  String get flagEmoji {
    return FlagEmoji.fromIsoA2(
      isoA2,
    );
  }

  String get instruction {
    switch (modeId) {
      case 'find_capital':
        return 'Trouve la capitale de';

      case 'find_flag':
        return 'Trouve le pays de ce drapeau';

      case 'mixed':
        return 'Trouve';

      case 'find_country':
      default:
        return 'Trouve';
    }
  }

  String get prompt {
    switch (modeId) {
      case 'find_capital':
        return 'Trouve la capitale de $countryName';

      case 'find_flag':
        return 'Clique sur le pays correspondant';

      case 'mixed':
        return 'Trouve $countryName';

      case 'find_country':
      default:
        return 'Trouve $countryName';
    }
  }

  @override
  String toString() {
    return 'GameQuestion('
        'modeId: $modeId, '
        'countryId: $countryId, '
        'countryName: $countryName, '
        'isoA2: $isoA2, '
        'continent: $continent'
        ')';
  }
}