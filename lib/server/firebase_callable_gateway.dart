import '../admin/geopoint_admin_control.dart';
import '../challenges/challenge_definition.dart';
import '../challenges/challenge_official_session.dart';
import '../challenges/challenge_leaderboard.dart';
import '../challenges/challenge_ranking.dart';
import '../challenges/challenge_ranking_sync.dart';
import '../challenges/challenge_remote_pack.dart';
import '../challenges/challenge_reward_sync.dart';
import '../challenges/challenge_season_reward.dart';
import '../challenges/challenge_wallet.dart';
import '../monetization/ad_free_entitlement.dart';
import '../social/geopoint_friends.dart';
import 'geopoint_server_contract.dart';

abstract interface class GeoPointCallableTransport {
  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  );
}

class FirebaseCallableNames {
  const FirebaseCallableNames._();

  static const String serverStatus = 'getServerStatus';
  static const String registerPlayerIdentity = 'registerPlayerIdentity';
  static const String submitProfileMigration = 'submitProfileMigration';
  static const String profileMigrationStatus = 'getProfileMigrationStatus';
  static const String activeChallengePack = 'getActiveChallengePack';
  static const String startOfficialChallengeSession =
      'startOfficialChallengeSession';
  static const String submitRankedResults = 'submitRankedResults';
  static const String validateChallengeRewards = 'validateChallengeRewards';
  static const String challengeLeaderboards = 'getChallengeLeaderboards';
  static const String claimSeasonReward = 'claimSeasonReward';
  static const String friendDashboard = 'getFriendDashboard';
  static const String sendFriendRequest = 'sendFriendRequest';
  static const String updateFriendRelation = 'updateFriendRelation';
  static const String adminControlDashboard = 'getAdminControlDashboard';
  static const String adminUpdateRankedSubmission =
      'adminUpdateRankedSubmission';
  static const String adminUpdateCompetition = 'adminUpdateCompetition';
  static const String adminGrantAdFreeByFriendCode =
      'adminGrantAdFreeByFriendCode';
  static const String adminPublishChallengePack =
      'adminPublishChallengePack';
  static const String adFreeEntitlement = 'getAdFreeEntitlement';
  static const String verifyAdFreePurchase = 'verifyAdFreePurchase';
}

