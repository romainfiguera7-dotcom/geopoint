import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../design/geopoint_design.dart';
import 'france/france_expedition_screen.dart';

class NationalExplorationsScreen extends StatelessWidget {
  const NationalExplorationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'EXPLORATIONS NATIONALES',
                      subtitle: 'Choisis un pays à explorer en profondeur',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 26),
                    const GeoSectionHeading(
                      eyebrow: 'NOUVELLE ÉCHELLE',
                      title: 'Au cœur d’un pays',
                      description:
                          'Chaque parcours national possède sa propre carte, ses étapes et sa progression.',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 180,
                      child: GeoFeatureCard(
                        icon: Icons.flag_rounded,
                        title: 'France',
                        subtitle:
                            '9 étapes • régions, villes, fleuves, reliefs et monuments',
                        color: const Color(0xFF5AD7FF),
                        badge: 'PILOTE',
                        large: true,
                        artwork: const Text('🇫🇷', style: TextStyle(fontSize: 55)),
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  const FranceExpeditionScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.add_location_alt_rounded,
                              color: GeoColors.purple),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'D’autres pays pourront rejoindre cette liste sans modifier les expéditions continentales.',
                              style: GoogleFonts.nunitoSans(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
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
