import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const GeoPointApp());
}

class GeoPointApp extends StatelessWidget {
  const GeoPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GeoPoint',
      theme: ThemeData.dark(),
      home: const MapScreen(),
    );
  }
}

class GeoQuestion {
  final String name;
  final LatLng position;
  final double perfectRadiusKm;
  final double zeroDistanceKm;

  const GeoQuestion({
    required this.name,
    required this.position,
    required this.perfectRadiusKm,
    required this.zeroDistanceKm,
  });
}

const List<GeoQuestion> questions = [
  GeoQuestion(
    name: 'Tokyo 🇯🇵',
    position: LatLng(35.6586, 139.7454),
    perfectRadiusKm: 10,
    zeroDistanceKm: 2000,
  ),
  GeoQuestion(
    name: 'Paris 🇫🇷',
    position: LatLng(48.8584, 2.2945),
    perfectRadiusKm: 10,
    zeroDistanceKm: 2000,
  ),
  GeoQuestion(
    name: 'New York 🇺🇸',
    position: LatLng(40.7128, -74.0060),
    perfectRadiusKm: 10,
    zeroDistanceKm: 2000,
  ),
  GeoQuestion(
    name: 'Sydney 🇦🇺',
    position: LatLng(-33.8688, 151.2093),
    perfectRadiusKm: 10,
    zeroDistanceKm: 2000,
  ),
  GeoQuestion(
    name: 'Rio de Janeiro 🇧🇷',
    position: LatLng(-22.9068, -43.1729),
    perfectRadiusKm: 10,
    zeroDistanceKm: 2000,
  ),
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Random random = Random();

  late GeoQuestion currentQuestion;

  LatLng? selectedPoint;
  double? distanceKm;
  int? score;
  bool showAnswer = false;

  @override
  void initState() {
    super.initState();
    currentQuestion = questions[random.nextInt(questions.length)];
  }

  void newQuestion() {
    setState(() {
      currentQuestion = questions[random.nextInt(questions.length)];
      selectedPoint = null;
      distanceKm = null;
      score = null;
      showAnswer = false;
    });
  }

  void validateAnswer() {
    if (selectedPoint == null) return;

    final distance = const Distance().as(
      LengthUnit.Kilometer,
      selectedPoint!,
      currentQuestion.position,
    );

    int calculatedScore;

    if (distance <= currentQuestion.perfectRadiusKm) {
      calculatedScore = 100;
    } else if (distance >= currentQuestion.zeroDistanceKm) {
      calculatedScore = 0;
    } else {
      calculatedScore =
          (100 -
                  ((distance - currentQuestion.perfectRadiusKm) /
                          (currentQuestion.zeroDistanceKm -
                              currentQuestion.perfectRadiusKm) *
                      100))
              .round();
    }

    setState(() {
      distanceKm = distance;
      score = calculatedScore;
      showAnswer = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF5DB7D9),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(20, 0),
                initialZoom: 2.4,
                minZoom: 2.4,
                maxZoom: 8,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
                onTap: (tapPosition, point) {
                  if (showAnswer) return;

                  setState(() {
                    selectedPoint = point;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.geopoint',
                ),

                if (showAnswer)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: currentQuestion.position,
                        radius: currentQuestion.perfectRadiusKm * 1000,
                        useRadiusInMeter: true,
                        color: Colors.green.withValues(alpha: 0.25),
                        borderColor: Colors.green,
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),

                if (showAnswer && selectedPoint != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          selectedPoint!,
                          currentQuestion.position,
                        ],
                        strokeWidth: 4,
                        color: Colors.orange,
                      ),
                    ],
                  ),

                MarkerLayer(
                  markers: [
                    if (selectedPoint != null)
                      Marker(
                        point: selectedPoint!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 50,
                        ),
                      ),

                    if (showAnswer)
                      Marker(
                        point: currentQuestion.position,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.star,
                          color: Colors.yellow,
                          size: 45,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '🌍 Où se trouve ${currentQuestion.name} ?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
                        if (showAnswer && distanceKm != null)
              Positioned(
                bottom: 150,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Distance : ${distanceKm!.toStringAsFixed(0)} km\n'
                    'Score : $score / 100',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          selectedPoint == null || showAnswer
                              ? null
                              : validateAnswer,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                      ),
                      child: const Text(
                        'Valider',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: showAnswer ? newQuestion : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                      ),
                      child: const Text(
                        'Nouvelle',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}