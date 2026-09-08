import 'dart:math';

import '../geo_engine/geo_country.dart';
import 'country_mastery.dart';
import 'geobrain_service.dart';
import 'geobrain_theme.dart';
import 'theme_mastery.dart';

enum GeoBrainSelectionProfile {
  balanced,
  reviewDifficulties,
}

class CountrySelector {
  CountrySelector({
    required this.geoBrain,
    Random? random,
  }) : _random = random ?? Random();

  static const int _recentSelectionMemorySize = 12;

  final GeoBrainService geoBrain;
  final Random _random;
  final List<String> _recentlySelectedIds = <String>[];

  /// Sélectionne des pays déjà filtrés par le contrôleur selon la zone,
  /// le mode et la difficulté de la mission.
  ///
  /// Le profil équilibré mélange nouveautés, difficultés et vérifications de
  /// connaissances maîtrisées. Le profil [GeoBrainSelectionProfile.reviewDifficulties]
  /// consacre la majorité de la séance aux éléments fragiles ou à réviser.
  List<GeoCountry> selectCountries({
    required List<GeoCountry> availableCountries,
    required int questionCount,
    GeoBrainTheme? theme,
    GeoBrainSelectionProfile selectionProfile =
        GeoBrainSelectionProfile.balanced,
    DateTime? now,
  }) {
    if (questionCount <= 0 || availableCountries.isEmpty) {
      return const <GeoCountry>[];
    }

    final int resolvedQuestionCount = min(
      questionCount,
      availableCountries.length,
    );
    final DateTime selectionDate = now ?? DateTime.now();

    final List<_CountryCandidate> allCandidates = availableCountries
        .map<_CountryCandidate>((GeoCountry country) {
      final CountryMastery mastery = geoBrain.masteryFor(country.id);
      return _CountryCandidate(
        country: country,
        mastery: mastery,
        weight: _calculateWeight(
          mastery: mastery,
          theme: theme,
          now: selectionDate,
        ),
      );
    }).toList(growable: false);

    // Si le catalogue est assez grand, les pays vus dans les missions les plus
    // récentes sont temporairement écartés. Ils redeviennent disponibles dès
    // que le filtre empêcherait de remplir la séance.
    final List<_CountryCandidate> freshCandidates = allCandidates
        .where(
          (_CountryCandidate candidate) =>
              !_recentlySelectedIds.contains(candidate.normalizedId),
        )
        .toList(growable: false);
    final List<_CountryCandidate> candidates =
        freshCandidates.length >= resolvedQuestionCount
            ? freshCandidates
            : allCandidates;

    final List<_CountryCandidate> newCountries = candidates
        .where(
          (_CountryCandidate candidate) =>
              _isNewForTheme(candidate.mastery, theme),
        )
        .toList(growable: false);
    final List<_CountryCandidate> priorityCountries = candidates
        .where(
          (_CountryCandidate candidate) => _isPriority(
            candidate.mastery,
            selectionDate,
            theme,
          ),
        )
        .toList(growable: false);
    final List<_CountryCandidate> masteredChecks = candidates
        .where(
          (_CountryCandidate candidate) =>
              !_isPriority(candidate.mastery, selectionDate, theme) &&
              _isMastered(candidate.mastery, selectionDate, theme),
        )
        .toList(growable: false);
    final List<_CountryCandidate> neutralCountries = candidates
        .where(
          (_CountryCandidate candidate) =>
              !_isNewForTheme(candidate.mastery, theme) &&
              !_isPriority(candidate.mastery, selectionDate, theme) &&
              !_isMastered(candidate.mastery, selectionDate, theme),
        )
        .toList(growable: false);

    final _SelectionTargets targets = selectionProfile ==
            GeoBrainSelectionProfile.reviewDifficulties
        ? _reviewTargets(resolvedQuestionCount)
        : _balancedTargets(
            resolvedQuestionCount: resolvedQuestionCount,
            seenCount: candidates.length - newCountries.length,
            candidateCount: candidates.length,
          );

    final List<GeoCountry> result = <GeoCountry>[];
    final Set<String> selectedIds = <String>{};

    if (selectionProfile == GeoBrainSelectionProfile.reviewDifficulties) {
      _takeWeightedCandidates(
        source: priorityCountries,
        count: targets.priority,
        result: result,
        selectedIds: selectedIds,
      );
      _takeWeightedCandidates(
        source: masteredChecks,
        count: min(targets.mastered, resolvedQuestionCount - result.length),
        result: result,
        selectedIds: selectedIds,
      );
      _takeWeightedCandidates(
        source: newCountries,
        count: min(targets.newCountries, resolvedQuestionCount - result.length),
        result: result,
        selectedIds: selectedIds,
      );
    } else {
      _takeWeightedCandidates(
        source: newCountries,
        count: targets.newCountries,
        result: result,
        selectedIds: selectedIds,
      );
      _takeWeightedCandidates(
        source: priorityCountries,
        count: min(targets.priority, resolvedQuestionCount - result.length),
        result: result,
        selectedIds: selectedIds,
      );
      _takeWeightedCandidates(
        source: masteredChecks,
        count: min(targets.mastered, resolvedQuestionCount - result.length),
        result: result,
        selectedIds: selectedIds,
      );
    }

    _takeWeightedCandidates(
      source: neutralCountries,
      count: resolvedQuestionCount - result.length,
      result: result,
      selectedIds: selectedIds,
    );
    _takeWeightedCandidates(
      source: newCountries,
      count: resolvedQuestionCount - result.length,
      result: result,
      selectedIds: selectedIds,
    );
    _takeWeightedCandidates(
      source: masteredChecks,
      count: resolvedQuestionCount - result.length,
      result: result,
      selectedIds: selectedIds,
    );

    // Les priorités supplémentaires ne complètent la séance qu'en dernier
    // recours : une partie normale ne devient donc pas une longue répétition.
    _takeWeightedCandidates(
      source: priorityCountries,
      count: resolvedQuestionCount - result.length,
      result: result,
      selectedIds: selectedIds,
    );
    _takeWeightedCandidates(
      source: allCandidates,
      count: resolvedQuestionCount - result.length,
      result: result,
      selectedIds: selectedIds,
    );

    result.shuffle(_random);
    _rememberSelection(result);
    return List<GeoCountry>.unmodifiable(result);
  }

