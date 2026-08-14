import 'package:latlong2/latlong.dart';

class GuidedLevel {
  const GuidedLevel({
    required this.id,
    required this.modeId,
    required this.title,
    required this.description,
    required this.instruction,
    required this.countryIds,
    required this.questionCount,
    required this.questionDurationSeconds,
    required this.initialCenter,
    required this.initialZoom,
    this.questionModeIds = const <String>[],
  });

  final String id;
  final String modeId;
  final String title;
  final String description;
  final String instruction;
  final List<String> countryIds;
  final int questionCount;
  final int questionDurationSeconds;
  final LatLng initialCenter;
  final double initialZoom;

  /// Utilisé par le tutoriel mixte afin d'imposer
  /// une question Pays, une Capitale puis un Drapeau.
  final List<String> questionModeIds;

  bool get hasTimer {
    return questionDurationSeconds > 0;
  }

  String modeIdForQuestion(int questionIndex) {
    if (questionModeIds.isEmpty) {
      return modeId;
    }

    final int safeIndex = questionIndex < 0
        ? 0
        : questionIndex >= questionModeIds.length
            ? questionModeIds.length - 1
            : questionIndex;

    return questionModeIds[safeIndex];
  }
}

class GuidedLevelCatalog {
  GuidedLevelCatalog._();

  static const GuidedLevel countries = GuidedLevel(
    id: 'tutorial_find_country',
    modeId: 'find_country',
    title: 'Tutoriel Pays',
    description: 'Apprends à sélectionner un pays sur la carte.',
    instruction: 'Touche le pays coloré en bleu',
    countryIds: <String>[
      'FRA',
      'ESP',
      'PRT',
    ],
    questionCount: 3,
    questionDurationSeconds: 0,
    initialCenter: LatLng(44, -2),
    initialZoom: 3.6,
  );

  static const GuidedLevel capitals = GuidedLevel(
    id: 'tutorial_find_capital',
    modeId: 'find_capital',
    title: 'Tutoriel Capitales',
    description: 'Apprends à placer une capitale sur la carte.',
    instruction: 'Touche la zone bleue autour de la capitale',
    countryIds: <String>[
      'FRA',
      'ESP',
      'ITA',
    ],
    questionCount: 3,
    questionDurationSeconds: 0,
    initialCenter: LatLng(45, 5),
    initialZoom: 3.4,
  );

  static const GuidedLevel flags = GuidedLevel(
    id: 'tutorial_find_flag',
    modeId: 'find_flag',
    title: 'Tutoriel Drapeaux',
    description: 'Apprends à retrouver le pays correspondant au drapeau.',
    instruction: 'Repère le drapeau puis touche le pays bleu',
    countryIds: <String>[
      'DEU',
      'ITA',
      'ESP',
    ],
    questionCount: 3,
    questionDurationSeconds: 0,
    initialCenter: LatLng(47, 7),
    initialZoom: 3.4,
  );

  static const GuidedLevel mixed = GuidedLevel(
    id: 'tutorial_mixed',
    modeId: 'mixed',
    title: 'Tutoriel Mixte',
    description: 'Découvre les trois mécaniques dans une seule partie.',
    instruction: 'Observe la consigne puis touche la zone bleue',
    countryIds: <String>[
      'FRA',
      'ESP',
      'ITA',
    ],
    questionCount: 3,
    questionDurationSeconds: 0,
    initialCenter: LatLng(45, 3),
    initialZoom: 3.4,
    questionModeIds: <String>[
      'find_country',
      'find_capital',
      'find_flag',
    ],
  );

  static const List<GuidedLevel> tutorials = <GuidedLevel>[
    countries,
    capitals,
    flags,
    mixed,
  ];
}
