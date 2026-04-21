from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class OffboardPhase(str, Enum):
    WAITING_FOR_HEARTBEAT = 'waiting_for_heartbeat'
    WAITING_FOR_ODOMETRY = 'waiting_for_odometry'
    ARMING = 'arming'
    ENTERING_OFFBOARD = 'entering_offboard'
    TAKEOFF = 'takeoff'
    HOVER = 'hover'
    MISSION = 'mission'
    LANDING = 'landing'
    DISARMED = 'disarmed'
    FAILED = 'failed'


@dataclass
class PhaseContext:
    has_heartbeat: bool = False
    has_odometry: bool = False
    is_armed: bool = False
    is_offboard: bool = False
    takeoff_reached: bool = False
    mission_completed: bool = False
    landing_completed: bool = False
    failure_reason: Optional[str] = None


@dataclass
class OffboardStateMachine:
    phase: OffboardPhase = OffboardPhase.WAITING_FOR_HEARTBEAT
    history: list[OffboardPhase] = field(default_factory=lambda: [OffboardPhase.WAITING_FOR_HEARTBEAT])

    def advance(self, context: PhaseContext) -> OffboardPhase:
        if context.failure_reason:
            return self._set_phase(OffboardPhase.FAILED)

        if self.phase == OffboardPhase.WAITING_FOR_HEARTBEAT:
            if context.has_heartbeat:
                return self._set_phase(OffboardPhase.WAITING_FOR_ODOMETRY)
            return self.phase

        if self.phase == OffboardPhase.WAITING_FOR_ODOMETRY:
            if context.has_odometry:
                return self._set_phase(OffboardPhase.ARMING)
            return self.phase

        if self.phase == OffboardPhase.ARMING:
            if context.is_armed:
                return self._set_phase(OffboardPhase.ENTERING_OFFBOARD)
            return self.phase

        if self.phase == OffboardPhase.ENTERING_OFFBOARD:
            if context.is_offboard:
                return self._set_phase(OffboardPhase.TAKEOFF)
            return self.phase

        if self.phase == OffboardPhase.TAKEOFF:
            if context.takeoff_reached:
                return self._set_phase(OffboardPhase.HOVER)
            return self.phase

        if self.phase == OffboardPhase.HOVER:
            return self._set_phase(OffboardPhase.MISSION)

        if self.phase == OffboardPhase.MISSION:
            if context.mission_completed:
                return self._set_phase(OffboardPhase.LANDING)
            return self.phase

        if self.phase == OffboardPhase.LANDING:
            if context.landing_completed:
                return self._set_phase(OffboardPhase.DISARMED)
            return self.phase

        return self.phase

    def fail(self, reason: str) -> OffboardPhase:
        if not reason:
            raise ValueError('failure reason must not be empty')
        return self._set_phase(OffboardPhase.FAILED)

    def _set_phase(self, new_phase: OffboardPhase) -> OffboardPhase:
        if new_phase != self.phase:
            self.phase = new_phase
            self.history.append(new_phase)
        return self.phase
