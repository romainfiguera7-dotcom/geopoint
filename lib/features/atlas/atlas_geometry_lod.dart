import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../geo_engine/geo_country.dart';

enum AtlasGeometryDetail {
  overview,
  continent,
  regional,
  full,
}

/// Géométries préparées pour que l'Atlas ne retravaille pas les 548 000
/// points de la carte haute définition pendant chaque geste.
///
/// Les trois niveaux allégés restent sous 1,5 pixel au zoom maximal où ils
/// sont utilisés. Cette différence est imperceptible sur l'écran du téléphone.
/// Dès que le joueur se rapproche, l'Atlas revient automatiquement aux
/// frontières originales complètes.
class AtlasGeometryLod {
  AtlasGeometryLod._({
    required this.overviewMaximumZoom,
    required this.continentMaximumZoom,
    required this.regionalMaximumZoom,
    required this._overviewPolygons,
    required this._continentPolygons,
    required this._regionalPolygons,
  });

  static const String _assetPath =
      'assets/maps/world_countries_atlas_lod.bin';
  static const int _formatVersion = 1;
  static const List<int> _magic = <int>[0x47, 0x50, 0x4C, 0x44];

  static Future<AtlasGeometryLod>? _cachedFuture;

  final double overviewMaximumZoom;
  final double continentMaximumZoom;
  final double regionalMaximumZoom;
  final Map<String, List<List<LatLng>>> _overviewPolygons;
  final Map<String, List<List<LatLng>>> _continentPolygons;
  final Map<String, List<List<LatLng>>> _regionalPolygons;

  static Future<AtlasGeometryLod> load() {
    return _cachedFuture ??= _loadAsset();
  }

  static Future<AtlasGeometryLod> _loadAsset() async {
    final ByteData bytes = await rootBundle.load(_assetPath);
    return decode(bytes);
  }

  static AtlasGeometryLod decode(ByteData source) {
    final _AtlasBinaryReader reader = _AtlasBinaryReader(source);

    for (final int expectedByte in _magic) {
      if (reader.readUint8() != expectedByte) {
        throw const FormatException(
          'Le cache de géométrie Atlas possède une signature invalide.',
        );
      }
    }

    final int version = reader.readUint32();
    if (version != _formatVersion) {
      throw FormatException(
        'Version de géométrie Atlas non prise en charge : $version.',
      );
    }

    final int levelCount = reader.readUint32();
    if (levelCount != 3) {
      throw FormatException(
        'Le cache de géométrie Atlas doit contenir trois niveaux, '
        'pas $levelCount.',
      );
    }

    final _AtlasGeometryLevel overview = _readLevel(reader);
    final _AtlasGeometryLevel continent = _readLevel(reader);
    final _AtlasGeometryLevel regional = _readLevel(reader);

    if (!reader.isAtEnd) {
      throw const FormatException(
        'Le cache de géométrie Atlas contient des données inattendues.',
      );
    }

    if (overview.maximumZoom >= continent.maximumZoom ||
        continent.maximumZoom >= regional.maximumZoom) {
      throw const FormatException(
        'Les niveaux de géométrie Atlas ne sont pas dans le bon ordre.',
      );
    }

    return AtlasGeometryLod._(
      overviewMaximumZoom: overview.maximumZoom,
      continentMaximumZoom: continent.maximumZoom,
      regionalMaximumZoom: regional.maximumZoom,
      overviewPolygons: overview.polygonsByCountry,
      continentPolygons: continent.polygonsByCountry,
      regionalPolygons: regional.polygonsByCountry,
    );
  }

  AtlasGeometryDetail detailForZoom(double zoom) {
    if (zoom < overviewMaximumZoom) {
      return AtlasGeometryDetail.overview;
    }

    if (zoom < continentMaximumZoom) {
      return AtlasGeometryDetail.continent;
    }

    if (zoom < regionalMaximumZoom) {
      return AtlasGeometryDetail.regional;
    }

    return AtlasGeometryDetail.full;
  }

  List<List<LatLng>> polygonsFor(
    GeoCountry country,
    AtlasGeometryDetail detail,
  ) {
    switch (detail) {
      case AtlasGeometryDetail.overview:
        return _overviewPolygons[country.id] ?? country.polygons;
      case AtlasGeometryDetail.continent:
        return _continentPolygons[country.id] ?? country.polygons;
      case AtlasGeometryDetail.regional:
        return _regionalPolygons[country.id] ?? country.polygons;
      case AtlasGeometryDetail.full:
        return country.polygons;
    }
  }

  static _AtlasGeometryLevel _readLevel(_AtlasBinaryReader reader) {
    final double maximumZoom = reader.readFloat64();
    final int countryCount = reader.readUint32();
    final Map<String, List<List<LatLng>>> polygonsByCountry =
        <String, List<List<LatLng>>>{};

    for (int countryIndex = 0; countryIndex < countryCount; countryIndex++) {
      final String countryId = reader.readString();
      final int ringCount = reader.readUint32();
      final List<List<LatLng>> rings = <List<LatLng>>[];

      for (int ringIndex = 0; ringIndex < ringCount; ringIndex++) {
        final int pointCount = reader.readUint32();
        if (pointCount < 4) {
          throw FormatException(
            'Un polygone Atlas de $countryId contient moins de quatre points.',
          );
        }

        final List<LatLng> points = List<LatLng>.generate(
          pointCount,
          (int _) {
            final double longitude = reader.readInt32() / 1000000;
            final double latitude = reader.readInt32() / 1000000;
            return LatLng(latitude, longitude);
          },
          growable: false,
        );
        rings.add(List<LatLng>.unmodifiable(points));
      }

      polygonsByCountry[countryId] =
          List<List<LatLng>>.unmodifiable(rings);
    }

    return _AtlasGeometryLevel(
      maximumZoom: maximumZoom,
      polygonsByCountry:
          Map<String, List<List<LatLng>>>.unmodifiable(polygonsByCountry),
    );
  }
}

class _AtlasGeometryLevel {
  const _AtlasGeometryLevel({
    required this.maximumZoom,
    required this.polygonsByCountry,
  });

  final double maximumZoom;
  final Map<String, List<List<LatLng>>> polygonsByCountry;
}

class _AtlasBinaryReader {
  _AtlasBinaryReader(ByteData source)
      : _bytes = source.buffer.asUint8List(
          source.offsetInBytes,
          source.lengthInBytes,
        ),
        _data = source;

  final Uint8List _bytes;
  final ByteData _data;
  int _offset = 0;

  bool get isAtEnd => _offset == _bytes.length;

  int readUint8() {
    _require(1);
    return _data.getUint8(_offset++);
  }

  int readUint32() {
    _require(4);
    final int value = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int readInt32() {
    _require(4);
    final int value = _data.getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  double readFloat64() {
    _require(8);
    final double value = _data.getFloat64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  String readString() {
    final int length = readUint8();
    _require(length);
    final String value = utf8.decode(
      _bytes.sublist(_offset, _offset + length),
    );
    _offset += length;
    return value;
  }

  void _require(int byteCount) {
    if (byteCount < 0 || _offset + byteCount > _bytes.length) {
      throw const FormatException(
        'Le cache de géométrie Atlas est incomplet.',
      );
    }
  }
}
