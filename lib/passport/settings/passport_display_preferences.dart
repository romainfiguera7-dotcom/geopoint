class PassportDisplayPreferences {
  const PassportDisplayPreferences({
    required this.schemaVersion,
    required this.soundEffectsEnabled,
    required this.hapticsEnabled,
    required this.stampAnimationsEnabled,
    required this.majorLevelAnimationsEnabled,
  });

  static const int currentSchemaVersion = 3;

  final int schemaVersion;
  final bool soundEffectsEnabled;
  final bool hapticsEnabled;
  final bool stampAnimationsEnabled;
  final bool majorLevelAnimationsEnabled;

  factory PassportDisplayPreferences.initial() {
    return const PassportDisplayPreferences(
      schemaVersion: currentSchemaVersion,
      soundEffectsEnabled: true,
      hapticsEnabled: true,
      stampAnimationsEnabled: true,
      majorLevelAnimationsEnabled: true,
    );
  }

  PassportDisplayPreferences copyWith({
    bool? soundEffectsEnabled,
    bool? hapticsEnabled,
    bool? stampAnimationsEnabled,
    bool? majorLevelAnimationsEnabled,
  }) {
    return PassportDisplayPreferences(
      schemaVersion: currentSchemaVersion,
      soundEffectsEnabled:
          soundEffectsEnabled ?? this.soundEffectsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      stampAnimationsEnabled:
          stampAnimationsEnabled ?? this.stampAnimationsEnabled,
      majorLevelAnimationsEnabled:
          majorLevelAnimationsEnabled ?? this.majorLevelAnimationsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'soundEffectsEnabled': soundEffectsEnabled,
      'hapticsEnabled': hapticsEnabled,
      'stampAnimationsEnabled': stampAnimationsEnabled,
      'majorLevelAnimationsEnabled': majorLevelAnimationsEnabled,
    };
  }

  factory PassportDisplayPreferences.fromJson(Map<String, dynamic> json) {
    final Object? rawAnimations = json['stampAnimationsEnabled'];
    final Object? rawSoundEffects = json['soundEffectsEnabled'];
    final Object? rawHaptics = json['hapticsEnabled'];
    final Object? rawMajorLevelAnimations =
        json['majorLevelAnimationsEnabled'];

    return PassportDisplayPreferences(
      schemaVersion: currentSchemaVersion,
      soundEffectsEnabled:
          rawSoundEffects is bool ? rawSoundEffects : true,
      hapticsEnabled: rawHaptics is bool ? rawHaptics : true,
      stampAnimationsEnabled: rawAnimations is bool ? rawAnimations : true,
      majorLevelAnimationsEnabled:
          rawMajorLevelAnimations is bool ? rawMajorLevelAnimations : true,
    );
  }
}
