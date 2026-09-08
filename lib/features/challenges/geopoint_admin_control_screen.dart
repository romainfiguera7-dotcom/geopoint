import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin/geopoint_admin_control.dart';
import '../../challenges/challenge_server_connection.dart';
import '../design/geopoint_design.dart';

class GeoPointAdminControlScreen extends StatefulWidget {
  const GeoPointAdminControlScreen({super.key});

  @override
  State<GeoPointAdminControlScreen> createState() =>
      _GeoPointAdminControlScreenState();
}

class _GeoPointAdminControlScreenState
    extends State<GeoPointAdminControlScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _giftCodeController = TextEditingController();
  GeoPointAdminDashboard? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _giftCodeController.dispose();
    super.dispose();
  }

  Future<void> _load([String? query]) async {
    final GeoPointAdminGateway? gateway =
        ChallengeServerConnection.adminGateway;
    if (gateway == null) {
      setState(() {
        _loading = false;
        _error = 'Connexion Firebase indisponible.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final GeoPointAdminDashboard dashboard = await gateway.fetchDashboard(
        query: query ?? _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final String details = error.toString();
      setState(() {
        _loading = false;
        _error = details.contains('permission-denied')
            ? 'Accès refusé : ce compte ne possède pas le rôle '
                'administrateur PointGeo.'
            : 'Contrôle interne indisponible : $details';
      });
    }
  }

  Future<String?> _askReason(String title) async {
    final TextEditingController controller = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Motif obligatoire',
            hintText: 'Explique la raison de cette action…',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ANNULER'),
          ),
          FilledButton(
            onPressed: () {
              final String value = controller.text.trim();
              if (value.length >= 5) Navigator.of(dialogContext).pop(value);
            },
            child: const Text('CONFIRMER'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _updateSubmission(
    GeoPointAdminSubmission submission,
    GeoPointAdminScoreAction action,
  ) async {
    final String? reason = await _askReason(_scoreActionLabel(action));
    if (reason == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await ChallengeServerConnection.adminGateway!.updateSubmission(
        playerId: submission.playerId,
        submissionId: submission.submissionId,
        action: action,
        reason: reason,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action enregistrée et classement recalculé.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Action refusée : $error';
      });
    }
  }

  Future<void> _updateCompetition(
    GeoPointAdminCompetition competition,
    GeoPointAdminCompetitionAction action,
  ) async {
    final String? reason = await _askReason(_competitionActionLabel(action));
    if (reason == null || !mounted) return;
    setState(() => _loading = true);
    try {
      await ChallengeServerConnection.adminGateway!.updateCompetition(
        rankingGroupId: competition.rankingGroupId,
        action: action,
        reason: reason,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Action refusée : $error';
      });
    }
  }

  Future<void> _grantAdFree() async {
    final String code = _giftCodeController.text.trim();
    if (code.isEmpty) return;
    final String? reason = await _askReason('OFFRIR LE COMPTE SANS PUB');
    if (reason == null || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String displayName = await ChallengeServerConnection.adminGateway!
          .grantAdFreeByFriendCode(friendCode: code, reason: reason);
      if (!mounted) return;
      _giftCodeController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compte sans publicité offert à $displayName.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Cadeau refusé : $error';
      });
    }
  }

  String _scoreActionLabel(GeoPointAdminScoreAction action) {
    switch (action) {
      case GeoPointAdminScoreAction.approveQuarantine:
        return 'VALIDER LE SCORE';
      case GeoPointAdminScoreAction.rejectQuarantine:
        return 'REFUSER LE SCORE';
      case GeoPointAdminScoreAction.invalidate:
        return 'ANNULER LE SCORE';
      case GeoPointAdminScoreAction.restore:
        return 'RÉTABLIR LE SCORE';
      case GeoPointAdminScoreAction.restoreExpired:
        return 'RÉTABLIR APRÈS CONTRÔLE';
    }
  }

  String _competitionActionLabel(GeoPointAdminCompetitionAction action) {
    switch (action) {
      case GeoPointAdminCompetitionAction.enable:
        return 'RÉACTIVER LA COMPÉTITION';
      case GeoPointAdminCompetitionAction.disable:
        return 'SUSPENDRE LA COMPÉTITION';
      case GeoPointAdminCompetitionAction.rebuild:
        return 'RECALCULER LES RANGS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        brightness: Brightness.dark,
        colorScheme: baseTheme.colorScheme.copyWith(
          brightness: Brightness.dark,
          surface: const Color(0xFF102542),
          onSurface: Colors.white,
        ),
        textTheme: baseTheme.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: const TextStyle(color: Colors.white70),
          labelStyle: const TextStyle(color: Colors.white),
          prefixIconColor: Colors.white,
          suffixIconColor: Colors.white,
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: GeoColors.gold, width: 2),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
      child: Scaffold(
        body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 820),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 42),
                    children: <Widget>[
                      GeoGameTopBar(
                        title: 'CONTRÔLE INTERNE',
                        subtitle: 'Défis, classements et avantages',
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 20),
                      _AdFreeGiftCard(
                        controller: _giftCodeController,
                        onGrant: _grantAdFree,
                      ),
                      const SizedBox(height: 16),
                      _SearchCard(
                        controller: _searchController,
                        onSearch: () => _load(_searchController.text),
                        onClear: () {
                          _searchController.clear();
                          _load('');
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 70),
                          child: Center(
                            child: CircularProgressIndicator(color: GeoColors.gold),
                          ),
                        )
                      else if (_error != null)
                        _MessageCard(message: _error!, error: true)
                      else if (_dashboard != null)
                        ..._dashboardContent(_dashboard!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  List<Widget> _dashboardContent(GeoPointAdminDashboard dashboard) {
    return <Widget>[
      _CountersCard(counters: dashboard.counters),
      if (dashboard.player != null) ...<Widget>[
        const SizedBox(height: 16),
        _PlayerCard(player: dashboard.player!),
      ],
      if (dashboard.competition != null) ...<Widget>[
        const SizedBox(height: 16),
        _CompetitionCard(
          competition: dashboard.competition!,
          onAction: (action) =>
              _updateCompetition(dashboard.competition!, action),
        ),
      ],
      const SizedBox(height: 24),
      _Heading(
        title: 'Tentatives à contrôler',
        subtitle: '${dashboard.submissions.length} résultat(s) affiché(s)',
      ),
      const SizedBox(height: 10),
      if (dashboard.submissions.isEmpty)
        const _MessageCard(message: 'Aucune tentative trouvée.')
      else
        ...dashboard.submissions.map(
          (submission) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SubmissionCard(
              submission: submission,
              onAction: (action) => _updateSubmission(submission, action),
              actionLabel: _scoreActionLabel,
            ),
          ),
        ),
      const SizedBox(height: 24),
      const _Heading(
        title: 'Journal de traçabilité',
        subtitle: 'Les 15 dernières actions administratives',
      ),
      const SizedBox(height: 10),
      if (dashboard.auditLogs.isEmpty)
        const _MessageCard(message: 'Aucune action manuelle enregistrée.')
      else
        _AuditCard(logs: dashboard.auditLogs),
    ];
  }
}

