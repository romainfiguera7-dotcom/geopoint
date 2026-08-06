import 'package:flutter/material.dart';

class ExpeditionMission {
  const ExpeditionMission({
    required this.id,
    required this.modeId,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUltimate,
  });

  final String id;
  final String modeId;
  final String title;
  final String description;
  final IconData icon;
  final bool isUltimate;

  static const List<ExpeditionMission> defaultMissions =
      <ExpeditionMission>[
    ExpeditionMission(
      id: 'find_country',
      modeId: 'find_country',
      title: 'Trouver le pays',
      description:
          'Repère le pays demandé directement sur la carte.',
      icon: Icons.public_rounded,
      isUltimate: false,
    ),
    ExpeditionMission(
      id: 'find_capital',
      modeId: 'find_capital',
      title: 'Trouver la capitale',
      description:
          'Retrouve la capitale demandée sur la carte.',
      icon: Icons.location_city_rounded,
      isUltimate: false,
    ),
    ExpeditionMission(
      id: 'find_flag',
      modeId: 'find_flag',
      title: 'Reconnaître le drapeau',
      description:
          'Associe le drapeau affiché au bon pays.',
      icon: Icons.flag_rounded,
      isUltimate: false,
    ),
    ExpeditionMission(
      id: 'mixed',
      modeId: 'mixed',
      title: 'Épreuve combinée',
      description:
          'Enchaîne pays, capitales et drapeaux.',
      icon: Icons.extension_rounded,
      isUltimate: false,
    ),
    ExpeditionMission(
      id: 'ultimate',
      modeId: 'ultimate',
      title: 'Défi Silhouettes',
      description:
          'Reconnais un pays grâce à sa silhouette parmi quatre propositions.',
      icon: Icons.extension_rounded,
      isUltimate: true,
    ),
  ];

  @override
  String toString() {
    return 'ExpeditionMission('
        'id: $id, '
        'modeId: $modeId, '
        'title: $title, '
        'isUltimate: $isUltimate'
        ')';
  }
}
