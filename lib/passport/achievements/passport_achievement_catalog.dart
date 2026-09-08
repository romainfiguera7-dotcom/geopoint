import 'passport_achievement.dart';

class PassportAchievementCatalog {
  PassportAchievementCatalog._();

  static const List<PassportAchievement> achievements =
      <PassportAchievement>[
    PassportAchievement(
      id: 'world_discovery',
      category: PassportAchievementCategory.discovery,
      name: 'Le monde se dévoile',
      description: 'Rencontre de nouveaux pays et territoires.',
      iconKey: 'discover',
      metric: PassportAchievementMetric.discoveredEntities,
      unitLabel: 'découverts',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'world_discovery_10',
          target: 10,
          rewardLabel: 'Cadre de Passeport bronze',
        ),
        PassportAchievementTier(
          id: 'world_discovery_50',
          target: 50,
          rewardLabel: 'Emblème Éclaireur du monde',
          rewardItemId: 'emblem_world_scout',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'world_discovery_100',
          target: 100,
          rewardLabel: 'Jumelles de terrain',
          rewardItemId: 'avatar_binoculars',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'world_discovery_200',
          target: 200,
          rewardLabel: 'Cadre de Passeport épique',
        ),
        PassportAchievementTier(
          id: 'world_discovery_258',
          target: 258,
          rewardLabel: 'Emblème secret Le monde entier',
          rewardItemId: 'emblem_world_complete',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'country_mastery',
      category: PassportAchievementCategory.mastery,
      name: 'Connaissances solides',
      description: 'Fais progresser les pays jusqu’à la maîtrise GeoBrain.',
      iconKey: 'brain',
      metric: PassportAchievementMetric.masteredEntities,
      unitLabel: 'maîtrisés',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'country_mastery_1',
          target: 1,
          rewardLabel: 'Ruban Première maîtrise',
        ),
        PassportAchievementTier(
          id: 'country_mastery_10',
          target: 10,
          rewardLabel: 'Emblème Esprit GeoBrain',
          rewardItemId: 'emblem_geobrain',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'country_mastery_25',
          target: 25,
          rewardLabel: 'Cadre GeoBrain argent',
        ),
        PassportAchievementTier(
          id: 'country_mastery_50',
          target: 50,
          rewardLabel: 'Emblème Cartographe confirmé',
          rewardItemId: 'emblem_master_cartographer',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'country_mastery_100',
          target: 100,
          rewardLabel: 'Aura de maîtrise',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'continent_mastery',
      category: PassportAchievementCategory.mastery,
      name: 'Maître des continents',
      description: 'Maîtrise entièrement chaque grande zone du monde.',
      iconKey: 'continent',
      metric: PassportAchievementMetric.masteredContinents,
      unitLabel: 'continents',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'continent_mastery_1',
          target: 1,
          rewardLabel: 'Fanion continental',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'continent_mastery_3',
          target: 3,
          rewardLabel: 'Emblème Triple horizon',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'continent_mastery_6',
          target: 6,
          rewardLabel: 'Bannière Maître des continents',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'play_regularity',
      category: PassportAchievementCategory.regularity,
      name: 'Rendez-vous régulier',
      description: 'Reviens jouer sur plusieurs journées différentes.',
      iconKey: 'calendar',
      metric: PassportAchievementMetric.playDays,
      unitLabel: 'jours',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'play_regularity_3',
          target: 3,
          rewardLabel: 'Autocollant Trois jours',
        ),
        PassportAchievementTier(
          id: 'play_regularity_7',
          target: 7,
          rewardLabel: 'Emblème Semaine d’exploration',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'play_regularity_30',
          target: 30,
          rewardLabel: 'Bordure Fidèle voyageur',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'play_regularity_100',
          target: 100,
          rewardLabel: 'Aura Cent escales',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'answer_streak',
      category: PassportAchievementCategory.regularity,
      name: 'Sans perdre le nord',
      description: 'Enchaîne les bonnes réponses sans erreur.',
      iconKey: 'streak',
      metric: PassportAchievementMetric.bestAnswerStreak,
      unitLabel: 'de série',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'answer_streak_5',
          target: 5,
          rewardLabel: 'Éclat de boussole',
        ),
        PassportAchievementTier(
          id: 'answer_streak_10',
          target: 10,
          rewardLabel: 'Emblème Cap maintenu',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'answer_streak_25',
          target: 25,
          rewardLabel: 'Traînée de comète',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'answer_streak_50',
          target: 50,
          rewardLabel: 'Aura Infaillible',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'precision_10km',
      category: PassportAchievementCategory.precision,
      name: 'Dans le mille',
      description: 'Place ta réponse à moins de 10 km de la cible.',
      iconKey: 'target',
      metric: PassportAchievementMetric.placementsUnder10Km,
      unitLabel: 'placements',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'precision_10km_1',
          target: 1,
          rewardLabel: 'Pastille Précision',
        ),
        PassportAchievementTier(
          id: 'precision_10km_10',
          target: 10,
          rewardLabel: 'Emblème Dans le mille',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'precision_10km_50',
          target: 50,
          rewardLabel: 'Viseur doré',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'precision_10km_100',
          target: 100,
          rewardLabel: 'Aura Précision absolue',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'precision_50km',
      category: PassportAchievementCategory.precision,
      name: 'Toujours très proche',
      description: 'Multiplie les placements à moins de 50 km.',
      iconKey: 'near',
      metric: PassportAchievementMetric.placementsUnder50Km,
      unitLabel: 'placements',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'precision_50km_10',
          target: 10,
          rewardLabel: 'Ruban Proche de la cible',
        ),
        PassportAchievementTier(
          id: 'precision_50km_50',
          target: 50,
          rewardLabel: 'Emblème Œil de lynx',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'precision_50km_200',
          target: 200,
          rewardLabel: 'Cadre Topographe',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'expedition_levels',
      category: PassportAchievementCategory.exploration,
      name: 'Chef d’expédition',
      description: 'Termine des étapes dans les parcours PointGeo.',
      iconKey: 'expedition',
      metric: PassportAchievementMetric.completedExpeditionLevels,
      unitLabel: 'étapes',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'expedition_levels_5',
          target: 5,
          rewardLabel: 'Écusson Premières étapes',
        ),
        PassportAchievementTier(
          id: 'expedition_levels_25',
          target: 25,
          rewardLabel: 'Emblème Chef d’expédition',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'expedition_levels_75',
          target: 75,
          rewardLabel: 'Sac d’expédition',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'expedition_levels_150',
          target: 150,
          rewardLabel: 'Bannière Grande traversée',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'expedition_stars',
      category: PassportAchievementCategory.exploration,
      name: 'Ciel étoilé',
      description: 'Accumule les étoiles dans toutes les expéditions.',
      iconKey: 'stars',
      metric: PassportAchievementMetric.expeditionStars,
      unitLabel: 'étoiles',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'expedition_stars_25',
          target: 25,
          rewardLabel: 'Poussière d’étoiles',
        ),
        PassportAchievementTier(
          id: 'expedition_stars_100',
          target: 100,
          rewardLabel: 'Emblème Constellation',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'expedition_stars_250',
          target: 250,
          rewardLabel: 'Cadre Galaxie',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'expedition_stars_500',
          target: 500,
          rewardLabel: 'Aura Ciel du monde',
          isMajor: true,
        ),
      ],
    ),
    ..._cultureAchievements,
    PassportAchievement(
      id: 'personal_visited',
      category: PassportAchievementCategory.personalTravel,
      name: 'Carnet de voyage réel',
      description: 'Ajoute les pays que tu as réellement visités.',
      iconKey: 'visited',
      metric: PassportAchievementMetric.visitedEntities,
      unitLabel: 'visités',
      isPersonalOnly: true,
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'personal_visited_5',
          target: 5,
          rewardLabel: 'Autocollant Voyageur réel',
        ),
        PassportAchievementTier(
          id: 'personal_visited_10',
          target: 10,
          rewardLabel: 'Emblème Voyageur véritable',
          rewardItemId: 'emblem_real_traveler',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'personal_visited_25',
          target: 25,
          rewardLabel: 'Cadre Souvenirs du monde',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'personal_visited_50',
          target: 50,
          rewardLabel: 'Bannière Grand voyageur',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'personal_wishlist',
      category: PassportAchievementCategory.personalTravel,
      name: 'Rêves d’ailleurs',
      description: 'Prépare ta liste personnelle de destinations.',
      iconKey: 'wishlist',
      metric: PassportAchievementMetric.wishlistedEntities,
      unitLabel: 'à visiter',
      isPersonalOnly: true,
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'personal_wishlist_5',
          target: 5,
          rewardLabel: 'Autocollant Prochaine escale',
        ),
        PassportAchievementTier(
          id: 'personal_wishlist_20',
          target: 20,
          rewardLabel: 'Cadre Rêves d’ailleurs',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'personal_wishlist_50',
          target: 50,
          rewardLabel: 'Bannière Mille projets',
          isMajor: true,
        ),
      ],
    ),
  ];

  static const List<PassportAchievement> _cultureAchievements =
      <PassportAchievement>[
    PassportAchievement(
      id: 'culture_capitals',
      category: PassportAchievementCategory.culture,
      name: 'Cap sur les capitales',
      description: 'Réponds correctement aux questions sur les capitales.',
      iconKey: 'capital',
      metric: PassportAchievementMetric.capitalCorrectAnswers,
      unitLabel: 'réponses',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'culture_capitals_25',
          target: 25,
          rewardLabel: 'Autocollant Capitale',
        ),
        PassportAchievementTier(
          id: 'culture_capitals_100',
          target: 100,
          rewardLabel: 'Emblème Ambassadeur',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'culture_capitals_250',
          target: 250,
          rewardLabel: 'Cadre Métropoles',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'culture_flags',
      category: PassportAchievementCategory.culture,
      name: 'Forêt de drapeaux',
      description: 'Reconnais les drapeaux du monde.',
      iconKey: 'flag',
      metric: PassportAchievementMetric.flagCorrectAnswers,
      unitLabel: 'réponses',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'culture_flags_25',
          target: 25,
          rewardLabel: 'Fanion coloré',
        ),
        PassportAchievementTier(
          id: 'culture_flags_100',
          target: 100,
          rewardLabel: 'Emblème Porte-drapeau',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'culture_flags_250',
          target: 250,
          rewardLabel: 'Bannière des nations',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'culture_silhouettes',
      category: PassportAchievementCategory.culture,
      name: 'Contours familiers',
      description: 'Reconnais les pays grâce à leur silhouette.',
      iconKey: 'silhouette',
      metric: PassportAchievementMetric.silhouetteCorrectAnswers,
      unitLabel: 'réponses',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'culture_silhouettes_10',
          target: 10,
          rewardLabel: 'Autocollant Silhouette',
        ),
        PassportAchievementTier(
          id: 'culture_silhouettes_50',
          target: 50,
          rewardLabel: 'Emblème Œil cartographe',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'culture_silhouettes_150',
          target: 150,
          rewardLabel: 'Cadre Sans frontières',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'culture_cities',
      category: PassportAchievementCategory.culture,
      name: 'Grandes villes',
      description: 'Développe ta connaissance des villes du monde.',
      iconKey: 'city',
      metric: PassportAchievementMetric.cityCorrectAnswers,
      unitLabel: 'réponses',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'culture_cities_25',
          target: 25,
          rewardLabel: 'Autocollant Skyline',
        ),
        PassportAchievementTier(
          id: 'culture_cities_100',
          target: 100,
          rewardLabel: 'Emblème Citadin du monde',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'culture_cities_250',
          target: 250,
          rewardLabel: 'Cadre Mégalopoles',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'culture_currencies',
      category: PassportAchievementCategory.culture,
      name: 'Monnaies du monde',
      description: 'Associe les monnaies aux bons pays.',
      iconKey: 'currency',
      metric: PassportAchievementMetric.currencyCorrectAnswers,
      unitLabel: 'réponses',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'culture_currencies_25',
          target: 25,
          rewardLabel: 'Jeton du voyageur',
        ),
        PassportAchievementTier(
          id: 'culture_currencies_100',
          target: 100,
          rewardLabel: 'Emblème Changeur du monde',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'culture_currencies_250',
          target: 250,
          rewardLabel: 'Cadre Trésor mondial',
          isMajor: true,
        ),
      ],
    ),
    PassportAchievement(
      id: 'culture_languages',
      category: PassportAchievementCategory.culture,
      name: 'Langues sans frontières',
      description: 'Reconnais les langues parlées à travers le monde.',
      iconKey: 'language',
      metric: PassportAchievementMetric.languageCorrectAnswers,
      unitLabel: 'réponses',
      tiers: <PassportAchievementTier>[
        PassportAchievementTier(
          id: 'culture_languages_25',
          target: 25,
          rewardLabel: 'Autocollant Bonjour',
        ),
        PassportAchievementTier(
          id: 'culture_languages_100',
          target: 100,
          rewardLabel: 'Emblème Polyglotte',
          isMajor: true,
        ),
        PassportAchievementTier(
          id: 'culture_languages_250',
          target: 250,
          rewardLabel: 'Cadre Voix du monde',
          isMajor: true,
        ),
      ],
    ),
  ];

  static List<PassportAchievement> forCategory(
    PassportAchievementCategory? category,
  ) {
    if (category == null) {
      return achievements;
    }
    return achievements
        .where((PassportAchievement achievement) {
          return achievement.category == category;
        })
        .toList(growable: false);
  }

  static Iterable<PassportAchievementTier> allTiers() sync* {
    for (final PassportAchievement achievement in achievements) {
      yield* achievement.tiers;
    }
  }

  static PassportAchievement? achievementForTierId(String tierId) {
    final String normalizedTierId = tierId.trim().toLowerCase();
    if (normalizedTierId.isEmpty) {
      return null;
    }

    for (final PassportAchievement achievement in achievements) {
      if (achievement.tiers.any((PassportAchievementTier tier) {
        return tier.id.toLowerCase() == normalizedTierId;
      })) {
        return achievement;
      }
    }
    return null;
  }

  static PassportAchievementTier? tierById(String tierId) {
    final String normalizedTierId = tierId.trim().toLowerCase();
    if (normalizedTierId.isEmpty) {
      return null;
    }

    for (final PassportAchievementTier tier in allTiers()) {
      if (tier.id.toLowerCase() == normalizedTierId) {
        return tier;
      }
    }
    return null;
  }
}
