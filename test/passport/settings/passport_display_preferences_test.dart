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

    test('active l’animation des tampons par défaut', () {
      final PassportDisplayPreferences preferences =
          PassportDisplayPreferences.initial();

      expect(preferences.stampAnimationsEnabled, isTrue);
      expect(
        preferences.schemaVersion,
        PassportDisplayPreferences.currentSchemaVersion,
      );
    });

    test('relit les anciennes préférences sans perdre la valeur par défaut', () {
      final PassportDisplayPreferences preferences =
          PassportDisplayPreferences.fromJson(<String, dynamic>{});

      expect(preferences.stampAnimationsEnabled, isTrue);
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
  });
}
