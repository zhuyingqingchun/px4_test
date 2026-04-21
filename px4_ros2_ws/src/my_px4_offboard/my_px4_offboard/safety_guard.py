from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class SafetyLimits:
    max_height_m: float
    mission_timeout_s: float


@dataclass(frozen=True)
class SafetyDecision:
    allowed: bool
    reason: Optional[str] = None


class SafetyGuard:
    def __init__(self, limits: SafetyLimits) -> None:
        if limits.max_height_m <= 0.0:
            raise ValueError('max_height_m must be > 0')
        if limits.mission_timeout_s <= 0.0:
            raise ValueError('mission_timeout_s must be > 0')
        self._limits = limits

    def check_altitude(self, z_m: float) -> SafetyDecision:
        current_height_m = abs(z_m)
        if current_height_m > self._limits.max_height_m:
            return SafetyDecision(False, f'altitude limit exceeded: {current_height_m:.2f}m')
        return SafetyDecision(True)

    def check_timeout(self, elapsed_s: float) -> SafetyDecision:
        if elapsed_s > self._limits.mission_timeout_s:
            return SafetyDecision(False, f'mission timeout exceeded: {elapsed_s:.1f}s')
        return SafetyDecision(True)
