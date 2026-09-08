import 'challenge_definition.dart';
import 'challenge_pack.dart';
import 'challenge_pack_cache.dart';
import 'challenge_pack_cache_storage.dart';
import 'challenge_pack_loader.dart';
import 'challenge_pack_validator.dart';
import 'challenge_remote_pack.dart';

typedef ChallengeBundledPackLoader = Future<ChallengePack> Function();

class ChallengePackRepository {
  ChallengePackRepository({
    this.remoteGateway,
    ChallengeBundledPackLoader? bundledLoader,
  }) : _bundledLoader = bundledLoader ?? _loadBundledPack;

  final ChallengeRemoteGateway? remoteGateway;
  final ChallengeBundledPackLoader _bundledLoader;

  static Future<ChallengePack> _loadBundledPack() {
    return ChallengePackLoader.load();
  }

  Future<ChallengePackResolution> load({
    required Set<String> countryIds,
  }) async {
    final ChallengePackValidationContext context =
        ChallengePackValidationContext(countryIds: countryIds);
    final ChallengePack bundled = await _bundledLoader();
    _requireValidPack(bundled, context: context);
    String? remoteFailure;

    if (remoteGateway != null) {
      final ChallengePackCache? cached =
          await ChallengePackCacheStorage.load();
      try {
        final ChallengeRemotePackDocument? document =
            await remoteGateway!.fetchActivePack();
        if (document == null) {
          throw const FormatException('Aucun pack distant n’est publié.');
        }
        _validateRemoteMetadata(document);
        final ChallengePack remotePack = ChallengePackLoader.decode(
          document.jsonSource,
          sourceName: 'pack distant révision ${document.revision}',
        );
        _requireValidPack(remotePack, context: context);

        if (cached != null && document.revision < cached.revision) {
          throw FormatException(
            'La révision distante ${document.revision} est antérieure à la '
            'révision ${cached.revision} déjà reçue.',
          );
        }

        ChallengePack resolvedPack = _withBundledPermanentChallenges(
          remotePack,
          bundled,
        );
        _requireValidPack(resolvedPack, context: context);
        if (cached != null && document.revision == cached.revision) {
          resolvedPack = _withBundledPermanentChallenges(
            cached.pack,
            bundled,
          );
          _requireValidPack(resolvedPack, context: context);
        } else {
          await ChallengePackCacheStorage.save(
            ChallengePackCache(
              revision: document.revision,
              fetchedAtUtc: document.serverNowUtc,
              pack: remotePack,
            ),
          );
        }

        return ChallengePackResolution(
          pack: resolvedPack,
          origin: ChallengePackOrigin.remote,
          revision: document.revision,
          serverNowUtc: document.serverNowUtc,
        );
      } catch (error) {
        remoteFailure = error.toString();
        if (cached != null) {
          try {
            final ChallengePack completedCache =
                _withBundledPermanentChallenges(cached.pack, bundled);
            _requireValidPack(completedCache, context: context);
            return ChallengePackResolution(
              pack: completedCache,
              origin: ChallengePackOrigin.cache,
              revision: cached.revision,
              fallbackReason: remoteFailure,
            );
          } catch (_) {
            // Le cache est ignoré et le pack inclus devient le dernier repli.
          }
        }
      }
    }

    return ChallengePackResolution(
      pack: bundled,
      origin: ChallengePackOrigin.bundled,
      revision: 0,
      fallbackReason: remoteFailure,
    );
  }

  static ChallengePack _withBundledPermanentChallenges(
    ChallengePack candidate,
    ChallengePack bundled,
  ) {
    final Set<String> existingIds = candidate.challenges
        .map((ChallengeDefinition challenge) => challenge.id)
        .toSet();
    final List<ChallengeDefinition> missingPermanent = bundled.challenges
        .where(
          (ChallengeDefinition challenge) =>
              challenge.period == ChallengePeriod.permanent &&
              !existingIds.contains(challenge.id),
        )
        .toList(growable: false);
    if (missingPermanent.isEmpty) {
      return candidate;
    }
    return ChallengePack(
      schemaVersion: candidate.schemaVersion,
      id: candidate.id,
      title: candidate.title,
      monthKey: candidate.monthKey,
      validFromUtc: candidate.validFromUtc,
      validUntilUtc: candidate.validUntilUtc,
      challenges: List<ChallengeDefinition>.unmodifiable(
        <ChallengeDefinition>[
          ...candidate.challenges,
          ...missingPermanent,
        ],
      ),
      disabledChallengeIds: candidate.disabledChallengeIds,
    );
  }

  static void _validateRemoteMetadata(ChallengeRemotePackDocument document) {
    if (document.revision <= 0) {
      throw const FormatException(
        'La révision distante doit être strictement positive.',
      );
    }
    final DateTime serverNow = document.serverNowUtc.toUtc();
    final DateTime publishedAt = document.publishedAtUtc.toUtc();
    if (publishedAt.isAfter(serverNow.add(const Duration(minutes: 5)))) {
      throw const FormatException(
        'La date de publication distante est incohérente.',
      );
    }
  }

  static void _requireValidPack(
    ChallengePack pack, {
    required ChallengePackValidationContext context,
  }) {
    final List<ChallengeValidationIssue> errors =
        ChallengePackValidator.validate(pack, context: context)
            .where((ChallengeValidationIssue issue) => issue.isError)
            .toList(growable: false);
    if (errors.isEmpty) {
      return;
    }
    throw FormatException(
      errors.map((ChallengeValidationIssue issue) => issue.message).join(' '),
    );
  }
}
