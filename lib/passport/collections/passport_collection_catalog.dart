import 'passport_collection_item.dart';

class PassportCollectionCatalog {
  PassportCollectionCatalog._();

  static const List<PassportCollectionItem> _baseItems =
      <PassportCollectionItem>[
    PassportCollectionItem(
      id: 'emblem_first_stamp',
      category: PassportCollectionCategory.emblem,
      name: 'Premier tampon',
      description: 'Le premier souvenir de ton carnet de voyage.',
      obtainMethod: 'Obtenir ton premier tampon-pays.',
      iconKey: 'stamp',
      rarity: PassportCollectionRarity.common,
      unlockRule: PassportCollectionUnlockRule.countryStamps,
      unlockThreshold: 1,
    ),
    PassportCollectionItem(
      id: 'emblem_world_scout',
      category: PassportCollectionCategory.emblem,
      name: 'Éclaireur du monde',
      description: 'Tu as déjà rencontré de nombreux horizons.',
      obtainMethod: 'Découvrir 50 pays ou territoires.',
      iconKey: 'explore',
      rarity: PassportCollectionRarity.uncommon,
      unlockRule: PassportCollectionUnlockRule.discoveredEntities,
      unlockThreshold: 50,
    ),
    PassportCollectionItem(
      id: 'emblem_stamp_collector',
      category: PassportCollectionCategory.emblem,
      name: 'Collectionneur',
      description: 'Ton Passeport commence à raconter une grande aventure.',
      obtainMethod: 'Obtenir 100 tampons-pays.',
      iconKey: 'collection',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.countryStamps,
      unlockThreshold: 100,
    ),
    PassportCollectionItem(
      id: 'emblem_geobrain',
      category: PassportCollectionCategory.emblem,
      name: 'Esprit GeoBrain',
      description: 'Tes connaissances résistent au temps.',
      obtainMethod: 'Maîtriser 10 pays ou territoires.',
      iconKey: 'brain',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.masteredEntities,
      unlockThreshold: 10,
    ),
    PassportCollectionItem(
      id: 'emblem_master_cartographer',
      category: PassportCollectionCategory.emblem,
      name: 'Cartographe confirmé',
      description: 'Une grande partie du monde n’a plus de secret pour toi.',
      obtainMethod: 'Maîtriser 50 pays ou territoires.',
      iconKey: 'map',
      rarity: PassportCollectionRarity.epic,
      unlockRule: PassportCollectionUnlockRule.masteredEntities,
      unlockThreshold: 50,
    ),
    PassportCollectionItem(
      id: 'emblem_real_traveler',
      category: PassportCollectionCategory.emblem,
      name: 'Voyageur véritable',
      description: 'Tes aventures dépassent l’écran de PointGeo.',
      obtainMethod: 'Indiquer 10 pays visités dans l’Atlas.',
      iconKey: 'flight',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.visitedEntities,
      unlockThreshold: 10,
    ),
    PassportCollectionItem(
      id: 'emblem_world_complete',
      category: PassportCollectionCategory.emblem,
      name: 'Le monde entier',
      description: 'La récompense ultime des grands explorateurs.',
      obtainMethod: 'Obtenir les 258 tampons du monde.',
      iconKey: 'world',
      rarity: PassportCollectionRarity.legendary,
      unlockRule: PassportCollectionUnlockRule.countryStamps,
      unlockThreshold: 258,
      isSecret: true,
    ),
    PassportCollectionItem(
      id: 'title_first_steps',
      category: PassportCollectionCategory.title,
      name: 'Premiers pas',
      description: 'Le premier titre de chaque aventure PointGeo.',
      obtainMethod: 'Commencer la progression joueur.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.common,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 1,
    ),
    PassportCollectionItem(
      id: 'title_world_curious',
      category: PassportCollectionCategory.title,
      name: 'Curieux du monde',
      description: 'Ta curiosité commence à dépasser les frontières.',
      obtainMethod: 'Atteindre Curieux du monde I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.common,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 5,
    ),
    PassportCollectionItem(
      id: 'title_scout',
      category: PassportCollectionCategory.title,
      name: 'Éclaireur',
      description: 'Tu découvres de nouveaux repères sur la carte.',
      obtainMethod: 'Atteindre Éclaireur I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.common,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 9,
    ),
    PassportCollectionItem(
      id: 'title_explorer',
      category: PassportCollectionCategory.title,
      name: 'Explorateur',
      description: 'Tu avances avec assurance sur chaque continent.',
      obtainMethod: 'Atteindre Explorateur I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.uncommon,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 13,
    ),
    PassportCollectionItem(
      id: 'title_traveler',
      category: PassportCollectionCategory.title,
      name: 'Voyageur',
      description: 'Ton aventure PointGeo prend de l’ampleur.',
      obtainMethod: 'Atteindre Voyageur I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.uncommon,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 17,
    ),
    PassportCollectionItem(
      id: 'title_adventurer',
      category: PassportCollectionCategory.title,
      name: 'Aventurier',
      description: 'Les nouveaux défis ne te font plus peur.',
      obtainMethod: 'Atteindre Aventurier I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.uncommon,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 21,
    ),
    PassportCollectionItem(
      id: 'title_world_guide',
      category: PassportCollectionCategory.title,
      name: 'Guide du monde',
      description: 'Ton expérience accompagne désormais chaque voyage.',
      obtainMethod: 'Atteindre Guide du monde I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 25,
    ),
    PassportCollectionItem(
      id: 'title_navigator',
      category: PassportCollectionCategory.title,
      name: 'Navigateur',
      description: 'Tu gardes ton cap à travers tous les continents.',
      obtainMethod: 'Atteindre Navigateur I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 29,
    ),
    PassportCollectionItem(
      id: 'title_geographer',
      category: PassportCollectionCategory.title,
      name: 'Géographe',
      description: 'Ton parcours dans PointGeo devient remarquable.',
      obtainMethod: 'Atteindre Géographe I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 33,
    ),
    PassportCollectionItem(
      id: 'title_cartographer',
      category: PassportCollectionCategory.title,
      name: 'Cartographe',
      description: 'Tu lis le monde comme une carte ouverte.',
      obtainMethod: 'Atteindre Cartographe I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.epic,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 37,
    ),
    PassportCollectionItem(
      id: 'title_grand_cartographer',
      category: PassportCollectionCategory.title,
      name: 'Grand cartographe',
      description: 'Très peu de joueurs atteignent ce rang.',
      obtainMethod: 'Atteindre Grand cartographe I.',
      iconKey: 'title',
      rarity: PassportCollectionRarity.epic,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 41,
    ),
    PassportCollectionItem(
      id: 'title_world_master',
      category: PassportCollectionCategory.title,
      name: 'Maître du monde',
      description: 'Le titre ultime de la progression PointGeo.',
      obtainMethod: 'Atteindre Maître du monde I.',
      iconKey: 'crown',
      rarity: PassportCollectionRarity.legendary,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 45,
    ),
    PassportCollectionItem(
      id: 'avatar_explorer_cap',
      category: PassportCollectionCategory.avatar,
      name: 'Casquette d’explorateur',
      description: 'L’accessoire indispensable pour débuter.',
      obtainMethod: 'Commencer ton aventure PointGeo.',
      iconKey: 'cap',
      rarity: PassportCollectionRarity.common,
      unlockRule: PassportCollectionUnlockRule.always,
      unlockThreshold: 0,
    ),
    PassportCollectionItem(
      id: 'avatar_backpack',
      category: PassportCollectionCategory.avatar,
      name: 'Sac à dos azur',
      description: 'De quoi emporter tes souvenirs de voyage.',
      obtainMethod: 'Atteindre Curieux du monde I.',
      iconKey: 'backpack',
      rarity: PassportCollectionRarity.uncommon,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 5,
    ),
    PassportCollectionItem(
      id: 'avatar_binoculars',
      category: PassportCollectionCategory.avatar,
      name: 'Jumelles de terrain',
      description: 'Pour observer les frontières les plus discrètes.',
      obtainMethod: 'Découvrir 100 pays ou territoires.',
      iconKey: 'binoculars',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.discoveredEntities,
      unlockThreshold: 100,
    ),
    PassportCollectionItem(
      id: 'avatar_golden_compass',
      category: PassportCollectionCategory.avatar,
      name: 'Boussole dorée',
      description: 'Une boussole réservée aux globe-trotteurs.',
      obtainMethod: 'Atteindre Navigateur I.',
      iconKey: 'compass',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 29,
    ),
    PassportCollectionItem(
      id: 'avatar_cartographer_coat',
      category: PassportCollectionCategory.avatar,
      name: 'Veste de cartographe',
      description: 'La tenue des experts des cartes.',
      obtainMethod: 'Maîtriser 50 pays ou territoires.',
      iconKey: 'coat',
      rarity: PassportCollectionRarity.epic,
      unlockRule: PassportCollectionUnlockRule.masteredEntities,
      unlockThreshold: 50,
    ),
    PassportCollectionItem(
      id: 'avatar_world_crown',
      category: PassportCollectionCategory.avatar,
      name: 'Couronne du monde',
      description: 'Un objet que presque personne ne possède.',
      obtainMethod: 'Atteindre Maître du monde IV.',
      iconKey: 'crown',
      rarity: PassportCollectionRarity.legendary,
      unlockRule: PassportCollectionUnlockRule.playerLevel,
      unlockThreshold: 48,
      isSecret: true,
    ),
    PassportCollectionItem(
      id: 'event_passport_pioneer',
      category: PassportCollectionCategory.event,
      name: 'Pionnier du Passeport',
      description: 'Un souvenir réservé aux premiers voyageurs PointGeo.',
      obtainMethod: 'Avoir joué avant l’arrivée des premiers événements.',
      iconKey: 'pioneer',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.gamesPlayed,
      unlockThreshold: 1,
    ),
    PassportCollectionItem(
      id: 'event_world_challenge',
      category: PassportCollectionCategory.event,
      name: 'Défi mondial',
      description: 'Une médaille obtenue pendant un défi communautaire.',
      obtainMethod: 'Terminer un futur défi mondial spécial.',
      iconKey: 'trophy',
      rarity: PassportCollectionRarity.epic,
      unlockRule: PassportCollectionUnlockRule.eventOnly,
      unlockThreshold: 1,
    ),
    PassportCollectionItem(
      id: 'event_france_week',
      category: PassportCollectionCategory.event,
      name: 'Semaine française',
      description: 'Un ruban aux couleurs de l’exploration nationale.',
      obtainMethod: 'Participer à la future Semaine française.',
      iconKey: 'ribbon',
      rarity: PassportCollectionRarity.rare,
      unlockRule: PassportCollectionUnlockRule.eventOnly,
      unlockThreshold: 1,
    ),
    PassportCollectionItem(
      id: 'event_season_one',
      category: PassportCollectionCategory.event,
      name: 'Saison 1',
      description: 'Le trophée de la première saison PointGeo.',
      obtainMethod: 'Atteindre un palier pendant la future Saison 1.',
      iconKey: 'season',
      rarity: PassportCollectionRarity.legendary,
      unlockRule: PassportCollectionUnlockRule.eventOnly,
      unlockThreshold: 1,
    ),
    PassportCollectionItem(
      id: 'event_secret_reward',
      category: PassportCollectionCategory.event,
      name: 'Éclipse cartographique',
      description: 'Une récompense secrète encore inconnue.',
      obtainMethod: 'Condition secrète.',
      iconKey: 'secret',
      rarity: PassportCollectionRarity.legendary,
      unlockRule: PassportCollectionUnlockRule.eventOnly,
      unlockThreshold: 1,
      isSecret: true,
    ),
  ];

