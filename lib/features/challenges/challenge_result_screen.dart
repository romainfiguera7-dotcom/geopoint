import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../challenges/challenge_definition.dart';
import '../../challenges/challenge_player_state.dart';
import '../../challenges/challenge_ranking.dart';
import '../../challenges/challenge_ranking_sync.dart';
import '../../challenges/challenge_result.dart';
import '../../challenges/challenge_session_service.dart';
import '../design/geopoint_design.dart';

enum ChallengeResultAction {
  backToChallenges,
  retry,
}

class ChallengeResultScreen extends StatelessWidget {
  const ChallengeResultScreen({
    required this.challenge,
    required this.outcome,
    this.awardedXp = 0,
    this.rankingSync,
    this.adFree = false,
    super.key,
  });

  final ChallengeDefinition challenge;
  final ChallengeSessionOutcome outcome;
  final int awardedXp;
  final ChallengeRankingSyncReport? rankingSync;
  final bool adFree;

  @override
  Widget build(BuildContext context) {
    final bool succeeded = outcome.succeeded;
    final bool canRetry = _canRetry;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 34),
                  children: <Widget>[
                    Icon(
                      succeeded
                          ? Icons.emoji_events_rounded
                          : Icons.explore_off_rounded,
                      color: succeeded ? GeoColors.gold : GeoColors.coral,
                      size: 72,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      succeeded ? 'DÉFI RÉUSSI !' : 'PRESQUE !',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      challenge.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ResultCard(challenge: challenge, outcome: outcome),
                    const SizedBox(height: 16),
                    _RewardStatusCard(
                      challenge: challenge,
                      outcome: outcome,
                      awardedXp: awardedXp,
                    ),
                    if (challenge.isRanked) ...<Widget>[
                      const SizedBox(height: 16),
                      _RankingStatusCard(
                        outcome: outcome,
                        syncReport: rankingSync,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (canRetry)
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(
                          ChallengeResultAction.retry,
                        ),
                        icon: const Icon(Icons.replay_rounded),
                        label: Text(
                          succeeded
                              ? 'AMÉLIORER MON SCORE'
                              : 'RECOMMENCER',
                        ),
                      ),
                    if (canRetry) const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        ChallengeResultAction.backToChallenges,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('RETOUR AUX DÉFIS'),
                    ),
                    if (canRetry) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        challenge.retryPolicy.rewardedAdvertisementAllowed &&
                                !adFree
                            ? 'Le prochain essai demande une publicité récompensée.'
                            : 'Le prochain essai est gratuit.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white.withValues(alpha: 0.64),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canRetry {
    final progress = outcome.playerState.progressFor(challenge.id);
    final policy = challenge.retryPolicy;
    return progress.canUseFreeAttempt(
          policy,
          allowAfterCompletion: challenge.isRanked,
        ) ||
        progress.canUseRewardedAdvertisementRetry(
          policy,
          allowAfterCompletion: challenge.isRanked,
        );
  }
}

class _RankingStatusCard extends StatelessWidget {
  const _RankingStatusCard({
    required this.outcome,
    this.syncReport,
  });

  final ChallengeSessionOutcome outcome;
  final ChallengeRankingSyncReport? syncReport;

  @override
  Widget build(BuildContext context) {
    final ChallengeRankingEnqueueDecision? enqueue = outcome.rankingEnqueue;
    final ChallengeRankingSubmission? submission = enqueue?.submission;
    final ChallengeRankingSubmission? synchronizedSubmission =
        submission == null
            ? null
            : syncReport
                ?.playerState.rankingLedger.submissions[submission.submissionId];
    final String message;
    final IconData icon;
    final ChallengeRankingSyncReport? report = syncReport;
    if (enqueue?.outcome ==
        ChallengeRankingEnqueueOutcome.ignoredOptedOut) {
      message = 'Le classement automatique n’était pas disponible pour cette '
          'tentative.';
      icon = Icons.shield_outlined;
    } else if (submission == null) {
      message = 'Aucun résultat classé n’a été enregistré.';
      icon = Icons.shield_outlined;
    } else if (synchronizedSubmission?.status ==
        ChallengeRankingSubmissionStatus.confirmed) {
      message = outcome.rankingAttemptIsBest
          ? 'Nouveau meilleur résultat validé par Firebase. Le classement est actualisé.'
          : 'Tentative validée par Firebase. Ton meilleur résultat reste conservé.';
      icon = Icons.cloud_done_rounded;
    } else if (synchronizedSubmission?.status ==
        ChallengeRankingSubmissionStatus.quarantined) {
      message = 'Résultat reçu par Firebase et placé en vérification. Il ne sera visible qu’après validation.';
      icon = Icons.manage_search_rounded;
    } else if (synchronizedSubmission?.status ==
        ChallengeRankingSubmissionStatus.rejected) {
      message = 'Firebase a refusé cette tentative. Elle ne modifie pas le classement.';
      icon = Icons.gpp_bad_rounded;
    } else if (report?.status == ChallengeRankingSyncStatus.pendingConnection ||
        report?.status == ChallengeRankingSyncStatus.serverUnavailable) {
      message = 'Connexion Firebase indisponible. Le résultat est conservé et sera renvoyé automatiquement.';
      icon = Icons.cloud_off_rounded;
    } else if (report?.status ==
        ChallengeRankingSyncStatus.pendingPlayerIdentity) {
      message = 'Le résultat attend la liaison de ton identité Firebase.';
      icon = Icons.person_search_rounded;
    } else if (report?.status ==
        ChallengeRankingSyncStatus.invalidServerResponse) {
      message = 'La réponse Firebase a été ignorée pour protéger le classement. Le résultat reste en attente.';
      icon = Icons.gpp_maybe_rounded;
    } else if (report?.status == ChallengeRankingSyncStatus.storageFailure) {
      message = 'Le score a été traité, mais sa confirmation locale sera retentée.';
      icon = Icons.sync_problem_rounded;
    } else if (outcome.rankingAttemptIsBest) {
      message = 'Nouveau meilleur résultat enregistré. Il sera classé après '
          'validation serveur.';
      icon = Icons.trending_up_rounded;
    } else {
      message = 'Tentative enregistrée. Ton meilleur résultat précédent reste '
          'conservé.';
      icon = Icons.verified_outlined;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GeoColors.purple.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GeoColors.purple.withValues(alpha: 0.60),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 25),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunitoSans(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.challenge, required this.outcome});

