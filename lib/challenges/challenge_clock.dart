enum ChallengeClockSource {
  server,
  offlineEstimate,
  deviceFirstUse,
  blockedRollback,
}

class ChallengeClockState {
  const ChallengeClockState({
    this.lastTrustedServerUtc,
    this.lastDeviceUtc,
    this.lastEffectiveUtc,
  });

  final DateTime? lastTrustedServerUtc;
  final DateTime? lastDeviceUtc;
  final DateTime? lastEffectiveUtc;

  factory ChallengeClockState.initial() {
    return const ChallengeClockState();
  }

  factory ChallengeClockState.fromJson(Map<String, dynamic> json) {
    return ChallengeClockState(
      lastTrustedServerUtc: _readOptionalDateTime(
        json['lastTrustedServerUtc'],
      ),
      lastDeviceUtc: _readOptionalDateTime(json['lastDeviceUtc']),
      lastEffectiveUtc: _readOptionalDateTime(json['lastEffectiveUtc']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (lastTrustedServerUtc != null)
        'lastTrustedServerUtc':
            lastTrustedServerUtc!.toUtc().toIso8601String(),
      if (lastDeviceUtc != null)
        'lastDeviceUtc': lastDeviceUtc!.toUtc().toIso8601String(),
      if (lastEffectiveUtc != null)
        'lastEffectiveUtc': lastEffectiveUtc!.toUtc().toIso8601String(),
    };
  }
}

class ChallengeClockEvaluation {
  const ChallengeClockEvaluation({
    required this.effectiveNowUtc,
    required this.source,
    required this.canStartChallenge,
    required this.canClaimReward,
    required this.requiresServerValidation,
    required this.updatedState,
  });

  final DateTime effectiveNowUtc;
  final ChallengeClockSource source;
  final bool canStartChallenge;
  final bool canClaimReward;
  final bool requiresServerValidation;
  final ChallengeClockState updatedState;

  bool get isClockRollbackBlocked {
    return source == ChallengeClockSource.blockedRollback;
  }
}

class ChallengeClock {
  const ChallengeClock._();

  static const Duration rollbackTolerance = Duration(minutes: 5);

  static ChallengeClockEvaluation evaluate({
    required DateTime deviceNow,
    DateTime? serverNow,
    ChallengeClockState previousState = const ChallengeClockState(),
  }) {
    final DateTime deviceUtc = deviceNow.toUtc();
    final DateTime? serverUtc = serverNow?.toUtc();

    if (serverUtc != null) {
      final ChallengeClockState updated = ChallengeClockState(
        lastTrustedServerUtc: serverUtc,
        lastDeviceUtc: deviceUtc,
        lastEffectiveUtc: serverUtc,
      );
      return ChallengeClockEvaluation(
        effectiveNowUtc: serverUtc,
        source: ChallengeClockSource.server,
        canStartChallenge: true,
        canClaimReward: true,
        requiresServerValidation: false,
        updatedState: updated,
      );
    }

    final DateTime? previousDeviceUtc = previousState.lastDeviceUtc?.toUtc();
    if (previousDeviceUtc != null &&
        deviceUtc.add(rollbackTolerance).isBefore(previousDeviceUtc)) {
      final DateTime frozenTime =
          previousState.lastEffectiveUtc?.toUtc() ?? previousDeviceUtc;
      return ChallengeClockEvaluation(
        effectiveNowUtc: frozenTime,
        source: ChallengeClockSource.blockedRollback,
        canStartChallenge: false,
        canClaimReward: false,
        requiresServerValidation: true,
        updatedState: previousState,
      );
    }

    final DateTime? trustedServerUtc =
        previousState.lastTrustedServerUtc?.toUtc();
    final DateTime effectiveUtc;
    final ChallengeClockSource source;

    if (trustedServerUtc != null && previousDeviceUtc != null) {
      final Duration elapsed = deviceUtc.difference(previousDeviceUtc);
      effectiveUtc = trustedServerUtc.add(elapsed);
      source = ChallengeClockSource.offlineEstimate;
    } else {
      effectiveUtc = deviceUtc;
      source = ChallengeClockSource.deviceFirstUse;
    }

    final ChallengeClockState updated = ChallengeClockState(
      lastTrustedServerUtc: trustedServerUtc,
      lastDeviceUtc: deviceUtc,
      lastEffectiveUtc: effectiveUtc,
    );
    return ChallengeClockEvaluation(
      effectiveNowUtc: effectiveUtc,
      source: source,
      canStartChallenge: true,
      canClaimReward: true,
      requiresServerValidation: true,
      updatedState: updated,
    );
  }
}

DateTime? _readOptionalDateTime(Object? value) {
  final String source = value?.toString().trim() ?? '';
  if (source.isEmpty) {
    return null;
  }
  return DateTime.tryParse(source)?.toUtc();
}
