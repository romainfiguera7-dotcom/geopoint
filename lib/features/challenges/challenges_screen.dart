import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../challenges/challenge_definition.dart';
import '../../challenges/challenge_hub_service.dart';
import '../../challenges/challenge_player_state.dart';
import '../../challenges/challenge_ranking.dart';
import '../../challenges/challenge_reward_sync.dart';
import '../../challenges/challenge_season_reward.dart';
import '../../challenges/challenge_wallet.dart';
import '../../game/game_controller.dart';
import '../../monetization/ad_free_entitlement.dart';
import '../design/geopoint_design.dart';
import 'challenge_detail_screen.dart';
import 'challenge_leaderboards_screen.dart';
import 'challenge_studio_screen.dart';
import 'challenge_ui_helpers.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  late Future<ChallengeHubSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _snapshotFuture = _loadAndSynchronizeRewards();
  }

  Future<ChallengeHubSnapshot> _loadAndSynchronizeRewards() async {
    final ChallengeHubSnapshot snapshot = await ChallengeHubService.load(
      playerLevel: widget.controller.playerProfile.currentLevel,
      // Le mode enfant est temporairement désactivé pour la V1. Une ancienne
      // sauvegarde ne doit donc ni masquer les défis permanents, ni charger
      // leurs variantes enfant.
      isChildProfile: false,
      playerIdentity: widget.controller.playerIdentity,
    );
    final rankingSync = snapshot.rankingSync;
    if (rankingSync != null) {
      debugPrint(
        'GeoPoint Classement : synchronisation à l’ouverture '
        '${rankingSync.status.name} • '
        '${rankingSync.confirmedCount} validé(s), '
        '${rankingSync.quarantinedCount} en vérification, '
        '${rankingSync.rejectedCount} refusé(s), '
        '${rankingSync.pendingAfter} en attente'
        '${rankingSync.failureReason == null ? '' : ' • ${rankingSync.failureReason}'}',
      );
    }
    for (final ChallengeRewardClaimRecord claim
        in snapshot.playerState.rewardLedger.claims.values) {
      if (!claim.canDeliverReward) {
        continue;
      }
      await widget.controller.registerChallengeXpReward(
        rewardClaimId: claim.claimId,
        xp: claim.reward.xp,
        completedAt: claim.claimedAtUtc,
      );
    }
    return snapshot;
  }

  void _retry() {
    setState(_load);
  }

  Future<void> _openStudio() async {
    if (!kDebugMode) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ChallengeStudioScreen(
          controller: widget.controller,
        ),
      ),
    );
  }

  Future<void> _openChallenge(
    ChallengeHubSnapshot snapshot,
    ChallengeDefinition challenge,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) {
          return ChallengeDetailScreen(
            controller: widget.controller,
            challenge: challenge,
            progress: snapshot.playerState.progressFor(challenge.id),
            effectiveNowUtc: snapshot.clock.effectiveNowUtc,
          );
        },
      ),
    );
    if (mounted) {
      _retry();
    }
  }

  Future<void> _openLeaderboards({
    required ChallengeHubSnapshot snapshot,
    required ChallengeDefinition? daily,
    required ChallengeDefinition? weekly,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ChallengeLeaderboardsScreen(
          seasonKey: snapshot.pack.monthKey,
          dailyChallenge: daily,
          weeklyChallenge: weekly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                child: FutureBuilder<ChallengeHubSnapshot>(
                  future: _snapshotFuture,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<ChallengeHubSnapshot> asyncSnapshot,
                  ) {
                    return _buildBody(asyncSnapshot);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<ChallengeHubSnapshot> asyncSnapshot) {
    final Widget header = GeoGameTopBar(
      title: 'DÉFIS',
      subtitle: 'Chaque jour, une nouvelle aventure',
      onBack: () => Navigator.of(context).pop(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (kDebugMode) ...<Widget>[
            GeoRoundAction(
              icon: Icons.dashboard_customize_rounded,
              tooltip: 'PointGeo Studio',
              onPressed: _openStudio,
            ),
            const SizedBox(width: 8),
          ],
          if (asyncSnapshot.hasData)
            GeoRoundAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Actualiser',
              onPressed: _retry,
            ),
        ],
      ),
    );

    if (asyncSnapshot.connectionState != ConnectionState.done) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
        children: <Widget>[
          header,
          const SizedBox(height: 120),
          const Center(
            child: CircularProgressIndicator(color: GeoColors.gold),
          ),
        ],
      );
    }

    if (asyncSnapshot.hasError || !asyncSnapshot.hasData) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
        children: <Widget>[
          header,
          const SizedBox(height: 40),
          _LoadErrorCard(
            message: asyncSnapshot.error?.toString() ??
                'Les défis sont momentanément indisponibles.',
            onRetry: _retry,
          ),
        ],
      );
    }

    final ChallengeHubSnapshot snapshot = asyncSnapshot.data!;
    final ChallengeDefinition? daily = snapshot.dailyChallenge;
    final List<ChallengeDefinition> weekly =
        snapshot.challengesFor(ChallengePeriod.weekly);
    final List<ChallengeDefinition> monthly =
        snapshot.challengesFor(ChallengePeriod.monthly);
    final List<ChallengeDefinition> permanent =
        snapshot.challengesFor(ChallengePeriod.permanent);
    final ChallengeDefinition? weeklyChallenge =
        weekly.isEmpty ? null : weekly.first;
    final ChallengeDefinition? monthlyChallenge =
        monthly.isEmpty ? null : monthly.first;
    final List<ChallengeDefinition> history =
        snapshot.recentlyCompletedChallenges;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
      children: <Widget>[
        header,
        const SizedBox(height: 24),
        if (kDebugMode) ...<Widget>[
          const SizedBox(height: 12),
          _StudioAccessCard(onPressed: _openStudio),
        ],
        const SizedBox(height: 12),
        _ChallengeWalletCard(
          wallet: snapshot.playerState.wallet,
          pendingRewards:
              snapshot.playerState.rewardLedger.pendingClaims.length,
          syncReport: snapshot.rewardSync,
        ),
        if (snapshot.seasonRewardClaim?.wasDelivered == true) ...<Widget>[
          const SizedBox(height: 12),
          _SeasonRewardDeliveredCard(
            report: snapshot.seasonRewardClaim!,
          ),
        ],
        const SizedBox(height: 12),
        if (!snapshot.isChildProfile)
          _LeaderboardsAccessCard(
            onPressed: () => _openLeaderboards(
              snapshot: snapshot,
              daily: daily,
              weekly: weeklyChallenge,
            ),
          )
        else
          const _ChildProtectionCard(),
        const SizedBox(height: 24),
        const GeoSectionHeading(
          eyebrow: 'Aujourd’hui',
          title: 'Le défi du jour',
          description: 'Un objectif rapide pour faire avancer ton Passeport.',
        ),
        const SizedBox(height: 14),
        if (daily != null)
          _ChallengeCard(
            challenge: daily,
            progress: snapshot.playerState.progressFor(daily.id),
            nowUtc: snapshot.clock.effectiveNowUtc,
            color: GeoColors.coral,
            featured: true,
            onPressed: () => _openChallenge(snapshot, daily),
          )
        else
          const _EmptyPeriodCard(
            message: 'Aucun défi quotidien n’est disponible actuellement.',
          ),
        const SizedBox(height: 28),
        const GeoSectionHeading(
          eyebrow: 'Cette semaine',
          title: 'Le défi de la semaine',
          description:
              'Une mission plus longue à réussir avant la fin de la semaine.',
        ),
        const SizedBox(height: 14),
        if (weeklyChallenge == null)
          const _EmptyPeriodCard(
            message: 'Le prochain défi de la semaine arrive bientôt.',
          )
        else
          _ChallengeCard(
            challenge: weeklyChallenge,
            progress: snapshot.playerState.progressFor(weeklyChallenge.id),
            nowUtc: snapshot.clock.effectiveNowUtc,
            color: GeoColors.gold,
            featured: true,
            onPressed: () => _openChallenge(snapshot, weeklyChallenge),
          ),
        const SizedBox(height: 28),
        GeoSectionHeading(
          eyebrow: challengeMonthLabel(snapshot.pack.monthKey),
          title: 'Le défi du mois',
          description: 'La grande mission du mois et sa récompense spéciale.',
        ),
        const SizedBox(height: 14),
        if (monthlyChallenge == null)
          const _EmptyPeriodCard(
            message: 'Le prochain défi du mois arrive bientôt.',
          )
        else
          _ChallengeCard(
            challenge: monthlyChallenge,
            progress: snapshot.playerState.progressFor(monthlyChallenge.id),
            nowUtc: snapshot.clock.effectiveNowUtc,
            color: GeoColors.purple,
            featured: true,
            onPressed: () => _openChallenge(snapshot, monthlyChallenge),
          ),
        const SizedBox(height: 28),
        const GeoSectionHeading(
          eyebrow: 'Toujours disponibles',
          title: 'Défis permanents',
          description:
              'Améliore ton meilleur score sur le monde et les continents.',
        ),
        const SizedBox(height: 14),
        if (permanent.isEmpty)
          const _EmptyPeriodCard(
            message: 'Les défis permanents arrivent bientôt.',
          )
        else
          ...permanent.asMap().entries.map(
            (MapEntry<int, ChallengeDefinition> entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChallengeCard(
                challenge: entry.value,
                progress: snapshot.playerState.progressFor(entry.value.id),
                nowUtc: snapshot.clock.effectiveNowUtc,
                color: <Color>[
                  GeoColors.blue,
                  GeoColors.sky,
                  GeoColors.coral,
                  GeoColors.purple,
                  GeoColors.gold,
                  GeoColors.mint,
                ][entry.key % 6],
                featured: false,
                onPressed: () => _openChallenge(snapshot, entry.value),
              ),
            ),
          ),
        const SizedBox(height: 28),
        const GeoSectionHeading(
          eyebrow: 'Carnet de route',
          title: 'Historique récent',
        ),
        const SizedBox(height: 14),
        _HistoryCard(
          challenges: history,
          playerState: snapshot.playerState,
        ),
      ],
    );
  }
}

