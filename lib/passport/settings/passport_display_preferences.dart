class PassportDisplayPreferences {
  const PassportDisplayPreferences({
    required this.schemaVersion,
    required this.stampAnimationsEnabled,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final bool stampAnimationsEnabled;

  factory PassportDisplayPreferences.initial() {
    return const PassportDisplayPreferences(
      schemaVersion: currentSchemaVersion,
      stampAnimationsEnabled: true,
    );
  }

  PassportDisplayPreferences copyWith({
    bool? stampAnimationsEnabled,
  }) {
    return PassportDisplayPreferences(
      schemaVersion: currentSchemaVersion,
      stampAnimationsEnabled:
          stampAnimationsEnabled ?? this.stampAnimationsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'stampAnimationsEnabled': stampAnimationsEnabled,
    };
  }

  factory PassportDisplayPreferences.fromJson(Map<String, dynamic> json) {
    final Object? rawAnimations = json['stampAnimationsEnabled'];

    return PassportDisplayPreferences(
      schemaVersion: currentSchemaVersion,
      stampAnimationsEnabled: rawAnimations is bool ? rawAnimations : true,
    );
  }
}
