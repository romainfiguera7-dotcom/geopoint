import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../player/player_level.dart';
import '../../player/player_profile.dart';
import '../../player/player_xp_debug_tools.dart';
import '../design/geopoint_design.dart';

class PlayerXpDebugScreen extends StatefulWidget {
  const PlayerXpDebugScreen({
    required this.controller,
    super.key,
  });

  final GameController controller;

  @override
  State<PlayerXpDebugScreen> createState() => _PlayerXpDebugScreenState();
}

class _PlayerXpDebugScreenState extends State<PlayerXpDebugScreen> {
  final TextEditingController _amountController =
      TextEditingController(text: '100');
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _runAction(
    PlayerXpDebugAction action, {
    int amount = 0,
    required String successMessage,
  }) async {
    if (_isApplying) {
      return;
    }

    setState(() => _isApplying = true);
    try {
      await widget.controller.applyDebugPlayerXpAction(
        action,
        amount: amount,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action impossible : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _addXp() async {
    final int? amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre une quantité d’XP positive.')),
      );
      return;
    }

    await _runAction(
      PlayerXpDebugAction.addXp,
      amount: amount,
      successMessage: '+$amount XP de test ajoutés.',
    );
  }

  Future<void> _resetXp() async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Remettre l’XP à zéro ?'),
              content: const Text(
                'Seule la progression XP et son registre anti-doublon seront '
                'réinitialisés. Les parties, statistiques, tampons, Atlas et '
                'GeoBrain seront conservés.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ANNULER'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('REMETTRE À 0'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    await _runAction(
      PlayerXpDebugAction.resetXp,
      successMessage: 'Progression XP remise à zéro.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlayerProfile profile = widget.controller.playerProfile;
    final int nextMajorLevel =
        (profile.majorLevel + 1).clamp(1, PlayerLevelCatalog.majorLevelCount);
    final String nextMajorTitle =
        PlayerLevelCatalog.titleForMajorLevel(nextMajorLevel);

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
                      title: 'OUTILS XP DEBUG',
                      subtitle: 'Tests locaux · absents de la version publiée',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 22),
                    _XpStatusCard(profile: profile),
                    const SizedBox(height: 14),
                    _DebugCard(
                      icon: Icons.add_circle_rounded,
                      title: 'Ajouter une quantité précise',
                      description:
                          'Ajoute de l’XP sans modifier les statistiques.',
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              enabled: !_isApplying,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Quantité d’XP',
                                suffixText: 'XP',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => unawaited(_addXp()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _isApplying
                                ? null
                                : () => unawaited(_addXp()),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(84, 56),
                            ),
                            child: const Text('AJOUTER'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DebugCard(
                      icon: Icons.flag_circle_rounded,
                      title: 'Préparer un passage de palier',
                      description: profile.isMaximumLevel
                          ? 'Le niveau maximal est déjà atteint.'
                          : 'Place le profil exactement à 1 XP du prochain '
                              'palier.',
                      child: _DebugActionButton(
                        label: 'À 1 XP DU PROCHAIN PALIER',
                        icon: Icons.skip_next_rounded,
                        enabled: !_isApplying && !profile.isMaximumLevel,
                        onPressed: () => unawaited(
                          _runAction(
                            PlayerXpDebugAction.prepareNextTier,
                            successMessage:
                                'Profil placé à 1 XP du prochain palier.',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DebugCard(
                      icon: Icons.celebration_rounded,
                      title: 'Simuler un grand niveau',
                      description: profile.majorLevel >=
                              PlayerLevelCatalog.majorLevelCount
                          ? 'Maître du monde est déjà atteint.'
                          : 'Place le profil à 1 XP de $nextMajorTitle. La '
                              'prochaine partie déclenchera la célébration.',
                      child: _DebugActionButton(
                        label: 'PRÉPARER LE GRAND NIVEAU',
                        icon: Icons.auto_awesome_rounded,
                        enabled: !_isApplying &&
                            profile.majorLevel <
                                PlayerLevelCatalog.majorLevelCount,
                        onPressed: () => unawaited(
                          _runAction(
                            PlayerXpDebugAction.prepareNextMajorLevel,
                            successMessage:
                                'Prochain grand niveau prêt à être testé.',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DebugCard(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Tester le niveau maximal',
                      description:
                          'Passe directement à Maître du monde IV, sans '
                          'modifier le GeoBrain.',
                      child: _DebugActionButton(
                        label: 'ATTEINDRE LE NIVEAU MAXIMAL',
                        icon: Icons.emoji_events_rounded,
                        enabled: !_isApplying && !profile.isMaximumLevel,
                        onPressed: () => unawaited(
                          _runAction(
                            PlayerXpDebugAction.reachMaximumLevel,
                            successMessage:
                                'Niveau Maître du monde IV atteint.',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DebugCard(
                      icon: Icons.restart_alt_rounded,
                      title: 'Réinitialiser uniquement l’XP',
                      description:
                          'Conserve les parties, statistiques, tampons, Atlas '
                          'et connaissances GeoBrain.',
                      color: GeoColors.coral,
                      child: _DebugActionButton(
                        label: 'REMETTRE L’XP À 0',
                        icon: Icons.delete_sweep_rounded,
                        enabled: !_isApplying && profile.totalXp > 0,
                        color: GeoColors.coral,
                        onPressed: () => unawaited(_resetXp()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isApplying)
            const Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Color(0x33071B3A),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _XpStatusCard extends StatelessWidget {
  const _XpStatusCard({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GeoColors.navy.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: GeoColors.gold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.science_rounded,
                  color: GeoColors.gold,
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.displayLevelTitle,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Niveau interne ${profile.currentLevel}/48 · '
                      '${profile.totalXp} XP',
                      style: GoogleFonts.nunitoSans(
                        color: const Color(0xFFBFD0E8),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: profile.levelProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              valueColor: const AlwaysStoppedAnimation<Color>(GeoColors.gold),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            profile.isMaximumLevel
                ? 'Niveau maximal atteint'
                : '${profile.xpRemainingForNextLevel} XP avant le prochain '
                    'palier',
            style: GoogleFonts.nunitoSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugCard extends StatelessWidget {
  const _DebugCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
    this.color = GeoColors.blue,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
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
              Icon(icon, color: color, size: 27),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _DebugActionButton extends StatelessWidget {
  const _DebugActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.color = GeoColors.blue,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: GoogleFonts.fredoka(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
