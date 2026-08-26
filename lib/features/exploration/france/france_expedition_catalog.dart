import 'package:flutter/material.dart';

enum FranceQuestionKind { region, overseas, point, mixed }

class FranceExpeditionLevel {
  const FranceExpeditionLevel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.category,
    required this.difficulty,
    required this.questionCount,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final FranceQuestionKind kind;
  final String category;
  final String difficulty;
  final int questionCount;
  final IconData icon;
}

abstract final class FranceExpeditionCatalog {
  static const List<FranceExpeditionLevel> levels = <FranceExpeditionLevel>[
    FranceExpeditionLevel(
      id: 'france-regions-reperes',
      title: 'Premières régions',
      subtitle: 'Place 6 grandes régions métropolitaines',
      kind: FranceQuestionKind.region,
      category: 'region',
      difficulty: 'easy',
      questionCount: 6,
      icon: Icons.map_rounded,
    ),
    FranceExpeditionLevel(
      id: 'france-regions',
      title: 'Les régions de France',
      subtitle: 'Maîtrise les 13 régions métropolitaines',
      kind: FranceQuestionKind.region,
      category: 'region',
      difficulty: 'intermediate',
      questionCount: 13,
      icon: Icons.grid_view_rounded,
    ),
    FranceExpeditionLevel(
      id: 'france-outre-mer',
      title: 'France d’outre-mer',
      subtitle: 'Associe chaque chef-lieu à sa région',
      kind: FranceQuestionKind.overseas,
      category: 'overseas',
      difficulty: 'intermediate',
      questionCount: 5,
      icon: Icons.public_rounded,
    ),
    FranceExpeditionLevel(
      id: 'france-grandes-villes',
      title: 'Grandes villes',
      subtitle: 'Place les métropoles françaises',
      kind: FranceQuestionKind.point,
      category: 'city',
      difficulty: 'intermediate',
      questionCount: 10,
      icon: Icons.location_city_rounded,
    ),
    FranceExpeditionLevel(
      id: 'france-prefectures',
      title: 'Préfectures régionales',
      subtitle: 'Retrouve les capitales des régions',
      kind: FranceQuestionKind.point,
      category: 'prefecture',
      difficulty: 'hard',
      questionCount: 10,
      icon: Icons.account_balance_rounded,
    ),
    FranceExpeditionLevel(
      id: 'france-fleuves',
      title: 'Fleuves et rivières',
      subtitle: 'Loire, Rhône, Seine, Garonne…',
      kind: FranceQuestionKind.point,
      category: 'river',
      difficulty: 'intermediate',
      questionCount: 6,
      icon: Icons.water_rounded,
    ),
    FranceExpeditionLevel(
      id: 'france-reliefs',
      title: 'Reliefs français',
      subtitle: 'Alpes, Pyrénées, Massif central…',
      kind: FranceQuestionKind.point,
      category: 'mountain',
      difficulty: 'intermediate',
      questionCount: 6,
      icon: Icons.landscape_rounded,
    ),
    FranceExpeditionLevel(
      id: 'france-monuments',
      title: 'Monuments emblématiques',
      subtitle: 'Du Mont-Saint-Michel aux Arènes de Nîmes',
      kind: FranceQuestionKind.point,
      category: 'monument',
      difficulty: 'hard',
      questionCount: 10,
      icon: Icons.account_balance_rounded,
    ),
    FranceExpeditionLevel(
      id: 'france-grand-tour',
      title: 'Le grand tour de France',
      subtitle: 'L’épreuve finale mélange tous les repères',
      kind: FranceQuestionKind.mixed,
      category: 'mixed',
      difficulty: 'expert',
      questionCount: 20,
      icon: Icons.workspace_premium_rounded,
    ),
  ];
}
