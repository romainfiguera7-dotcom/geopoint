import 'package:latlong2/latlong.dart';

class ContinentLevel {
  const ContinentLevel({
    required this.id,
    required this.order,
    required this.title,
    required this.description,
    required this.objective,
    required this.modeId,
    required this.difficultyId,
    required this.countryIds,
    required this.questionCount,
    required this.questionDurationSeconds,
    required this.initialCenter,
    required this.initialZoom,
    required this.rewardLabel,
    this.useGeoBrain = false,
    this.isSilhouette = false,
    this.isExam = false,
    this.isMaster = false,
  });

  final String id;
  final int order;
  final String title;
  final String description;
  final String objective;
  final String modeId;
  final String difficultyId;
  final List<String> countryIds;
  final int questionCount;
  final int questionDurationSeconds;
  final LatLng initialCenter;
  final double initialZoom;
  final String rewardLabel;
  final bool useGeoBrain;
  final bool isSilhouette;
  final bool isExam;
  final bool isMaster;

  int get maximumScore {
    return questionCount * 120;
  }

  int get oneStarScore {
    return (maximumScore * 0.40).ceil();
  }

  int get twoStarScore {
    return (maximumScore * 0.65).ceil();
  }

  int get threeStarScore {
    return (maximumScore * 0.85).ceil();
  }

  int starsForScore(int score) {
    if (score >= threeStarScore) {
      return 3;
    }

    if (score >= twoStarScore) {
      return 2;
    }

    if (score >= oneStarScore) {
      return 1;
    }

    return 0;
  }
}

class ContinentExpedition {
  const ContinentExpedition({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.levels,
    required this.completionReward,
  });

  final String id;
  final String name;
  final String subtitle;
  final List<ContinentLevel> levels;
  final String completionReward;

  int get maximumStars {
    return levels.length * 3;
  }
}