  final ChallengeDefinition challenge;
  final ChallengeSessionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final ChallengeResultEvaluation evaluation = outcome.evaluation;
    final ChallengeSuccessCondition condition = challenge.successCondition;
    return _WhiteCard(
      title: 'Ton résultat',
      children: <Widget>[
        _ResultLine(
          label: 'Bonnes réponses',
          value: '${outcome.performance.correctAnswers} / '
              '${condition.minimumCorrectAnswers} minimum',
          reached: evaluation.correctAnswersReached,
        ),
        _ResultLine(
          label: 'Score',
          value: '${outcome.performance.score} / '
              '${condition.minimumScore} minimum',
          reached: evaluation.scoreReached,
        ),
        if (condition.maximumAverageDistanceKilometers != null)
          _ResultLine(
            label: 'Distance moyenne',
            value:
                '${outcome.performance.averageDistanceKilometers?.round() ?? 0} km / '
                '${condition.maximumAverageDistanceKilometers!.round()} km maximum',
            reached: evaluation.distanceReached,
          ),
      ],
    );
  }
}

class _RewardStatusCard extends StatelessWidget {
  const _RewardStatusCard({
    required this.challenge,
    required this.outcome,
    required this.awardedXp,
  });

  final ChallengeDefinition challenge;
  final ChallengeSessionOutcome outcome;
  final int awardedXp;

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;
    final Color color;
    if (!outcome.saved) {
      message = 'Le résultat n’a pas pu être sauvegardé.';
      icon = Icons.cloud_off_rounded;
      color = GeoColors.coral;
    } else if (!outcome.succeeded &&
        outcome.playerState.rewardLedger.containsClaim(
          challenge.rewardClaimId,
        )) {
      message = 'La récompense est déjà enregistrée. Cette nouvelle tentative '
          'compte uniquement pour améliorer ton classement.';
      icon = Icons.workspace_premium_outlined;
      color = GeoColors.purple;
    } else if (!outcome.succeeded) {
      message = 'Réussis le défi pour débloquer sa récompense.';
      icon = Icons.lock_outline_rounded;
      color = GeoColors.sky;
    } else if (outcome.rewardClaim?.outcome ==
        ChallengeRewardClaimOutcome.rejectedDuplicate) {
      message = 'Ton classement peut encore progresser, mais la récompense '
          'de ce défi a déjà été obtenue.';
      icon = Icons.workspace_premium_outlined;
      color = GeoColors.purple;
    } else if (!outcome.rewardWasAccepted) {
      message = 'Le défi est terminé, mais la récompense doit être vérifiée.';
      icon = Icons.shield_outlined;
      color = GeoColors.coral;
    } else if (outcome.rewardIsPending) {
      message = 'Récompense enregistrée, en attente de la prochaine '
          'validation serveur.';
      icon = Icons.cloud_sync_rounded;
      color = GeoColors.gold;
    } else {
      message = 'Récompense débloquée et enregistrée.';
      icon = Icons.card_giftcard_rounded;
      color = GeoColors.mint;
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (outcome.rewardWasDelivered) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (awardedXp > 0)
                  _DeliveredRewardChip(
                    icon: Icons.bolt_rounded,
                    label: '+$awardedXp XP',
                  ),
                if ((outcome.deliveredReward?.coins ?? 0) > 0)
                  _DeliveredRewardChip(
                    icon: Icons.monetization_on_rounded,
                    label: '+${outcome.deliveredReward!.coins} pièces',
                  ),
                if ((outcome.deliveredReward?.diamonds ?? 0) > 0)
                  _DeliveredRewardChip(
                    icon: Icons.diamond_rounded,
                    label: '+${outcome.deliveredReward!.diamonds} diamant(s)',
                  ),
                if ((outcome.deliveredReward?.progressionPoints ?? 0) > 0)
                  _DeliveredRewardChip(
                    icon: Icons.trending_up_rounded,
                    label:
                        '+${outcome.deliveredReward!.progressionPoints} progression',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveredRewardChip extends StatelessWidget {
  const _DeliveredRewardChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GeoColors.cream,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.fredoka(
              color: GeoColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.label,
    required this.value,
    required this.reached,
  });

  final String label;
  final String value;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Icon(
            reached ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: reached ? GeoColors.mint : GeoColors.coral,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunitoSans(
                color: GeoColors.mutedInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.nunitoSans(
                color: GeoColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
