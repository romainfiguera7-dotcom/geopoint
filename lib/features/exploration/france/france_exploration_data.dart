import 'package:latlong2/latlong.dart';

class FranceRegionShape {
  const FranceRegionShape({
    required this.code,
    required this.name,
    required this.polygons,
    required this.center,
  });

  final String code;
  final String name;
  final List<List<LatLng>> polygons;
  final LatLng center;
}

class FranceDepartmentShape {
  const FranceDepartmentShape({
    required this.code,
    required this.name,
    required this.regionCode,
    required this.polygons,
    required this.center,
  });

  final String code;
  final String name;
  final String regionCode;
  final List<List<LatLng>> polygons;
  final LatLng center;
}

class FranceExplorationItem {
  const FranceExplorationItem({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.regionCode,
    required this.difficulty,
    required this.description,
    required this.path,
    this.regionName,
  });

  final String id;
  final String name;
  final String category;
  final LatLng position;
  final String regionCode;
  final String difficulty;
  final String description;
  final List<LatLng> path;
  final String? regionName;

  factory FranceExplorationItem.fromJson(Map<String, dynamic> json) {
    final String id = (json['id']?.toString() ?? '').trim();
    final String name = (json['name']?.toString() ?? '').trim();
    final String category = (json['category']?.toString() ?? '').trim();
    final double? latitude = _readDouble(json['latitude']);
    final double? longitude = _readDouble(json['longitude']);
    if (id.isEmpty ||
        name.isEmpty ||
        category.isEmpty ||
        latitude == null ||
        longitude == null) {
      throw const FormatException('Élément France invalide.');
    }

    final List<LatLng> path = <LatLng>[];
    final Object? rawPath = json['path'];
    if (rawPath is List) {
      for (final Object? rawPoint in rawPath) {
        if (rawPoint is List && rawPoint.length >= 2) {
          final double? pointLatitude = _readDouble(rawPoint[0]);
          final double? pointLongitude = _readDouble(rawPoint[1]);
          if (pointLatitude != null && pointLongitude != null) {
            path.add(LatLng(pointLatitude, pointLongitude));
          }
        }
      }
    }

    return FranceExplorationItem(
      id: id,
      name: name,
      category: category,
      position: LatLng(latitude, longitude),
      regionCode: (json['regionCode']?.toString() ?? '').trim(),
      difficulty: (json['difficulty']?.toString() ?? 'easy').trim(),
      description: (json['description']?.toString() ?? '').trim(),
      path: List<LatLng>.unmodifiable(path),
      regionName: (json['regionName']?.toString() ?? '').trim().isEmpty
          ? null
          : json['regionName'].toString().trim(),
    );
  }
}

class FranceExplorationData {
  const FranceExplorationData({
    required this.regions,
    required this.departments,
    required this.items,
  });

  final List<FranceRegionShape> regions;
  final List<FranceDepartmentShape> departments;
  final List<FranceExplorationItem> items;

  List<FranceExplorationItem> itemsForCategory(String category) {
    return items
        .where((FranceExplorationItem item) => item.category == category)
        .toList(growable: false);
  }
}

double? _readDouble(Object? raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  return double.tryParse(raw?.toString() ?? '');
}
