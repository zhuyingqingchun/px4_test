from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass
class VehicleStateSnapshot:
    timestamp_us: int = 0
    has_heartbeat: bool = False
    has_odometry: bool = False
    armed: bool = False
    offboard_enabled: bool = False
    x_m: float = 0.0
    y_m: float = 0.0
    z_m: float = 0.0
    yaw_rad: float = 0.0
    last_error: Optional[str] = None


class Px4StateMonitor:
    """Lightweight in-memory state holder for future ROS 2 subscriber integration."""

    def __init__(self) -> None:
        self._snapshot = VehicleStateSnapshot()

    @property
    def snapshot(self) -> VehicleStateSnapshot:
        return self._snapshot

    def update_heartbeat(self, timestamp_us: int) -> None:
        self._snapshot.timestamp_us = timestamp_us
        self._snapshot.has_heartbeat = True

    def update_odometry(self, x_m: float, y_m: float, z_m: float, yaw_rad: float, timestamp_us: int) -> None:
        self._snapshot.timestamp_us = timestamp_us
        self._snapshot.has_odometry = True
        self._snapshot.x_m = x_m
        self._snapshot.y_m = y_m
        self._snapshot.z_m = z_m
        self._snapshot.yaw_rad = yaw_rad

    def update_mode(self, armed: bool, offboard_enabled: bool) -> None:
        self._snapshot.armed = armed
        self._snapshot.offboard_enabled = offboard_enabled

    def set_error(self, message: str) -> None:
        self._snapshot.last_error = message
