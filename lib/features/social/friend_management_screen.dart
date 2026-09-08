import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../challenges/challenge_server_connection.dart';
import '../../social/geopoint_friends.dart';
import '../design/geopoint_design.dart';

class FriendManagementScreen extends StatefulWidget {
  const FriendManagementScreen({super.key});

  @override
  State<FriendManagementScreen> createState() =>
      _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen> {
  final TextEditingController _friendCodeController = TextEditingController();
  late Future<GeoPointFriendDashboard> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _friendCodeController.dispose();
    super.dispose();
  }

  void _load() {
    final GeoPointFriendGateway? gateway =
        ChallengeServerConnection.friendGateway;
    _future = gateway == null
        ? Future<GeoPointFriendDashboard>.error(
            StateError('Les amis en ligne sont indisponibles.'),
          )
        : gateway.fetchFriendDashboard();
  }

  void _retry() => setState(_load);

  Future<bool> _execute(
    Future<void> Function(GeoPointFriendGateway gateway) action,
    String successMessage,
  ) async {
    if (_busy) return false;
    final GeoPointFriendGateway? gateway =
        ChallengeServerConnection.friendGateway;
    if (gateway == null) return false;
    setState(() => _busy = true);
    try {
      await action(gateway);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      setState(_load);
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GeoColors.coral,
          content: Text(_friendlySocialError(error)),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendRequest() async {
    final String code = _friendCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre d’abord un code ami.')),
      );
      return;
    }
    final bool sent = await _execute(
      (GeoPointFriendGateway gateway) => gateway.sendFriendRequest(code),
      'Demande d’ami envoyée.',
    );
    if (sent) _friendCodeController.clear();
  }

  Future<void> _requestAction(
    GeoPointFriendRelationAction action,
    String requestId,
    String message,
  ) async {
    await _execute(
      (GeoPointFriendGateway gateway) => gateway.updateFriendRelation(
        action: action,
        requestId: requestId,
      ),
      message,
    );
  }

  Future<void> _playerAction(
    GeoPointFriendRelationAction action,
    String playerId,
    String message,
  ) async {
    await _execute(
      (GeoPointFriendGateway gateway) => gateway.updateFriendRelation(
        action: action,
        playerId: playerId,
      ),
      message,
    );
  }

