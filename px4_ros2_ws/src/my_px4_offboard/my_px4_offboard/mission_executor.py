from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, List

from .offboard_state_machine import OffboardPhase, OffboardStateMachine, PhaseContext
from .safety_guard import SafetyDecision, SafetyGuard
from .trajectory_library import TrajectoryPoint, ensure_nonempty


@dataclass(frozen=True)
class MissionPlan:
    name: str
    mission_type: str
    points: List[TrajectoryPoint]


class MissionExecutor:
    """Pure-Python orchestration skeleton for future ROS 2 node integration."""

    def __init__(self, mission_plan: MissionPlan, safety_guard: SafetyGuard) -> None:
        self._mission_plan = MissionPlan(
            name=mission_plan.name,
            mission_type=mission_plan.mission_type,
            points=ensure_nonempty(mission_plan.points),
        )
        self._safety_guard = safety_guard
        self._sm = OffboardStateMachine()
        self._current_index = 0

    @property
    def phase(self) -> OffboardPhase:
        return self._sm.phase

    @property
    def active_target(self) -> TrajectoryPoint:
        return self._mission_plan.points[self._current_index]

    @property
    def mission_name(self) -> str:
        return self._mission_plan.name

    def advance(self, context: PhaseContext, current_z_m: float, elapsed_s: float) -> OffboardPhase:
        for decision in self._check_safety(current_z_m=current_z_m, elapsed_s=elapsed_s):
            if not decision.allowed:
                context.failure_reason = decision.reason
                break

        phase = self._sm.advance(context)
        if phase == OffboardPhase.MISSION and self._current_index < len(self._mission_plan.points) - 1:
            self._current_index += 1
        return phase

    def _check_safety(self, current_z_m: float, elapsed_s: float) -> Iterable[SafetyDecision]:
        yield self._safety_guard.check_altitude(current_z_m)
        yield self._safety_guard.check_timeout(elapsed_s)
