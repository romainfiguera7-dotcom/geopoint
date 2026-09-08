import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../challenges/challenge_definition.dart';
import '../../challenges/challenge_leaderboard.dart';
import '../../challenges/challenge_server_connection.dart';
import '../../challenges/challenge_season_reward.dart';
import '../design/geopoint_design.dart';
import '../social/friend_management_screen.dart';
import 'challenge_ui_helpers.dart';

class ChallengeLeaderboardsScreen extends StatefulWidget {
  const ChallengeLeaderboardsScreen({
    required this.seasonKey,
    this.dailyChallenge,
    this.weeklyChallenge,
    super.key,
  });

  final String seasonKey;
  final ChallengeDefinition? dailyChallenge;
  final ChallengeDefinition? weeklyChallenge;

  @override
  State<ChallengeLeaderboardsScreen> createState() =>
      _ChallengeLeaderboardsScreenState();
}

class _ChallengeLeaderboardsScreenState
    extends State<ChallengeLeaderboardsScreen> {
  late Future<ChallengeLeaderboardSnapshot> _future;
  ChallengeLeaderboardScope _scope = ChallengeLeaderboardScope.global;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ChallengeLeaderboardGateway? gateway =
        ChallengeServerConnection.leaderboardGateway;
    if (gateway == null) {
      _future = Future<ChallengeLeaderboardSnapshot>.error(
        StateError('Les classements en ligne sont indisponibles.'),
      );
      return;
    }
    final List<String> groupIds = <String>{
      if (widget.dailyChallenge?.rankingGroupId != null)
        widget.dailyChallenge!.rankingGroupId!,
      if (widget.weeklyChallenge?.rankingGroupId != null)
        widget.weeklyChallenge!.rankingGroupId!,
    }.toList(growable: false);
    _future = gateway.fetchLeaderboards(
      rankingGroupIds: groupIds,
      seasonKey: widget.seasonKey,
      scope: _scope,
    );
  }

  void _retry() {
    setState(_load);
  }

  void _selectScope(ChallengeLeaderboardScope scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _load();
    });
  }

  Future<void> _openFriends() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const FriendManagementScreen(),
      ),
    );
    if (mounted) _retry();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: ChallengeLeaderboardKind.values.length,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            const Positioned.fill(child: GeoAdventureBackground()),
            SafeArea(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        child: GeoGameTopBar(
                          title: 'CLASSEMENTS',
                          subtitle: 'Les meilleurs explorateurs',
                          onBack: () => Navigator.of(context).pop(),
                          trailing: GeoRoundAction(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Actualiser',
                            onPressed: _retry,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _LeaderboardHero(
                          seasonLabel: challengeMonthLabel(widget.seasonKey),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _LeaderboardScopeSelector(
                          selected: _scope,
                          onChanged: _selectScope,
                          onManageFriends: _openFriends,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: TabBar(
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: GeoColors.gold,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            labelColor: GeoColors.navy,
                            unselectedLabelColor: Colors.white70,
                            labelStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                            tabs: const <Tab>[
                              Tab(text: 'JOUR'),
                              Tab(text: 'SEMAINE'),
                              Tab(text: 'SAISON'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: FutureBuilder<ChallengeLeaderboardSnapshot>(
                          future: _future,
                          builder: (
                            BuildContext context,
                            AsyncSnapshot<ChallengeLeaderboardSnapshot>
                                snapshot,
                          ) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: GeoColors.gold,
                                ),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              return _LeaderboardError(
                                onRetry: _retry,
                                message: snapshot.error?.toString() ??
                                    'Les classements sont indisponibles.',
                              );
                            }
                            final ChallengeLeaderboardSnapshot data =
                                snapshot.data!;
                            return TabBarView(
                              children: ChallengeLeaderboardKind.values
                                  .map(
                                    (ChallengeLeaderboardKind kind) =>
                                        _LeaderboardView(
                                      kind: kind,
                                      board: data.boardFor(kind),
                                      seasonRewardTiers:
                                          data.seasonRewardTiers,
                                      history: data.currentPlayerHistory,
                                      scope: data.scope,
                                    ),
                                  )
                                  .toList(growable: false),
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
      ),
    );
  }
}

class _LeaderboardScopeSelector extends StatelessWidget {
  const _LeaderboardScopeSelector({
    required this.selected,
    required this.onChanged,
    required this.onManageFriends,
  });

  final ChallengeLeaderboardScope selected;
  final ValueChanged<ChallengeLeaderboardScope> onChanged;
  final VoidCallback onManageFriends;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 45,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: ChallengeLeaderboardScope.values
                  .map(
                    (ChallengeLeaderboardScope scope) => Expanded(
                      child: GestureDetector(
                        onTap: () => onChanged(scope),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected == scope
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                scope == ChallengeLeaderboardScope.global
                                    ? Icons.public_rounded
                                    : Icons.group_rounded,
                                color: selected == scope
                                    ? GeoColors.navy
                                    : Colors.white70,
                                size: 17,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                scope.label.toUpperCase(),
                                style: TextStyle(
                                  color: selected == scope
                                      ? GeoColors.navy
                                      : Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onManageFriends,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: selected == ChallengeLeaderboardScope.friends
                    ? GeoColors.gold
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                Icons.group_add_rounded,
                color: selected == ChallengeLeaderboardScope.friends
                    ? GeoColors.navy
                    : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardHero extends StatelessWidget {
  const _LeaderboardHero({required this.seasonLabel});

  final String seasonLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[GeoColors.purple, Color(0xFF3B75B7)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: GeoColors.gold,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: GeoColors.navy,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SAISON ${seasonLabel.toUpperCase()}',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Chaque défi compte. Seule ta meilleure partie est retenue.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
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

class _LeaderboardView extends StatelessWidget {
  const _LeaderboardView({
    required this.kind,
    required this.board,
    required this.seasonRewardTiers,
    required this.history,
    required this.scope,
  });

  final ChallengeLeaderboardKind kind;
  final ChallengeLeaderboardBoard? board;
  final List<ChallengeSeasonRewardTier> seasonRewardTiers;
  final List<ChallengeRankingHistoryEntry> history;
  final ChallengeLeaderboardScope scope;

  @override
  Widget build(BuildContext context) {
    final ChallengeLeaderboardBoard? currentBoard = board;
    if (currentBoard == null) {
      return const _LeaderboardEmpty(
        message: 'Ce classement n’est pas disponible actuellement.',
      );
    }
    final ChallengeLeaderboardEntry? currentPlayer =
        currentBoard.visibleCurrentPlayerEntry;
    final List<ChallengeLeaderboardEntry> podium =
        currentBoard.entries.take(3).toList(growable: false);
    final List<ChallengeLeaderboardEntry> remaining =
        currentBoard.entries.skip(3).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    currentBoard.title,
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${currentBoard.totalParticipants} participant${currentBoard.totalParticipants > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const _FairPlayBadge(),
          ],
        ),
        if (currentPlayer != null) ...<Widget>[
          const SizedBox(height: 13),
          _MyPositionCard(entry: currentPlayer, kind: kind),
        ],
        if (history.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _HistoryButton(history: history),
        ],
        if (kind == ChallengeLeaderboardKind.season) ...<Widget>[
          const SizedBox(height: 13),
          _SeasonRewardPreview(
            entry: currentPlayer,
            tiers: seasonRewardTiers,
          ),
        ],
        const SizedBox(height: 14),
        if (currentBoard.entries.isEmpty)
          _LeaderboardEmpty(
            message: scope == ChallengeLeaderboardScope.friends
                ? 'Aucun score parmi tes amis pour le moment. Invite-les avec ton code ami !'
                : 'Aucun score validé pour le moment. Sois le premier !',
          )
        else ...<Widget>[
          _LeaderboardPodium(entries: podium, kind: kind),
          if (remaining.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: GeoColors.cream,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: remaining
                    .map(
                      (ChallengeLeaderboardEntry entry) =>
                          _LeaderboardRow(entry: entry, kind: kind),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),
        Text(
          kind == ChallengeLeaderboardKind.season
              ? 'La saison additionne le meilleur score obtenu sur chaque défi.'
              : 'Départage : score, précision, puis temps total.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardPodium extends StatelessWidget {
  const _LeaderboardPodium({required this.entries, required this.kind});

  final List<ChallengeLeaderboardEntry> entries;
  final ChallengeLeaderboardKind kind;

  @override
  Widget build(BuildContext context) {
    ChallengeLeaderboardEntry? at(int index) {
      return index < entries.length ? entries[index] : null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 15, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.16),
            GeoColors.purple.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'LE PODIUM',
            style: TextStyle(
              color: GeoColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 158,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: _PodiumPlace(
                    entry: at(1),
                    rank: 2,
                    height: 112,
                    color: const Color(0xFFC7D0DA),
                    kind: kind,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PodiumPlace(
                    entry: at(0),
                    rank: 1,
                    height: 146,
                    color: GeoColors.gold,
                    kind: kind,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PodiumPlace(
                    entry: at(2),
                    rank: 3,
                    height: 94,
                    color: const Color(0xFFD79262),
                    kind: kind,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Appuie sur un joueur pour voir sa fiche.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.entry,
    required this.rank,
    required this.height,
    required this.color,
    required this.kind,
  });

  final ChallengeLeaderboardEntry? entry;
  final int rank;
  final double height;
  final Color color;
  final ChallengeLeaderboardKind kind;

  @override
  Widget build(BuildContext context) {
    final ChallengeLeaderboardEntry? player = entry;
    if (player == null) {
      return SizedBox(height: height);
    }
    return GestureDetector(
      onTap: () => _showPlayerProfile(context, player, kind),
      child: SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            Positioned.fill(
              top: 30,
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 27, 5, 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                    bottom: Radius.circular(10),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      player.isCurrentPlayer
                          ? '${player.displayName} • MOI'
                          : player.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GeoColors.navy,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${player.score} pts',
                      style: GoogleFonts.fredoka(
                        color: GeoColors.navy,
                        fontSize: rank == 1 ? 17 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            CircleAvatar(
              radius: rank == 1 ? 31 : 27,
              backgroundColor: GeoColors.navy,
              child: Text(
                player.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: rank == 1 ? 25 : 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 6,
              child: Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: GeoColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.history});

  final List<ChallengeRankingHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRankingHistory(context, history),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.history_rounded, color: Colors.white, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'MON HISTORIQUE • ${history.length} PARTIE${history.length > 1 ? 'S' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonRewardPreview extends StatelessWidget {
  const _SeasonRewardPreview({required this.tiers, this.entry});

  final ChallengeLeaderboardEntry? entry;
  final List<ChallengeSeasonRewardTier> tiers;

  @override
  Widget build(BuildContext context) {
    final int? rank = entry?.rank;
    final ChallengeSeasonRewardTier? projected =
        rank == null
            ? null
            : tiers.firstWhere(
                (ChallengeSeasonRewardTier tier) =>
                    tier.maximumRank == null || rank <= tier.maximumRank!,
              );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GeoColors.gold.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.card_giftcard_rounded,
                  color: GeoColors.gold, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  projected == null
                      ? 'RÉCOMPENSES DE FIN DE SAISON'
                      : 'PALIER ACTUEL : ${projected.label.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (projected != null)
                Text(
                  '${projected.coins} 🪙  ${projected.diamonds} 💎',
                  style: const TextStyle(
                    color: GeoColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tiers
                .map(
                  (ChallengeSeasonRewardTier tier) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: projected?.id == tier.id
                          ? GeoColors.gold
                          : Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${tier.label} · ${tier.coins} 🪙'
                      '${tier.diamonds > 0 ? ' · ${tier.diamonds} 💎' : ''}',
                      style: TextStyle(
                        color: projected?.id == tier.id
                            ? GeoColors.navy
                            : Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          const Text(
            'Un seul versement après la clôture. Tous les participants gagnent au minimum 75 pièces.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FairPlayBadge extends StatelessWidget {
  const _FairPlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: GeoColors.mint.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: GeoColors.mint.withValues(alpha: 0.65)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.verified_user_rounded, color: GeoColors.mint, size: 15),
          SizedBox(width: 5),
          Text(
            'VÉRIFIÉ',
            style: TextStyle(
              color: GeoColors.mint,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPositionCard extends StatelessWidget {
  const _MyPositionCard({required this.entry, required this.kind});

  final ChallengeLeaderboardEntry entry;
  final ChallengeLeaderboardKind kind;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPlayerProfile(context, entry, kind),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: GeoColors.gold,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.person_pin_circle_rounded,
                color: GeoColors.navy,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.rank == null
                      ? 'Ma position : au-delà du top 25'
                      : 'Ma position : #${entry.rank}',
                  style: const TextStyle(
                    color: GeoColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${entry.score} pts',
                style: const TextStyle(
                  color: GeoColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right_rounded,
                color: GeoColors.navy,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.kind});

  final ChallengeLeaderboardEntry entry;
  final ChallengeLeaderboardKind kind;

  @override
  Widget build(BuildContext context) {
    final int rank = entry.rank ?? 0;
    final Color accent = rank == 1
        ? const Color(0xFFFFB800)
        : rank == 2
            ? const Color(0xFFAEB8C4)
            : rank == 3
                ? const Color(0xFFCF8152)
                : GeoColors.sky;
    return GestureDetector(
      onTap: () => _showPlayerProfile(context, entry, kind),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: entry.isCurrentPlayer
              ? GeoColors.purple.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(16),
          border: entry.isCurrentPlayer
              ? Border.all(color: GeoColors.purple.withValues(alpha: 0.60))
              : null,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Text(
                '#$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontSize: rank <= 3 ? 16 : 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 19,
              backgroundColor: accent.withValues(alpha: 0.20),
              child: Text(
                entry.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(color: accent, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.isCurrentPlayer
                        ? '${entry.displayName} • MOI'
                        : entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      color: GeoColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kind == ChallengeLeaderboardKind.season
                        ? '${entry.challengeCount} défi${entry.challengeCount > 1 ? 's' : ''}'
                        : '${entry.correctAnswers} bonnes • ${_formatDuration(entry.elapsedSeconds)}',
                    style: const TextStyle(
                      color: GeoColors.mutedInk,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.score}',
              style: GoogleFonts.fredoka(
                color: GeoColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showPlayerProfile(
  BuildContext context,
  ChallengeLeaderboardEntry entry,
  ChallengeLeaderboardKind kind,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _PlayerProfileSheet(
      entry: entry,
      kind: kind,
    ),
  );
}

Future<void> _showRankingHistory(
  BuildContext context,
  List<ChallengeRankingHistoryEntry> history,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _RankingHistorySheet(history: history),
  );
}

class _PlayerProfileSheet extends StatelessWidget {
  const _PlayerProfileSheet({required this.entry, required this.kind});

  final ChallengeLeaderboardEntry entry;
  final ChallengeLeaderboardKind kind;

  @override
  Widget build(BuildContext context) {
    final String precision = entry.averageDistanceKilometers < 1
        ? '${(entry.averageDistanceKilometers * 1000).round()} m'
        : '${entry.averageDistanceKilometers.toStringAsFixed(1)} km';
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        decoration: BoxDecoration(
          color: GeoColors.cream,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: GeoColors.mutedInk.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            CircleAvatar(
              radius: 39,
              backgroundColor: GeoColors.navy,
              child: Text(
                entry.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: GeoColors.gold,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              entry.displayName,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: GeoColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (entry.isCurrentPlayer)
              const Text(
                'C’EST TOI',
                style: TextStyle(
                  color: GeoColors.purple,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                _ProfileMetric(
                  icon: Icons.emoji_events_rounded,
                  label: 'RANG',
                  value: entry.rank == null ? '25+' : '#${entry.rank}',
                ),
                const SizedBox(width: 8),
                _ProfileMetric(
                  icon: Icons.stars_rounded,
                  label: 'SCORE',
                  value: '${entry.score}',
                ),
                const SizedBox(width: 8),
                _ProfileMetric(
                  icon: kind == ChallengeLeaderboardKind.season
                      ? Icons.flag_rounded
                      : Icons.timer_rounded,
                  label: kind == ChallengeLeaderboardKind.season
                      ? 'DÉFIS'
                      : 'TEMPS',
                  value: kind == ChallengeLeaderboardKind.season
                      ? '${entry.challengeCount}'
                      : _formatDuration(entry.elapsedSeconds),
                ),
              ],
            ),
            if (kind != ChallengeLeaderboardKind.season) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _ProfileMetric(
                    icon: Icons.check_circle_rounded,
                    label: 'BONNES RÉPONSES',
                    value: '${entry.correctAnswers}',
                  ),
                  const SizedBox(width: 8),
                  _ProfileMetric(
                    icon: Icons.near_me_rounded,
                    label: 'DISTANCE MOYENNE',
                    value: precision,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('FERMER'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: GeoColors.purple, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: GeoColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GeoColors.mutedInk,
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingHistorySheet extends StatelessWidget {
  const _RankingHistorySheet({required this.history});

  final List<ChallengeRankingHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.46,
        maxChildSize: 0.92,
        builder: (BuildContext context, ScrollController controller) {
          return Container(
            decoration: const BoxDecoration(
              color: GeoColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GeoColors.mutedInk.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.history_rounded,
                        color: GeoColors.purple,
                        size: 27,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'MON HISTORIQUE',
                              style: GoogleFonts.fredoka(
                                color: GeoColors.ink,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${history.length} dernière${history.length > 1 ? 's' : ''} partie${history.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: GeoColors.mutedInk,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: history.length,
                    separatorBuilder: (
                      BuildContext context,
                      int index,
                    ) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) =>
                        _HistoryRow(entry: history[index]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final ChallengeRankingHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    switch (entry.status) {
      case ChallengeRankingHistoryStatus.validated:
        statusColor = GeoColors.mint;
        statusIcon = Icons.verified_rounded;
        break;
      case ChallengeRankingHistoryStatus.quarantined:
        statusColor = GeoColors.gold;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case ChallengeRankingHistoryStatus.rejected:
        statusColor = GeoColors.coral;
        statusIcon = Icons.cancel_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.17),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.challengeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GeoColors.ink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (entry.isBest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: GeoColors.gold,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'MEILLEUR',
                          style: TextStyle(
                            color: GeoColors.navy,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.status.label} • ${_formatHistoryDate(entry.completedAtUtc)}',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${entry.correctAnswers} bonnes • ${_formatDuration(entry.elapsedSeconds)}',
                  style: const TextStyle(
                    color: GeoColors.mutedInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.score}',
            style: GoogleFonts.fredoka(
              color: GeoColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(int seconds) {
  final int minutes = seconds ~/ 60;
  final int remainingSeconds = seconds % 60;
  if (minutes == 0) {
    return '${remainingSeconds}s';
  }
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _formatHistoryDate(DateTime utcDate) {
  final DateTime date = utcDate.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

class _LeaderboardEmpty extends StatelessWidget {
  const _LeaderboardEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.emoji_events_outlined,
                color: GeoColors.gold,
                size: 42,
              ),
              const SizedBox(height: 11),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardError extends StatelessWidget {
  const _LeaderboardError({required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: GeoColors.cream,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.cloud_off_rounded,
                color: GeoColors.coral,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                'Classements indisponibles',
                style: GoogleFonts.fredoka(
                  color: GeoColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: GeoColors.mutedInk),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('RÉESSAYER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
