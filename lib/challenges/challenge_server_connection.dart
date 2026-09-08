import '../admin/geopoint_admin_control.dart';
import '../monetization/ad_free_entitlement.dart';
import '../server/geopoint_server_contract.dart';
import '../social/geopoint_friends.dart';
import 'challenge_leaderboard.dart';
import 'challenge_official_session.dart';
import 'challenge_remote_pack.dart';
import 'challenge_ranking_sync.dart';
import 'challenge_reward_sync.dart';
import 'challenge_season_reward.dart';

/// Point de branchement unique du futur fournisseur distant.
///
/// L’application peut ainsi recevoir une implémentation Firebase, Supabase ou
/// serveur personnel sans modifier le moteur de défis ni ses écrans.
class ChallengeServerConnection {
  ChallengeServerConnection._();

  static ChallengeRemoteGateway? packGateway;
  static ChallengeRewardValidationGateway? rewardValidationGateway;
  static ChallengeRankingGateway? rankingGateway;
  static ChallengeLeaderboardGateway? leaderboardGateway;
  static ChallengeSeasonRewardGateway? seasonRewardGateway;
  static GeoPointFriendGateway? friendGateway;
  static GeoPointServerGateway? coreGateway;
  static ChallengeOfficialSessionGateway? officialSessionGateway;
  static GeoPointAdminGateway? adminGateway;
  static AdFreeEntitlementGateway? monetizationGateway;

  static bool get isConfigured {
    return coreGateway != null ||
        packGateway != null ||
        rewardValidationGateway != null ||
        rankingGateway != null ||
        leaderboardGateway != null ||
        friendGateway != null ||
        seasonRewardGateway != null ||
        officialSessionGateway != null ||
        adminGateway != null ||
        monetizationGateway != null;
  }

  static void configure({
    ChallengeRemoteGateway? packs,
    ChallengeRewardValidationGateway? rewards,
    ChallengeRankingGateway? rankings,
    ChallengeLeaderboardGateway? leaderboards,
    ChallengeSeasonRewardGateway? seasonRewards,
    GeoPointFriendGateway? friends,
    GeoPointServerGateway? server,
    ChallengeOfficialSessionGateway? officialSessions,
    GeoPointAdminGateway? administration,
    AdFreeEntitlementGateway? monetization,
  }) {
    coreGateway = server;
    packGateway = packs;
    rewardValidationGateway = rewards;
    rankingGateway = rankings;
    leaderboardGateway = leaderboards;
    seasonRewardGateway = seasonRewards;
    friendGateway = friends;
    officialSessionGateway = officialSessions;
    adminGateway = administration;
    monetizationGateway = monetization;
  }

  static void clear() {
    coreGateway = null;
    packGateway = null;
    rewardValidationGateway = null;
    rankingGateway = null;
    leaderboardGateway = null;
    seasonRewardGateway = null;
    friendGateway = null;
    officialSessionGateway = null;
    adminGateway = null;
    monetizationGateway = null;
  }
}