  static const List<_LevelRewardTheme> _levelRewardThemes =
      <_LevelRewardTheme>[
    _LevelRewardTheme(
      slug: 'first_steps',
      title: 'Premiers pas',
      frameName: 'Cadre du départ',
      backgroundName: 'Aube du voyage',
      avatarName: 'Foulard azur',
    ),
    _LevelRewardTheme(
      slug: 'world_curious',
      title: 'Curieux du monde',
      frameName: 'Cadre Curiosité',
      backgroundName: 'Horizon curieux',
      avatarName: 'Carnet de poche',
    ),
    _LevelRewardTheme(
      slug: 'scout',
      title: 'Éclaireur',
      frameName: 'Cadre Éclaireur',
      backgroundName: 'Sentier d’éclaireur',
      avatarName: 'Lanterne d’éclaireur',
    ),
    _LevelRewardTheme(
      slug: 'explorer',
      title: 'Explorateur',
      frameName: 'Cadre Exploration',
      backgroundName: 'Terres nouvelles',
      avatarName: 'Sacoche d’explorateur',
    ),
    _LevelRewardTheme(
      slug: 'traveler',
      title: 'Voyageur',
      frameName: 'Cadre Voyageur',
      backgroundName: 'Route du monde',
      avatarName: 'Écharpe du voyageur',
    ),
    _LevelRewardTheme(
      slug: 'adventurer',
      title: 'Aventurier',
      frameName: 'Cadre Aventure',
      backgroundName: 'Grand départ',
      avatarName: 'Gourde d’aventurier',
    ),
    _LevelRewardTheme(
      slug: 'world_guide',
      title: 'Guide du monde',
      frameName: 'Cadre du guide',
      backgroundName: 'Chemins partagés',
      avatarName: 'Insigne de guide',
    ),
    _LevelRewardTheme(
      slug: 'navigator',
      title: 'Navigateur',
      frameName: 'Cadre Navigation',
      backgroundName: 'Océan étoilé',
      avatarName: 'Longue-vue',
    ),
    _LevelRewardTheme(
      slug: 'geographer',
      title: 'Géographe',
      frameName: 'Cadre Géographe',
      backgroundName: 'Relief du monde',
      avatarName: 'Carnet de terrain',
    ),
    _LevelRewardTheme(
      slug: 'cartographer',
      title: 'Cartographe',
      frameName: 'Cadre Cartographe',
      backgroundName: 'Parchemin cartographique',
      avatarName: 'Plume de cartographe',
    ),
    _LevelRewardTheme(
      slug: 'grand_cartographer',
      title: 'Grand cartographe',
      frameName: 'Cadre Grand cartographe',
      backgroundName: 'Atlas magistral',
      avatarName: 'Cape de grand cartographe',
    ),
    _LevelRewardTheme(
      slug: 'world_master',
      title: 'Maître du monde',
      frameName: 'Cadre Maître du monde',
      backgroundName: 'Monde céleste',
      avatarName: 'Globe royal',
    ),
  ];

