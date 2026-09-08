import '../geo_engine/geo_country.dart';
import 'country_mastery.dart';
import 'geobrain_attempt.dart';
import 'geobrain_profile.dart';
import 'geobrain_theme.dart';
import 'theme_mastery.dart';

enum GeoBrainSuggestionType {
  regionalReview,
  thematicReview,
  recentConfirmation,
  discovery,
}

class GeoBrainTrainingSuggestion {
  const GeoBrainTrainingSuggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.reason,
    required this.modeId,
    required this.regionId,
    required this.questionCount,
    required this.countryIds,
    required this.reviewDifficultiesOnly,
    required this.priority,
  });

  final String id;
  final GeoBrainSuggestionType type;
  final String title;
  final String reason;
  final String modeId;
  final String regionId;
  final int questionCount;
  final Set<String> countryIds;
  final bool reviewDifficultiesOnly;
  final int priority;
}

class GeoBrainTrainingSuggestionEngine {
  const GeoBrainTrainingSuggestionEngine();

  static const Set<String> _balkanCountryIds = <String>{
    'ALB',
    'BIH',
    'BGR',
    'HRV',
    'GRC',
    'MNE',
    'MKD',
    'ROU',
    'SRB',
    'SVN',
  };

  static const List<String> _oceaniaDiscoveryOrder = <String>[
    'AUS',
    'NZL',
    'PNG',
    'FJI',
    'SLB',
    'VUT',
    'WSM',
    'TON',
  ];

