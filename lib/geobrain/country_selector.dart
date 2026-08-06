import 'dart:math';

import '../geo_engine/geo_country.dart';
import 'country_mastery.dart';
import 'geobrain_service.dart';

class CountrySelector {
  CountrySelector({
    required this.geoBrain,
    Random? random,
  }) : _random = random ?? Random();

  final GeoBrainService geoBrain;
  final Random _random;

  /// Sélectionne les pays d’une mission en tenant compte :
  /// - des pays jamais vus ;
  /// - des révisions arrivées à échéance ;
  /// - du niveau de maîtrise ;
  /// - du nombre d’erreurs ;
  /// - des séries de réponses ;
  /// - d’une petite part d’aléatoire.
  ///
  /// La liste reçue doit déjà être filtrée selon
  /// l’expédition et sa difficulté.
  List<GeoCountry> selectCountries({
    required List<GeoCountry> availableCountries,
    required int questionCount,
    DateTime? now,
  }) {
    if (questionCount <= 0 ||
        availableCountries.isEmpty) {
      return const <GeoCountry>[];
    }

    final int resolvedQuestionCount =
        min(
      questionCount,
      availableCountries.length,
    );

    final DateTime selectionDate =
        now ?? DateTime.now();

    final List<_CountryCandidate> candidates =
        availableCountries
            .map<_CountryCandidate>(
              (GeoCountry country) {
                final CountryMastery mastery =
                    geoBrain.masteryFor(
                  country.id,
                );

                return _CountryCandidate(
                  country: country,
                  mastery: mastery,
                  weight: _calculateWeight(
                    mastery: mastery,
                    now: selectionDate,
                  ),
                );
              },
            )
            .toList(
              growable: false,
            );

    final List<GeoCountry> result =
        <GeoCountry>[];

    final Set<String> selectedIds =
        <String>{};

    /*
     * Pour une mission de 10 questions :
     *
     * - jusqu’à 6 nouveaux pays ;
     * - jusqu’à 2 pays à réviser ;
     * - au moins 1 pays faible ;
     * - le reste est sélectionné par poids.
     *
     * Les quotas restent souples :
     * si une catégorie est vide, les places sont
     * automatiquement remplies par les autres pays.
     */
    final int newCountryTarget =
        (resolvedQuestionCount * 0.60).round();

    final int reviewTarget =
        (resolvedQuestionCount * 0.20).round();

    final int weakTarget =
        max(
      1,
      (resolvedQuestionCount * 0.10).round(),
    );

    final List<_CountryCandidate> newCountries =
        candidates
            .where(
              (_CountryCandidate candidate) {
                return !candidate
                    .mastery
                    .hasBeenSeen;
              },
            )
            .toList();

    final List<_CountryCandidate> reviewCountries =
        candidates
            .where(
              (_CountryCandidate candidate) {
                return candidate
                        .mastery
                        .hasBeenSeen &&
                    _isDueForReview(
                      candidate.mastery,
                      selectionDate,
                    );
              },
            )
            .toList();

    final List<_CountryCandidate> weakCountries =
        candidates
            .where(
              (_CountryCandidate candidate) {
                return candidate
                        .mastery
                        .hasBeenSeen &&
                    candidate
                            .mastery
                            .masteryLevel <=
                        2;
              },
            )
            .toList();

    _takeWeightedCandidates(
      source: newCountries,
      count: newCountryTarget,
      result: result,
      selectedIds: selectedIds,
    );

    _takeWeightedCandidates(
      source: reviewCountries,
      count: reviewTarget,
      result: result,
      selectedIds: selectedIds,
    );

    _takeWeightedCandidates(
      source: weakCountries,
      count: weakTarget,
      result: result,
      selectedIds: selectedIds,
    );

    /*
     * On complète ensuite la mission avec tous
     * les candidats restants, toujours selon leur
     * poids d’apprentissage.
     */
    _takeWeightedCandidates(
      source: candidates,
      count:
          resolvedQuestionCount -
              result.length,
      result: result,
      selectedIds: selectedIds,
    );

    /*
     * Dernière sécurité : si les catégories se
     * chevauchaient fortement, on complète avec
     * les pays encore absents.
     */
    if (result.length <
        resolvedQuestionCount) {
      final List<GeoCountry> remaining =
          availableCountries
              .where(
                (GeoCountry country) {
                  return !selectedIds.contains(
                    _normalizeId(
                      country.id,
                    ),
                  );
                },
              )
              .toList();

      remaining.shuffle(
        _random,
      );

      for (final GeoCountry country
          in remaining) {
        result.add(
          country,
        );

        selectedIds.add(
          _normalizeId(
            country.id,
          ),
        );

        if (result.length >=
            resolvedQuestionCount) {
          break;
        }
      }
    }

    /*
     * L’ordre final est mélangé pour éviter que
     * les nouveaux pays soient toujours présentés
     * au début de la mission.
     */
    result.shuffle(
      _random,
    );

    return List<GeoCountry>.unmodifiable(
      result,
    );
  }

