import 'package:flutter/foundation.dart';

import '../storage/versioned_local_storage.dart';
import 'challenge_studio_draft.dart';

class ChallengeStudioStorage {
  ChallengeStudioStorage._();

  static const String storageKey = 'geopoint_challenge_studio_drafts';
  static const String _recordType = 'challenge_studio_drafts';

  static Future<List<ChallengeStudioDraft>> load() async {
    try {
      final Map<String, dynamic>? json =
          await VersionedLocalStorage.loadData(storageKey: storageKey);
      if (json == null) {
        return const <ChallengeStudioDraft>[];
      }
      final Object? rawDrafts = json['drafts'];
      if (rawDrafts is! List) {
        throw const FormatException('La liste des brouillons est absente.');
      }
      return List<ChallengeStudioDraft>.unmodifiable(
        rawDrafts.map((Object? rawDraft) {
          if (rawDraft is! Map) {
            throw const FormatException('Brouillon Studio invalide.');
          }
          return ChallengeStudioDraft.fromJson(
            rawDraft.map<String, dynamic>(
              (dynamic key, dynamic value) =>
                  MapEntry<String, dynamic>(key.toString(), value),
            ),
          );
        }),
      );
    } catch (error, stackTrace) {
      debugPrint('GeoPoint Studio : erreur de chargement : $error');
      debugPrintStack(stackTrace: stackTrace);
      return const <ChallengeStudioDraft>[];
    }
  }

  static Future<bool> save(List<ChallengeStudioDraft> drafts) {
    return VersionedLocalStorage.saveData(
      storageKey: storageKey,
      recordType: _recordType,
      data: <String, dynamic>{
        'schemaVersion': ChallengeStudioDraft.schemaVersion,
        'drafts': drafts
            .map((ChallengeStudioDraft draft) => draft.toJson())
            .toList(growable: false),
      },
    );
  }

  static Future<bool> clear() {
    return VersionedLocalStorage.clear(storageKey: storageKey);
  }
}
