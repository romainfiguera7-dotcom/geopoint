import 'challenge_definition.dart';

class ChallengeOfficialSessionRequest {
  const ChallengeOfficialSessionRequest({
    required this.launchId,
    required this.challengeId,
    required this.rankingGroupId,
    required this.competitiveSignature,
  });

  static const int apiVersion = 1;

  final String launchId;
  final String challengeId;
  final String rankingGroupId;
  final String competitiveSignature;

  factory ChallengeOfficialSessionRequest.forChallenge({
    required ChallengeDefinition challenge,
    required String launchId,
  }) {
    final String? rankingGroupId = challenge.rankingGroupId;
    if (rankingGroupId == null) {
      throw StateError('Le défi ne possède pas de classement officiel.');
    }
    return ChallengeOfficialSessionRequest(
      launchId: launchId,
      challengeId: challenge.id,
      rankingGroupId: rankingGroupId,
      competitiveSignature: challenge.competitiveSignature,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'apiVersion': apiVersion,
      'launchId': launchId,
      'challengeId': challengeId,
      'rankingGroupId': rankingGroupId,
      'competitiveSignature': competitiveSignature,
    };
  }
}

class ChallengeOfficialSession {
  const ChallengeOfficialSession({
    required this.sessionId,
    required this.challengeId,
    required this.rankingGroupId,
    required this.competitiveSignature,
    required this.startedAtUtc,
    required this.expiresAtUtc,
    required this.serverNowUtc,
    required this.rankingEligible,
    required this.migrationStatus,
  });

  final String sessionId;
  final String challengeId;
  final String rankingGroupId;
  final String competitiveSignature;
  final DateTime startedAtUtc;
  final DateTime expiresAtUtc;
  final DateTime serverNowUtc;
  final bool rankingEligible;
  final String migrationStatus;

  bool get isActiveAtServerTime {
    return !serverNowUtc.isBefore(startedAtUtc) &&
        serverNowUtc.isBefore(expiresAtUtc);
  }

  factory ChallengeOfficialSession.fromJson(Map<String, dynamic> json) {
    final int apiVersion = _positiveInt(json['apiVersion'], 'apiVersion');
    if (apiVersion != ChallengeOfficialSessionRequest.apiVersion) {
      throw FormatException(
        'Version de session officielle incompatible : $apiVersion.',
      );
    }
    final ChallengeOfficialSession session = ChallengeOfficialSession(
      sessionId: _identifier(json['sessionId'], 'sessionId'),
      challengeId: _identifier(json['challengeId'], 'challengeId'),
      rankingGroupId:
          _identifier(json['rankingGroupId'], 'rankingGroupId'),
      competitiveSignature:
          _text(json['competitiveSignature'], 'competitiveSignature'),
      startedAtUtc: _date(json['startedAtUtc'], 'startedAtUtc'),
      expiresAtUtc: _date(json['expiresAtUtc'], 'expiresAtUtc'),
      serverNowUtc: _date(json['serverNowUtc'], 'serverNowUtc'),
      rankingEligible: json['rankingEligible'] == true,
      migrationStatus: _identifier(
        json['migrationStatus'],
        'migrationStatus',
      ),
    );
    if (!session.expiresAtUtc.isAfter(session.startedAtUtc) ||
        !session.isActiveAtServerTime) {
      throw const FormatException('La session officielle a déjà expiré.');
    }
    return session;
  }
}

abstract interface class ChallengeOfficialSessionGateway {
  Future<ChallengeOfficialSession> startOfficialSession(
    ChallengeOfficialSessionRequest request,
  );
}

enum ChallengeOfficialSessionStartStatus {
  started,
  ignoredNotRanked,
  ignoredOptedOut,
  pendingConnection,
  serverRejected,
}

class ChallengeOfficialSessionStartReport {
  const ChallengeOfficialSessionStartReport({
    required this.status,
    this.session,
    this.failureReason,
  });

  final ChallengeOfficialSessionStartStatus status;
  final ChallengeOfficialSession? session;
  final String? failureReason;

  bool get wasStarted {
    return status == ChallengeOfficialSessionStartStatus.started &&
        session != null;
  }
}

class ChallengeOfficialSessionService {
  const ChallengeOfficialSessionService._();

  static Future<ChallengeOfficialSessionStartReport> start({
    required ChallengeDefinition challenge,
    required bool participationEnabled,
    required String launchId,
    ChallengeOfficialSessionGateway? gateway,
  }) async {
    if (!challenge.isRanked) {
      return const ChallengeOfficialSessionStartReport(
        status: ChallengeOfficialSessionStartStatus.ignoredNotRanked,
      );
    }
    if (!participationEnabled) {
      return const ChallengeOfficialSessionStartReport(
        status: ChallengeOfficialSessionStartStatus.ignoredOptedOut,
      );
    }
    if (gateway == null) {
      return const ChallengeOfficialSessionStartReport(
        status: ChallengeOfficialSessionStartStatus.pendingConnection,
        failureReason: 'Le serveur de classement est indisponible.',
      );
    }
    try {
      final ChallengeOfficialSession session =
          await gateway.startOfficialSession(
        ChallengeOfficialSessionRequest.forChallenge(
          challenge: challenge,
          launchId: launchId,
        ),
      );
      if (session.challengeId != challenge.id ||
          session.rankingGroupId != challenge.rankingGroupId ||
          session.competitiveSignature != challenge.competitiveSignature) {
        throw const FormatException(
          'La session ne correspond pas au défi demandé.',
        );
      }
      return ChallengeOfficialSessionStartReport(
        status: ChallengeOfficialSessionStartStatus.started,
        session: session,
      );
    } catch (error) {
      return ChallengeOfficialSessionStartReport(
        status: ChallengeOfficialSessionStartStatus.serverRejected,
        failureReason: error.toString(),
      );
    }
  }
}

String _identifier(Object? value, String fieldName) {
  final String text = _text(value, fieldName);
  if (text.length > 128 || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(text)) {
    throw FormatException('Identifiant de session invalide : $fieldName.');
  }
  return text;
}

String _text(Object? value, String fieldName) {
  final String text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    throw FormatException('Champ de session manquant : $fieldName.');
  }
  return text;
}

int _positiveInt(Object? value, String fieldName) {
  final int? number = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (number == null || number <= 0) {
    throw FormatException('Nombre de session invalide : $fieldName.');
  }
  return number;
}

DateTime _date(Object? value, String fieldName) {
  final DateTime? date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) {
    throw FormatException('Date de session invalide : $fieldName.');
  }
  return date.toUtc();
}
