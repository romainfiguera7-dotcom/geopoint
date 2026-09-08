import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/challenges/challenge_leaderboard.dart';

void main() {
  test('décode les classements et retrouve la position du joueur', () {
    final ChallengeLeaderboardSnapshot snapshot =
        ChallengeLeaderboardSnapshot.fromJson(
      <String, dynamic>{
        'serverNowUtc': '2026-09-06T12:00:00.000Z',
        'scope': 'friends',
        'currentPlayerHistory': <Map<String, dynamic>>[
          <String, dynamic>{
            'submissionId': 'ranking:daily:attempt:2',
            'challengeId': 'daily_2026_09_06',
            'challengeTitle': 'Mix mondial',
            'completedAtUtc': '2026-09-06T11:45:00.000Z',
            'score': 580,
            'correctAnswers': 5,
            'elapsedSeconds': 76,
            'status': 'validated',
            'isBest': true,
            'reason': null,
          },
        ],
        'boards': <Map<String, dynamic>>[
          <String, dynamic>{
            'boardId': 'daily_2026_09_06',
            'type': 'daily',
            'title': 'Mix mondial',
            'seasonKey': '2026-09',
            'totalParticipants': 2,
            'entries': <Map<String, dynamic>>[
              <String, dynamic>{
                'rank': 1,
                'displayName': 'Explorateur 0001',
                'avatarId': 'default',
                'score': 620,
                'correctAnswers': 6,
                'averageDistanceKilometers': 120.5,
                'elapsedSeconds': 71,
                'challengeCount': 1,
                'isCurrentPlayer': false,
              },
              <String, dynamic>{
                'rank': 2,
                'displayName': 'Explorateur 0002',
                'avatarId': 'default',
                'score': 580,
                'correctAnswers': 5,
                'averageDistanceKilometers': 160,
                'elapsedSeconds': 76,
                'challengeCount': 1,
                'isCurrentPlayer': true,
              },
            ],
            'currentPlayerEntry': null,
          },
        ],
      },
    );

    final ChallengeLeaderboardBoard? board =
        snapshot.boardFor(ChallengeLeaderboardKind.daily);
    expect(board, isNotNull);
    expect(board!.entries, hasLength(2));
    expect(board.visibleCurrentPlayerEntry?.rank, 2);
    expect(board.totalParticipants, 2);
    expect(snapshot.scope, ChallengeLeaderboardScope.friends);
    expect(snapshot.currentPlayerHistory, hasLength(1));
    expect(snapshot.currentPlayerHistory.single.isBest, isTrue);
    expect(
      snapshot.currentPlayerHistory.single.status,
      ChallengeRankingHistoryStatus.validated,
    );
  });

  test('conserve la position personnelle hors du top 25', () {
    final ChallengeLeaderboardBoard board =
        ChallengeLeaderboardBoard.fromJson(
      <String, dynamic>{
        'boardId': 'season_2026_09',
        'type': 'season',
        'title': 'Saison 2026-09',
        'seasonKey': '2026-09',
        'totalParticipants': 80,
        'entries': <Map<String, dynamic>>[],
        'currentPlayerEntry': <String, dynamic>{
          'rank': null,
          'displayName': 'Explorateur TEST',
          'avatarId': 'default',
          'score': 100,
          'correctAnswers': 1,
          'averageDistanceKilometers': 200,
          'elapsedSeconds': 20,
          'challengeCount': 2,
          'isCurrentPlayer': true,
        },
      },
    );

    expect(board.visibleCurrentPlayerEntry?.rank, isNull);
    expect(board.visibleCurrentPlayerEntry?.challengeCount, 2);
  });

  test('décode une tentative refusée avec sa raison', () {
    final ChallengeRankingHistoryEntry entry =
        ChallengeRankingHistoryEntry.fromJson(
      <String, dynamic>{
        'submissionId': 'ranking:weekly:attempt:1',
        'challengeId': 'weekly_01',
        'challengeTitle': 'Tour d’Europe',
        'completedAtUtc': '2026-09-06T12:00:00.000Z',
        'score': 400,
        'correctAnswers': 4,
        'elapsedSeconds': 80,
        'status': 'rejected',
        'isBest': false,
        'reason': 'Session officielle expirée.',
      },
    );

    expect(entry.status, ChallengeRankingHistoryStatus.rejected);
    expect(entry.reason, contains('expirée'));
  });
}