  static final List<PassportCollectionItem> items =
      List<PassportCollectionItem>.unmodifiable(<PassportCollectionItem>[
    ..._baseItems,
    ..._buildLevelTierRewards(),
  ]);

  static List<PassportCollectionItem> _buildLevelTierRewards() {
    final List<PassportCollectionItem> rewards = <PassportCollectionItem>[];
    for (int index = 0; index < _levelRewardThemes.length; index++) {
      final _LevelRewardTheme theme = _levelRewardThemes[index];
      final int majorLevel = index + 1;
      final int firstInternalLevel = index * 4 + 1;
      final PassportCollectionRarity rarity = _rarityForMajorLevel(majorLevel);

      rewards.addAll(<PassportCollectionItem>[
        PassportCollectionItem(
          id: 'level_${theme.slug}_frame',
          category: PassportCollectionCategory.passportFrame,
          name: theme.frameName,
          description:
              'Un cadre de Passeport inspiré du rang ${theme.title}.',
          obtainMethod: 'Atteindre ${theme.title} II.',
          iconKey: 'frame',
          rarity: rarity,
          unlockRule: PassportCollectionUnlockRule.playerLevel,
          unlockThreshold: firstInternalLevel + 1,
        ),
        PassportCollectionItem(
          id: 'level_${theme.slug}_background',
          category: PassportCollectionCategory.passportBackground,
          name: theme.backgroundName,
          description:
              'Un décor de Passeport inspiré du rang ${theme.title}.',
          obtainMethod: 'Atteindre ${theme.title} III.',
          iconKey: 'background',
          rarity: rarity,
          unlockRule: PassportCollectionUnlockRule.playerLevel,
          unlockThreshold: firstInternalLevel + 2,
        ),
        PassportCollectionItem(
          id: 'level_${theme.slug}_avatar',
          category: PassportCollectionCategory.avatar,
          name: theme.avatarName,
          description:
              'Un objet d’avatar inspiré du rang ${theme.title}.',
          obtainMethod: 'Atteindre ${theme.title} IV.',
          iconKey: 'accessory',
          rarity: rarity,
          unlockRule: PassportCollectionUnlockRule.playerLevel,
          unlockThreshold: firstInternalLevel + 3,
        ),
      ]);
    }
    return rewards;
  }

