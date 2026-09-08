import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/game_controller.dart';
import '../../monetization/ad_free_entitlement.dart';
import '../../passport/settings/passport_display_preferences.dart';
import '../../passport/settings/passport_display_preferences_storage.dart';
import '../design/geopoint_design.dart';
import 'account_screen.dart';
import 'ad_free_purchase_screen.dart';
import 'gameplay_feedback.dart';
import 'legal_information_screen.dart';
import 'player_xp_debug_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PassportDisplayPreferences _preferences =
      PassportDisplayPreferences.initial();
  bool _isLoading = true;
  bool _isSaving = false;

  Future<void> _openAdFree() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AdFreePurchaseScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openAccount() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            AccountScreen(controller: widget.controller),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openLegalInformation() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const LegalInformationScreen(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    try {
      final PassportDisplayPreferences preferences =
          await PassportDisplayPreferencesStorage.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _preferences = preferences;
        _isLoading = false;
      });
    } on Object catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePreferences(
    PassportDisplayPreferences updated, {
    VoidCallback? preview,
  }) async {
    if (_isSaving) {
      return;
    }
    final PassportDisplayPreferences previous = _preferences;

    setState(() {
      _preferences = updated;
      _isSaving = true;
    });

    final bool saved = await PassportDisplayPreferencesStorage.save(updated);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      if (!saved) {
        _preferences = previous;
      }
    });

    if (saved) {
      GameplayFeedback.apply(updated);
      preview?.call();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible d’enregistrer ce réglage.')),
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
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'PARAMÈTRES',
                      subtitle: 'Personnalise ton expérience',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 24),
                    _AccountSettingsCard(
                      controller: widget.controller,
                      onPressed: _openAccount,
                    ),
                    const SizedBox(height: 16),
                    _AdFreeSettingsCard(onPressed: _openAdFree),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'JEU',
                      children: <Widget>[
                        _SettingsSwitchTile(
                          icon: Icons.volume_up_rounded,
                          iconColor: GeoColors.blue,
                          title: 'Effets sonores',
                          subtitle: 'Joue un son après chaque réponse.',
                          value: _preferences.soundEffectsEnabled,
                          enabled: !_isLoading && !_isSaving,
                          onChanged: (bool value) {
                            unawaited(
                              _savePreferences(
                                _preferences.copyWith(
                                  soundEffectsEnabled: value,
                                ),
                                preview: value
                                    ? GameplayFeedback.previewSound
                                    : null,
                              ),
                            );
                          },
                        ),
                        const _SettingsDivider(),
                        _SettingsSwitchTile(
                          icon: Icons.vibration_rounded,
                          iconColor: GeoColors.coral,
                          title: 'Vibrations',
                          subtitle: 'Ajoute un retour tactile aux réponses.',
                          value: _preferences.hapticsEnabled,
                          enabled: !_isLoading && !_isSaving,
                          onChanged: (bool value) {
                            unawaited(
                              _savePreferences(
                                _preferences.copyWith(hapticsEnabled: value),
                                preview: value
                                    ? GameplayFeedback.previewHaptic
                                    : null,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'ANIMATIONS',
                      children: <Widget>[
                        _SettingsSwitchTile(
                          icon: Icons.approval_rounded,
                          iconColor: GeoColors.purple,
                          title: 'Nouveaux tampons',
                          subtitle:
                              'Affiche le tampon lorsqu’un pays est découvert.',
                          value: _preferences.stampAnimationsEnabled,
                          enabled: !_isLoading && !_isSaving,
                          onChanged: (bool value) {
                            unawaited(
                              _savePreferences(
                                _preferences.copyWith(
                                  stampAnimationsEnabled: value,
                                ),
                              ),
                            );
                          },
                        ),
                        const _SettingsDivider(),
                        _SettingsSwitchTile(
                          icon: Icons.celebration_rounded,
                          iconColor: GeoColors.gold,
                          title: 'Grands niveaux',
                          subtitle:
                              'Anime les passages des 12 grands niveaux.',
                          value: _preferences.majorLevelAnimationsEnabled,
                          enabled: !_isLoading && !_isSaving,
                          onChanged: (bool value) {
                            unawaited(
                              _savePreferences(
                                _preferences.copyWith(
                                  majorLevelAnimationsEnabled: value,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'INFORMATIONS ET CONFIDENTIALITÉ',
                      children: <Widget>[
                        _SettingsNavigationTile(
                          icon: Icons.policy_rounded,
                          iconColor: GeoColors.mint,
                          title: 'Informations légales',
                          subtitle:
                              'Confidentialité, conditions et choix publicitaires.',
                          onTap: () => unawaited(_openLegalInformation()),
                        ),
                      ],
                    ),
                    if (kDebugMode) ...<Widget>[
                      const SizedBox(height: 16),
                      _DebugToolsCard(controller: widget.controller),
                    ],
                    const SizedBox(height: 16),
                    const _AboutCard(),
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

class _AccountSettingsCard extends StatelessWidget {
  const _AccountSettingsCard({
    required this.controller,
    required this.onPressed,
  });

  final GameController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPressed,
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.account_circle_rounded,
                    color: GeoColors.blue, size: 38),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'MON COMPTE',
                        style: GoogleFonts.fredoka(
                          color: GeoColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${controller.playerProfile.displayName} • connexion et profil',
                        style: const TextStyle(
                          color: Color(0xFF58708D),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: GeoColors.ink),
              ],
            ),
          ),
        ),
      );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.nunitoSans(
              color: GeoColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _AdFreeSettingsCard extends StatelessWidget {
  const _AdFreeSettingsCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool active = AdFreeAccess.instance.isActive;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[GeoColors.purple, GeoColors.blue],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white38),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                active ? Icons.verified_rounded : Icons.block_rounded,
                color: active ? GeoColors.mint : GeoColors.gold,
                size: 34,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      active ? 'COMPTE SANS PUBLICITÉ' : 'RETIRER LES PUBLICITÉS',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      active
                          ? 'Avantage actif sur ce compte'
                          : 'Achat unique à 2,99 € • sans abonnement',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.fredoka(
                    color: GeoColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF58708D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: GeoColors.blue,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunitoSans(
                        color: const Color(0xFF58708D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: GeoColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 77,
      endIndent: 16,
      color: Color(0x1A173B61),
    );
  }
}

class _DebugToolsCard extends StatelessWidget {
  const _DebugToolsCard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext context) {
                return PlayerXpDebugScreen(controller: controller);
              },
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            color: GeoColors.coral.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white70),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.science_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  'Outils XP de développement',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
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

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          const GeoCompassLogo(size: 44, showShadow: false),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PointGeo',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Version 1.0.0 • réglages enregistrés sur cet appareil',
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white60,
                    fontSize: 10,
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
