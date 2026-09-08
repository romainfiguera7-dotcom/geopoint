import 'package:flutter_test/flutter_test.dart';
import 'package:geopoint/passport/settings/passport_display_preferences.dart';
import 'package:geopoint/passport/settings/passport_display_preferences_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PassportDisplayPreferences', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('active les animations du Passeport par défaut', () {
      final PassportDisplayPreferences preferences =
          PassportDisplayPreferences.initial();

      expect(preferences.stampAnimationsEnabled, isTrue);
      expect(preferences.majorLevelAnimationsEnabled, isTrue);
      expect(preferences.soundEffectsEnabled, isTrue);
      expect(preferences.hapticsEnabled, isTrue);
      expect(
        preferences.schemaVersion,
        PassportDisplayPreferences.currentSchemaVersion,
      );
    });

    test('relit les anciennes préférences sans perdre la valeur par défaut', () {
      final PassportDisplayPreferences preferences =
          PassportDisplayPreferences.fromJson(<String, dynamic>{});

      expect(preferences.stampAnimationsEnabled, isTrue);
      expect(preferences.majorLevelAnimationsEnabled, isTrue);
      expect(preferences.soundEffectsEnabled, isTrue);
      expect(preferences.hapticsEnabled, isTrue);
    });

    test('sauvegarde les sons et les vibrations séparément', () async {
      final PassportDisplayPreferences disabled =
          PassportDisplayPreferences.initial().copyWith(
        soundEffectsEnabled: false,
        hapticsEnabled: false,
      );

      expect(
        await PassportDisplayPreferencesStorage.save(disabled),
        isTrue,
      );

      final PassportDisplayPreferences restored =
          await PassportDisplayPreferencesStorage.load();

      expect(restored.soundEffectsEnabled, isFalse);
      expect(restored.hapticsEnabled, isFalse);
      expect(restored.stampAnimationsEnabled, isTrue);
    });

    test('sauvegarde le choix de désactiver l’animation', () async {
      final PassportDisplayPreferences disabled =
          PassportDisplayPreferences.initial().copyWith(
        stampAnimationsEnabled: false,
      );

      expect(
        await PassportDisplayPreferencesStorage.save(disabled),
        isTrue,
      );

      final PassportDisplayPreferences restored =
          await PassportDisplayPreferencesStorage.load();

      expect(restored.stampAnimationsEnabled, isFalse);
      expect(
        restored.schemaVersion,
        PassportDisplayPreferences.currentSchemaVersion,
      );
    });

    test('sauvegarde séparément l’animation des grands niveaux', () async {
      final PassportDisplayPreferences disabled =
          PassportDisplayPreferences.initial().copyWith(
        majorLevelAnimationsEnabled: false,
      );

      expect(
        await PassportDisplayPreferencesStorage.save(disabled),
        isTrue,
      );

      final PassportDisplayPreferences restored =
          await PassportDisplayPreferencesStorage.load();

      expect(restored.stampAnimationsEnabled, isTrue);
      expect(restored.majorLevelAnimationsEnabled, isFalse);
    });
  });
}
