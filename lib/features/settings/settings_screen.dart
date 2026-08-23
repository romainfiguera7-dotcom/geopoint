import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../design/geopoint_design.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                            'Les réglages arrivent',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                              color: GeoColors.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Le son, les vibrations, les animations et les '
                            'options d’accessibilité seront regroupés ici.',
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
