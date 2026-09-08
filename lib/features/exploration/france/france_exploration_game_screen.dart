import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../design/geo_vector_map.dart';
import '../../design/geopoint_design.dart';
import '../../../monetization/interstitial_ad_service.dart';
import '../../settings/gameplay_feedback.dart';
import 'france_expedition_catalog.dart';
import 'france_exploration_data.dart';
import 'france_exploration_loader.dart';

class FranceExplorationGameResult {
  const FranceExplorationGameResult({
    required this.stars,
    required this.score,
    required this.correctAnswers,
    required this.questionCount,
  });

  final int stars;
  final int score;
  final int correctAnswers;
  final int questionCount;
}

class FranceExplorationGameScreen extends StatefulWidget {
  const FranceExplorationGameScreen({
    required this.title,
    required this.kind,
    required this.category,
    required this.difficulty,
    required this.questionCount,
    required this.isTraining,
    super.key,
  });

  final String title;
  final FranceQuestionKind kind;
  final String category;
  final String difficulty;
  final int questionCount;
  final bool isTraining;

  @override
  State<FranceExplorationGameScreen> createState() =>
      _FranceExplorationGameScreenState();
}

class _FranceExplorationGameScreenState
    extends State<FranceExplorationGameScreen> {
  static const Set<String> _metropolitanRegionCodes = <String>{
    '11', '24', '27', '28', '32', '44', '52',
    '53', '75', '76', '84', '93', '94',
  };
  static const List<String> _easyRegionCodes = <String>[
    '11', '32', '75', '76', '84', '93',
  ];
  static const Set<String> _easyDepartmentCodes = <String>{
    '06', '13', '29', '31', '33', '34',
    '44', '59', '67', '75', '83', '2A',
  };

  final math.Random _random = math.Random();
  final Distance _distance = const Distance();

  FranceExplorationData? _data;
  Object? _loadError;
  List<_FranceQuestion> _questions = const <_FranceQuestion>[];
  int _questionIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  bool _answered = false;
  bool _finished = false;
  bool _lastAnswerCorrect = false;
  String _feedback = '';
  String? _selectedAreaCode;
  LatLng? _selectedPoint;

  _FranceQuestion get _currentQuestion => _questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final FranceExplorationData data =
          await FranceExplorationLoader.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _questions = _buildQuestions(data);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
        });
      }
    }
  }

  List<_FranceQuestion> _buildQuestions(FranceExplorationData data) {
    final List<_FranceQuestion> pool = <_FranceQuestion>[];
    if (widget.kind == FranceQuestionKind.region) {
      final List<String> allowedCodes = widget.difficulty == 'easy'
          ? _easyRegionCodes
          : _metropolitanRegionCodes.toList(growable: false);
      for (final FranceRegionShape region in data.regions) {
        if (allowedCodes.contains(region.code)) {
          pool.add(_FranceQuestion.region(region));
        }
      }
    } else if (widget.kind == FranceQuestionKind.department) {
      for (final FranceDepartmentShape department in data.departments) {
        if (!_metropolitanRegionCodes.contains(department.regionCode)) {
          continue;
        }
        if (widget.difficulty == 'easy' &&
            !_easyDepartmentCodes.contains(department.code)) {
          continue;
        }
        pool.add(_FranceQuestion.department(department));
      }
    } else if (widget.kind == FranceQuestionKind.overseas) {
      for (final FranceExplorationItem item
          in data.itemsForCategory('overseas')) {
        pool.add(_FranceQuestion.item(item, FranceQuestionKind.overseas));
      }
    } else if (widget.kind == FranceQuestionKind.mixed) {
      for (final FranceRegionShape region in data.regions) {
        final Set<String> allowedRegions = widget.difficulty == 'easy'
            ? _easyRegionCodes.toSet()
            : _metropolitanRegionCodes;
        if (allowedRegions.contains(region.code)) {
          pool.add(_FranceQuestion.region(region));
        }
      }
      for (final FranceExplorationItem item in data.items) {
        if (item.category != 'overseas' &&
            item.category != 'river' &&
            item.category != 'mountain' &&
            _difficultyRank(item.difficulty) <=
                _difficultyRank(widget.difficulty)) {
          pool.add(_FranceQuestion.item(item, FranceQuestionKind.point));
        }
      }
    } else {
      for (final FranceExplorationItem item
          in data.itemsForCategory(widget.category)) {
        if (_difficultyRank(item.difficulty) <=
            _difficultyRank(widget.difficulty)) {
          pool.add(_FranceQuestion.item(item, FranceQuestionKind.point));
        }
      }
    }

    pool.shuffle(_random);
    if (pool.isEmpty) {
      return const <_FranceQuestion>[];
    }
    final List<_FranceQuestion> result = <_FranceQuestion>[];
    while (result.length < widget.questionCount) {
      final List<_FranceQuestion> round = List<_FranceQuestion>.from(pool)
        ..shuffle(_random);
      result.addAll(round);
    }
    return result.take(widget.questionCount).toList(growable: false);
  }

  int _difficultyRank(String difficulty) {
    switch (difficulty) {
      case 'expert':
        return 4;
      case 'hard':
        return 3;
      case 'intermediate':
        return 2;
      case 'easy':
      default:
        return 1;
    }
  }

  void _handlePositionTap(LatLng point) {
    if (_answered || _finished || _questions.isEmpty) {
      return;
    }
    final _FranceQuestion question = _currentQuestion;
    if (question.kind != FranceQuestionKind.point) {
      return;
    }

    final FranceExplorationItem item = question.item!;
    final double kilometers =
        _distance.as(LengthUnit.Kilometer, point, item.position);
    final double threshold = _pointThreshold(item.category);
    final bool correct = kilometers <= threshold;
    final int points = correct
        ? (100 - (kilometers / threshold * 35)).round().clamp(65, 100)
        : math.max(0, (55 - kilometers / threshold * 18).round());
    _registerAnswer(
      correct: correct,
      points: points,
      feedback: correct
          ? '${item.name} trouvé à ${kilometers.round()} km près.'
          : '${item.name} se trouvait à ${kilometers.round()} km de ton choix.',
      selectedPoint: point,
    );
  }

  void _handleRegionTap(String? regionCode) {
    if (_answered ||
        _finished ||
        _questions.isEmpty ||
        regionCode == null ||
        _currentQuestion.kind != FranceQuestionKind.region) {
      return;
    }
    final FranceRegionShape target = _currentQuestion.region!;
    final bool correct = regionCode == target.code;
    _registerAnswer(
      correct: correct,
      points: correct ? 100 : 0,
      feedback: correct
          ? '${target.name} est bien placée.'
          : 'C’était ${target.name}.',
      selectedAreaCode: regionCode,
    );
  }

  void _handleDepartmentTap(String? departmentCode) {
    if (_answered ||
        _finished ||
        _questions.isEmpty ||
        departmentCode == null ||
        _currentQuestion.kind != FranceQuestionKind.department) {
      return;
    }
    final FranceDepartmentShape target = _currentQuestion.department!;
    final bool correct = departmentCode == target.code;
    _registerAnswer(
      correct: correct,
      points: correct ? 100 : 0,
      feedback: correct
          ? '${target.name} est bien placé.'
          : 'C’était ${target.name} (${target.code}).',
      selectedAreaCode: departmentCode,
    );
  }

  double _pointThreshold(String category) {
    final double base;
    switch (widget.difficulty) {
      case 'expert':
        base = 45;
        break;
      case 'hard':
        base = 65;
        break;
      case 'intermediate':
        base = 90;
        break;
      case 'easy':
      default:
        base = 130;
    }
    return base;
  }

  void _answerOverseas(String regionName) {
    if (_answered) {
      return;
    }
    final FranceExplorationItem item = _currentQuestion.item!;
    final bool correct = regionName == item.regionName;
    _registerAnswer(
      correct: correct,
      points: correct ? 100 : 0,
      feedback: correct
          ? '${item.name} est bien le chef-lieu de ${item.regionName}.'
          : '${item.name} est le chef-lieu de ${item.regionName}.',
    );
  }

  void _registerAnswer({
    required bool correct,
    required int points,
    required String feedback,
    String? selectedAreaCode,
    LatLng? selectedPoint,
  }) {
    setState(() {
      _answered = true;
      _lastAnswerCorrect = correct;
      _feedback = feedback;
      _score += points;
      if (correct) {
        _correctAnswers++;
      }
      _selectedAreaCode = selectedAreaCode;
      _selectedPoint = selectedPoint;
    });
    GameplayFeedback.answer(isCorrect: correct);
  }

  void _nextQuestion() {
    if (_questionIndex + 1 >= _questions.length) {
      setState(() {
        _finished = true;
      });
      return;
    }
    setState(() {
      _questionIndex++;
      _answered = false;
      _feedback = '';
      _selectedAreaCode = null;
      _selectedPoint = null;
    });
  }

  FranceExplorationGameResult _result() {
    final double ratio = _questions.isEmpty
        ? 0
        : _correctAnswers / _questions.length;
    final int stars = ratio >= 0.85
        ? 3
        : ratio >= 0.65
            ? 2
            : ratio >= 0.45
                ? 1
                : 0;
    return FranceExplorationGameResult(
      stars: stars,
      score: _score,
      correctAnswers: _correctAnswers,
      questionCount: _questions.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return _buildLoadError();
    }
    if (_data == null) {
      return const Scaffold(
        backgroundColor: GeoColors.navy,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_questions.isEmpty) {
      return _buildLoadError(message: 'Aucune question disponible.');
    }
    if (_finished) {
      return _buildResult();
    }
    return Scaffold(
      backgroundColor: GeoColors.navy,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: GeoGameTopBar(
                title: widget.title,
                subtitle: widget.isTraining
                    ? 'Entraînement national'
                    : 'Exploration nationale • France',
                onBack: () => Navigator.of(context).pop(),
                trailing: _ScoreBadge(
                  current: _questionIndex + 1,
                  total: _questions.length,
                ),
              ),
            ),
            _QuestionBanner(question: _currentQuestion),
            const SizedBox(height: 8),
            Expanded(
              child: _currentQuestion.kind == FranceQuestionKind.overseas
                  ? _buildOverseasQuestion()
                  : _buildMap(),
            ),
            if (_answered) _buildFeedback(),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final FranceExplorationData data = _data!;
    final _FranceQuestion question = _currentQuestion;
    final bool regionMap = question.kind == FranceQuestionKind.region;
    final bool departmentQuestion =
        question.kind == FranceQuestionKind.department;
    final List<GeoVectorShape> shapes = <GeoVectorShape>[];
    if (regionMap) {
      for (final FranceRegionShape region in data.regions) {
        if (!_metropolitanRegionCodes.contains(region.code)) {
          continue;
        }
        final bool isTarget =
            _answered && question.region?.code == region.code;
        final bool isSelected = _selectedAreaCode == region.code;
        final Color color = isTarget
            ? GeoColors.mint
            : isSelected
                ? GeoColors.coral
                : _regionMapColor(region.code);
        shapes.add(
          GeoVectorShape(
            id: region.code,
            polygons: region.polygons,
            fillColor: color.withValues(alpha: 0.96),
            borderColor: Colors.white.withValues(alpha: 0.86),
            borderWidth: isTarget || isSelected ? 2.8 : 1.25,
          ),
        );
      }
    } else {
      for (final FranceDepartmentShape department in data.departments) {
        if (!_metropolitanRegionCodes.contains(department.regionCode)) {
          continue;
        }
        final bool isTarget =
            _answered && question.department?.code == department.code;
        final bool isSelected = _selectedAreaCode == department.code;
        final Color color = isTarget
            ? GeoColors.mint
            : isSelected
                ? GeoColors.coral
                : _regionMapColor(department.regionCode);
        shapes.add(
          GeoVectorShape(
            id: department.code,
            polygons: department.polygons,
            fillColor: color.withValues(alpha: 0.92),
            borderColor: Colors.white.withValues(alpha: 0.72),
            borderWidth: isTarget || isSelected ? 2.5 : 0.7,
          ),
        );
      }
      for (final FranceRegionShape region in data.regions) {
        if (!_metropolitanRegionCodes.contains(region.code)) {
          continue;
        }
        shapes.add(
          GeoVectorShape(
            id: 'region-border-${region.code}',
            polygons: region.polygons,
            fillColor: Colors.transparent,
            borderColor: const Color(0xFF07284D).withValues(alpha: 0.82),
            borderWidth: 1.7,
          ),
        );
      }
    }

    final List<GeoVectorPoint> points = <GeoVectorPoint>[];
    final List<GeoVectorLine> lines = <GeoVectorLine>[];
    if (_answered && question.item != null) {
      final FranceExplorationItem item = question.item!;
      points.add(
        GeoVectorPoint(
          position: item.position,
          color: GeoColors.mint,
          radius: 9,
          label: item.name,
        ),
      );
      if (_selectedPoint != null) {
        points.add(
          GeoVectorPoint(
            position: _selectedPoint!,
            color: GeoColors.coral,
            radius: 7,
          ),
        );
        lines.add(
          GeoVectorLine(
            points: <LatLng>[_selectedPoint!, item.position],
            color: GeoColors.coral,
            width: 3,
          ),
        );
      }
      if (item.path.length >= 2) {
        lines.add(
          GeoVectorLine(
            points: item.path,
            color: GeoColors.blue,
            width: 5,
          ),
        );
      }
    }
    if (_answered && question.region != null) {
      points.add(
        GeoVectorPoint(
          position: question.region!.center,
          color: GeoColors.mint,
          radius: 6,
          label: question.region!.name,
        ),
      );
    }
    if (_answered && question.department != null) {
      points.add(
        GeoVectorPoint(
          position: question.department!.center,
          color: GeoColors.mint,
          radius: 5,
          label: '${question.department!.name} • ${question.department!.code}',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GeoVectorMap(
                viewId: 'france-${widget.title}-$_questionIndex',
                initialBounds: const GeoVectorBounds(
                  minLatitude: 41.1,
                  maxLatitude: 51.4,
                  minLongitude: -5.6,
                  maxLongitude: 10.0,
                ),
                shapes: shapes,
                lines: lines,
                points: points,
                backgroundColor: const Color(0xFF096B91),
                onShapeTap: regionMap
                    ? _handleRegionTap
                    : departmentQuestion
                        ? _handleDepartmentTap
                        : null,
                onPositionTap: question.kind == FranceQuestionKind.point
                    ? _handlePositionTap
                    : null,
                maximumZoom: departmentQuestion ? 14 : 11,
                initialZoom: regionMap ? 1.08 : 1.16,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xE6071B3A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  regionMap ? 'CARTE DES RÉGIONS' : 'CARTE DES DÉPARTEMENTS',
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _regionMapColor(String regionCode) {
    switch (regionCode) {
      case '11':
        return const Color(0xFFB9A3E8);
      case '24':
        return const Color(0xFFF1C15B);
      case '27':
        return const Color(0xFF8BC9A8);
      case '28':
        return const Color(0xFF83B9E8);
      case '32':
        return const Color(0xFF65C6C0);
      case '44':
        return const Color(0xFFF2A866);
      case '52':
        return const Color(0xFFD7CE6F);
      case '53':
        return const Color(0xFF78B998);
      case '75':
        return const Color(0xFFF0A0B7);
      case '76':
        return const Color(0xFFE68C72);
      case '84':
        return const Color(0xFF9CABE8);
      case '93':
        return const Color(0xFFE88877);
      case '94':
        return const Color(0xFFC49BDF);
      default:
        return const Color(0xFFAAD1C2);
    }
  }

  Widget _buildOverseasQuestion() {
    final FranceExplorationItem item = _currentQuestion.item!;
    final List<String> options = _data!.itemsForCategory('overseas')
        .map((FranceExplorationItem entry) => entry.regionName ?? '')
        .where((String name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return Container(
      width: double.infinity,
      color: const Color(0xFF0C2D5D),
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.public_rounded, color: GeoColors.sky, size: 70),
              const SizedBox(height: 18),
              Text(
                '${item.name} est le chef-lieu de…',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              for (final String option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _answered ? null : () => _answerOverseas(option),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    final _FranceQuestion question = _currentQuestion;
    final String explanation = question.item?.description ??
        'Observe sa position et retiens la forme de la région.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 15),
      color: _lastAnswerCorrect
          ? const Color(0xFF087A67)
          : const Color(0xFF9D3C43),
      child: Row(
        children: <Widget>[
          Icon(
            _lastAnswerCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _feedback,
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  explanation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _nextQuestion,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              maximumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              backgroundColor: GeoColors.gold,
              foregroundColor: GeoColors.navy,
            ),
            child: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final FranceExplorationGameResult result = _result();
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: GeoAdventureBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: <Widget>[
                      const Icon(
                        Icons.flag_rounded,
                        color: GeoColors.gold,
                        size: 92,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.isTraining
                            ? 'Entraînement terminé'
                            : 'Étape terminée',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 31,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (int index = 0; index < 3; index++)
                            Icon(
                              Icons.star_rounded,
                              color: index < result.stars
                                  ? GeoColors.gold
                                  : Colors.white24,
                              size: 43,
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${result.correctAnswers}/${result.questionCount} bonnes réponses • ${result.score} points',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await InterstitialAdService.instance
                                .registerCompletedGame();
                            if (!mounted) return;
                            Navigator.of(context).pop(result);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: GeoColors.gold,
                            foregroundColor: GeoColors.navy,
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            'CONTINUER',
                            style: GoogleFonts.fredoka(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError({String? message}) {
    return Scaffold(
      backgroundColor: GeoColors.navy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, color: GeoColors.coral, size: 54),
              const SizedBox(height: 12),
              Text(
                message ?? 'Impossible de charger l’exploration France.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('RETOUR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FranceQuestion {
  const _FranceQuestion({
    required this.kind,
    this.region,
    this.department,
    this.item,
  });

  factory _FranceQuestion.region(FranceRegionShape region) {
    return _FranceQuestion(kind: FranceQuestionKind.region, region: region);
  }

  factory _FranceQuestion.department(FranceDepartmentShape department) {
    return _FranceQuestion(
      kind: FranceQuestionKind.department,
      department: department,
    );
  }

  factory _FranceQuestion.item(
    FranceExplorationItem item,
    FranceQuestionKind kind,
  ) {
    return _FranceQuestion(kind: kind, item: item);
  }

  final FranceQuestionKind kind;
  final FranceRegionShape? region;
  final FranceDepartmentShape? department;
  final FranceExplorationItem? item;

  String get prompt {
    if (region != null) {
      return 'Trouve ${region!.name}';
    }
    if (department != null) {
      return 'Trouve ${department!.name}';
    }
    if (kind == FranceQuestionKind.overseas) {
      return 'Associe ce chef-lieu à sa région';
    }
    switch (item!.category) {
      case 'city':
        return 'Place la ville de ${item!.name}';
      case 'monument':
        return 'Place ${item!.name}';
      default:
        return 'Trouve ${item!.name}';
    }
  }
}

class _QuestionBanner extends StatelessWidget {
  const _QuestionBanner({required this.question});

  final _FranceQuestion question;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        question.prompt,
        textAlign: TextAlign.center,
        style: GoogleFonts.fredoka(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        '$current/$total',
        style: GoogleFonts.nunitoSans(
          color: GeoColors.gold,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