  _SelectionTargets _balancedTargets({
    required int resolvedQuestionCount,
    required int seenCount,
    required int candidateCount,
  }) {
    final double seenRatio = candidateCount == 0 ? 0 : seenCount / candidateCount;
    final double newShare;
    if (seenCount == 0) {
      newShare = 0.75;
    } else if (seenRatio < 0.30) {
      newShare = 0.70;
    } else if (seenRatio < 0.70) {
      newShare = 0.45;
    } else {
      newShare = 0.25;
    }
    return _SelectionTargets(
      newCountries: max(1, (resolvedQuestionCount * newShare).round()),
      priority: min(
        3,
        max(1, (resolvedQuestionCount * 0.25).round()),
      ),
      mastered: resolvedQuestionCount < 5
          ? 0
          : max(1, (resolvedQuestionCount * 0.10).round()),
    );
  }

  _SelectionTargets _reviewTargets(int resolvedQuestionCount) {
    return _SelectionTargets(
      priority: max(1, (resolvedQuestionCount * 0.70).round()),
      mastered: resolvedQuestionCount < 5
          ? 0
          : max(1, (resolvedQuestionCount * 0.15).round()),
      newCountries: resolvedQuestionCount < 4
          ? 0
          : max(1, (resolvedQuestionCount * 0.15).round()),
    );
  }

  double _calculateWeight({
    required CountryMastery mastery,
    required GeoBrainTheme? theme,
    required DateTime now,
  }) {
    if (_isNewForTheme(mastery, theme)) {
      return 100 + _random.nextDouble() * 8;
    }

    final ThemeMastery? themedMastery =
        theme == null ? null : mastery.masteryForTheme(theme);
    final int wrongAnswers = themedMastery?.wrongAnswers ?? mastery.wrongAnswers;
    final int currentStreak = themedMastery?.currentStreak ?? mastery.currentStreak;
    final double accuracy = themedMastery?.accuracy ?? mastery.accuracy;
    final double retainedScore = theme == null
        ? mastery.retainedGeneralScoreAt(now)
        : mastery.retentionForTheme(theme, now).retainedScore;

    double weight = 15;
    weight += (100 - retainedScore) * 0.55;
    weight += min(wrongAnswers * 4, 28);
    weight += (1 - accuracy) * 25;

    if (_isDueForReview(mastery, now, theme)) {
      weight += 45;
      final DateTime? nextReviewAt =
          themedMastery?.nextReviewAt ?? mastery.nextReviewAt;
      if (nextReviewAt != null && nextReviewAt.isBefore(now)) {
        weight += min(now.difference(nextReviewAt).inDays * 2, 30);
      }
    }

    weight -= min(currentStreak * 3, 15);
    if (_isMastered(mastery, now, theme)) {
      weight *= 0.20;
    }
    weight += _random.nextDouble() * 8;
    return max(weight, 1);
  }

