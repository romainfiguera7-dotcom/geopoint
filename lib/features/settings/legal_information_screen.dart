import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../legal/legal_documents.dart';
import '../../monetization/ad_consent_service.dart';
import '../design/geopoint_design.dart';

class LegalInformationScreen extends StatelessWidget {
  const LegalInformationScreen({super.key});

  void _open(
    BuildContext context,
    PointGeoLegalDocument document,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _LegalDocumentScreen(
          document: document,
        ),
      ),
    );
  }

  Future<void> _openAdChoices(BuildContext context) async {
    String? message;
    try {
      message = await AdConsentService.instance.showPrivacyOptions();
    } on Object {
      message = 'Les choix publicitaires sont momentanément indisponibles.';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ?? 'Tes choix publicitaires ont été mis à jour.',
        ),
      ),
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
                      title: 'INFORMATIONS LÉGALES',
                      subtitle: 'PointGeo • 16 ans et plus',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 24),
                    _LegalCard(
                      icon: Icons.gavel_rounded,
                      title: 'Mentions légales',
                      subtitle: 'Éditeur, hébergement et contact',
                      onTap: () => _open(
                        context,
                        PointGeoLegalDocuments.legalNotice,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LegalCard(
                      icon: Icons.privacy_tip_rounded,
                      title: 'Politique de confidentialité',
                      subtitle: 'Données, Firebase, AdMob et tes droits',
                      onTap: () => _open(
                        context,
                        PointGeoLegalDocuments.privacyPolicy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LegalCard(
                      icon: Icons.description_rounded,
                      title: 'Conditions d’utilisation',
                      subtitle: 'Règles du service et des classements',
                      onTap: () => _open(
                        context,
                        PointGeoLegalDocuments.terms,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LegalCard(
                      icon: Icons.tune_rounded,
                      title: 'Choix publicitaires',
                      subtitle: 'Consulter ou modifier ton consentement AdMob',
                      onTap: () => unawaited(_openAdChoices(context)),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text(
                        'Éditeur : Romain Figuera\n'
                        '3B rue du Salaison, 34740 Vendargues\n'
                        'vipers34170@gmail.com',
                        style: TextStyle(
                          color: Color(0xFF45617E),
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
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

class _LegalCard extends StatelessWidget {
  const _LegalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: GeoColors.blue, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: GoogleFonts.fredoka(
                        color: GeoColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF58708D)),
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

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.document});

  final PointGeoLegalDocument document;

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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: document.title.toUpperCase(),
                      subtitle: 'Mise à jour : ${document.updatedAt}',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 24),
                    ...document.sections.map(
                      (PointGeoLegalSection section) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.97),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                section.title,
                                style: GoogleFonts.fredoka(
                                  color: GeoColors.ink,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                section.body,
                                style: const TextStyle(
                                  color: Color(0xFF405D7A),
                                  fontSize: 14,
                                  height: 1.5,
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
            ),
          ),
        ],
      ),
    );
  }
}
