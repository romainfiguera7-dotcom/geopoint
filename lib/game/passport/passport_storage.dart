import 'package:flutter/foundation.dart';

import '../../storage/versioned_local_storage.dart';
import 'player_passport.dart';

class PassportStorage {
  PassportStorage._();

  static const String _passportKey = 'geopoint_player_passport';
  static const String _recordType = 'player_passport';

  static Future<PlayerPassport?> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(
        storageKey: _passportKey,
      );

      if (json == null) {
        return null;
      }

      return PlayerPassport.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : erreur pendant le '
        'chargement du Passeport : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  static Future<bool> save(
    PlayerPassport passport,
  ) async {
    try {
      return await VersionedLocalStorage.saveData(
        storageKey: _passportKey,
        recordType: _recordType,
        data: passport.toJson(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'GeoPoint : erreur pendant la '
        'sauvegarde du Passeport : $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  }

  static Future<bool> clear() async {
    return VersionedLocalStorage.clear(
      storageKey: _passportKey,
    );
  }
}