  double _calculateWeight({
    required CountryMastery mastery,
    required DateTime now,
  }) {
    /*
     * Un pays jamais vu bénéficie d’une forte
     * priorité afin de faire progresser le joueur.
     */
    if (!mastery.hasBeenSeen) {
      return 100;
    }

    double weight = 15;

    /*
     * Plus le niveau de maîtrise est faible,
     * plus le pays doit revenir souvent.
     */
    weight +=
        (
          CountryMastery.maximumMasteryLevel -
          mastery.masteryLevel
        ) *
        14;

    /*
     * Les erreurs augmentent la priorité.
     * On limite leur influence pour ne pas rendre
     * une mission entièrement répétitive.
     */
    weight +=
        min(
      mastery.wrongAnswers * 4,
      28,
    );

    /*
     * Une mauvaise précision indique que le pays
     * mérite davantage de révisions.
     */
    weight +=
        (1 - mastery.accuracy) * 30;

    /*
     * Les pays arrivés à leur date de révision
     * reçoivent un bonus.
     */
    if (_isDueForReview(
      mastery,
      now,
    )) {
      weight += 45;

      final DateTime? nextReviewAt =
          mastery.nextReviewAt;

      if (nextReviewAt != null &&
          nextReviewAt.isBefore(now)) {
        final int overdueDays =
            now
                .difference(
                  nextReviewAt,
                )
                .inDays;

        weight +=
            min(
          overdueDays * 2,
          30,
        );
      }
    }

    /*
     * Une série de bonnes réponses diminue
     * légèrement la priorité : ce pays semble
     * être en cours d’acquisition.
     */
    weight -=
        min(
      mastery.currentStreak * 3,
      15,
    );

    /*
     * Les pays parfaitement maîtrisés doivent
     * toujours pouvoir revenir, mais rarement.
     */
    if (mastery.isMastered) {
      weight *= 0.20;
    }

    /*
     * Petite variation aléatoire afin que deux
     * missions successives ne soient pas identiques.
     */
    weight +=
        _random.nextDouble() * 8;

    return max(
      weight,
      1,
    );
  }

  void _takeWeightedCandidates({
    required List<_CountryCandidate> source,
    required int count,
    required List<GeoCountry> result,
    required Set<String> selectedIds,
  }) {
    if (count <= 0 ||
        source.isEmpty) {
      return;
    }

    final List<_CountryCandidate> pool =
        source
            .where(
              (_CountryCandidate candidate) {
                return !selectedIds.contains(
                  candidate.normalizedId,
                );
              },
            )
            .toList();

    int remainingCount =
        count;

    while (pool.isNotEmpty &&
        remainingCount > 0) {
      final _CountryCandidate selected =
          _drawWeighted(
        pool,
      );

      result.add(
        selected.country,
      );

      selectedIds.add(
        selected.normalizedId,
      );

      pool.removeWhere(
        (_CountryCandidate candidate) {
          return candidate.normalizedId ==
              selected.normalizedId;
        },
      );

      remainingCount--;
    }
  }

  _CountryCandidate _drawWeighted(
    List<_CountryCandidate> candidates,
  ) {
    if (candidates.length == 1) {
      return candidates.first;
    }

    final double totalWeight =
        candidates.fold<double>(
      0,
      (
        double total,
        _CountryCandidate candidate,
      ) {
        return total +
            candidate.weight;
      },
    );

    if (totalWeight <= 0) {
      return candidates[
          _random.nextInt(
        candidates.length,
      )];
    }

    double cursor =
        _random.nextDouble() *
            totalWeight;

    for (final _CountryCandidate candidate
        in candidates) {
      cursor -=
          candidate.weight;

      if (cursor <= 0) {
        return candidate;
      }
    }

    return candidates.last;
  }

  bool _isDueForReview(
    CountryMastery mastery,
    DateTime now,
  ) {
    final DateTime? nextReviewAt =
        mastery.nextReviewAt;

    if (nextReviewAt == null) {
      return mastery.hasBeenSeen;
    }

    return !nextReviewAt.isAfter(
      now,
    );
  }

  static String _normalizeId(
    String countryId,
  ) {
    return countryId
        .trim()
        .toUpperCase();
  }
}

class _CountryCandidate {
  const _CountryCandidate({
    required this.country,
    required this.mastery,
    required this.weight,
  });

  final GeoCountry country;
  final CountryMastery mastery;
  final double weight;

  String get normalizedId {
    return country.id
        .trim()
        .toUpperCase();
  }
}