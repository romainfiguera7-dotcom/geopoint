import 'passport_progress_rules.dart';

class PassportStampUnlockEvent {
  const PassportStampUnlockEvent({
    required this.sequence,
    required this.entityId,
    required this.unlockedAt,
    required this.source,
  });

  final int sequence;
  final String entityId;
  final DateTime unlockedAt;
  final PassportDiscoverySource source;
}
