import 'package:flutter/material.dart';

IconData challengeIcon(String modeId) {
  switch (modeId) {
    case 'find_capital':
      return Icons.location_city_rounded;
    case 'find_flag':
      return Icons.flag_rounded;
    case 'ultimate':
      return Icons.extension_rounded;
    case 'mixed':
      return Icons.shuffle_rounded;
    default:
      return Icons.public_rounded;
  }
}

String challengeDifficultyLabel(String difficultyId) {
  switch (difficultyId) {
    case 'discovery':
      return 'Découverte';
    case 'easy':
      return 'Facile';
    case 'intermediate':
      return 'Intermédiaire';
    case 'hard':
      return 'Difficile';
    case 'expert':
      return 'Expert';
    default:
      return difficultyId;
  }
}

String challengeTimeRemaining(Duration duration) {
  if (duration <= Duration.zero) {
    return 'Terminé';
  }
  if (duration.inDays >= 1) {
    return 'Encore ${duration.inDays} j';
  }
  if (duration.inHours >= 1) {
    return 'Encore ${duration.inHours} h';
  }
  return 'Encore ${duration.inMinutes.clamp(1, 59)} min';
}

String challengeMonthLabel(String monthKey) {
  final List<String> parts = monthKey.split('-');
  if (parts.length != 2) {
    return monthKey;
  }
  final int? month = int.tryParse(parts[1]);
  const List<String> names = <String>[
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  if (month == null || month < 1 || month > names.length) {
    return monthKey;
  }
  return names[month - 1];
}
