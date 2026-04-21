from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable, List


@dataclass(frozen=True)
class TrajectoryPoint:
    x_m: float
    y_m: float
    z_m: float
    yaw_rad: float = 0.0
    dwell_s: float = 0.0


def hover_point(x_m: float, y_m: float, z_m: float, yaw_rad: float = 0.0, dwell_s: float = 0.0) -> TrajectoryPoint:
    _validate_finite(x_m, y_m, z_m, yaw_rad, dwell_s)
    return TrajectoryPoint(x_m=x_m, y_m=y_m, z_m=z_m, yaw_rad=yaw_rad, dwell_s=dwell_s)


def square_trajectory(
    center_x_m: float,
    center_y_m: float,
    altitude_m: float,
    side_length_m: float,
    dwell_s: float = 0.0,
    yaw_rad: float = 0.0,
    include_return_to_start: bool = True,
) -> List[TrajectoryPoint]:
    _validate_finite(center_x_m, center_y_m, altitude_m, side_length_m, dwell_s, yaw_rad)
    if side_length_m <= 0.0:
        raise ValueError('side_length_m must be > 0')
    if altitude_m <= 0.0:
        raise ValueError('altitude_m must be > 0')
    if dwell_s < 0.0:
        raise ValueError('dwell_s must be >= 0')

    half = side_length_m / 2.0
    z_m = -altitude_m  # PX4 local NED convention
    corners = [
        (center_x_m - half, center_y_m - half),
        (center_x_m + half, center_y_m - half),
        (center_x_m + half, center_y_m + half),
        (center_x_m - half, center_y_m + half),
    ]
    points = [
        TrajectoryPoint(x_m=x, y_m=y, z_m=z_m, yaw_rad=yaw_rad, dwell_s=dwell_s)
        for x, y in corners
    ]
    if include_return_to_start:
        points.append(points[0])
    return points


def out_and_back_trajectory(
    start_x_m: float,
    start_y_m: float,
    altitude_m: float,
    distance_x_m: float,
    dwell_s: float = 0.0,
    yaw_rad: float = 0.0,
) -> List[TrajectoryPoint]:
    _validate_finite(start_x_m, start_y_m, altitude_m, distance_x_m, dwell_s, yaw_rad)
    if altitude_m <= 0.0:
        raise ValueError('altitude_m must be > 0')
    if dwell_s < 0.0:
        raise ValueError('dwell_s must be >= 0')

    z_m = -altitude_m
    start = TrajectoryPoint(start_x_m, start_y_m, z_m, yaw_rad=yaw_rad, dwell_s=dwell_s)
    target = TrajectoryPoint(start_x_m + distance_x_m, start_y_m, z_m, yaw_rad=yaw_rad, dwell_s=dwell_s)
    return [start, target, start]


def ensure_nonempty(points: Iterable[TrajectoryPoint]) -> List[TrajectoryPoint]:
    point_list = list(points)
    if not point_list:
        raise ValueError('trajectory must contain at least one point')
    return point_list


def _validate_finite(*values: float) -> None:
    for value in values:
        if not isfinite(value):
            raise ValueError(f'non-finite value detected: {value!r}')