class _SeasonRewardDeliveredCard extends StatelessWidget {
  const _SeasonRewardDeliveredCard({required this.report});

  final ChallengeSeasonRewardClaimReport report;

  @override
  Widget build(BuildContext context) {
    final ChallengeReward reward = report.reward!;
    final ChallengeSeasonRewardTier tier =
        ChallengeSeasonRewardTier.forRank(report.rank!);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[GeoColors.purple, Color(0xFF3B75B7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GeoColors.gold.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.workspace_premium_rounded,
              color: GeoColors.gold, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SAISON ${report.seasonKey} • ${tier.label.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${reward.coins} pièces'
                  '${reward.diamonds > 0 ? ' + ${reward.diamonds} diamant${reward.diamonds > 1 ? 's' : ''}' : ''} crédités.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '#${report.rank}',
            style: GoogleFonts.fredoka(
              color: GeoColors.gold,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeWalletCard extends StatelessWidget {
  const _ChallengeWalletCard({
    required this.wallet,
    required this.pendingRewards,
    this.syncReport,
  });

  final ChallengeWallet wallet;
  final int pendingRewards;
  final ChallengeRewardSyncReport? syncReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF142A4A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: GeoColors.mint,
              ),
              const SizedBox(width: 9),
              Text(
                'MES RÉCOMPENSES',
                style: GoogleFonts.nunitoSans(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (pendingRewards > 0)
                Text(
                  '$pendingRewards en attente',
                  style: GoogleFonts.nunitoSans(
                    color: GeoColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              Expanded(
                child: _WalletAmount(
                  icon: Icons.monetization_on_rounded,
                  value: '${wallet.coins}',
                  label: 'Pièces',
                  color: GeoColors.gold,
                ),
              ),
              Expanded(
                child: _WalletAmount(
                  icon: Icons.diamond_rounded,
                  value: '${wallet.diamonds}',
                  label: 'Diamants',
                  color: GeoColors.sky,
                ),
              ),
              Expanded(
                child: _WalletAmount(
                  icon: Icons.trending_up_rounded,
                  value: '${wallet.progressionPoints}',
                  label: 'Progression',
                  color: GeoColors.mint,
                ),
              ),
            ],
          ),
          if (_syncMessage != null) ...<Widget>[
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(_syncIcon, color: _syncColor, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _syncMessage!,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? get _syncMessage {
    final ChallengeRewardSyncReport? report = syncReport;
    if (report == null ||
        report.status == ChallengeRewardSyncStatus.upToDate) {
      return null;
    }
    switch (report.status) {
      case ChallengeRewardSyncStatus.synchronized:
        return report.confirmedCount == 1
            ? '1 récompense vient d’être validée par le serveur.'
            : '${report.confirmedCount} récompenses viennent d’être validées.';
      case ChallengeRewardSyncStatus.awaitingValidation:
        return 'Les résultats officiels sont encore en cours de validation.';
      case ChallengeRewardSyncStatus.partiallyRejected:
        return 'Synchronisation terminée : ${report.confirmedCount} validée(s), '
            '${report.rejectedCount} refusée(s).';
      case ChallengeRewardSyncStatus.pendingConnection:
      case ChallengeRewardSyncStatus.serverUnavailable:
        return 'Les gains en attente seront validés à la prochaine connexion.';
      case ChallengeRewardSyncStatus.invalidServerResponse:
        return 'La réponse distante a été ignorée pour protéger tes gains.';
      case ChallengeRewardSyncStatus.storageFailure:
        return 'La synchronisation sera retentée après la sauvegarde.';
      case ChallengeRewardSyncStatus.upToDate:
        return null;
    }
  }

  IconData get _syncIcon {
    switch (syncReport?.status) {
      case ChallengeRewardSyncStatus.synchronized:
        return Icons.cloud_done_rounded;
      case ChallengeRewardSyncStatus.awaitingValidation:
        return Icons.cloud_sync_rounded;
      case ChallengeRewardSyncStatus.partiallyRejected:
      case ChallengeRewardSyncStatus.invalidServerResponse:
        return Icons.gpp_maybe_rounded;
      case ChallengeRewardSyncStatus.pendingConnection:
      case ChallengeRewardSyncStatus.serverUnavailable:
      case ChallengeRewardSyncStatus.storageFailure:
      case ChallengeRewardSyncStatus.upToDate:
      case null:
        return Icons.cloud_queue_rounded;
    }
  }

  Color get _syncColor {
    switch (syncReport?.status) {
      case ChallengeRewardSyncStatus.synchronized:
        return GeoColors.mint;
      case ChallengeRewardSyncStatus.awaitingValidation:
        return GeoColors.gold;
      case ChallengeRewardSyncStatus.partiallyRejected:
      case ChallengeRewardSyncStatus.invalidServerResponse:
        return GeoColors.coral;
      case ChallengeRewardSyncStatus.pendingConnection:
      case ChallengeRewardSyncStatus.serverUnavailable:
      case ChallengeRewardSyncStatus.storageFailure:
      case ChallengeRewardSyncStatus.upToDate:
      case null:
        return GeoColors.gold;
    }
  }
}

class _WalletAmount extends StatelessWidget {
  const _WalletAmount({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudioAccessCard extends StatelessWidget {
  const _StudioAccessCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: GeoColors.purple.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: GeoColors.purple.withValues(alpha: 0.72),
            ),
          ),
          child: const Row(
            children: <Widget>[
              Icon(Icons.dashboard_customize_rounded, color: Colors.white),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'POINTGEO STUDIO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Créer et programmer les défis — développement uniquement',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardsAccessCard extends StatelessWidget {
  const _LeaderboardsAccessCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[GeoColors.purple, Color(0xFF4C80B7)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: GeoColors.gold,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: GeoColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'CLASSEMENTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Jour, semaine et saison • meilleur score conservé',
                      style: TextStyle(color: Colors.white70, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildProtectionCard extends StatelessWidget {
  const _ChildProtectionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: GeoColors.sky.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white70),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.shield_rounded, color: GeoColors.navy, size: 34),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PROFIL ENFANT PROTÉGÉ',
                  style: TextStyle(
                    color: GeoColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Défis gratuits, sans publicité et sans classement public.',
                  style: TextStyle(
                    color: Color(0xFF274967),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.progress,
    required this.nowUtc,
    required this.color,
    required this.onPressed,
    this.featured = false,
  });

  final ChallengeDefinition challenge;
  final ChallengeAttemptProgress progress;
  final DateTime nowUtc;
  final Color color;
  final VoidCallback onPressed;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : GeoColors.navy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.14),
                  color,
                ),
                color,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: featured ? 54 : 46,
                    height: featured ? 54 : 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.23),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      challengeIcon(challenge.modeId),
                      color: foreground,
                      size: featured ? 29 : 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          challenge.title,
                          style: GoogleFonts.fredoka(
                            color: foreground,
                            fontSize: featured ? 22 : 18,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          challenge.period == ChallengePeriod.permanent
                              ? 'TOUJOURS DISPONIBLE • MEILLEUR SCORE CLASSÉ'
                              : challengeTimeRemaining(
                                  challenge.validUntilUtc.difference(nowUtc),
                                ),
                          style: GoogleFonts.nunitoSans(
                            color: foreground.withValues(alpha: 0.72),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    progress.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_rounded,
                    color: foreground,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                challenge.description,
                maxLines: featured ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunitoSans(
                  color: foreground.withValues(alpha: 0.82),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  _CardPill(
                    text: challengeDifficultyLabel(challenge.difficultyId),
                    foreground: foreground,
                  ),
                  _CardPill(
                    text: challenge.questionCount != null
                        ? '${challenge.questionCount} questions'
                        : '${challenge.durationSeconds} secondes',
                    foreground: foreground,
                  ),
                  _CardPill(
                    text: '+${challenge.reward.xp} XP',
                    foreground: foreground,
                  ),
                  if (challenge.retryPolicy
                          .unlimitedRewardedAdvertisementRetries ||
                      challenge.retryPolicy.unlimitedFreeAttempts)
                    _CardPill(
                      text: challenge.retryPolicy.rewardedAdvertisementAllowed &&
                              !AdFreeAccess.instance.isActive
                          ? 'Pub • illimité'
                          : 'Rejouer • illimité',
                      foreground: foreground,
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

class _CardPill extends StatelessWidget {
  const _CardPill({required this.text, required this.foreground});

  final String text;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.nunitoSans(
          color: foreground,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.challenges,
    required this.playerState,
  });

  final List<ChallengeDefinition> challenges;
  final ChallengePlayerState playerState;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GeoColors.cream,
        borderRadius: BorderRadius.circular(24),
      ),
      child: challenges.isEmpty
          ? Row(
              children: <Widget>[
                const Icon(Icons.route_rounded, color: GeoColors.mutedInk),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tes défis terminés apparaîtront ici.',
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.mutedInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: challenges
                  .map(
                    (ChallengeDefinition challenge) => _HistoryTile(
                      challenge: challenge,
                      rankingSubmission: playerState.rankingLedger
                          .submissionForChallenge(challenge.id),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.challenge,
    required this.rankingSubmission,
  });

  final ChallengeDefinition challenge;
  final ChallengeRankingSubmission? rankingSubmission;

  @override
  Widget build(BuildContext context) {
    final ChallengeLeaderboardPosition? position = rankingSubmission?.position;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.check_circle_rounded,
        color: GeoColors.mint,
      ),
      title: Text(
        challenge.title,
        style: GoogleFonts.fredoka(
          color: GeoColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: challenge.isRanked
          ? Text(
              _rankingLabel,
              style: GoogleFonts.nunitoSans(
                color: GeoColors.mutedInk,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
      trailing: Text(
        position == null
            ? '+${challenge.reward.xp} XP'
            : '#${position.rank} / ${position.totalParticipants}',
        style: GoogleFonts.nunitoSans(
          color: position == null ? GeoColors.mutedInk : GeoColors.purple,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String get _rankingLabel {
    final ChallengeRankingSubmission? submission = rankingSubmission;
    if (submission == null) {
      return 'Aucune tentative classée enregistrée';
    }
    switch (submission.status) {
      case ChallengeRankingSubmissionStatus.pendingServerValidation:
        return 'Position en attente de validation';
      case ChallengeRankingSubmissionStatus.confirmed:
        final int? movement = submission.position?.movement;
        if (movement == null || movement == 0) {
          return 'Position validée';
        }
        return movement > 0
            ? 'Progression de $movement place${movement > 1 ? 's' : ''}'
            : 'Recul de ${-movement} place${movement < -1 ? 's' : ''}';
      case ChallengeRankingSubmissionStatus.quarantined:
        return 'Résultat en cours de vérification';
      case ChallengeRankingSubmissionStatus.rejected:
        return 'Résultat non classé';
    }
  }
}

class _EmptyPeriodCard extends StatelessWidget {
  const _EmptyPeriodCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        message,
        style: GoogleFonts.nunitoSans(
          color: Colors.white.withValues(alpha: 0.74),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: GeoColors.cream,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: GeoColors.coral,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            'Impossible de charger les défis',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.mutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