class _AdFreeGiftCard extends StatelessWidget {
  const _AdFreeGiftCard({
    required this.controller,
    required this.onGrant,
  });

  final TextEditingController controller;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.card_giftcard_rounded, color: GeoColors.gold),
              SizedBox(width: 9),
              Text(
                'OFFRIR LE SANS-PUB',
                style: TextStyle(
                  color: GeoColors.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Saisissez le code ami du destinataire. L’avantage sera lié à '
            'son compte PointGeo et restera actif sur ses appareils.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            cursorColor: GeoColors.gold,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'CODE AMI',
              prefixIcon: Icon(Icons.group_add_rounded),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onGrant,
              icon: const Icon(Icons.redeem_rounded),
              label: const Text('OFFRIR LE COMPTE SANS PUB'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'RECHERCHE SÉCURISÉE',
            style: TextStyle(color: GeoColors.gold, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            cursorColor: GeoColors.gold,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'UID, identifiant de tentative ou de compétition',
              prefixIcon: const Icon(Icons.manage_search_rounded),
              suffixIcon: IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded),
              label: const Text('RECHERCHER'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountersCard extends StatelessWidget {
  const _CountersCard({required this.counters});
  final GeoPointAdminCounters counters;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _Counter(label: 'À vérifier', value: counters.pendingReviews,
            color: GeoColors.gold),
        _Counter(label: 'Refusées', value: counters.rejectedSubmissions,
            color: GeoColors.coral),
        _Counter(label: 'Sessions actives', value: counters.activeSessions,
            color: GeoColors.mint),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF102542).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$value', style: GoogleFonts.fredoka(
            color: color, fontSize: 28, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player});
  final GeoPointAdminPlayer player;

  @override
  Widget build(BuildContext context) => _Panel(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.person_search_rounded)),
      title: Text(player.playerId, style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      )),
      subtitle: Text(
        '${player.profileType} • ${player.status} • '
        '${player.totalXp} XP • ${player.gamesPlayed} parties',
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({required this.competition, required this.onAction});
  final GeoPointAdminCompetition competition;
  final ValueChanged<GeoPointAdminCompetitionAction> onAction;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(competition.rankingGroupId,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(competition.disabled ? 'COMPÉTITION SUSPENDUE' : 'COMPÉTITION ACTIVE',
            style: TextStyle(color: competition.disabled ? GeoColors.coral : GeoColors.mint,
                fontWeight: FontWeight.w900)),
        if (competition.disabledReason != null)
          Text(
            competition.disabledReason!,
            style: const TextStyle(color: Colors.white),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => onAction(competition.disabled
                  ? GeoPointAdminCompetitionAction.enable
                  : GeoPointAdminCompetitionAction.disable),
              icon: Icon(competition.disabled ? Icons.play_arrow_rounded : Icons.pause_rounded),
              label: Text(competition.disabled ? 'RÉACTIVER' : 'SUSPENDRE'),
            ),
            FilledButton.icon(
              onPressed: () => onAction(GeoPointAdminCompetitionAction.rebuild),
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('RECALCULER'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.submission,
    required this.onAction,
    required this.actionLabel,
  });
  final GeoPointAdminSubmission submission;
  final ValueChanged<GeoPointAdminScoreAction> onAction;
  final String Function(GeoPointAdminScoreAction) actionLabel;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text(submission.challengeId,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          Text(submission.status.toUpperCase(),
              style: const TextStyle(color: GeoColors.gold,
                  fontWeight: FontWeight.w900, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        SelectableText('${submission.playerId}\n${submission.submissionId}',
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 9),
        Text(
          '${submission.score} points • ${submission.correctAnswers} bonnes '
          'réponses • '
          '${submission.averageDistanceKilometers.toStringAsFixed(1)} km '
          '• ${submission.elapsedSeconds} s',
          style: const TextStyle(color: Colors.white),
        ),
        if (submission.reason != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(submission.reason!, style: const TextStyle(color: GeoColors.coral)),
        ],
        if (submission.availableActions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: submission.availableActions.map((action) =>
              OutlinedButton(
                onPressed: () => onAction(action),
                child: Text(actionLabel(action)),
              )).toList(growable: false),
          ),
        ],
      ],
    ),
  );
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.logs});
  final List<GeoPointAdminAuditLog> logs;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      children: logs.map((log) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.history_rounded, color: GeoColors.mint),
        title: Text(
          '${log.action} • ${log.target}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${log.reason}\n${log.before} → ${log.after}',
          style: const TextStyle(color: Colors.white),
        ),
      )).toList(growable: false),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(title, style: GoogleFonts.fredoka(
        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      Text(subtitle, style: const TextStyle(color: Colors.white)),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF102542).withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: child,
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.error = false});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(children: <Widget>[
      Icon(error ? Icons.lock_rounded : Icons.check_circle_outline_rounded,
          color: error ? GeoColors.coral : GeoColors.mint),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ]),
  );
}