/// Adaptateur testable du protocole callable Firebase.
///
/// Le transport FlutterFire concret sera activé après la création du projet
/// Firebase et la génération de `firebase_options.dart`.
class FirebaseCallableGeoPointGateway
    implements
        GeoPointServerGateway,
        ChallengeRemoteGateway,
        ChallengeOfficialSessionGateway,
        ChallengeRankingGateway,
        ChallengeRewardValidationGateway,
        ChallengeLeaderboardGateway,
        ChallengeSeasonRewardGateway,
        GeoPointFriendGateway,
        GeoPointAdminGateway,
        AdFreeEntitlementGateway {
  const FirebaseCallableGeoPointGateway({required this.transport});

  final GeoPointCallableTransport transport;

  @override
  Future<GeoPointServerStatus> getStatus() async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.serverStatus,
      const <String, dynamic>{'apiVersion': 1},
    );
    return GeoPointServerStatus.fromJson(json);
  }

  @override
  Future<PlayerIdentityRegistrationResponse> registerPlayerIdentity(
    PlayerIdentityRegistrationRequest request,
  ) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.registerPlayerIdentity,
      request.toJson(),
    );
    return PlayerIdentityRegistrationResponse.fromJson(json);
  }

  @override
  Future<PlayerProfileMigrationResponse> submitProfileMigration(
    PlayerProfileMigrationRequest request,
  ) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.submitProfileMigration,
      request.toJson(),
    );
    return PlayerProfileMigrationResponse.fromJson(json);
  }

  @override
  Future<PlayerProfileMigrationStatusResponse>
      getProfileMigrationStatus() async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.profileMigrationStatus,
      const <String, dynamic>{'apiVersion': 1},
    );
    return PlayerProfileMigrationStatusResponse.fromJson(json);
  }

  @override
  Future<ChallengeRemotePackDocument?> fetchActivePack() async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.activeChallengePack,
      const <String, dynamic>{'apiVersion': 1},
    );
    final Object? rawPack = json['pack'];
    if (rawPack == null) {
      return null;
    }
    if (rawPack is! Map) {
      throw const FormatException('Pack Firebase invalide.');
    }
    final Map<String, dynamic> pack = rawPack.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
    final int? revision = pack['revision'] is num
        ? (pack['revision'] as num).toInt()
        : int.tryParse(pack['revision']?.toString() ?? '');
    final DateTime? publishedAt =
        DateTime.tryParse(pack['publishedAtUtc']?.toString() ?? '');
    final DateTime? serverNow =
        DateTime.tryParse(json['serverNowUtc']?.toString() ?? '');
    final String jsonSource = pack['jsonSource']?.toString() ?? '';
    if (revision == null ||
        revision <= 0 ||
        publishedAt == null ||
        serverNow == null ||
        jsonSource.trim().isEmpty) {
      throw const FormatException('Pack Firebase incomplet.');
    }
    return ChallengeRemotePackDocument(
      revision: revision,
      publishedAtUtc: publishedAt.toUtc(),
      serverNowUtc: serverNow.toUtc(),
      jsonSource: jsonSource,
    );
  }

  @override
  Future<ChallengeOfficialSession> startOfficialSession(
    ChallengeOfficialSessionRequest request,
  ) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.startOfficialChallengeSession,
      request.toJson(),
    );
    return ChallengeOfficialSession.fromJson(json);
  }

  @override
  Future<ChallengeRankingSyncResponse> submitRankedResults(
    List<ChallengeRankingSubmissionRequest> requests,
  ) async {
    if (requests.isEmpty) {
      throw ArgumentError.value(
        requests,
        'requests',
        'Au moins un résultat classé est requis.',
      );
    }
    final List<ChallengeRankingSubmissionResult> results =
        <ChallengeRankingSubmissionResult>[];
    DateTime? latestServerNow;
    for (int offset = 0; offset < requests.length; offset += 10) {
      final int proposedEnd = offset + 10;
      final int end = proposedEnd < requests.length
          ? proposedEnd
          : requests.length;
      final Map<String, dynamic> json = await transport.call(
        FirebaseCallableNames.submitRankedResults,
        <String, dynamic>{
          'apiVersion': 1,
          'submissions': requests
              .sublist(offset, end)
              .map(
                (ChallengeRankingSubmissionRequest request) =>
                    request.toJson(),
              )
              .toList(growable: false),
        },
      );
      final DateTime? serverNow =
          DateTime.tryParse(json['serverNowUtc']?.toString() ?? '');
      final Object? rawResults = json['results'];
      if (serverNow == null || rawResults is! List) {
        throw const FormatException('Réponse de classement Firebase invalide.');
      }
      latestServerNow = serverNow.toUtc();
      results.addAll(
        rawResults.map<ChallengeRankingSubmissionResult>(
          _rankingResultFromJson,
        ),
      );
    }
    return ChallengeRankingSyncResponse(
      serverNowUtc: latestServerNow!,
      results: List<ChallengeRankingSubmissionResult>.unmodifiable(results),
    );
  }

  @override
  Future<ChallengeRewardValidationResponse> validatePendingRewards(
    List<ChallengeRewardValidationRequest> requests,
  ) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.validateChallengeRewards,
      <String, dynamic>{
        'apiVersion': 1,
        'claims': requests
            .map((ChallengeRewardValidationRequest request) => request.toJson())
            .toList(growable: false),
      },
    );
    final DateTime? serverNow =
        DateTime.tryParse(json['serverNowUtc']?.toString() ?? '');
    final Object? rawResults = json['results'];
    final Object? rawWallet = json['wallet'];
    if (serverNow == null || rawResults is! List || rawWallet is! Map) {
      throw const FormatException(
        'Réponse du portefeuille Firebase invalide.',
      );
    }
    return ChallengeRewardValidationResponse(
      serverNowUtc: serverNow.toUtc(),
      results: rawResults
          .map<ChallengeRewardValidationResult>(_rewardResultFromJson)
          .toList(growable: false),
      authoritativeWallet: ChallengeWallet.fromJson(
        rawWallet.map<String, dynamic>(
          (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        ),
      ),
    );
  }

  @override
  Future<ChallengeLeaderboardSnapshot> fetchLeaderboards({
    required List<String> rankingGroupIds,
    required String seasonKey,
    ChallengeLeaderboardScope scope = ChallengeLeaderboardScope.global,
  }) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.challengeLeaderboards,
      <String, dynamic>{
        'apiVersion': 1,
        'rankingGroupIds': rankingGroupIds,
        'seasonKey': seasonKey,
        'scope': scope.id,
      },
    );
    return ChallengeLeaderboardSnapshot.fromJson(json);
  }

  @override
  Future<GeoPointFriendDashboard> fetchFriendDashboard() async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.friendDashboard,
      const <String, dynamic>{'apiVersion': 1},
    );
    return GeoPointFriendDashboard.fromJson(json);
  }

  @override
  Future<void> sendFriendRequest(String friendCode) async {
    await transport.call(
      FirebaseCallableNames.sendFriendRequest,
      <String, dynamic>{
        'apiVersion': 1,
        'friendCode': friendCode,
      },
    );
  }

  @override
  Future<void> updateFriendRelation({
    required GeoPointFriendRelationAction action,
    String? requestId,
    String? playerId,
  }) async {
    final bool usesRequest = action == GeoPointFriendRelationAction.accept ||
        action == GeoPointFriendRelationAction.decline ||
        action == GeoPointFriendRelationAction.cancel;
    if (usesRequest && (requestId == null || requestId.trim().isEmpty)) {
      throw ArgumentError.value(requestId, 'requestId');
    }
    if (!usesRequest && (playerId == null || playerId.trim().isEmpty)) {
      throw ArgumentError.value(playerId, 'playerId');
    }
    await transport.call(
      FirebaseCallableNames.updateFriendRelation,
      <String, dynamic>{
        'apiVersion': 1,
        'action': action.id,
        if (usesRequest) 'requestId': requestId,
        if (!usesRequest) 'playerId': playerId,
      },
    );
  }

  @override
  Future<ChallengeSeasonRewardResponse> claimSeasonReward(
    String seasonKey,
  ) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.claimSeasonReward,
      <String, dynamic>{
        'apiVersion': 1,
        'seasonKey': seasonKey,
      },
    );
    return ChallengeSeasonRewardResponse.fromJson(json);
  }

  @override
  Future<GeoPointAdminDashboard> fetchDashboard({String query = ''}) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.adminControlDashboard,
      <String, dynamic>{
        'apiVersion': 1,
        'query': query.trim(),
        'limit': 30,
      },
    );
    return GeoPointAdminDashboard.fromJson(json);
  }

  @override
  Future<void> updateSubmission({
    required String playerId,
    required String submissionId,
    required GeoPointAdminScoreAction action,
    required String reason,
  }) async {
    await transport.call(
      FirebaseCallableNames.adminUpdateRankedSubmission,
      <String, dynamic>{
        'apiVersion': 1,
        'playerId': playerId,
        'submissionId': submissionId,
        'action': action.id,
        'reason': reason,
      },
    );
  }

  @override
  Future<void> updateCompetition({
    required String rankingGroupId,
    required GeoPointAdminCompetitionAction action,
    required String reason,
  }) async {
    await transport.call(
      FirebaseCallableNames.adminUpdateCompetition,
      <String, dynamic>{
        'apiVersion': 1,
        'rankingGroupId': rankingGroupId,
        'action': action.id,
        'reason': reason,
      },
    );
  }

  @override
  Future<AdFreeEntitlement> fetchEntitlement() async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.adFreeEntitlement,
      const <String, dynamic>{'apiVersion': 1},
    );
    return AdFreeEntitlement.fromJson(json);
  }

  @override
  Future<String> grantAdFreeByFriendCode({
    required String friendCode,
    required String reason,
  }) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.adminGrantAdFreeByFriendCode,
      <String, dynamic>{
        'apiVersion': 1,
        'friendCode': friendCode,
        'reason': reason,
      },
    );
    final String displayName = json['displayName']?.toString().trim() ?? '';
    if (displayName.isEmpty) {
      throw const FormatException('Confirmation de cadeau invalide.');
    }
    return displayName;
  }

  @override
  Future<GeoPointAdminPublishedPack> publishChallengePack(
    String jsonSource,
  ) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.adminPublishChallengePack,
      <String, dynamic>{
        'apiVersion': 1,
        'jsonSource': jsonSource,
      },
    );
    return GeoPointAdminPublishedPack.fromJson(json);
  }

  @override
  Future<AdFreeEntitlement> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    final Map<String, dynamic> json = await transport.call(
      FirebaseCallableNames.verifyAdFreePurchase,
      <String, dynamic>{
        'apiVersion': 1,
        'platform': 'android',
        'productId': productId,
        'purchaseToken': purchaseToken,
      },
    );
    return AdFreeEntitlement.fromJson(json);
  }

  static ChallengeRankingSubmissionResult _rankingResultFromJson(
    Object? value,
  ) {
    if (value is! Map) {
      throw const FormatException('Résultat classé Firebase invalide.');
    }
    final Map<String, dynamic> json = value.map<String, dynamic>(
      (dynamic key, dynamic item) =>
          MapEntry<String, dynamic>(key.toString(), item),
    );
    final String submissionId = json['submissionId']?.toString().trim() ?? '';
    final ChallengeRankingServerDecision decision;
    switch (json['decision']?.toString()) {
      case 'confirmed':
        decision = ChallengeRankingServerDecision.confirmed;
      case 'quarantined':
        decision = ChallengeRankingServerDecision.quarantined;
      case 'rejected':
        decision = ChallengeRankingServerDecision.rejected;
      default:
        throw const FormatException('Décision de classement Firebase inconnue.');
    }
    if (submissionId.isEmpty) {
      throw const FormatException('Identifiant de résultat classé manquant.');
    }
    final Object? rawPosition = json['position'];
    ChallengeLeaderboardPosition? position;
    if (rawPosition != null) {
      if (rawPosition is! Map) {
        throw const FormatException('Position de classement Firebase invalide.');
      }
      position = ChallengeLeaderboardPosition.fromJson(
        rawPosition.map<String, dynamic>(
          (dynamic key, dynamic item) =>
              MapEntry<String, dynamic>(key.toString(), item),
        ),
      );
    }
    final String reason = json['reason']?.toString().trim() ?? '';
    return ChallengeRankingSubmissionResult(
      submissionId: submissionId,
      decision: decision,
      position: position,
      reason: reason.isEmpty ? null : reason,
    );
  }

  static ChallengeRewardValidationResult _rewardResultFromJson(
    Object? value,
  ) {
    if (value is! Map) {
      throw const FormatException('Validation de récompense invalide.');
    }
    final Map<String, dynamic> json = value.map<String, dynamic>(
      (dynamic key, dynamic item) =>
          MapEntry<String, dynamic>(key.toString(), item),
    );
    final String claimId = json['claimId']?.toString().trim() ?? '';
    final ChallengeRewardValidationDecision decision;
    switch (json['decision']?.toString()) {
      case 'confirmed':
        decision = ChallengeRewardValidationDecision.confirmed;
      case 'pending':
        decision = ChallengeRewardValidationDecision.pending;
      case 'rejected':
        decision = ChallengeRewardValidationDecision.rejected;
      default:
        throw const FormatException('Décision de récompense inconnue.');
    }
    if (claimId.isEmpty) {
      throw const FormatException('Identifiant de récompense manquant.');
    }
    final Object? rawReward = json['confirmedReward'];
    final ChallengeReward? reward = rawReward == null
        ? null
        : rawReward is Map
            ? ChallengeReward.fromJson(
                rawReward.map<String, dynamic>(
                  (dynamic key, dynamic item) =>
                      MapEntry<String, dynamic>(key.toString(), item),
                ),
              )
            : throw const FormatException('Montant de récompense invalide.');
    final String reason = json['rejectionReason']?.toString().trim() ?? '';
    return ChallengeRewardValidationResult(
      claimId: claimId,
      decision: decision,
      confirmedReward: reward,
      rejectionReason: reason.isEmpty ? null : reason,
    );
  }
}
