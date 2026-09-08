import 'package:flutter/material.dart';

import '../../game/game_controller.dart';
import '../challenges/challenges_screen.dart';
import '../design/geopoint_design.dart';
import '../expeditions/expeditions_screen.dart';
import '../training/training_screen.dart';

class PlayHubScreen extends StatefulWidget {
  const PlayHubScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<PlayHubScreen> createState() => _PlayHubScreenState();
}

class _PlayHubScreenState extends State<PlayHubScreen> {
  GameController get controller => widget.controller;

  void _openExpeditions(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ExpeditionsScreen(controller: controller);
        },
      ),
    );
  }

  void _openTraining(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TrainingScreen(controller: controller);
        },
      ),
    );
  }

  void _openChallenges(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ChallengesScreen(controller: controller);
        },
      ),
    );
  }

  void _showSoon(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showGeoComingSoon(
      context,
      title: title,
      message: message,
      icon: icon,
      color: color,
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
                constraints: const BoxConstraints(maxWidth: 580),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'JOUER',
                      subtitle: 'Choisis ton aventure',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 30),
                    const GeoSectionHeading(
                      eyebrow: '',
                      title: 'Où veux-tu jouer ?',
                    ),
                    const SizedBox(height: 20),
                    GeoFeatureCard(
                      icon: Icons.route_rounded,
                      title: 'EXPÉDITIONS',
                      subtitle:
                          'Explore les continents et deviens Maître cartographe.',
                      color: GeoColors.gold,
                      badge: 'Disponible',
                      large: true,
                      onPressed: () => _openExpeditions(context),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 154,
                      child: GeoFeatureCard(
                        icon: Icons.gps_fixed_rounded,
                        title: 'ENTRAÎNEMENT',
                        subtitle:
                            'Pays, capitales, drapeaux, villes, monnaies et langues.',
                        color: GeoColors.mint,
                        badge: 'Disponible',
                        artwork: const GeoCardArtwork(
                          primary: Icons.gps_fixed_rounded,
                          secondary: Icons.location_on_rounded,
                          color: GeoColors.navy,
                        ),
                        onPressed: () => _openTraining(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: SizedBox(
                            height: 190,
                            child: GeoFeatureCard(
                              icon: Icons.emoji_events_rounded,
                              title: 'DÉFIS',
                              subtitle:
                                  'Défis du jour, de la semaine, du mois et permanents.',
                              color: GeoColors.coral,
                              badge: 'Nouveau',
                              artwork: const GeoCardArtwork(
                                primary: Icons.emoji_events_rounded,
                                secondary: Icons.auto_awesome_rounded,
                                color: GeoColors.navy,
                              ),
                              onPressed: () => _openChallenges(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 190,
                            child: GeoFeatureCard(
                              icon: Icons.public_rounded,
                              title: 'EN LIGNE',
                              subtitle:
                                  'Affronte bientôt les joueurs du monde entier.',
                              color: GeoColors.purple,
                              badge: 'Bientôt',
                              artwork: const GeoCardArtwork(
                                primary: Icons.public_rounded,
                                secondary: Icons.sports_esports_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => _showSoon(
                                context,
                                title: 'Mode en ligne',
                                message:
                                    'Duels, classements et parties entre amis '
                                    'seront accessibles depuis cet espace.',
                                icon: Icons.public_rounded,
                                color: GeoColors.purple,
                              ),
                            ),
                          ),
                        ),
                      ],
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
