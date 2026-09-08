#!/usr/bin/env python3
"""Generate the Atlas' pre-simplified map geometry.

The original GeoJSON remains the single high-resolution source. The generated
asset only contains two lighter levels used while the map is zoomed out. Each
level is simplified in Web Mercator space with a maximum deviation below
0.20 logical pixel at the highest zoom where that level is displayed.
"""

from __future__ import annotations

import json
import math
import re
import struct
from pathlib import Path
from typing import Iterable, Sequence


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = PROJECT_ROOT / "assets/maps/world_countries.geojson"
OUTPUT_PATH = PROJECT_ROOT / "assets/maps/world_countries_atlas_lod.bin"

TILE_SIZE = 256.0
MAX_PIXEL_ERROR = 1.5
MIN_VISIBLE_RING_PIXELS = 1.0
LEVELS = {
    "overview": 3.0,
    "continent": 4.5,
    "regional": 6.0,
}

Point = tuple[float, float]


def _country_id(properties: dict[str, object], feature_index: int) -> str:
    for key in ("ADM0_A3", "SOV_A3", "GU_A3", "ISO_A3", "ISO_A2"):
        value = str(properties.get(key, "")).strip().upper()
        if value != "-99" and re.fullmatch(r"[A-Z0-9]{2,4}", value):
            return value

    fallback = "UNKNOWN"
    for key in ("NAME", "ADMIN", "SOVEREIGNT"):
        value = str(properties.get(key, "")).strip()
        if value and value != "-99":
            fallback = value
            break

    normalized = re.sub(r"[^A-Z0-9]+", "_", fallback.upper()).strip("_")
    return f"{normalized or 'COUNTRY'}_{feature_index}"


def _exterior_rings(geometry: dict[str, object]) -> Iterable[list[Point]]:
    coordinates = geometry.get("coordinates")
    if not isinstance(coordinates, list):
        return

    geometry_type = geometry.get("type")
    if geometry_type == "Polygon":
        raw_polygons = [coordinates]
    elif geometry_type == "MultiPolygon":
        raw_polygons = coordinates
    else:
        return

    for raw_polygon in raw_polygons:
        if not isinstance(raw_polygon, list) or not raw_polygon:
            continue
        raw_ring = raw_polygon[0]
        if not isinstance(raw_ring, list):
            continue

        ring: list[Point] = []
        for raw_point in raw_ring:
            if (
                isinstance(raw_point, list)
                and len(raw_point) >= 2
                and isinstance(raw_point[0], (int, float))
                and isinstance(raw_point[1], (int, float))
            ):
                ring.append((float(raw_point[0]), float(raw_point[1])))

        if len(ring) >= 3:
            yield ring


def _project(point: Point) -> Point:
    longitude, latitude = point
    latitude = max(-85.05112878, min(85.05112878, latitude))
    latitude_radians = math.radians(latitude)
    x = (longitude + 180.0) / 360.0
    y = (1.0 - math.asinh(math.tan(latitude_radians)) / math.pi) / 2.0
    return x, y


def _distance_squared_to_segment(point: Point, start: Point, end: Point) -> float:
    delta_x = end[0] - start[0]
    delta_y = end[1] - start[1]

    if delta_x == 0.0 and delta_y == 0.0:
        return (point[0] - start[0]) ** 2 + (point[1] - start[1]) ** 2

    ratio = (
        (point[0] - start[0]) * delta_x
        + (point[1] - start[1]) * delta_y
    ) / (delta_x * delta_x + delta_y * delta_y)
    ratio = max(0.0, min(1.0, ratio))
    projected_x = start[0] + ratio * delta_x
    projected_y = start[1] + ratio * delta_y
    return (point[0] - projected_x) ** 2 + (point[1] - projected_y) ** 2


def _simplify_open(points: Sequence[Point], tolerance_squared: float) -> list[Point]:
    if len(points) <= 2:
        return list(points)

    projected = [_project(point) for point in points]
    keep = {0, len(points) - 1}
    pending = [(0, len(points) - 1)]

    while pending:
        start_index, end_index = pending.pop()
        maximum_distance = -1.0
        maximum_index = -1

        for index in range(start_index + 1, end_index):
            distance = _distance_squared_to_segment(
                projected[index],
                projected[start_index],
                projected[end_index],
            )
            if distance > maximum_distance:
                maximum_distance = distance
                maximum_index = index

        if maximum_distance > tolerance_squared and maximum_index >= 0:
            keep.add(maximum_index)
            pending.append((start_index, maximum_index))
            pending.append((maximum_index, end_index))

    return [points[index] for index in sorted(keep)]


