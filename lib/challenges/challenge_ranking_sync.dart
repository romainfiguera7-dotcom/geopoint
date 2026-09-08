import '../player/player_online_identity.dart';
import 'challenge_clock.dart';
import 'challenge_player_state.dart';
import 'challenge_ranking.dart';
import 'challenge_result.dart';
import 'challenge_storage.dart';

class ChallengeRankingSubmissionRequest {
  const ChallengeRankingSubmissionRequest({
    required this.playerId,
    required this.submission,
  });

  final String playerId;
  final ChallengeRankingSubmission submission;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'playerId': playerId,
      'submissionId': submission.submissionId,
      'challengeId': submission.challengeId,
      'rankingGroupId': submission.rankingGroupId,
      'attemptNumber': submission.attemptNumber,
      'competitiveSignature': submission.competitiveSignature,
      if (submission.officialSessionId != null)
        'officialSessionId': submission.officialSessionId,
      'completedAtUtc': submission.completedAtUtc.toUtc().toIso8601String(),
      'score': submission.score,
      'correctAnswers': submission.correctAnswers,
      'averageDistanceKilometers':
          submission.averageDistanceKilometers,
      'elapsedSeconds': submission.elapsedSeconds,
      'answerEvidence': submission.answerEvidence
          .map((ChallengeAnswerEvidence item) => item.toJson())
          .toList(growable: false),
    };
  }
}

enum ChallengeRankingServerDecision {
  confirmed,
  quarantined,
  rejected,
}

class ChallengeRankingSubmissionResult {
  const ChallengeRankingSubmissionResult({
    required this.submissionId,
    required this.decision,
    this.position,
    this.reason,
  });

  final String submissionId;
  final ChallengeRankingServerDecision decision;
  final ChallengeLeaderboardPosition? position;
  final String? reason;
}

class ChallengeRankingSyncResponse {
  const ChallengeRankingSyncResponse({
    required this.serverNowUtc,
    required this.results,
  });

  final DateTime serverNowUtc;
  final List<ChallengeRankingSubmissionResult> results;
}

abstract interface class ChallengeRankingGateway {
  Future<ChallengeRankingSyncResponse> submitRankedResults(
    List<ChallengeRankingSubmissionRequest> requests,
  );
}

enum ChallengeRankingSyncStatus {
  upToDate,
  synchronized,
  pendingConnection,
  pendingPlayerIdentity,
  serverUnavailable,
  invalidServerResponse,
  storageFailure,
}

class ChallengeRankingSyncReport {
  const ChallengeRankingSyncReport({
    required this.status,
    required this.playerState,
    required this.clock,
    required this.pendingBefore,
    required this.pendingAfter,
    this.confirmedCount = 0,
    this.quarantinedCount = 0,
    this.rejectedCount = 0,
    this.failureReason,
  });

  final ChallengeRankingSyncStatus status;
  final ChallengePlayerState playerState;
  final ChallengeClockEvaluation clock;
  final int pendingBefore;
  final int pendingAfter;
  final int confirmedCount;
  final int quarantinedCount;
  final int rejectedCount;
  final String? failureReason;
}

class ChallengeRankingSyncService {
  const ChallengeRankingSyncService._();

