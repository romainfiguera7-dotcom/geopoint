import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../passport/settings/passport_display_preferences.dart';
import '../../passport/settings/passport_display_preferences_storage.dart';
import '../design/geopoint_design.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PassportDisplayPreferences _passportPreferences =
      PassportDisplayPreferences.initial();
  bool _savingPassportPreferences = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPassportPreferences());
  }

  Future<void> _loadPassportPreferences() async {
    try {
      final PassportDisplayPreferences preferences =
          await PassportDisplayPreferencesStorage.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _passportPreferences = preferences;
      });
    } on Object catch (_) {
      // Les valeurs par défaut restent utilisables hors ligne.
    }
  }

  Future<void> _setStampAnimationsEnabled(bool value) async {
    if (_savingPassportPreferences) {
      return;
    }

    final PassportDisplayPreferences previous = _passportPreferences;
    final PassportDisplayPreferences updated = previous.copyWith(
      stampAnimationsEnabled: value,
    );

    setState(() {
      _passportPreferences = updated;
      _savingPassportPreferences = true;
    });

    final bool saved = await PassportDisplayPreferencesStorage.save(updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _savingPassportPreferences = false;

      if (!saved) {
        _passportPreferences = previous;
      }
    });
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
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
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
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF5FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.approval_rounded,
                              color: GeoColors.blue,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Animation des tampons',
                                  style: GoogleFonts.fredoka(
                                    color: GeoColors.ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Affiche le nouveau tampon après son '
                                  'déblocage.',
                                  style: GoogleFonts.nunitoSans(
                                    color: const Color(0xFF58708D),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value:
                                _passportPreferences.stampAnimationsEnabled,
                            activeTrackColor: GeoColors.blue,
                            onChanged: _savingPassportPreferences
                                ? null
                                : (bool value) {
                                    unawaited(
                                      _setStampAnimationsEnabled(value),
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(27),
                        border: Border.all(color: Colors.white),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 18,
                            offset: const Offset(0, 9),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: GeoColors.sky,
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: GeoColors.navy,
                              size: 37,
                            ),
                          ),
                          const SizedBox(height: 17),
                          Text(
                            'D’autres réglages arrivent',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                              color: GeoColors.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Le son, les vibrations et les options '
                            'd’accessibilité seront regroupés ici.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunitoSans(
                              color: const Color(0xFF58708D),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ],
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