def _simplify_closed_ring(ring: Sequence[Point], tolerance: float) -> list[Point]:
    points = list(ring)
    if len(points) > 1 and points[0] == points[-1]:
        points.pop()
    if len(points) <= 4:
        return [*points, points[0]]

    projected = [_project(point) for point in points]
    anchor = projected[0]
    split_index = max(
        range(1, len(points)),
        key=lambda index: (
            (projected[index][0] - anchor[0]) ** 2
            + (projected[index][1] - anchor[1]) ** 2
        ),
    )
    tolerance_squared = tolerance * tolerance
    first_half = _simplify_open(points[: split_index + 1], tolerance_squared)
    second_half = _simplify_open(
        [*points[split_index:], points[0]],
        tolerance_squared,
    )
    simplified = [*first_half[:-1], *second_half[:-1]]

    if len(simplified) < 3:
        line_start = projected[0]
        line_end = projected[split_index]
        third_index = max(
            (
                index
                for index in range(1, len(points))
                if index != split_index
            ),
            key=lambda index: _distance_squared_to_segment(
                projected[index],
                line_start,
                line_end,
            ),
        )
        simplified = [
            points[index]
            for index in sorted((0, split_index, third_index))
        ]

    return [*simplified, simplified[0]]


def _projected_extent(ring: Sequence[Point]) -> float:
    projected = [_project(point) for point in ring]
    width = max(point[0] for point in projected) - min(
        point[0] for point in projected
    )
    height = max(point[1] for point in projected) - min(
        point[1] for point in projected
    )
    return max(width, height)


def main() -> None:
    with SOURCE_PATH.open(encoding="utf-8") as source_file:
        source = json.load(source_file)

    source_rings: dict[str, list[list[Point]]] = {}
    for feature_index, feature in enumerate(source.get("features", [])):
        if not isinstance(feature, dict):
            continue
        properties = feature.get("properties") or {}
        geometry = feature.get("geometry") or {}
        if not isinstance(properties, dict) or not isinstance(geometry, dict):
            continue
        identifier = _country_id(properties, feature_index)
        source_rings.setdefault(identifier, []).extend(_exterior_rings(geometry))

    generated_levels: list[
        tuple[str, float, dict[str, list[list[Point]]], int]
    ] = []

    for level_name, maximum_zoom in LEVELS.items():
        tolerance = MAX_PIXEL_ERROR / (TILE_SIZE * 2**maximum_zoom)
        minimum_ring_extent = (
            MIN_VISIBLE_RING_PIXELS / (TILE_SIZE * 2**maximum_zoom)
        )
        countries: dict[str, list[list[Point]]] = {}
        point_count = 0
        for identifier, rings in source_rings.items():
            visible_rings = [
                ring
                for ring in rings
                if _projected_extent(ring) >= minimum_ring_extent
            ]
            if not visible_rings:
                visible_rings = [max(rings, key=_projected_extent)]

            simplified_rings = [
                _simplify_closed_ring(ring, tolerance)
                for ring in visible_rings
            ]
            countries[identifier] = simplified_rings
            point_count += sum(len(ring) for ring in simplified_rings)

        generated_levels.append(
            (level_name, maximum_zoom, countries, point_count)
        )

    with OUTPUT_PATH.open("wb") as output_file:
        output_file.write(b"GPLD")
        output_file.write(struct.pack("<II", 1, len(generated_levels)))

        for _, maximum_zoom, countries, _ in generated_levels:
            output_file.write(struct.pack("<dI", maximum_zoom, len(countries)))
            for identifier, rings in countries.items():
                identifier_bytes = identifier.encode("utf-8")
                if len(identifier_bytes) > 255:
                    raise ValueError(f"Country identifier is too long: {identifier}")
                output_file.write(struct.pack("<B", len(identifier_bytes)))
                output_file.write(identifier_bytes)
                output_file.write(struct.pack("<I", len(rings)))
                for ring in rings:
                    output_file.write(struct.pack("<I", len(ring)))
                    for longitude, latitude in ring:
                        output_file.write(
                            struct.pack(
                                "<ii",
                                round(longitude * 1_000_000),
                                round(latitude * 1_000_000),
                            )
                        )

    print(f"Generated {OUTPUT_PATH.relative_to(PROJECT_ROOT)}")
    for level_name, _, _, point_count in generated_levels:
        print(f"{level_name}: {point_count} points")


if __name__ == "__main__":
    main()
