import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../account/player_account_service.dart';
import '../../game/game_controller.dart';
import '../../monetization/ad_free_entitlement.dart';
import '../design/geopoint_design.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  StreamSubscription<User?>? _subscription;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subscription = PlayerAccountService.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await widget.controller.refreshOnlineIdentityAfterAccountChange();
      await AdFreeAccess.instance.refresh();
      if (mounted) setState(() {});
    } on FirebaseAuthException catch (error) {
      _message(_firebaseMessage(error));
    } on Object catch (error) {
      _message('La connexion n’a pas abouti : $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _rename() async {
    final TextEditingController name = TextEditingController(
      text: widget.controller.playerProfile.displayName,
    );
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Modifier mon pseudo'),
        content: TextField(
          controller: name,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Pseudo',
            hintText: 'Entre 2 et 20 caractères',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULER'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ENREGISTRER'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final bool saved = await widget.controller.renamePlayer(name.text);
    _message(saved
        ? 'Ton pseudo a bien été modifié.'
        : 'Choisis un pseudo comprenant entre 2 et 20 caractères.');
    if (mounted) setState(() {});
  }

  Future<void> _emailDialog({required bool create}) async {
    final TextEditingController email = TextEditingController();
    final TextEditingController password = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(create ? 'Créer mon compte' : 'Connexion par e-mail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Adresse e-mail'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                helperText: '6 caractères minimum',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULER'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(create ? 'CRÉER' : 'SE CONNECTER'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (create && !await _confirmMinimumAge()) return;
    if (!mounted) return;
    await _run(() async {
      if (create) {
        await PlayerAccountService.instance.createEmailAccount(
          email: email.text,
          password: password.text,
        );
      } else {
        await PlayerAccountService.instance.signInWithEmail(
          email: email.text,
          password: password.text,
        );
      }
    });
  }

  Future<bool> _confirmMinimumAge() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Confirmation d’âge'),
        content: const Text(
          'PointGeo est destiné aux personnes de 16 ans ou plus. En créant '
          'un compte, tu confirmes avoir au moins 16 ans et accepter les '
          'Conditions d’utilisation et la Politique de confidentialité '
          'accessibles dans les Paramètres.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULER'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('J’AI 16 ANS OU PLUS'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _signInWithGoogle() async {
    if (!await _confirmMinimumAge() || !mounted) return;
    await _run(PlayerAccountService.instance.signInWithGoogle);
  }

  Future<void> _deleteAccount() async {
    final TextEditingController confirmation = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
          title: const Text('Supprimer définitivement mon compte ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'La progression, les classements, les amis, les récompenses '
                'et les données du profil seront effacés. Cette action est '
                'irréversible.',
              ),
              const SizedBox(height: 16),
              const Text('Écris SUPPRIMER pour confirmer.'),
              const SizedBox(height: 8),
              TextField(
                controller: confirmation,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(labelText: 'SUPPRIMER'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ANNULER'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: confirmation.text.trim().toUpperCase() == 'SUPPRIMER'
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('SUPPRIMER MON COMPTE'),
            ),
          ],
        ),
      ),
    );
    confirmation.dispose();
    if (confirmed != true || _busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await PlayerAccountService.instance.deleteAccountAndData();
      await widget.controller.deleteLocalPlayerData();
      await AdFreeAccess.instance.refresh();
      _message('Ton compte et tes données PointGeo ont été supprimés.');
      if (mounted) setState(() {});
    } on Object catch (error) {
      _message(
        'La suppression n’a pas abouti. Vérifie ta connexion puis réessaie : '
        '$error',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayerAccountSnapshot account = PlayerAccountService.instance.snapshot;
    final String accountLabel = switch (account.kind) {
      PlayerAccountKind.guest => 'Mode invité',
      PlayerAccountKind.google => 'Compte Google',
      PlayerAccountKind.email => 'Compte e-mail',
    };
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'MON COMPTE',
                      subtitle: 'Profil et connexion',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 24),
                    _AccountCard(
                      icon: account.isGuest
                          ? Icons.person_outline_rounded
                          : Icons.verified_user_rounded,
                      title: widget.controller.playerProfile.displayName,
                      subtitle: account.email ?? accountLabel,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _rename,
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('MODIFIER MON PSEUDO'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (account.isGuest)
                      _AccountCard(
                        icon: Icons.cloud_upload_rounded,
                        title: 'Associer mon compte',
                        subtitle:
                            'Associe ta partie actuelle à Google ou à ton e-mail.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : _signInWithGoogle,
                              icon: const Icon(Icons.g_mobiledata_rounded),
                              label: const Text('CONTINUER AVEC GOOGLE'),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _emailDialog(create: true),
                              icon: const Icon(Icons.mail_outline_rounded),
                              label: const Text('CRÉER AVEC MON E-MAIL'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _emailDialog(create: false),
                              child: const Text('J’AI DÉJÀ UN COMPTE'),
                            ),
                          ],
                        ),
                      )
                    else
                      _AccountCard(
                        icon: Icons.cloud_done_rounded,
                        title: 'Compte connecté',
                        subtitle:
                            'Cette partie est associée à ton compte PointGeo.',
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                    PlayerAccountService.instance.signOutToGuest,
                                  ),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('SE DÉCONNECTER'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _AccountCard(
                      icon: Icons.delete_forever_rounded,
                      title: 'Supprimer mon compte',
                      subtitle:
                          'Efface définitivement le compte et ses données.',
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                        onPressed: _busy ? null : _deleteAccount,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('SUPPRIMER MON COMPTE'),
                      ),
                    ),
                    if (_busy) ...<Widget>[
                      const SizedBox(height: 20),
                      const Center(child: CircularProgressIndicator()),
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: GeoColors.blue, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: GoogleFonts.fredoka(
                          color: GeoColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(subtitle, style: const TextStyle(color: Color(0xFF58708D))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      );
}

String _firebaseMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => 'Cette adresse e-mail n’est pas valide.',
    'weak-password' => 'Le mot de passe doit contenir au moins 6 caractères.',
    'email-already-in-use' => 'Un compte existe déjà avec cette adresse.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' =>
      'Adresse e-mail ou mot de passe incorrect.',
    'network-request-failed' => 'Vérifie ta connexion Internet.',
    _ => error.message ?? 'La connexion n’a pas abouti.',
  };
}
