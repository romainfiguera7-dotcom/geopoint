import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../geobrain/geobrain_training_suggestion.dart';
import '../../passport/collections/passport_collection_item.dart';
import '../../passport/progression/passport_level_goal.dart';
import '../../passport/progress/passport_progress_v2.dart';
import '../../player/player_profile.dart';
import '../design/geopoint_design.dart';
import '../statistics/statistics_overview_screen.dart';
import '../social/friend_management_screen.dart';
import '../training/training_screen.dart';
import 'geobrain_screen.dart';
import 'passport_achievements_screen.dart';
import 'passport_collections_screen.dart';
import 'passport_world_screen.dart';

class PassportHubScreen extends StatefulWidget {
  const PassportHubScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<PassportHubScreen> createState() => _PassportHubScreenState();
}

class _PassportHubScreenState extends State<PassportHubScreen> {
  final Set<String> _ignoredSuggestionIds = <String>{};

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _openCollections(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return PassportCollectionsScreen(controller: controller);
        },
      ),
    );
  }

  void _openStatistics(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return StatisticsOverviewScreen(controller: controller);
        },
      ),
    );
  }

  void _openWorld(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return PassportWorldScreen(controller: controller);
        },
      ),
    );
  }

  void _openContinents(BuildContext context) {
    _openWorld(context);
  }

  void _openAchievements(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return PassportAchievementsScreen(controller: controller);
        },
      ),
    );
  }

  void _openDifficultyReview(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TrainingScreen(
            controller: controller,
            reviewDifficultiesOnly: true,
          );
        },
      ),
    );
  }

  void _openGeoBrain(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return GeoBrainScreen(controller: controller);
        },
      ),
    );
  }

  void _openFriends(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const FriendManagementScreen(),
      ),
    );
  }

  void _openSuggestion(
    BuildContext context,
    GeoBrainTrainingSuggestion suggestion,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TrainingScreen(
            controller: controller,
            suggestion: suggestion,
          );
        },
      ),
    );
  }

  int get _worldEntityCount {
    return controller.countries
        .map((country) => country.id.trim().toUpperCase())
        .where((String entityId) => entityId.isNotEmpty)
        .toSet()
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final PassportProgressV2 progress = controller.passportProgress;
    final PlayerProfile profile = controller.playerProfile;
    final PassportLevelGoal levelGoal = PassportLevelGoal.forProfile(profile);
    final int worldEntityCount = _worldEntityCount;
    final DateTime now = DateTime.now();
    final int retainedMasteryScore = controller.geoBrainService.profile
        .globalRetainedMasteryScoreAt(now)
        .round();
    final int reviewCount =
        controller.geoBrainService.profile.reviewCountryCountAt(now);
    final List<GeoBrainTrainingSuggestion> suggestions =
        const GeoBrainTrainingSuggestionEngine().build(
      profile: controller.geoBrainService.profile,
      countries: controller.countries,
      now: DateTime.now(),
      ignoredSuggestionIds: _ignoredSuggestionIds,
    );

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 38),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'MON PASSEPORT',
                      subtitle: 'Toute ta progression PointGeo',
                      onBack: () => Navigator.of(context).pop(),
                      trailing: _HeaderLevelBadge(
                        level: profile.currentLevel,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _PlayerProgressCard(
                      displayName: controller.passport.displayName,
                      profile: profile,
                      goal: levelGoal,
                    ),
                    const SizedBox(height: 14),
                    _GeoBrainMasteryCard(
                      retainedMasteryScore: retainedMasteryScore,
                      masteredCount: progress.masteredEntityCount,
                      totalEntityCount: worldEntityCount,
                      reviewCount: reviewCount,
                      onPressed: () => _openGeoBrain(context),
                    ),
                    const SizedBox(height: 22),
                    const GeoSectionHeading(
                      eyebrow: 'PROGRESSION',
                      title: 'Ton aventure en un coup d’œil',
                      description:
                          'Découvre le monde, consolide tes connaissances et '
                          'complète tes collections.',
                    ),
                    const SizedBox(height: 15),
                    _WorldProgressCard(
                      discoveredCount: progress.discoveredEntityCount,
                      masteredCount: progress.masteredEntityCount,
                      totalEntityCount: worldEntityCount,
                      onPressed: () => _openWorld(context),
                    ),
                    const SizedBox(height: 14),
                    _PassportDestinationGrid(
                      items: <_PassportDestination>[
                        _PassportDestination(
                          icon: Icons.travel_explore_rounded,
                          title: 'CONTINENTS',
                          subtitle: 'Suis ta progression zone par zone.',
                          color: GeoColors.sky,
                          badge: '6 zones',
                          onPressed: () => _openContinents(context),
                        ),
                        _PassportDestination(
                          icon: Icons.collections_bookmark_rounded,
                          title: 'COLLECTIONS',
                          subtitle: 'Tampons, emblèmes, titres et objets.',
                          color: GeoColors.gold,
                          badge:
                              '${progress.unlockedCountryStampCount}/$worldEntityCount',
                          onPressed: () => _openCollections(context),
                        ),
                        _PassportDestination(
                          icon: Icons.emoji_events_rounded,
                          title: 'ACCOMPLISSEMENTS',
                          subtitle: 'Relève des objectifs de progression.',
                          color: GeoColors.coral,
                          badge: 'Disponible',
                          onPressed: () => _openAchievements(context),
                        ),
                        _PassportDestination(
                          icon: Icons.psychology_alt_rounded,
                          title: 'GEOBRAIN',
                          subtitle:
                              'Comprends tes forces et ce qu’il faut réviser.',
                          color: GeoColors.purple,
                          badge: '$retainedMasteryScore% maîtrise',
                          onPressed: () => _openGeoBrain(context),
                        ),
                        _PassportDestination(
                          icon: Icons.query_stats_rounded,
                          title: 'STATISTIQUES',
                          subtitle: 'Analyse tes parties et tes résultats.',
                          color: GeoColors.purple,
                          badge: '${profile.gamesPlayed} parties',
                          onPressed: () => _openStatistics(context),
                        ),
                        _PassportDestination(
                          icon: Icons.psychology_alt_rounded,
                          title: 'RÉVISER',
                          subtitle:
                              'Retravaille les connaissances choisies par ton GeoBrain.',
                          color: GeoColors.mint,
                          badge: '$reviewCount à réviser',
                          onPressed: () => _openDifficultyReview(context),
                        ),
                      ],
                    ),
                    if (!profile.isChildProfile) ...<Widget>[
                      const SizedBox(height: 14),
                      _PassportFriendsShortcut(
                        onPressed: () => _openFriends(context),
                      ),
                    ],
                    if (suggestions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 24),
                      const GeoSectionHeading(
                        eyebrow: 'GEOBRAIN',
                        title: 'Séances conseillées',
                        description:
                            'Des entraînements courts choisis à partir de tes réponses. Tu peux les ignorer sans modifier ta progression.',
                      ),
                      const SizedBox(height: 14),
                      for (final GeoBrainTrainingSuggestion suggestion
                          in suggestions) ...<Widget>[
                        _GeoBrainSuggestionCard(
                          suggestion: suggestion,
                          onStart: () => _openSuggestion(context, suggestion),
                          onIgnore: () {
                            setState(() {
                              _ignoredSuggestionIds.add(suggestion.id);
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
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

class _HeaderLevelBadge extends StatelessWidget {
  const _HeaderLevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GeoColors.gold,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'NIV. $level',
        style: GoogleFonts.fredoka(
          color: GeoColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlayerProgressCard extends StatelessWidget {
  const _PlayerProgressCard({
    required this.displayName,
    required this.profile,
    required this.goal,
  });

  final String displayName;
  final PlayerProfile profile;
  final PassportLevelGoal goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PassportPaperPainter()),
            ),
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isWide = constraints.maxWidth >= 650;
              final Widget identity = _PlayerIdentity(
                displayName: displayName,
                profile: profile,
                goal: goal,
              );
              final Widget nextGoal = _NextLevelGoalPanel(
                goal: goal,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(flex: 7, child: identity),
                    Container(
                      width: 1,
                      height: 142,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      color: const Color(0xFFB8D5ED),
                    ),
                    Expanded(flex: 5, child: nextGoal),
                  ],
                );
              }

              return Column(
                children: <Widget>[
                  identity,
                  const SizedBox(height: 18),
                  Container(height: 1, color: const Color(0xFFB8D5ED)),
                  const SizedBox(height: 15),
                  nextGoal,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlayerIdentity extends StatelessWidget {
  const _PlayerIdentity({
    required this.displayName,
    required this.profile,
    required this.goal,
  });

  final String displayName;
  final PlayerProfile profile;
  final PassportLevelGoal goal;

  String get _xpLabel {
    if (profile.isMaximumLevel) {
      return 'Niveau maximum · ${profile.totalXp} XP au total';
    }

    return '${profile.xpIntoCurrentLevel}/${goal.xpTarget} XP du palier '
        '· ${profile.totalXp} XP au total';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 82,
          height: 82,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const GeoCompassLogo(size: 76, showShadow: false),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: GeoColors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    profile.levelTierLabel,
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'NIVEAU JOUEUR · ACTIVITÉ',
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.blue,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fredoka(
                  color: GeoColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: GeoColors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      profile.displayLevelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: goal.progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.72),
                  color: GeoColors.blue,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _xpLabel,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.mutedInk,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'L’XP récompense ton activité générale, pas ton niveau de connaissance.',
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.mutedInk,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextLevelGoalPanel extends StatelessWidget {
  const _NextLevelGoalPanel({required this.goal});

  final PassportLevelGoal goal;

  @override
  Widget build(BuildContext context) {
    final PassportCollectionItem? reward =
        goal.rewards.isEmpty ? null : goal.rewards.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9E1F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            goal.isMaximumLevel ? 'PROGRESSION TERMINÉE' : 'PROCHAIN PALIER',
            style: GoogleFonts.nunitoSans(
              color: GeoColors.blue,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            goal.nextLevelLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            goal.isMaximumLevel
                ? 'Niveau maximum atteint'
                : 'Encore ${goal.xpRemaining} XP',
            style: GoogleFonts.nunitoSans(
              color: GeoColors.mutedInk,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: GeoColors.gold.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _levelRewardIcon(reward?.category),
                  color: GeoColors.ink,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      goal.rewardCategoryLabel,
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.mutedInk,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      goal.rewardSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GeoBrainMasteryCard extends StatelessWidget {
  const _GeoBrainMasteryCard({
    required this.retainedMasteryScore,
    required this.masteredCount,
    required this.totalEntityCount,
    required this.reviewCount,
    required this.onPressed,
  });

  final int retainedMasteryScore;
  final int masteredCount;
  final int totalEntityCount;
  final int reviewCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final int safeScore = retainedMasteryScore.clamp(0, 100);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF8EE),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.psychology_alt_rounded,
                      color: Color(0xFF147D59),
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'MAÎTRISE GEOBRAIN · CONNAISSANCES',
                          style: GoogleFonts.nunitoSans(
                            color: const Color(0xFF147D59),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        Text(
                          '$safeScore% de maîtrise retenue',
                          style: GoogleFonts.fredoka(
                            color: GeoColors.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: GeoColors.ink,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: safeScore / 100,
                  backgroundColor: Colors.white.withValues(alpha: 0.72),
                  color: const Color(0xFF18A879),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Le GeoBrain mesure tes connaissances réelles et reste indépendant de ton niveau joueur.',
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.ink.withValues(alpha: 0.76),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _GeoBrainMetricChip(
                    icon: Icons.school_rounded,
                    label: '$masteredCount/$totalEntityCount maîtrisés',
                  ),
                  _GeoBrainMetricChip(
                    icon: Icons.refresh_rounded,
                    label: '$reviewCount à réviser',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeoBrainMetricChip extends StatelessWidget {
  const _GeoBrainMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF147D59), size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.ink,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _levelRewardIcon(PassportCollectionCategory? category) {
  switch (category) {
    case PassportCollectionCategory.title:
      return Icons.workspace_premium_rounded;
    case PassportCollectionCategory.avatar:
      return Icons.face_retouching_natural_rounded;
    case PassportCollectionCategory.passportFrame:
      return Icons.filter_frames_rounded;
    case PassportCollectionCategory.passportBackground:
      return Icons.landscape_rounded;
    case PassportCollectionCategory.emblem:
      return Icons.military_tech_rounded;
    case PassportCollectionCategory.event:
    case null:
      return Icons.card_giftcard_rounded;
  }
}

class _WorldProgressCard extends StatelessWidget {
  const _WorldProgressCard({
    required this.discoveredCount,
    required this.masteredCount,
    required this.totalEntityCount,
    required this.onPressed,
  });

  final int discoveredCount;
  final int masteredCount;
  final int totalEntityCount;
  final VoidCallback onPressed;

  double get _discoveryProgress {
    if (totalEntityCount <= 0) {
      return 0;
    }

    return (discoveredCount / totalEntityCount).clamp(0, 1).toDouble();
  }

  int get _nextObjective {
    if (discoveredCount >= totalEntityCount) {
      return totalEntityCount;
    }

    final int nextStep = ((discoveredCount ~/ 5) + 1) * 5;
    return nextStep.clamp(0, totalEntityCount);
  }

  String get _objectiveLabel {
    if (totalEntityCount <= 0) {
      return 'Le monde est en cours de chargement.';
    }

    if (discoveredCount >= totalEntityCount) {
      return 'Tout le monde a été découvert !';
    }

    final int remaining = _nextObjective - discoveredCount;
    final String entityLabel = remaining > 1 ? 'entités' : 'entité';
    return 'Prochain objectif : découvre encore $remaining $entityLabel.';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(27),
        child: Ink(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFFBFF6DB),
                Color(0xFF69DEB5),
              ],
            ),
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isWide = constraints.maxWidth >= 620;
              final Widget information = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.public_rounded,
                          color: GeoColors.ink,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'MONDE',
                              style: GoogleFonts.fredoka(
                                color: GeoColors.ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$discoveredCount/$totalEntityCount découverts',
                              style: GoogleFonts.nunitoSans(
                                color: GeoColors.ink.withValues(alpha: 0.70),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: GeoColors.ink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: _discoveryProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.68),
                      color: GeoColors.blue,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _objectiveLabel,
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              );

              if (!isWide) {
                return information;
              }

              return Row(
                children: <Widget>[
                  Expanded(child: information),
                  const SizedBox(width: 28),
                  _WorldMasteryBadge(
                    masteredCount: masteredCount,
                    totalEntityCount: totalEntityCount,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorldMasteryBadge extends StatelessWidget {
  const _WorldMasteryBadge({
    required this.masteredCount,
    required this.totalEntityCount,
  });

  final int masteredCount;
  final int totalEntityCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.school_rounded,
            color: Color(0xFF147D59),
            size: 25,
          ),
          const SizedBox(height: 4),
          Text(
            '$masteredCount/$totalEntityCount',
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'maîtrisés',
            style: GoogleFonts.nunitoSans(
              color: GeoColors.ink.withValues(alpha: 0.66),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassportDestinationGrid extends StatelessWidget {
  const _PassportDestinationGrid({required this.items});

  final List<_PassportDestination> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = 12;
        final int columnCount = constraints.maxWidth >= 720 ? 4 : 2;
        final double cardWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map<Widget>((_PassportDestination item) {
            return SizedBox(
              width: cardWidth,
              height: 165,
              child: _PassportDestinationCard(item: item),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _PassportFriendsShortcut extends StatelessWidget {
  const _PassportFriendsShortcut({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            children: <Widget>[
              Icon(Icons.group_rounded, color: GeoColors.sky, size: 27),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'MES AMIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Partage ton code et retrouve tes proches.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassportDestination {
  const _PassportDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.badge,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String badge;
  final VoidCallback onPressed;
}

class _PassportDestinationCard extends StatelessWidget {
  const _PassportDestinationCard({required this.item});

  final _PassportDestination item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 11,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.icon, color: GeoColors.ink, size: 23),
                  ),
                  const Spacer(),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 90),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      item.badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        color: GeoColors.ink,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  item.title,
                  maxLines: 1,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: GeoColors.ink.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeoBrainSuggestionCard extends StatelessWidget {
  const _GeoBrainSuggestionCard({
    required this.suggestion,
    required this.onStart,
    required this.onIgnore,
  });

  final GeoBrainTrainingSuggestion suggestion;
  final VoidCallback onStart;
  final VoidCallback onIgnore;

  IconData get _icon {
    switch (suggestion.type) {
      case GeoBrainSuggestionType.regionalReview:
        return Icons.map_rounded;
      case GeoBrainSuggestionType.thematicReview:
        return Icons.school_rounded;
      case GeoBrainSuggestionType.recentConfirmation:
        return Icons.verified_rounded;
      case GeoBrainSuggestionType.discovery:
        return Icons.explore_rounded;
    }
  }

  Color get _color {
    switch (suggestion.type) {
      case GeoBrainSuggestionType.regionalReview:
        return GeoColors.coral;
      case GeoBrainSuggestionType.thematicReview:
        return GeoColors.purple;
      case GeoBrainSuggestionType.recentConfirmation:
        return GeoColors.sky;
      case GeoBrainSuggestionType.discovery:
        return GeoColors.mint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _color, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_icon, color: GeoColors.ink, size: 27),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  suggestion.title,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  suggestion.reason,
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.mutedInk,
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${suggestion.questionCount} questions',
                        style: GoogleFonts.nunitoSans(
                          color: GeoColors.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onIgnore,
                      child: const Text('IGNORER'),
                    ),
                    FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow_rounded, size: 19),
                      label: const Text('LANCER'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PassportPaperPainter extends CustomPainter {
  const _PassportPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = GeoColors.blue.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Offset stampCenter = Offset(
      size.width * 0.84,
      size.height * 0.70,
    );

    canvas.drawCircle(stampCenter, 42, line);
    canvas.drawCircle(stampCenter, 35, line);
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.90),
      Offset(size.width, size.height * 0.56),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.98),
      Offset(size.width, size.height * 0.68),
      line,
    );
  }

  @override
  bool shouldRepaint(
    covariant _PassportPaperPainter oldDelegate,
  ) {
    return false;
  }
}
