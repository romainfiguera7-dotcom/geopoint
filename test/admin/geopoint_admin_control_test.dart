import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/admin/geopoint_admin_control.dart';

void main() {
  test('décode le tableau de contrôle interne', () {
    final GeoPointAdminDashboard dashboard =
        GeoPointAdminDashboard.fromJson(<String, dynamic>{
      'apiVersion': 1,
      'serverNowUtc': '2026-09-07T12:00:00.000Z',
      'counters': <String, dynamic>{
        'pendingReviews': 2,
        'rejectedSubmissions': 4,
        'activeSessions': 3,
      },
      'player': null,
      'competition': null,
      'submissions': <Map<String, dynamic>>[
        <String, dynamic>{
          'playerId': 'uid_player',
          'submissionId': 'ranking:daily:1',
          'challengeId': 'daily_01',
          'rankingGroupId': 'daily_01',
          'status': 'quarantined',
          'score': 850,
          'correctAnswers': 8,
          'averageDistanceKilometers': 12.5,
          'elapsedSeconds': 42,
        },
      ],
      'auditLogs': <Map<String, dynamic>>[],
    });

    expect(dashboard.counters.pendingReviews, 2);
    expect(dashboard.submissions.single.score, 850);
    expect(
      dashboard.submissions.single.availableActions,
      contains(GeoPointAdminScoreAction.approveQuarantine),
    );
  });

  test('propose uniquement les transitions autorisées', () {
    GeoPointAdminSubmission fixture(String status, {String? reason}) =>
        GeoPointAdminSubmission(
          playerId: 'uid',
          submissionId: 'submission',
          challengeId: 'daily',
          rankingGroupId: 'daily',
          status: status,
          score: 100,
          correctAnswers: 1,
          averageDistanceKilometers: 10,
          elapsedSeconds: 5,
          reason: reason,
        );

    expect(fixture('validated').availableActions,
        <GeoPointAdminScoreAction>[GeoPointAdminScoreAction.invalidate]);
    expect(fixture('invalidated_manual').availableActions,
        <GeoPointAdminScoreAction>[GeoPointAdminScoreAction.restore]);
    expect(fixture('rejected').availableActions, isEmpty);
    expect(
      fixture(
        'rejected',
        reason: 'La session officielle a expiré.',
      ).availableActions,
      <GeoPointAdminScoreAction>[
        GeoPointAdminScoreAction.restoreExpired,
      ],
    );
  });
}