  List<GeoBrainTrainingSuggestion> build({
    required GeoBrainProfile profile,
    required List<GeoCountry> countries,
    required DateTime now,
    Set<String> ignoredSuggestionIds = const <String>{},
    int maximumSuggestions = 3,
  }) {
    if (maximumSuggestions <= 0 || countries.isEmpty) {
      return const <GeoBrainTrainingSuggestion>[];
    }

    final Map<String, GeoCountry> countriesById = <String, GeoCountry>{
      for (final GeoCountry country in countries)
        _normalizeId(country.id): country,
    };
    final List<GeoBrainTrainingSuggestion> candidates =
        <GeoBrainTrainingSuggestion>[];

    final Set<String> weakBalkans = _balkanCountryIds
        .where(
          (String id) =>
              countriesById.containsKey(id) &&
              _needsReviewAcrossCoreThemes(profile.masteryFor(id), now),
        )
        .toSet();
    if (weakBalkans.length >= 2) {
      candidates.add(
        GeoBrainTrainingSuggestion(
          id: 'review_balkans',
          type: GeoBrainSuggestionType.regionalReview,
          title: 'Réviser les Balkans',
          reason:
              '${weakBalkans.length} pays de la zone sont fragiles ou arrivés à révision.',
          modeId: 'mixed',
          regionId: 'europe',
          questionCount: weakBalkans.length.clamp(2, 10),
          countryIds: Set<String>.unmodifiable(weakBalkans),
          reviewDifficultiesOnly: true,
          priority: 100 + weakBalkans.length,
        ),
      );
    }

    final Set<String> weakAfricanFlags = countries
        .where((GeoCountry country) => _isContinent(country, 'africa'))
        .map<String>((GeoCountry country) => _normalizeId(country.id))
        .where(
          (String id) => _needsReviewForTheme(
            profile.masteryFor(id),
            GeoBrainTheme.flag,
            now,
          ),
        )
        .toSet();
    if (weakAfricanFlags.length >= 2) {
      candidates.add(
        GeoBrainTrainingSuggestion(
          id: 'review_africa_flags',
          type: GeoBrainSuggestionType.thematicReview,
          title: 'Retravailler les drapeaux d’Afrique',
          reason:
              '${weakAfricanFlags.length} drapeaux africains demandent une nouvelle vérification.',
          modeId: 'find_flag',
          regionId: 'africa',
          questionCount: weakAfricanFlags.length.clamp(2, 10),
          countryIds: Set<String>.unmodifiable(weakAfricanFlags),
          reviewDifficultiesOnly: true,
          priority: 95 + weakAfricanFlags.length,
        ),
      );
    }

    final DateTime weekStart = now.subtract(const Duration(days: 7));
    final Set<String> recentCapitalIds = profile.attemptHistory
        .where(
          (GeoBrainAttempt attempt) =>
              attempt.theme == GeoBrainTheme.capital &&
              attempt.isCorrect &&
              !attempt.answeredAt.isBefore(weekStart) &&
              !attempt.answeredAt.isAfter(now) &&
              countriesById.containsKey(attempt.countryId),
        )
        .map<String>((GeoBrainAttempt attempt) => attempt.countryId)
        .toSet();
    if (recentCapitalIds.length >= 2) {
      candidates.add(
        GeoBrainTrainingSuggestion(
          id: 'confirm_recent_capitals',
          type: GeoBrainSuggestionType.recentConfirmation,
          title: 'Confirmer les capitales apprises cette semaine',
          reason:
              '${recentCapitalIds.length} capitales récentes peuvent maintenant être confirmées.',
          modeId: 'find_capital',
          regionId: 'world',
          questionCount: recentCapitalIds.length.clamp(2, 10),
          countryIds: Set<String>.unmodifiable(recentCapitalIds),
          reviewDifficultiesOnly: false,
          priority: 85 + recentCapitalIds.length,
        ),
      );
    }

    final List<String> newOceaniaIds = _oceaniaDiscoveryOrder
        .where(
          (String id) =>
              countriesById.containsKey(id) &&
              !profile.masteryFor(id).masteryForTheme(GeoBrainTheme.location).hasBeenSeen,
        )
        .take(5)
        .toList(growable: false);
    if (newOceaniaIds.length == 5) {
      candidates.add(
        GeoBrainTrainingSuggestion(
          id: 'discover_oceania_five',
          type: GeoBrainSuggestionType.discovery,
          title: 'Découvrir cinq nouveaux pays d’Océanie',
          reason:
              'Ces cinq pays sont encore inconnus et élargiront progressivement ton atlas.',
          modeId: 'find_country',
          regionId: 'oceania',
          questionCount: 5,
          countryIds: Set<String>.unmodifiable(newOceaniaIds),
          reviewDifficultiesOnly: false,
          priority: 60,
        ),
      );
    }

    if (candidates.isEmpty) {
      final List<CountryMastery> due = profile.countriesDueForReviewAt(now)
          .where(
            (CountryMastery mastery) =>
                countriesById.containsKey(mastery.countryId),
          )
          .take(10)
          .toList(growable: false);
      if (due.isNotEmpty) {
        final Set<String> ids = due
            .map<String>((CountryMastery mastery) => mastery.countryId)
            .toSet();
        candidates.add(
          GeoBrainTrainingSuggestion(
            id: 'review_priorities',
            type: GeoBrainSuggestionType.thematicReview,
            title: 'Revoir mes priorités',
            reason:
                '${ids.length} connaissances sont arrivées au bon moment pour une révision.',
            modeId: 'mixed',
            regionId: 'world',
            questionCount: ids.length.clamp(1, 10),
            countryIds: Set<String>.unmodifiable(ids),
            reviewDifficultiesOnly: true,
            priority: 70,
          ),
        );
      }
    }

    final Set<String> normalizedIgnored = ignoredSuggestionIds
        .map<String>((String id) => id.trim().toLowerCase())
        .toSet();
    final List<GeoBrainTrainingSuggestion> result = candidates
        .where(
          (GeoBrainTrainingSuggestion suggestion) =>
              !normalizedIgnored.contains(suggestion.id.toLowerCase()),
        )
        .toList()
      ..sort(
        (GeoBrainTrainingSuggestion first,
                GeoBrainTrainingSuggestion second) =>
            second.priority.compareTo(first.priority),
      );
    return List<GeoBrainTrainingSuggestion>.unmodifiable(
      result.take(maximumSuggestions),
    );
  }

  bool _needsReviewAcrossCoreThemes(CountryMastery mastery, DateTime now) {
    return const <GeoBrainTheme>[
      GeoBrainTheme.location,
      GeoBrainTheme.capital,
      GeoBrainTheme.flag,
    ].any(
      (GeoBrainTheme theme) => _needsReviewForTheme(mastery, theme, now),
    );
  }

  bool _needsReviewForTheme(
    CountryMastery mastery,
    GeoBrainTheme theme,
    DateTime now,
  ) {
    final ThemeMastery value = mastery.masteryForTheme(theme);
    if (!value.hasBeenSeen) {
      return false;
    }
    if (mastery.themeNeedsReviewAt(theme, now)) {
      return true;
    }
    final GeoBrainMasteryStatus status = ThemeMastery.statusFor(
      score: mastery.retentionForTheme(theme, now).retainedScore,
      totalAttempts: value.totalAttempts,
    );
    return status == GeoBrainMasteryStatus.discovered ||
        status == GeoBrainMasteryStatus.fragile ||
        status == GeoBrainMasteryStatus.progressing;
  }

  bool _isContinent(GeoCountry country, String continent) {
    return country.continent.trim().toLowerCase().contains(continent);
  }

  String _normalizeId(String id) => id.trim().toUpperCase();
}
