import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/continent/continent_progress.dart';
import '../../game/continent/continent_storage.dart';
import '../../game/expedition/expedition_progress.dart';
import '../../game/expedition/expedition_storage.dart';
import '../../game/game_controller.dart';
import '../../passport/achievements/passport_achievement.dart';
import '../../passport/achievements/passport_achievement_catalog.dart';
import '../../passport/achievements/passport_achievement_progress.dart';
import '../../passport/achievements/passport_achievement_snapshot_builder.dart';
import '../../passport/achievements/passport_achievement_storage.dart';
import '../design/geopoint_design.dart';

class PassportAchievementsScreen extends StatefulWidget {
  const PassportAchievementsScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<PassportAchievementsScreen> createState() =>
      _PassportAchievementsScreenState();
}

class _PassportAchievementsScreenState
    extends State<PassportAchievementsScreen> {
  PassportAchievementCategory? _selectedCategory;
  PassportAchievementProgress _achievementProgress =
      PassportAchievementProgress.initial();
  ExpeditionProgress _expeditionProgress = ExpeditionProgress.initial();
  ContinentProgress _continentProgress = ContinentProgress.initial();
  bool _resourcesLoaded = false;
  bool _synchronizing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    unawaited(_loadResources());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    if (_resourcesLoaded) {
      unawaited(_synchronizeProgress());
    }
  }

  Future<void> _loadResources() async {
    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      PassportAchievementStorage.load(),
      ExpeditionStorage.load(),
      ContinentStorage.load(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _achievementProgress = (values[0] as PassportAchievementProgress)
          .mergeCompletedTierDates(
        widget.controller.passportProgress.completedAchievementTierDates,
      );
      _expeditionProgress = values[1] as ExpeditionProgress;
      _continentProgress = values[2] as ContinentProgress;
      _resourcesLoaded = true;
    });
    await _synchronizeProgress();
  }

  Future<void> _synchronizeProgress() async {
    if (_synchronizing || !_resourcesLoaded) {
      return;
    }
    _synchronizing = true;
    try {
      final PassportAchievementProgress previous = _achievementProgress;
      final PassportAchievementProgress updated = previous.synchronize(
        snapshot: _snapshot,
      );
      if (identical(previous, updated)) {
        return;
      }

      final Set<String> newTierIds =
          updated.newlyCompletedTierIdsComparedWith(previous);
      if (mounted) {
        setState(() => _achievementProgress = updated);
      } else {
        _achievementProgress = updated;
      }
      await widget.controller.synchronizePassportAchievementProgress(updated);

      final Map<String, PassportAchievementTier> tiersById =
          <String, PassportAchievementTier>{
        for (final PassportAchievementTier tier
            in PassportAchievementCatalog.allTiers())
          tier.id.toLowerCase(): tier,
      };
      for (final String tierId in newTierIds) {
        final String? rewardItemId = tiersById[tierId]?.rewardItemId;
        if (rewardItemId != null) {
          await widget.controller.unlockPassportCollectionItem(rewardItemId);
        }
      }
    } finally {
      _synchronizing = false;
    }
  }

  PassportAchievementSnapshot get _snapshot {
    return PassportAchievementSnapshotBuilder.build(
      progress: widget.controller.passportProgress,
      profile: widget.controller.playerProfile,
      countries: widget.controller.countries,
      expeditionProgress: _expeditionProgress,
      continentProgress: _continentProgress,
    );
  }

  int get _completedCatalogTierCount {
    return PassportAchievementCatalog.allTiers().where(
      (PassportAchievementTier tier) {
        return _achievementProgress.isTierCompleted(tier.id);
      },
    ).length;
  }

  PassportAchievement? _nextAchievement(PassportAchievementSnapshot snapshot) {
    PassportAchievement? result;
    double bestProgress = -1;
    for (final PassportAchievement achievement
        in PassportAchievementCatalog.achievements) {
      if (achievement.nextTier(snapshot) == null) {
        continue;
      }
      final double progress = achievement.progressToNextTier(snapshot);
      if (progress > bestProgress) {
        bestProgress = progress;
        result = achievement;
      }
    }
    return result;
  }

  void _showAchievementDetails(
    PassportAchievement achievement,
    PassportAchievementSnapshot snapshot,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GeoColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        final Color color = _categoryColor(achievement.category);
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: GeoColors.ink.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    _AchievementIcon(
                      icon: _achievementIcon(achievement.iconKey),
                      color: color,
                      size: 54,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            achievement.category.label.toUpperCase(),
                            style: GoogleFonts.nunitoSans(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            achievement.name,
                            style: GoogleFonts.fredoka(
                              color: GeoColors.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  achievement.description,
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.mutedInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (achievement.isPersonalOnly) ...<Widget>[
                  const SizedBox(height: 12),
                  const _PersonalOnlyNotice(dark: false),
                ],
                const SizedBox(height: 20),
                ...achievement.tiers.map((PassportAchievementTier tier) {
                  final bool completed =
                      _achievementProgress.isTierCompleted(tier.id);
                  final DateTime? completedAt =
                      _achievementProgress.completedAtByTierId[tier.id];
                  return _TierDetailRow(
                    tier: tier,
                    completed: completed,
                    completedAt: completedAt,
                    unitLabel: achievement.unitLabel,
                    color: color,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PassportAchievementSnapshot snapshot = _snapshot;
    final List<PassportAchievement> visibleAchievements =
        PassportAchievementCatalog.forCategory(_selectedCategory);
    final PassportAchievement? nextAchievement = _nextAchievement(snapshot);
    final int totalTiers = PassportAchievementCatalog.allTiers().length;

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
                            title: 'ACCOMPLISSEMENTS',
                            subtitle: 'Chaque étape de ton aventure compte',
                            onBack: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 22),
                          _AchievementSummary(
                            completedTiers: _completedCatalogTierCount,
                            totalTiers: totalTiers,
                            nextAchievement: nextAchievement,
                            snapshot: snapshot,
                            loading: !_resourcesLoaded,
                          ),
                          const SizedBox(height: 24),
                          const GeoSectionHeading(
                            eyebrow: 'DÉFIS',
                            title: 'Écris ton histoire',
                            description:
                                'Découverte, maîtrise, régularité, précision, '
                                'exploration et culture progressent séparément.',
                          ),
                          const SizedBox(height: 15),
                          _AchievementCategorySelector(
                            selected: _selectedCategory,
                            onSelected:
                                (PassportAchievementCategory? category) {
                              setState(() => _selectedCategory = category);
                            },
                          ),
                          const SizedBox(height: 16),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 38),
                      sliver: SliverList.builder(
                        itemCount: visibleAchievements.length,
                        itemBuilder: (BuildContext context, int index) {
                          final PassportAchievement achievement =
                              visibleAchievements[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 13),
                            child: _AchievementCard(
                              achievement: achievement,
                              snapshot: snapshot,
                              progress: _achievementProgress,
                              onPressed: () => _showAchievementDetails(
                                achievement,
                                snapshot,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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

class _AchievementSummary extends StatelessWidget {
  const _AchievementSummary({
    required this.completedTiers,
    required this.totalTiers,
    required this.nextAchievement,
    required this.snapshot,
    required this.loading,
  });

  final int completedTiers;
  final int totalTiers;
  final PassportAchievement? nextAchievement;
  final PassportAchievementSnapshot snapshot;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final double progress = totalTiers <= 0 ? 0 : completedTiers / totalTiers;
    final PassportAchievementTier? nextTier =
        nextAchievement?.nextTier(snapshot);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: GeoColors.navy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _AchievementIcon(
                icon: Icons.emoji_events_rounded,
                color: GeoColors.coral,
                size: 62,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      loading ? 'Mise à jour…' : '$completedTiers/$totalTiers',
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 31,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'paliers accomplis',
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: GeoColors.coral.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '7 catégories',
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 12,
              color: GeoColors.coral,
              backgroundColor: Colors.white,
            ),
          ),
          if (nextAchievement != null && nextTier != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'PROCHAIN OBJECTIF',
              style: GoogleFonts.nunitoSans(
                color: GeoColors.coral,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${nextAchievement!.name} · '
              '${nextAchievement!.valueFor(snapshot)}/${nextTier.target} '
              '${nextAchievement!.unitLabel}',
              style: GoogleFonts.nunitoSans(
                color: GeoColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementCategorySelector extends StatelessWidget {
  const _AchievementCategorySelector({
    required this.selected,
    required this.onSelected,
  });

  final PassportAchievementCategory? selected;
  final ValueChanged<PassportAchievementCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _CategoryChip(
            label: 'Tout',
            color: GeoColors.blue,
            selected: selected == null,
            onPressed: () => onSelected(null),
          ),
          ...PassportAchievementCategory.values.map(
            (PassportAchievementCategory category) => _CategoryChip(
              label: category.label,
              color: _categoryColor(category),
              selected: selected == category,
              onPressed: () => onSelected(category),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: Material(
        color: selected ? color : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
            child: Text(
              label,
              style: GoogleFonts.nunitoSans(
                color: selected ? GeoColors.ink : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.snapshot,
    required this.progress,
    required this.onPressed,
  });

  final PassportAchievement achievement;
  final PassportAchievementSnapshot snapshot;
  final PassportAchievementProgress progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = _categoryColor(achievement.category);
    final int value = achievement.valueFor(snapshot);
    final PassportAchievementTier? nextTier = achievement.nextTier(snapshot);
    final int completed = achievement.completedTierCount(snapshot);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _AchievementIcon(
                    icon: _achievementIcon(achievement.iconKey),
                    color: color,
                    size: 51,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          achievement.category.label.toUpperCase(),
                          style: GoogleFonts.nunitoSans(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          achievement.name,
                          style: GoogleFonts.fredoka(
                            color: GeoColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          achievement.description,
                          style: GoogleFonts.nunitoSans(
                            color: GeoColors.mutedInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: GeoColors.mutedInk,
                    size: 27,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: achievement.progressToNextTier(snapshot),
                        minHeight: 9,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    nextTier == null
                        ? '$value ${achievement.unitLabel}'
                        : '$value/${nextTier.target}',
                    style: GoogleFonts.fredoka(
                      color: GeoColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  ...achievement.tiers.map((PassportAchievementTier tier) {
                    final bool done = progress.isTierCompleted(tier.id);
                    return Container(
                      width: tier.isMajor ? 15 : 11,
                      height: tier.isMajor ? 15 : 11,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? color : Colors.transparent,
                        border: Border.all(color: color, width: 2),
                      ),
                    );
                  }),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$completed/${achievement.tiers.length} paliers',
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.ink,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: <Widget>[
                  Icon(
                    nextTier == null
                        ? Icons.check_circle_rounded
                        : Icons.card_giftcard_rounded,
                    color: color,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      nextTier == null
                          ? 'Tous les paliers sont terminés'
                          : 'Prochaine récompense : ${nextTier.rewardLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (achievement.isPersonalOnly) ...<Widget>[
                const SizedBox(height: 12),
                const _PersonalOnlyNotice(dark: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalOnlyNotice extends StatelessWidget {
  const _PersonalOnlyNotice({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.shield_outlined,
          size: 16,
          color: dark ? Colors.white : GeoColors.mutedInk,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Voyage personnel · aucun avantage compétitif',
            style: GoogleFonts.nunitoSans(
              color: dark ? Colors.white : GeoColors.mutedInk,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TierDetailRow extends StatelessWidget {
  const _TierDetailRow({
    required this.tier,
    required this.completed,
    required this.completedAt,
    required this.unitLabel,
    required this.color,
  });

  final PassportAchievementTier tier;
  final bool completed;
  final DateTime? completedAt;
  final String unitLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: completed ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: completed
              ? color.withValues(alpha: 0.55)
              : GeoColors.ink.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed ? color : const Color(0xFFE8EEF7),
            ),
            child: Icon(
              completed ? Icons.check_rounded : Icons.lock_outline_rounded,
              color: completed ? GeoColors.ink : GeoColors.mutedInk,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${tier.target} $unitLabel',
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  tier.rewardLabel,
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.mutedInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (completedAt != null)
                  Text(
                    'Obtenu le ${_formatDate(completedAt!)}',
                    style: GoogleFonts.nunitoSans(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
          if (tier.isMajor)
            Icon(Icons.star_rounded, color: color, size: 23),
        ],
      ),
    );
  }
}

class _AchievementIcon extends StatelessWidget {
  const _AchievementIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

Color _categoryColor(PassportAchievementCategory category) {
  switch (category) {
    case PassportAchievementCategory.discovery:
      return GeoColors.blue;
    case PassportAchievementCategory.mastery:
      return GeoColors.mint;
    case PassportAchievementCategory.regularity:
      return GeoColors.gold;
    case PassportAchievementCategory.precision:
      return GeoColors.coral;
    case PassportAchievementCategory.exploration:
      return GeoColors.sky;
    case PassportAchievementCategory.culture:
      return GeoColors.purple;
    case PassportAchievementCategory.personalTravel:
      return const Color(0xFFF29AB2);
  }
}

IconData _achievementIcon(String key) {
  switch (key) {
    case 'discover':
      return Icons.public_rounded;
    case 'brain':
      return Icons.school_rounded;
    case 'continent':
      return Icons.language_rounded;
    case 'calendar':
      return Icons.calendar_month_rounded;
    case 'streak':
      return Icons.local_fire_department_rounded;
    case 'target':
      return Icons.gps_fixed_rounded;
    case 'near':
      return Icons.my_location_rounded;
    case 'expedition':
      return Icons.hiking_rounded;
    case 'stars':
      return Icons.stars_rounded;
    case 'capital':
      return Icons.location_city_rounded;
    case 'flag':
      return Icons.flag_rounded;
    case 'silhouette':
      return Icons.extension_rounded;
    case 'city':
      return Icons.apartment_rounded;
    case 'currency':
      return Icons.paid_rounded;
    case 'language':
      return Icons.translate_rounded;
    case 'visited':
      return Icons.flight_takeoff_rounded;
    case 'wishlist':
      return Icons.favorite_rounded;
    default:
      return Icons.emoji_events_rounded;
  }
}

String _formatDate(DateTime date) {
  final DateTime local = date.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