  Future<void> _confirmFriendAction(
    GeoPointFriend friend,
    GeoPointFriendRelationAction action,
  ) async {
    final bool blocks = action == GeoPointFriendRelationAction.block;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(blocks ? 'Bloquer ce joueur ?' : 'Supprimer cet ami ?'),
        content: Text(
          blocks
              ? '${friend.displayName} ne pourra plus t’envoyer de demande.'
              : '${friend.displayName} disparaîtra de tes classements amis.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ANNULER'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(blocks ? 'BLOQUER' : 'SUPPRIMER'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _playerAction(
      action,
      friend.playerId,
      blocks ? 'Joueur bloqué.' : 'Ami supprimé.',
    );
  }

  Future<void> _copyCode(String friendCode) async {
    await Clipboard.setData(ClipboardData(text: friendCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code ami copié.')),
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
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                      child: GeoGameTopBar(
                        title: 'MES AMIS',
                        subtitle: 'Invite tes explorateurs préférés',
                        onBack: () => Navigator.of(context).pop(),
                        trailing: GeoRoundAction(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Actualiser',
                          onPressed: _retry,
                        ),
                      ),
                    ),
                    if (_busy)
                      const LinearProgressIndicator(
                        color: GeoColors.gold,
                        backgroundColor: Colors.transparent,
                      ),
                    Expanded(
                      child: FutureBuilder<GeoPointFriendDashboard>(
                        future: _future,
                        builder: (
                          BuildContext context,
                          AsyncSnapshot<GeoPointFriendDashboard> snapshot,
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
                            return _FriendError(
                              message: _friendlySocialError(snapshot.error),
                              onRetry: _retry,
                            );
                          }
                          return _FriendDashboardView(
                            dashboard: snapshot.data!,
                            codeController: _friendCodeController,
                            enabled: !_busy,
                            onCopyCode: _copyCode,
                            onSendRequest: _sendRequest,
                            onAccept: (GeoPointFriendRequest request) =>
                                _requestAction(
                              GeoPointFriendRelationAction.accept,
                              request.requestId,
                              '${request.displayName} est maintenant ton ami.',
                            ),
                            onDecline: (GeoPointFriendRequest request) =>
                                _requestAction(
                              GeoPointFriendRelationAction.decline,
                              request.requestId,
                              'Demande refusée.',
                            ),
                            onCancel: (GeoPointFriendRequest request) =>
                                _requestAction(
                              GeoPointFriendRelationAction.cancel,
                              request.requestId,
                              'Demande annulée.',
                            ),
                            onRemove: (GeoPointFriend friend) =>
                                _confirmFriendAction(
                              friend,
                              GeoPointFriendRelationAction.remove,
                            ),
                            onBlock: (GeoPointFriend friend) =>
                                _confirmFriendAction(
                              friend,
                              GeoPointFriendRelationAction.block,
                            ),
                            onUnblock: (GeoPointBlockedPlayer player) =>
                                _playerAction(
                              GeoPointFriendRelationAction.unblock,
                              player.playerId,
                              'Joueur débloqué.',
                            ),
                            onRefresh: () async => _retry(),
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

class _FriendDashboardView extends StatelessWidget {
  const _FriendDashboardView({
    required this.dashboard,
    required this.codeController,
    required this.enabled,
    required this.onCopyCode,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
    required this.onRemove,
    required this.onBlock,
    required this.onUnblock,
    required this.onRefresh,
  });

  final GeoPointFriendDashboard dashboard;
  final TextEditingController codeController;
  final bool enabled;
  final ValueChanged<String> onCopyCode;
  final VoidCallback onSendRequest;
  final ValueChanged<GeoPointFriendRequest> onAccept;
  final ValueChanged<GeoPointFriendRequest> onDecline;
  final ValueChanged<GeoPointFriendRequest> onCancel;
  final ValueChanged<GeoPointFriend> onRemove;
  final ValueChanged<GeoPointFriend> onBlock;
  final ValueChanged<GeoPointBlockedPlayer> onUnblock;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: <Widget>[
          _FriendCodeCard(
            friendCode: dashboard.friendCode,
            onCopy: () => onCopyCode(dashboard.friendCode),
          ),
          const SizedBox(height: 12),
          _AddFriendCard(
            controller: codeController,
            enabled: enabled,
            onSend: onSendRequest,
          ),
          if (dashboard.receivedRequests.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'DEMANDES REÇUES',
              count: dashboard.receivedRequests.length,
            ),
            const SizedBox(height: 8),
            ...dashboard.receivedRequests.map(
              (GeoPointFriendRequest request) => _ReceivedRequestCard(
                request: request,
                enabled: enabled,
                onAccept: () => onAccept(request),
                onDecline: () => onDecline(request),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'MES AMIS',
            count: dashboard.friends.length,
            trailing: '${dashboard.friends.length}/${dashboard.maximumFriends}',
          ),
          const SizedBox(height: 8),
          if (dashboard.friends.isEmpty)
            const _EmptySocialCard(
              icon: Icons.group_add_rounded,
              text: 'Ajoute un premier ami avec son code PointGeo.',
            )
          else
            ...dashboard.friends.map(
              (GeoPointFriend friend) => _FriendCard(
                friend: friend,
                enabled: enabled,
                onRemove: () => onRemove(friend),
                onBlock: () => onBlock(friend),
              ),
            ),
          if (dashboard.sentRequests.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'DEMANDES ENVOYÉES',
              count: dashboard.sentRequests.length,
            ),
            const SizedBox(height: 8),
            ...dashboard.sentRequests.map(
              (GeoPointFriendRequest request) => _SentRequestCard(
                request: request,
                enabled: enabled,
                onCancel: () => onCancel(request),
              ),
            ),
          ],
          if (dashboard.blockedPlayers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'JOUEURS BLOQUÉS',
              count: dashboard.blockedPlayers.length,
            ),
            const SizedBox(height: 8),
            ...dashboard.blockedPlayers.map(
              (GeoPointBlockedPlayer player) => _BlockedPlayerCard(
                player: player,
                enabled: enabled,
                onUnblock: () => onUnblock(player),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Ton code ne révèle ni ton adresse e-mail ni ton compte Firebase.',
            textAlign: TextAlign.center,
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

class _FriendCodeCard extends StatelessWidget {
  const _FriendCodeCard({required this.friendCode, required this.onCopy});

  final String friendCode;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[GeoColors.purple, Color(0xFF4A7FCC)],
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
              Icons.vpn_key_rounded,
              color: GeoColors.navy,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'MON CODE AMI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                SelectableText(
                  friendCode,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: onCopy,
            tooltip: 'Copier le code',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
            ),
            icon: const Icon(Icons.copy_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _AddFriendCard extends StatelessWidget {
  const _AddFriendCard({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: GeoColors.cream,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'AJOUTER UN AMI',
            style: TextStyle(
              color: GeoColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'GP-ABCD-2345',
                    prefixIcon: const Icon(Icons.person_search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: enabled ? onSend : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count, this.trailing});

  final String title;
  final int count;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '$title • $count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _ReceivedRequestCard extends StatelessWidget {
  const _ReceivedRequestCard({
    required this.request,
    required this.enabled,
    required this.onAccept,
    required this.onDecline,
  });

  final GeoPointFriendRequest request;
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return _PersonCard(
      displayName: request.displayName,
      subtitle: 'Veut rejoindre tes amis',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: enabled ? onDecline : null,
            tooltip: 'Refuser',
            icon: const Icon(Icons.close_rounded, color: GeoColors.coral),
          ),
          IconButton.filled(
            onPressed: enabled ? onAccept : null,
            tooltip: 'Accepter',
            style: IconButton.styleFrom(backgroundColor: GeoColors.mint),
            icon: const Icon(Icons.check_rounded, color: GeoColors.navy),
          ),
        ],
      ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  const _SentRequestCard({
    required this.request,
    required this.enabled,
    required this.onCancel,
  });

  final GeoPointFriendRequest request;
  final bool enabled;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return _PersonCard(
      displayName: request.displayName,
      subtitle: 'Demande en attente',
      trailing: TextButton(
        onPressed: enabled ? onCancel : null,
        child: const Text('ANNULER'),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.enabled,
    required this.onRemove,
    required this.onBlock,
  });

  final GeoPointFriend friend;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return _PersonCard(
      displayName: friend.displayName,
      subtitle: 'Visible dans tes classements amis',
      trailing: PopupMenuButton<String>(
        enabled: enabled,
        onSelected: (String value) {
          if (value == 'remove') onRemove();
          if (value == 'block') onBlock();
        },
        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'remove',
            child: Text('Supprimer de mes amis'),
          ),
          PopupMenuItem<String>(
            value: 'block',
            child: Text('Bloquer le joueur'),
          ),
        ],
      ),
    );
  }
}

class _BlockedPlayerCard extends StatelessWidget {
  const _BlockedPlayerCard({
    required this.player,
    required this.enabled,
    required this.onUnblock,
  });

  final GeoPointBlockedPlayer player;
  final bool enabled;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return _PersonCard(
      displayName: player.displayName,
      subtitle: 'Ne peut plus t’envoyer de demande',
      trailing: TextButton(
        onPressed: enabled ? onUnblock : null,
        child: const Text('DÉBLOQUER'),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.displayName,
    required this.subtitle,
    required this.trailing,
  });

  final String displayName;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(11, 9, 5, 9),
      decoration: BoxDecoration(
        color: GeoColors.cream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: GeoColors.purple.withValues(alpha: 0.20),
            child: Text(
              displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: GeoColors.purple,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GeoColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GeoColors.mutedInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _EmptySocialCard extends StatelessWidget {
  const _EmptySocialCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: GeoColors.gold, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendError extends StatelessWidget {
  const _FriendError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
              const Icon(Icons.group_off_rounded, color: GeoColors.coral, size: 40),
              const SizedBox(height: 10),
              Text(
                'Amis indisponibles',
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

String _friendlySocialError(Object? error) {
  final String message = error?.toString() ?? '';
  const List<String> knownMessages = <String>[
    'Ce code ami est introuvable.',
    'Tu ne peux pas utiliser ton propre code ami.',
    'Une demande est déjà en attente entre ces deux joueurs.',
    'Ce joueur est déjà ton ami.',
    'Trop de demandes sont déjà en attente.',
    'Ce joueur ne peut pas recevoir de nouvelle demande actuellement.',
    'Attends quelques secondes avant une nouvelle demande.',
    'La limite de 50 amis est atteinte.',
    'La limite de joueurs bloqués est atteinte.',
    'Les fonctions sociales ne sont pas disponibles pour ce profil.',
  ];
  for (final String known in knownMessages) {
    if (message.contains(known)) return known;
  }
  if (message.contains('unauthenticated')) {
    return 'La connexion PointGeo doit être renouvelée. Réessaie dans un instant.';
  }
  return 'Connexion aux amis impossible pour le moment.';
}
