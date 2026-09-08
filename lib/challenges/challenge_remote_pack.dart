import 'challenge_pack.dart';

enum ChallengePackOrigin {
  bundled,
  cache,
  remote,
}

extension ChallengePackOriginRules on ChallengePackOrigin {
  String get label {
    switch (this) {
      case ChallengePackOrigin.bundled:
        return 'Pack inclus dans l’application';
      case ChallengePackOrigin.cache:
        return 'Dernier pack valide hors ligne';
      case ChallengePackOrigin.remote:
        return 'Pack distant synchronisé';
    }
  }
}

class ChallengeRemotePackDocument {
  const ChallengeRemotePackDocument({
    required this.revision,
    required this.publishedAtUtc,
    required this.serverNowUtc,
    required this.jsonSource,
  });

  final int revision;
  final DateTime publishedAtUtc;
  final DateTime serverNowUtc;
  final String jsonSource;
}

abstract interface class ChallengeRemoteGateway {
  Future<ChallengeRemotePackDocument?> fetchActivePack();
}

class ChallengePackResolution {
  const ChallengePackResolution({
    required this.pack,
    required this.origin,
    required this.revision,
    this.serverNowUtc,
    this.fallbackReason,
  });

  final ChallengePack pack;
  final ChallengePackOrigin origin;
  final int revision;
  final DateTime? serverNowUtc;
  final String? fallbackReason;

  bool get usedFallback => fallbackReason != null;
}
