import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/geo_engine/geo_country.dart';
import 'package:geopoint/geobrain/country_mastery.dart';
import 'package:geopoint/geobrain/country_selector.dart';
import 'package:geopoint/geobrain/geobrain_attempt.dart';
import 'package:geopoint/geobrain/geobrain_profile.dart';
import 'package:geopoint/geobrain/geobrain_review_scheduler.dart';
import 'package:geopoint/geobrain/geobrain_service.dart';
import 'package:geopoint/geobrain/geobrain_storage.dart';
import 'package:geopoint/geobrain/geobrain_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime start = DateTime.utc(2026, 8, 30, 12);

  GeoBrainAttempt attempt({
    required String countryId,
    required GeoBrainTheme theme,
    required DateTime answeredAt,
    bool isCorrect = true,
    String? helpId,
    GeoBrainAttemptContext context = GeoBrainAttemptContext.classicGame,
  }) {
    return GeoBrainAttempt(
      countryId: countryId,
      theme: theme,
      answeredAt: answeredAt,
      modeId: theme.id,
      difficultyId: 'intermediate',
      isCorrect: isCorrect,
      helpId: helpId,
      context: context,
    );
  }

  test('un premier apprentissage programme une révision le lendemain', () {
    final GeoBrainReviewSchedule schedule =
        const GeoBrainReviewScheduler().schedule(
      attempt: attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: start,
      ),
      previousSuccessfulReviewCount: 0,
      previousNextReviewAt: null,
    );

    expect(schedule.successfulReviewCount, 1);
    expect(schedule.nextReviewAt, start.add(const Duration(days: 1)));
    expect(schedule.isConfirmedSuccess, isTrue);
  });

  test('les réussites confirmées espacent progressivement les révisions', () {
    const GeoBrainReviewScheduler scheduler = GeoBrainReviewScheduler();
    expect(
      <int>[
        for (int count = 1; count <= 7; count++)
          GeoBrainReviewScheduler
              .intervalForSuccessfulReviewCount(count)
              .inDays,
      ],
      <int>[1, 3, 7, 14, 30, 60, 120],
    );
    final GeoBrainReviewSchedule first = scheduler.schedule(
      attempt: attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: start,
      ),
      previousSuccessfulReviewCount: 0,
      previousNextReviewAt: null,
    );
    final GeoBrainReviewSchedule second = scheduler.schedule(
      attempt: attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: first.nextReviewAt,
      ),
      previousSuccessfulReviewCount: first.successfulReviewCount,
      previousNextReviewAt: first.nextReviewAt,
    );
    final GeoBrainReviewSchedule third = scheduler.schedule(
      attempt: attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: second.nextReviewAt,
      ),
      previousSuccessfulReviewCount: second.successfulReviewCount,
      previousNextReviewAt: second.nextReviewAt,
    );

    expect(second.successfulReviewCount, 2);
    expect(second.interval, const Duration(days: 3));
    expect(third.successfulReviewCount, 3);
    expect(third.interval, const Duration(days: 7));
  });

  test('une réponse anticipée ne repousse pas la révision prévue', () {
    final DateTime scheduledAt = start.add(const Duration(days: 1));
    final GeoBrainReviewSchedule schedule =
        const GeoBrainReviewScheduler().schedule(
      attempt: attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: start.add(const Duration(hours: 1)),
      ),
      previousSuccessfulReviewCount: 1,
      previousNextReviewAt: scheduledAt,
    );

    expect(schedule.successfulReviewCount, 1);
    expect(schedule.nextReviewAt, scheduledAt);
  });

  test('une erreur rapproche la révision et réduit deux paliers', () {
    final GeoBrainReviewSchedule schedule =
        const GeoBrainReviewScheduler().schedule(
      attempt: attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: start,
        isCorrect: false,
      ),
      previousSuccessfulReviewCount: 5,
      previousNextReviewAt: start,
    );

    expect(schedule.successfulReviewCount, 3);
    expect(schedule.interval, const Duration(hours: 6));
    expect(schedule.nextReviewAt, start.add(const Duration(hours: 6)));
  });

  test('une réussite très assistée ne confirme pas un nouveau palier', () {
    final GeoBrainReviewSchedule schedule =
        const GeoBrainReviewScheduler().schedule(
      attempt: attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: start,
        helpId: 'guided_target',
        context: GeoBrainAttemptContext.tutorial,
      ),
      previousSuccessfulReviewCount: 3,
      previousNextReviewAt: start,
    );

    expect(schedule.successfulReviewCount, 3);
    expect(schedule.interval, const Duration(days: 1));
    expect(schedule.isConfirmedSuccess, isFalse);
  });

  test('chaque thème conserve son propre calendrier de révision', () {
    CountryMastery mastery = CountryMastery.initial('FRA');
    mastery = mastery.registerAttempt(
      attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: start,
      ),
    );
    mastery = mastery.registerAttempt(
      attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.flag,
        answeredAt: start.add(const Duration(hours: 1)),
      ),
    );
    mastery = mastery.registerAttempt(
      attempt(
        countryId: 'FRA',
        theme: GeoBrainTheme.location,
        answeredAt: start.add(const Duration(days: 1)),
      ),
    );

    final DateTime flagReview = start.add(const Duration(days: 1, hours: 1));
    expect(
      mastery.masteryForTheme(GeoBrainTheme.location).successfulReviewCount,
      2,
    );
    expect(
      mastery.masteryForTheme(GeoBrainTheme.location).nextReviewAt,
      start.add(const Duration(days: 4)),
    );
    expect(mastery.themeNeedsReviewAt(GeoBrainTheme.flag, flagReview), isTrue);
    expect(
      mastery.themeNeedsReviewAt(GeoBrainTheme.location, flagReview),
      isFalse,
    );
    expect(mastery.nextReviewAt, flagReview);
  });

  test('une partie mélange les nouveautés et limite les révisions prioritaires',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final Set<String> reviewIds = <String>{'AAA', 'BBB', 'CCC', 'DDD'};
    final Map<String, CountryMastery> learned = <String, CountryMastery>{};
    for (final String countryId in reviewIds) {
      learned[countryId] = CountryMastery.initial(countryId).registerAttempt(
        attempt(
          countryId: countryId,
          theme: GeoBrainTheme.location,
          answeredAt: start,
        ),
      );
    }
    final GeoBrainProfile profile = GeoBrainProfile(
      schemaVersion: GeoBrainProfile.currentSchemaVersion,
      countries: learned,
      createdAt: start,
      updatedAt: start,
    );
    expect(await GeoBrainStorage.save(profile), isTrue);
    final GeoBrainService service = await GeoBrainService.create();
    final List<GeoCountry> countries = <String>[
      ...reviewIds,
      'EEE',
      'FFF',
      'GGG',
      'HHH',
      'III',
      'JJJ',
      'KKK',
      'LLL',
      'MMM',
      'NNN',
    ].map<GeoCountry>((String id) {
      return GeoCountry(
        id: id,
        isoA2: 'FR',
        name: id,
        continent: 'Test',
        polygons: const [],
      );
    }).toList(growable: false);
    final List<GeoCountry> selected = CountrySelector(
      geoBrain: service,
      random: Random(7),
    ).selectCountries(
      availableCountries: countries,
      questionCount: 8,
      theme: GeoBrainTheme.location,
      now: start.add(const Duration(days: 2)),
    );
    final int selectedReviews = selected
        .where((GeoCountry country) => reviewIds.contains(country.id))
        .length;

    expect(selected, hasLength(8));
    expect(selectedReviews, 2);
    expect(selected.length - selectedReviews, 6);

    final List<GeoCountry> longSession = CountrySelector(
      geoBrain: service,
      random: Random(9),
    ).selectCountries(
      availableCountries: countries,
      questionCount: 10,
      theme: GeoBrainTheme.location,
      now: start.add(const Duration(days: 2)),
    );
    expect(longSession, hasLength(10));
    expect(
      longSession
          .where((GeoCountry country) => reviewIds.contains(country.id))
          .length,
      3,
    );

    final List<GeoCountry> shortSession = CountrySelector(
      geoBrain: service,
      random: Random(8),
    ).selectCountries(
      availableCountries: countries,
      questionCount: 2,
      theme: GeoBrainTheme.location,
      now: start.add(const Duration(days: 2)),
    );
    expect(shortSession, hasLength(2));
  });
}
