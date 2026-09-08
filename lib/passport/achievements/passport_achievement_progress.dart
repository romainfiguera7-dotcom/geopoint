import 'passport_achievement.dart';
import 'passport_achievement_catalog.dart';

class PassportAchievementProgress {
  const PassportAchievementProgress({
    required this.schemaVersion,
    required this.completedAtByTierId,
    required this.updatedAt,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final Map<String, DateTime> completedAtByTierId;
  final DateTime updatedAt;

  factory PassportAchievementProgress.initial({DateTime? createdAt}) {
    final DateTime now = createdAt ?? DateTime.now();
    return PassportAchievementProgress(
      schemaVersion: currentSchemaVersion,
      completedAtByTierId: const <String, DateTime>{},
      updatedAt: now,
    );
  }

  bool isTierCompleted(String tierId) {
    return completedAtByTierId.containsKey(tierId.trim().toLowerCase());
  }

  int get completedTierCount => completedAtByTierId.length;

  PassportAchievementProgress mergeCompletedTierDates(
    Map<String, DateTime> dates,
  ) {
    final Map<String, DateTime> merged =
        Map<String, DateTime>.from(completedAtByTierId);
    bool changed = false;
    for (final MapEntry<String, DateTime> entry in dates.entries) {
      final String tierId = entry.key.trim().toLowerCase();
      if (tierId.isEmpty || merged.containsKey(tierId)) {
        continue;
      }
      merged[tierId] = entry.value;
      changed = true;
    }
    if (!changed) {
      return this;
    }
    return PassportAchievementProgress(
      schemaVersion: currentSchemaVersion,
      completedAtByTierId: Map<String, DateTime>.unmodifiable(merged),
      updatedAt: DateTime.now(),
    );
  }

  PassportAchievementProgress synchronize({
    required PassportAchievementSnapshot snapshot,
    DateTime? synchronizedAt,
  }) {
    final DateTime now = synchronizedAt ?? DateTime.now();
    final Map<String, DateTime> completed =
        Map<String, DateTime>.from(completedAtByTierId);

    for (final PassportAchievement achievement
        in PassportAchievementCatalog.achievements) {
      final int value = achievement.valueFor(snapshot);
      for (final PassportAchievementTier tier in achievement.tiers) {
        if (value >= tier.target) {
          completed.putIfAbsent(tier.id.toLowerCase(), () => now);
        }
      }
    }

    if (completed.length == completedAtByTierId.length) {
      return this;
    }

    return PassportAchievementProgress(
      schemaVersion: currentSchemaVersion,
      completedAtByTierId: Map<String, DateTime>.unmodifiable(completed),
      updatedAt: now,
    );
  }

  Set<String> newlyCompletedTierIdsComparedWith(
    PassportAchievementProgress previous,
  ) {
    return completedAtByTierId.keys
        .where((String tierId) => !previous.completedAtByTierId.containsKey(tierId))
        .toSet();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'completedAtByTierId': <String, dynamic>{
        for (final MapEntry<String, DateTime> entry
            in completedAtByTierId.entries)
          entry.key: entry.value.toIso8601String(),
      },
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PassportAchievementProgress.fromJson(Map<String, dynamic> json) {
    final DateTime now = DateTime.now();
    final Map<String, DateTime> completed = <String, DateTime>{};
    final Object? rawCompleted = json['completedAtByTierId'];

    if (rawCompleted is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawCompleted.entries) {
        final String tierId = entry.key.toString().trim().toLowerCase();
        final DateTime? completedAt = DateTime.tryParse(
          entry.value?.toString() ?? '',
        );
        if (tierId.isNotEmpty && completedAt != null) {
          completed[tierId] = completedAt;
        }
      }
    }

    return PassportAchievementProgress(
      schemaVersion: currentSchemaVersion,
      completedAtByTierId: Map<String, DateTime>.unmodifiable(completed),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
    );
  }
}