  static PassportCollectionRarity _rarityForMajorLevel(int majorLevel) {
    if (majorLevel >= 12) {
      return PassportCollectionRarity.legendary;
    }
    if (majorLevel >= 10) {
      return PassportCollectionRarity.epic;
    }
    if (majorLevel >= 7) {
      return PassportCollectionRarity.rare;
    }
    if (majorLevel >= 4) {
      return PassportCollectionRarity.uncommon;
    }
    return PassportCollectionRarity.common;
  }

  static List<PassportCollectionItem> forCategory(
    PassportCollectionCategory category,
  ) {
    return items
        .where((PassportCollectionItem item) => item.category == category)
        .toList(growable: false);
  }

  static int ownedCount(
    PassportCollectionSnapshot snapshot, {
    PassportCollectionCategory? category,
  }) {
    return items.where((PassportCollectionItem item) {
      return (category == null || item.category == category) &&
          item.isOwnedBy(snapshot);
    }).length;
  }

  static List<PassportCollectionItem> levelRewardsForLevel(int level) {
    return items.where((PassportCollectionItem item) {
      return item.unlockRule == PassportCollectionUnlockRule.playerLevel &&
          item.unlockThreshold == level;
    }).toList(growable: false);
  }

  static List<PassportCollectionItem> levelRewardsUnlockedBetween({
    required int previousLevel,
    required int newLevel,
  }) {
    if (newLevel <= previousLevel) {
      return const <PassportCollectionItem>[];
    }
    return items.where((PassportCollectionItem item) {
      return item.unlockRule == PassportCollectionUnlockRule.playerLevel &&
          item.unlockThreshold > previousLevel &&
          item.unlockThreshold <= newLevel;
    }).toList(growable: false);
  }
}

class _LevelRewardTheme {
  const _LevelRewardTheme({
    required this.slug,
    required this.title,
    required this.frameName,
    required this.backgroundName,
    required this.avatarName,
  });

  final String slug;
  final String title;
  final String frameName;
  final String backgroundName;
  final String avatarName;
}
