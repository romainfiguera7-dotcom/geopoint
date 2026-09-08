import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../monetization/ad_free_entitlement.dart';
import '../design/geopoint_design.dart';

class AdFreePurchaseScreen extends StatefulWidget {
  const AdFreePurchaseScreen({super.key});

  @override
  State<AdFreePurchaseScreen> createState() => _AdFreePurchaseScreenState();
}

class _AdFreePurchaseScreenState extends State<AdFreePurchaseScreen> {
  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _product;
  bool _loading = true;
  bool _storeAvailable = false;
  bool _purchasePending = false;
  String? _message;

  AdFreeAccess get _access => AdFreeAccess.instance;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _purchasePending = false;
          _message = 'La boutique a rencontré une erreur : $error';
        });
      },
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    await _access.refresh();
    if (_access.isActive) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final bool available = await _store.isAvailable();
      ProductDetails? product;
      String? message;
      if (available) {
        final ProductDetailsResponse response = await _store
            .queryProductDetails(const <String>{AdFreeAccess.productId});
        if (response.error != null) {
          message = response.error!.message;
        } else if (response.productDetails.isNotEmpty) {
          product = response.productDetails.first;
        } else {
          message = 'Le produit Google Play n’est pas encore configuré.';
        }
      } else {
        message = 'Google Play n’est pas disponible sur cet appareil.';
      }
      if (!mounted) return;
      setState(() {
        _storeAvailable = available;
        _product = product;
        _message = message;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Impossible de joindre Google Play : $error';
      });
    }
  }

  Future<void> _buy() async {
    final ProductDetails? product = _product;
    if (product == null || _purchasePending) return;
    setState(() {
      _purchasePending = true;
      _message = null;
    });
    final bool launched = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!launched && mounted) {
      setState(() {
        _purchasePending = false;
        _message = 'Google Play n’a pas pu ouvrir le paiement.';
      });
    }
  }

  Future<void> _restore() async {
    if (_purchasePending) return;
    setState(() {
      _purchasePending = true;
      _message = 'Recherche de votre achat…';
    });
    try {
      await _store.restorePurchases();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _purchasePending = false;
        _message = 'Restauration impossible : $error';
      });
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.productID != AdFreeAccess.productId) continue;
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _purchasePending = true);
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        if (!mounted) continue;
        setState(() {
          _purchasePending = false;
          _message = purchase.error?.message ?? 'Le paiement a échoué.';
        });
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() {
            _purchasePending = false;
            _message = 'Achat annulé.';
          });
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          final String token =
              purchase.verificationData.serverVerificationData.trim();
          if (token.isEmpty) {
            throw const FormatException('Jeton Google Play manquant.');
          }
          await _access.verifyGooglePlayPurchase(token);
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          if (!mounted) continue;
          setState(() {
            _purchasePending = false;
            _message = 'Merci ! PointGeo est maintenant sans publicité.';
          });
        } on Object catch (error) {
          if (!mounted) continue;
          setState(() {
            _purchasePending = false;
            _message = 'La vérification de l’achat a échoué : $error';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _access.isActive;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  children: <Widget>[
                    GeoGameTopBar(
                      title: 'SANS PUBLICITÉ',
                      subtitle: active ? 'Avantage actif' : 'Achat unique',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[GeoColors.purple, GeoColors.blue],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white54),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              active
                                  ? Icons.verified_rounded
                                  : Icons.block_rounded,
                              color: active ? GeoColors.mint : GeoColors.gold,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            active ? 'POINTGEO SANS PUB' : 'JOUEZ SANS PUB',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            active
                                ? _access.entitlement.source.label
                                : 'Un seul paiement, aucun abonnement.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _Benefit(
                            icon: Icons.visibility_off_rounded,
                            text: 'Toutes les publicités sont retirées',
                          ),
                          const _Benefit(
                            icon: Icons.replay_rounded,
                            text: 'Les reprises publicitaires deviennent gratuites',
                          ),
                          const _Benefit(
                            icon: Icons.devices_rounded,
                            text: 'Achat restaurable avec votre compte Google Play',
                          ),
                          const SizedBox(height: 22),
                          if (_loading)
                            const CircularProgressIndicator(color: Colors.white)
                          else if (active)
                            FilledButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('AVANTAGE ACTIF'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: _product != null && !_purchasePending
                                  ? _buy
                                  : null,
                              icon: const Icon(Icons.shopping_bag_rounded),
                              label: Text(
                                _purchasePending
                                    ? 'TRAITEMENT EN COURS…'
                                    : 'ACHETER • ${_product?.price ?? '2,99 €'}',
                              ),
                            ),
                          if (!active) ...<Widget>[
                            const SizedBox(height: 9),
                            TextButton.icon(
                              onPressed: _storeAvailable && !_purchasePending
                                  ? _restore
                                  : null,
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('RESTAURER MON ACHAT'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_message != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (!active && _product == null) ...<Widget>[
                      const SizedBox(height: 12),
                      const Text(
                        'Le bouton sera automatiquement activé dès que le '
                        'produit geopoint_no_ads sera publié dans Google Play '
                        'Console pour cette application.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
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

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Icon(icon, color: GeoColors.mint, size: 23),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
