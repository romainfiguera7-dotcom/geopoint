import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:google_fonts/google_fonts.dart';

import '../../game/continent/continent_progress.dart';
import '../../game/continent/continent_storage.dart';
import '../../game/expedition/expedition_progress.dart';
import '../../game/expedition/expedition_storage.dart';
import '../../game/game_controller.dart';
import '../../passport/collections/passport_collection_catalog.dart';
import '../../passport/collections/passport_collection_item.dart';
import '../design/geopoint_design.dart';
import 'passport_country_stamp_book_screen.dart';

class PassportCollectionsScreen extends StatefulWidget {
  const PassportCollectionsScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<PassportCollectionsScreen> createState() =>
      _PassportCollectionsScreenState();
}

class _PassportCollectionsScreenState extends State<PassportCollectionsScreen> {
  PassportCollectionCategory? _selectedCategory;
  ExpeditionProgress _expeditionProgress = ExpeditionProgress.initial();
  ContinentProgress _continentProgress = ContinentProgress.initial();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    unawaited(_loadExpeditionProgress());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadExpeditionProgress() async {
    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      ExpeditionStorage.load(),
      ContinentStorage.load(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _expeditionProgress = values[0] as ExpeditionProgress;
      _continentProgress = values[1] as ContinentProgress;
    });
  }

  int get _expeditionStars {
    int total = 0;
    for (final Map<String, int> missions
        in _expeditionProgress.starsByExpedition.values) {
      for (final int stars in missions.values) {
        total += stars.clamp(0, 3);
      }
    }
    for (final Map<String, int> levels
        in _continentProgress.starsByExpedition.values) {
      for (final int stars in levels.values) {
        total += stars.clamp(0, 3);
      }
    }
    return total;
  }

  int get _completedExpeditionLevels {
    int total = 0;
    for (final Map<String, int> missions
        in _expeditionProgress.starsByExpedition.values) {
      total += missions.values.where((int stars) => stars > 0).length;
    }
    for (final Map<String, int> levels
        in _continentProgress.starsByExpedition.values) {
      total += levels.values.where((int stars) => stars > 0).length;
    }
    return total;
  }

  PassportCollectionSnapshot get _snapshot {
    final progress = widget.controller.passportProgress;
    final profile = widget.controller.playerProfile;
    return PassportCollectionSnapshot(
      playerLevel: profile.currentLevel,
      discoveredEntities: progress.discoveredEntityCount,
      masteredEntities: progress.masteredEntityCount,
      countryStamps: progress.unlockedCountryStampCount,
      visitedEntities: progress.visitedEntityCount,
      gamesPlayed: profile.gamesPlayed,
      questionsPlayed: profile.totalAnswers,
      expeditionStars: _expeditionStars,
      completedExpeditionLevels: _completedExpeditionLevels,
      currentLicenseId: widget.controller.passport.currentLicenseId,
      explicitlyUnlockedItemIds: progress.unlockedCollectionItemIds,
    );
  }

  Future<void> _openStamps() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return PassportCountryStampBookScreen(
            controller: widget.controller,
          );
        },
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final PassportCollectionSnapshot snapshot = _snapshot;
    final int ownedItems = PassportCollectionCatalog.ownedCount(snapshot);
    final int totalItems = PassportCollectionCatalog.items.length;
    final int stampCount = snapshot.countryStamps;
    final int totalStamps = widget.controller.countries.length;
    final List<PassportCollectionItem> visibleItems = _selectedCategory == null
        ? const <PassportCollectionItem>[]
        : PassportCollectionCatalog.forCategory(_selectedCategory!);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(<Widget>[
                          GeoGameTopBar(
                            title: 'MES COLLECTIONS',
                            subtitle: 'Tout ce que ton aventure a débloqué',
                            onBack: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 22),
                          _CollectionsSummary(
                            ownedItems: ownedItems,
                            totalItems: totalItems,
                            stampCount: stampCount,
                            totalStamps: totalStamps,
                          ),
                          const SizedBox(height: 23),
                          const GeoSectionHeading(
                            eyebrow: 'VITRINE',
                            title: 'Construis ta collection',
                            description:
                                'Retrouve les objets possédés, ceux à débloquer '
                                'et leur méthode d’obtention.',
                          ),
                          const SizedBox(height: 14),
                          _CategorySelector(
                            selected: _selectedCategory,
                            onSelected: (PassportCollectionCategory? category) {
                              setState(() => _selectedCategory = category);
                            },
                          ),
                          const SizedBox(height: 15),
                          if (_selectedCategory == null)
                            _CollectionsOverview(
                              snapshot: snapshot,
                              totalStamps: totalStamps,
                              onOpenStamps: _openStamps,
                              onOpenCategory:
                                  (PassportCollectionCategory category) {
                                setState(() => _selectedCategory = category);
                              },
                            )
                          else ...<Widget>[
                            _CategoryHeading(
                              category: _selectedCategory!,
                              ownedCount: visibleItems
                                  .where((PassportCollectionItem item) {
                                    return item.isOwnedBy(snapshot);
                                  })
                                  .length,
                              totalCount: visibleItems.length,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ]),
                      ),
                    ),
                    if (_selectedCategory != null)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 38),
                        sliver: SliverLayoutBuilder(
                          builder: (
                            BuildContext context,
                            SliverConstraints constraints,
                          ) {
                            final int columns = constraints.crossAxisExtent >= 760
                                ? 3
                                : 2;
                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                mainAxisExtent: 258,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  final PassportCollectionItem item =
                                      visibleItems[index];
                                  return _CollectionItemCard(
                                    item: item,
                                    snapshot: snapshot,
                                    isEquippedTitle:
                                        item.category ==
                                                PassportCollectionCategory.title &&
                                            item.name ==
                                                widget.controller.playerProfile.title,
                                  );
                                },
                                childCount: visibleItems.length,
                              ),
                            );
                          },
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 38)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionsSummary extends StatelessWidget {
  const _CollectionsSummary({
    required this.ownedItems,
    required this.totalItems,
    required this.stampCount,
    required this.totalStamps,
  });

  final int ownedItems;
  final int totalItems;
  final int stampCount;
  final int totalStamps;

  @override
  Widget build(BuildContext context) {
    final int totalOwned = ownedItems + stampCount;
    final int grandTotal = totalItems + totalStamps;
    final double progress = grandTotal == 0 ? 0 : totalOwned / grandTotal;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: const Icon(
                  Icons.collections_bookmark_rounded,
                  color: GeoColors.blue,
                  size: 36,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$totalOwned/$grandTotal',
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'éléments collectionnés',
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 13,
              value: progress.clamp(0, 1),
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(GeoColors.blue),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryPill(
                  value: '$stampCount',
                  label: 'Tampons',
                  color: GeoColors.blue,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SummaryPill(
                  value: '$ownedItems',
                  label: 'Récompenses',
                  color: GeoColors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            value,
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                color: GeoColors.mutedInk,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.selected, required this.onSelected});

  final PassportCollectionCategory? selected;
  final ValueChanged<PassportCollectionCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _CategoryChip(
            label: 'Aperçu',
            selected: selected == null,
            onPressed: () => onSelected(null),
          ),
          for (final PassportCollectionCategory category
              in PassportCollectionCategory.values) ...<Widget>[
            const SizedBox(width: 8),
            _CategoryChip(
              label: category.label,
              selected: selected == category,
              onPressed: () => onSelected(category),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Text(
            label,
            style: GoogleFonts.nunitoSans(
              color: selected ? GeoColors.ink : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionsOverview extends StatelessWidget {
  const _CollectionsOverview({
    required this.snapshot,
    required this.totalStamps,
    required this.onOpenStamps,
    required this.onOpenCategory,
  });

  final PassportCollectionSnapshot snapshot;
  final int totalStamps;
  final VoidCallback onOpenStamps;
  final ValueChanged<PassportCollectionCategory> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final List<_OverviewCategory> categories = <_OverviewCategory>[
      _OverviewCategory(
        title: 'TAMPONS',
        subtitle: 'Le carnet complet des pays et territoires.',
        count: '${snapshot.countryStamps}/$totalStamps',
        icon: Icons.approval_rounded,
        color: GeoColors.blue,
        onPressed: onOpenStamps,
      ),
      for (final PassportCollectionCategory category
          in PassportCollectionCategory.values)
        _OverviewCategory(
          title: category.label.toUpperCase(),
          subtitle: _subtitleForCategory(category),
          count:
              '${PassportCollectionCatalog.ownedCount(snapshot, category: category)}/'
              '${PassportCollectionCatalog.forCategory(category).length}',
          icon: _categoryIcon(category),
          color: _categoryColor(category),
          onPressed: () => onOpenCategory(category),
        ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 720 ? 3 : 2;
        const double spacing = 10;
        final double width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final _OverviewCategory category in categories)
              SizedBox(
                width: width,
                height: 176,
                child: _OverviewCategoryCard(category: category),
              ),
          ],
        );
      },
    );
  }

  static String _subtitleForCategory(PassportCollectionCategory category) {
    switch (category) {
      case PassportCollectionCategory.emblem:
        return 'Les symboles de tes plus belles étapes.';
      case PassportCollectionCategory.title:
        return 'Tous les rangs gagnés avec ton niveau.';
      case PassportCollectionCategory.avatar:
        return 'Les accessoires de ton futur personnage.';
      case PassportCollectionCategory.passportFrame:
        return 'Les cadres gagnés au fil de ta progression.';
      case PassportCollectionCategory.passportBackground:
        return 'Les décors de tes différentes aventures.';
      case PassportCollectionCategory.event:
        return 'Des souvenirs disponibles pendant les événements.';
    }
  }
}

class _OverviewCategory {
  const _OverviewCategory({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
}

class _OverviewCategoryCard extends StatelessWidget {
  const _OverviewCategoryCard({required this.category});

  final _OverviewCategory category;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: category.onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: category.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 1.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(category.icon, color: GeoColors.ink, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    category.count,
                    style: GoogleFonts.fredoka(
                      color: GeoColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  category.title,
                  maxLines: 1,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.ink.withValues(alpha: 0.68),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading({
    required this.category,
    required this.ownedCount,
    required this.totalCount,
  });

  final PassportCollectionCategory category;
  final int ownedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _categoryColor(category),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(_categoryIcon(category), color: GeoColors.ink, size: 25),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                category.label,
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$ownedCount possédé${ownedCount > 1 ? 's' : ''} sur $totalCount',
                style: GoogleFonts.nunitoSans(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionItemCard extends StatelessWidget {
  const _CollectionItemCard({
    required this.item,
    required this.snapshot,
    required this.isEquippedTitle,
  });

  final PassportCollectionItem item;
  final PassportCollectionSnapshot snapshot;
  final bool isEquippedTitle;

  @override
  Widget build(BuildContext context) {
    final bool owned = item.isOwnedBy(snapshot);
    final bool hidden = item.isSecret && !owned;
    final Color categoryColor = _categoryColor(item.category);
    final Color rarityColor = _rarityColor(item.rarity);
    final String name = hidden ? 'Récompense secrète' : item.name;
    final String description = hidden
        ? 'Continue ton aventure pour révéler cette récompense.'
        : item.description;
    final String obtainMethod = hidden ? 'Condition secrète.' : item.obtainMethod;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: owned ? categoryColor : const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: owned ? Colors.white : Colors.white.withValues(alpha: 0.75),
          width: 1.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: owned
                      ? Colors.white.withValues(alpha: 0.70)
                      : const Color(0xFFDDE4ED),
                  shape: BoxShape.circle,
                ),
                child: hidden
                    ? Center(
                        child: Text(
                          '?',
                          style: GoogleFonts.fredoka(
                            color: GeoColors.mutedInk,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Icon(
                        _iconForKey(item.iconKey),
                        color: owned ? GeoColors.ink : GeoColors.mutedInk,
                        size: 28,
                      ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: owned ? 0.24 : 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  hidden ? 'SECRET' : item.rarity.label.toUpperCase(),
                  style: GoogleFonts.nunitoSans(
                    color: owned ? GeoColors.ink : rarityColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.ink.withValues(alpha: 0.61),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const Spacer(),
          if (!owned && item.unlockRule != PassportCollectionUnlockRule.eventOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: item.progress(snapshot),
                  backgroundColor: const Color(0xFFDDE4ED),
                  valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                owned ? Icons.check_circle_rounded : Icons.lock_rounded,
                size: 16,
                color: owned ? const Color(0xFF147D59) : GeoColors.mutedInk,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isEquippedTitle ? 'Titre équipé' : obtainMethod,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.ink.withValues(alpha: 0.78),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(PassportCollectionCategory category) {
  switch (category) {
    case PassportCollectionCategory.emblem:
      return Icons.military_tech_rounded;
    case PassportCollectionCategory.title:
      return Icons.workspace_premium_rounded;
    case PassportCollectionCategory.avatar:
      return Icons.face_retouching_natural_rounded;
    case PassportCollectionCategory.passportFrame:
      return Icons.filter_frames_rounded;
    case PassportCollectionCategory.passportBackground:
      return Icons.landscape_rounded;
    case PassportCollectionCategory.event:
      return Icons.celebration_rounded;
  }
}

Color _categoryColor(PassportCollectionCategory category) {
  switch (category) {
    case PassportCollectionCategory.emblem:
      return GeoColors.mint;
    case PassportCollectionCategory.title:
      return GeoColors.gold;
    case PassportCollectionCategory.avatar:
      return GeoColors.sky;
    case PassportCollectionCategory.passportFrame:
      return GeoColors.coral;
    case PassportCollectionCategory.passportBackground:
      return GeoColors.blue;
    case PassportCollectionCategory.event:
      return GeoColors.purple;
  }
}

Color _rarityColor(PassportCollectionRarity rarity) {
  switch (rarity) {
    case PassportCollectionRarity.common:
      return const Color(0xFF61738B);
    case PassportCollectionRarity.uncommon:
      return const Color(0xFF168B62);
    case PassportCollectionRarity.rare:
      return GeoColors.blue;
    case PassportCollectionRarity.epic:
      return const Color(0xFF7651D8);
    case PassportCollectionRarity.legendary:
      return const Color(0xFFB77900);
  }
}

IconData _iconForKey(String key) {
  switch (key) {
    case 'stamp':
      return Icons.approval_rounded;
    case 'explore':
      return Icons.travel_explore_rounded;
    case 'collection':
      return Icons.collections_bookmark_rounded;
    case 'brain':
      return Icons.psychology_rounded;
    case 'map':
      return Icons.map_rounded;
    case 'flight':
      return Icons.flight_takeoff_rounded;
    case 'world':
      return Icons.public_rounded;
    case 'title':
      return Icons.workspace_premium_rounded;
    case 'cap':
      return Icons.sports_baseball_rounded;
    case 'backpack':
      return Icons.backpack_rounded;
    case 'binoculars':
      return Icons.visibility_rounded;
    case 'compass':
      return Icons.explore_rounded;
    case 'coat':
      return Icons.checkroom_rounded;
    case 'crown':
      return Icons.emoji_events_rounded;
    case 'frame':
      return Icons.filter_frames_rounded;
    case 'background':
      return Icons.landscape_rounded;
    case 'accessory':
      return Icons.auto_awesome_rounded;
    case 'pioneer':
      return Icons.rocket_launch_rounded;
    case 'trophy':
      return Icons.emoji_events_rounded;
    case 'ribbon':
      return Icons.bookmark_rounded;
    case 'season':
      return Icons.stars_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}