  static Future<ChallengeRankingSyncReport> synchronize({
    required ChallengePlayerState playerState,
    required ChallengeClockEvaluation clock,
    required DateTime deviceNow,
    ChallengeRankingGateway? gateway,
    PlayerOnlineIdentity? playerIdentity,
  }) async {
    final List<ChallengeRankingSubmission> pending =
        playerState.rankingLedger.pendingSubmissions;
    if (pending.isEmpty) {
      return ChallengeRankingSyncReport(
        status: ChallengeRankingSyncStatus.upToDate,
        playerState: playerState,
        clock: clock,
        pendingBefore: 0,
        pendingAfter: 0,
      );
    }
    if (gateway == null) {
      return ChallengeRankingSyncReport(
        status: ChallengeRankingSyncStatus.pendingConnection,
        playerState: playerState,
        clock: clock,
        pendingBefore: pending.length,
        pendingAfter: pending.length,
      );
    }
    // Une migration en attente possède déjà l'UID Firebase authentifié. Elle
    // peut donc publier une nouvelle tentative recalculée sans attendre la
    // reprise complète de l'ancienne progression locale.
    final String? rankingPlayerId = playerIdentity?.onlinePlayerId;
    if (rankingPlayerId == null) {
      return ChallengeRankingSyncReport(
        status: ChallengeRankingSyncStatus.pendingPlayerIdentity,
        playerState: playerState,
        clock: clock,
        pendingBefore: pending.length,
        pendingAfter: pending.length,
        failureReason:
            'Le profil doit être relié à un compte avant l’envoi du classement.',
      );
    }

    final List<ChallengeRankingSubmissionRequest> requests = pending
        .map(
          (ChallengeRankingSubmission item) =>
              ChallengeRankingSubmissionRequest(
            playerId: rankingPlayerId,
            submission: item,
          ),
        )
        .toList(growable: false);
    final ChallengeRankingSyncResponse response;
    try {
      response = await gateway.submitRankedResults(requests);
      _validateResponse(response, pending);
    } catch (error) {
      return ChallengeRankingSyncReport(
        status: error is FormatException
            ? ChallengeRankingSyncStatus.invalidServerResponse
            : ChallengeRankingSyncStatus.serverUnavailable,
        playerState: playerState,
        clock: clock,
        pendingBefore: pending.length,
        pendingAfter: pending.length,
        failureReason: error.toString(),
      );
    }

    ChallengeRankingLedger ledger = playerState.rankingLedger;
    int confirmedCount = 0;
    int quarantinedCount = 0;
    int rejectedCount = 0;
    for (final ChallengeRankingSubmissionResult result in response.results) {
      switch (result.decision) {
        case ChallengeRankingServerDecision.confirmed:
          ledger = ledger.confirm(result.submissionId, result.position);
          confirmedCount += 1;
        case ChallengeRankingServerDecision.quarantined:
          ledger = ledger.quarantine(
            result.submissionId,
            reason: result.reason,
          );
          quarantinedCount += 1;
        case ChallengeRankingServerDecision.rejected:
          ledger = ledger.reject(
            result.submissionId,
            reason: result.reason,
          );
          rejectedCount += 1;
      }
    }

    final ChallengeClockEvaluation serverClock = ChallengeClock.evaluate(
      deviceNow: deviceNow,
      serverNow: response.serverNowUtc,
      previousState: playerState.clockState,
    );
    final ChallengePlayerState updated = playerState.copyWith(
      rankingLedger: ledger,
      clockState: serverClock.updatedState,
    );
    final bool saved = await ChallengeStorage.save(updated);
    if (!saved) {
      return ChallengeRankingSyncReport(
        status: ChallengeRankingSyncStatus.storageFailure,
        playerState: playerState,
        clock: clock,
        pendingBefore: pending.length,
        pendingAfter: pending.length,
        failureReason: 'Le classement validé n’a pas pu être sauvegardé.',
      );
    }
    return ChallengeRankingSyncReport(
      status: ChallengeRankingSyncStatus.synchronized,
      playerState: updated,
      clock: serverClock,
      pendingBefore: pending.length,
      pendingAfter: updated.rankingLedger.pendingSubmissions.length,
      confirmedCount: confirmedCount,
      quarantinedCount: quarantinedCount,
      rejectedCount: rejectedCount,
    );
  }

  static void _validateResponse(
    ChallengeRankingSyncResponse response,
    List<ChallengeRankingSubmission> pending,
  ) {
    final Map<String, ChallengeRankingSubmission> expected =
        <String, ChallengeRankingSubmission>{
      for (final ChallengeRankingSubmission item in pending)
        item.submissionId: item,
    };
    final Set<String> received = <String>{};
    for (final ChallengeRankingSubmissionResult result in response.results) {
      final String submissionId = result.submissionId.trim();
      final ChallengeRankingSubmission? submission = expected[submissionId];
      if (submission == null) {
        throw FormatException(
          'Le serveur a répondu pour un résultat classé inconnu : '
          '$submissionId.',
        );
      }
      if (!received.add(submissionId)) {
        throw FormatException(
          'Le serveur a répondu deux fois pour le résultat $submissionId.',
        );
      }
      if (result.decision == ChallengeRankingServerDecision.confirmed) {
        final ChallengeLeaderboardPosition? position = result.position;
        final int? previousRank = position?.previousRank;
        if (position != null &&
            (position.rank <= 0 ||
            position.totalParticipants < position.rank ||
            position.score != submission.score ||
            (previousRank != null && previousRank <= 0))) {
          throw FormatException(
            'La position renvoyée pour $submissionId est incohérente.',
          );
        }
      } else if (result.position != null) {
        throw FormatException(
          'Le serveur a fourni une position pour un résultat non confirmé.',
        );
      }
    }
    if (received.length != expected.length) {
      throw const FormatException(
        'La réponse du serveur ne couvre pas tous les résultats classés.',
      );
    }
  }
}