  void _takeWeightedCandidates({
    required List<_CountryCandidate> source,
    required int count,
    required List<GeoCountry> result,
    required Set<String> selectedIds,
  }) {
    if (count <= 0 || source.isEmpty) {
      return;
    }
    final List<_CountryCandidate> pool = source
        .where(
          (_CountryCandidate candidate) =>
              !selectedIds.contains(candidate.normalizedId),
        )
        .toList();

    int remainingCount = count;
    while (pool.isNotEmpty && remainingCount > 0) {
      final List<_CountryCandidate> freshPool = pool
          .where(
            (_CountryCandidate candidate) =>
                !_recentlySelectedIds.contains(candidate.normalizedId),
          )
          .toList(growable: false);
      final _CountryCandidate selected =
          _drawWeighted(freshPool.isEmpty ? pool : freshPool);
      result.add(selected.country);
      selectedIds.add(selected.normalizedId);
      pool.removeWhere(
        (_CountryCandidate candidate) =>
            candidate.normalizedId == selected.normalizedId,
      );
      remainingCount--;
    }
  }

  _CountryCandidate _drawWeighted(List<_CountryCandidate> candidates) {
    if (candidates.length == 1) {
      return candidates.first;
    }
    final double totalWeight = candidates.fold<double>(
      0,
      (double total, _CountryCandidate candidate) => total + candidate.weight,
    );
    if (totalWeight <= 0) {
      return candidates[_random.nextInt(candidates.length)];
    }
    double cursor = _random.nextDouble() * totalWeight;
    for (final _CountryCandidate candidate in candidates) {
      cursor -= candidate.weight;
      if (cursor <= 0) {
        return candidate;
      }
    }
    return candidates.last;
  }

  bool _isPriority(
    CountryMastery mastery,
    DateTime now,
    GeoBrainTheme? theme,
  ) {
    if (_isNewForTheme(mastery, theme)) {
      return false;
    }
    if (_isDueForReview(mastery, now, theme)) {
      return true;
    }
    final GeoBrainMasteryStatus status = _statusAt(mastery, now, theme);
    return status == GeoBrainMasteryStatus.discovered ||
        status == GeoBrainMasteryStatus.fragile ||
        status == GeoBrainMasteryStatus.progressing;
  }

  bool _isMastered(
    CountryMastery mastery,
    DateTime now,
    GeoBrainTheme? theme,
  ) {
    return !_isNewForTheme(mastery, theme) &&
        _statusAt(mastery, now, theme) == GeoBrainMasteryStatus.mastered;
  }

  GeoBrainMasteryStatus _statusAt(
    CountryMastery mastery,
    DateTime now,
    GeoBrainTheme? theme,
  ) {
    if (theme == null) {
      return mastery.statusAt(now);
    }
    final ThemeMastery themeMastery = mastery.masteryForTheme(theme);
    return ThemeMastery.statusFor(
      score: mastery.retentionForTheme(theme, now).retainedScore,
      totalAttempts: themeMastery.totalAttempts,
    );
  }

  bool _isDueForReview(
    CountryMastery mastery,
    DateTime now,
    GeoBrainTheme? theme,
  ) {
    return theme == null
        ? mastery.needsReviewAt(now)
        : mastery.themeNeedsReviewAt(theme, now);
  }

  bool _isNewForTheme(CountryMastery mastery, GeoBrainTheme? theme) {
    return theme == null
        ? !mastery.hasBeenSeen
        : !mastery.masteryForTheme(theme).hasBeenSeen;
  }

  void _rememberSelection(List<GeoCountry> countries) {
    for (final GeoCountry country in countries) {
      final String id = _normalizeId(country.id);
      _recentlySelectedIds
        ..remove(id)
        ..add(id);
    }
    if (_recentlySelectedIds.length > _recentSelectionMemorySize) {
      _recentlySelectedIds.removeRange(
        0,
        _recentlySelectedIds.length - _recentSelectionMemorySize,
      );
    }
  }

  static String _normalizeId(String countryId) {
    return countryId.trim().toUpperCase();
  }
}

class _SelectionTargets {
  const _SelectionTargets({
    required this.newCountries,
    required this.priority,
    required this.mastered,
  });

  final int newCountries;
  final int priority;
  final int mastered;
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

  String get normalizedId => country.id.trim().toUpperCase();
}
