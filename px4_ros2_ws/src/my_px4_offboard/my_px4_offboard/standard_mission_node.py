#!/usr/bin/env python3
import math
from enum import Enum
from typing import List, Optional, Tuple

import rclpy
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy

from px4_msgs.msg import (
    OffboardControlMode,
    TrajectorySetpoint,
    VehicleCommand,
    VehicleCommandAck,
    VehicleLocalPosition,
    VehicleStatus,
)


class MissionState(str, Enum):
    PRESTREAM = "prestream"
    REQUEST_OFFBOARD = "request_offboard"
    REQUEST_ARM = "request_arm"
    TAKEOFF_HOLD = "takeoff_hold"
    MISSION = "mission"
    POST_MISSION_HOLD = "post_mission_hold"
    REQUEST_LAND = "request_land"
    COMPLETE = "complete"


class StandardMissionNode(Node):
    def __init__(self) -> None:
        super().__init__("standard_mission")

        self.declare_parameter("mission_type", "hover")
        self.declare_parameter("takeoff_height_m", 3.0)
        self.declare_parameter("yaw_deg", 0.0)
        self.declare_parameter("setpoint_rate_hz", 20.0)
        self.declare_parameter("prestream_count", 20)
        self.declare_parameter("takeoff_hold_sec", 4.0)
        self.declare_parameter("hover_hold_sec", 8.0)
        self.declare_parameter("post_mission_hold_sec", 3.0)
        self.declare_parameter("square_side_length_m", 2.0)
        self.declare_parameter("square_leg_duration_sec", 4.0)
        self.declare_parameter("square_repeat_count", 1)
        self.declare_parameter("command_retry_sec", 1.0)
        self.declare_parameter("auto_land", True)
        self.declare_parameter("enable_debug_trace", False)

        self.mission_type = (
            self.get_parameter("mission_type").get_parameter_value().string_value
        ).strip().lower()
        self.takeoff_height_m = float(
            self.get_parameter("takeoff_height_m").get_parameter_value().double_value
        )
        self.yaw_deg = float(
            self.get_parameter("yaw_deg").get_parameter_value().double_value
        )
        self.setpoint_rate_hz = float(
            self.get_parameter("setpoint_rate_hz").get_parameter_value().double_value
        )
        self.prestream_count = int(
            self.get_parameter("prestream_count").get_parameter_value().integer_value
        )
        self.takeoff_hold_sec = float(
            self.get_parameter("takeoff_hold_sec").get_parameter_value().double_value
        )
        self.hover_hold_sec = float(
            self.get_parameter("hover_hold_sec").get_parameter_value().double_value
        )
        self.post_mission_hold_sec = float(
            self.get_parameter("post_mission_hold_sec")
            .get_parameter_value()
            .double_value
        )
        self.square_side_length_m = float(
            self.get_parameter("square_side_length_m")
            .get_parameter_value()
            .double_value
        )
        self.square_leg_duration_sec = float(
            self.get_parameter("square_leg_duration_sec")
            .get_parameter_value()
            .double_value
        )
        self.square_repeat_count = int(
            self.get_parameter("square_repeat_count")
            .get_parameter_value()
            .integer_value
        )
        self.command_retry_sec = float(
            self.get_parameter("command_retry_sec").get_parameter_value().double_value
        )
        self.auto_land = (
            self.get_parameter("auto_land").get_parameter_value().bool_value
        )
        self.enable_debug_trace = (
            self.get_parameter("enable_debug_trace").get_parameter_value().bool_value
        )

        if self.mission_type not in {"hover", "square"}:
            raise ValueError("mission_type must be one of: hover, square")
        if self.square_leg_duration_sec <= 0.0:
            raise ValueError("square_leg_duration_sec must be > 0")
        if self.square_repeat_count < 1:
            raise ValueError("square_repeat_count must be >= 1")

        self.target_z = -abs(self.takeoff_height_m)
        self.target_yaw = math.radians(self.yaw_deg)

        self.local_position: Optional[VehicleLocalPosition] = None
        self.vehicle_status: Optional[VehicleStatus] = None
        self.latest_command_ack: Optional[VehicleCommandAck] = None

        self.home_xy_locked = False
        self.home_x = 0.0
        self.home_y = 0.0

        self.state = MissionState.PRESTREAM
        self.state_deadline_sec: Optional[float] = None
        self.mission_start_sec: Optional[float] = None
        self.setpoint_counter = 0
        self.last_offboard_request_sec = -1.0
        self.last_arm_request_sec = -1.0
        self.last_land_request_sec = -1.0
        self.last_nav_state: Optional[int] = None
        self.last_arming_state: Optional[int] = None
        self.last_state_log = ""
        self.tracked_command_ids = {
            VehicleCommand.VEHICLE_CMD_DO_SET_MODE,
            VehicleCommand.VEHICLE_CMD_COMPONENT_ARM_DISARM,
            getattr(VehicleCommand, "VEHICLE_CMD_NAV_LAND", 21),
        }

        qos_profile = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )

        self.offboard_control_mode_pub = self.create_publisher(
            OffboardControlMode, "/fmu/in/offboard_control_mode", qos_profile
        )
        self.trajectory_setpoint_pub = self.create_publisher(
            TrajectorySetpoint, "/fmu/in/trajectory_setpoint", qos_profile
        )
        self.vehicle_command_pub = self.create_publisher(
            VehicleCommand, "/fmu/in/vehicle_command", qos_profile
        )

        self.local_pos_sub = self.create_subscription(
            VehicleLocalPosition,
            "/fmu/out/vehicle_local_position_v1",
            self.local_position_callback,
            qos_profile,
        )
        self.vehicle_status_sub = self.create_subscription(
            VehicleStatus,
            "/fmu/out/vehicle_status_v3",
            self.vehicle_status_callback,
            qos_profile,
        )
        self.vehicle_command_ack_sub = self.create_subscription(
            VehicleCommandAck,
            "/fmu/out/vehicle_command_ack_v1",
            self.vehicle_command_ack_callback,
            qos_profile,
        )

        period = 1.0 / self.setpoint_rate_hz
        self.timer = self.create_timer(period, self.timer_callback)

        self.get_logger().info("APP_OK: standard mission node started")
        self.get_logger().info(
            "APP_OK: mission config "
            f"type={self.mission_type}, target_z={self.target_z:.2f}, "
            f"yaw_deg={self.yaw_deg:.1f}, auto_land={self.auto_land}"
        )

    def now_us(self) -> int:
        return int(self.get_clock().now().nanoseconds / 1000)

    def now_sec(self) -> float:
        return self.get_clock().now().nanoseconds / 1e9

    def local_position_callback(self, msg: VehicleLocalPosition) -> None:
        self.local_position = msg

        if not self.home_xy_locked:
            self.home_x = float(msg.x)
            self.home_y = float(msg.y)
            self.home_xy_locked = True
            self.get_logger().info(
                f"APP_OK: locked home XY x={self.home_x:.2f}, y={self.home_y:.2f}"
            )

    def vehicle_status_callback(self, msg: VehicleStatus) -> None:
        prev_nav_state = self.last_nav_state
        prev_arming_state = self.last_arming_state

        self.vehicle_status = msg
        self.last_nav_state = int(msg.nav_state)
        self.last_arming_state = int(msg.arming_state)

        if prev_nav_state is not None and prev_nav_state != self.last_nav_state:
            self.get_logger().info(
                f"APP_OK: nav_state changed {prev_nav_state} -> {self.last_nav_state}"
            )

        if (
            prev_arming_state is not None
            and prev_arming_state != self.last_arming_state
        ):
            self.get_logger().info(
                "APP_OK: arming_state changed "
                f"{prev_arming_state} -> {self.last_arming_state}"
            )

    def vehicle_command_ack_callback(self, msg: VehicleCommandAck) -> None:
        self.latest_command_ack = msg
        if int(msg.command) not in self.tracked_command_ids:
            return

        if msg.result == VehicleCommandAck.VEHICLE_CMD_RESULT_ACCEPTED:
            self.get_logger().info(
                f"APP_OK: vehicle command accepted command={msg.command}"
            )
        else:
            self.get_logger().warn(
                f"APP_WARN: vehicle command ack command={msg.command}, result={msg.result}"
            )

    def publish_offboard_control_mode(self) -> None:
        msg = OffboardControlMode()
        msg.timestamp = self.now_us()
        msg.position = True
        msg.velocity = False
        msg.acceleration = False
        msg.attitude = False
        msg.body_rate = False
        msg.thrust_and_torque = False
        msg.direct_actuator = False
        self.offboard_control_mode_pub.publish(msg)

    def publish_position_setpoint(self, x: float, y: float, z: float, yaw: float) -> None:
        msg = TrajectorySetpoint()
        msg.timestamp = self.now_us()
        msg.position = [float(x), float(y), float(z)]
        msg.velocity = [math.nan, math.nan, math.nan]
        msg.acceleration = [math.nan, math.nan, math.nan]
        msg.jerk = [math.nan, math.nan, math.nan]
        msg.yaw = float(yaw)
        msg.yawspeed = math.nan
        self.trajectory_setpoint_pub.publish(msg)

    def publish_vehicle_command(
        self,
        command: int,
        param1: float = 0.0,
        param2: float = 0.0,
        param3: float = 0.0,
        param4: float = 0.0,
        param5: float = 0.0,
        param6: float = 0.0,
        param7: float = 0.0,
    ) -> None:
        msg = VehicleCommand()
        msg.timestamp = self.now_us()
        msg.param1 = float(param1)
        msg.param2 = float(param2)
        msg.param3 = float(param3)
        msg.param4 = float(param4)
        msg.param5 = float(param5)
        msg.param6 = float(param6)
        msg.param7 = float(param7)
        msg.command = int(command)
        msg.target_system = 1
        msg.target_component = 1
        msg.source_system = 1
        msg.source_component = 1
        msg.from_external = True
        self.vehicle_command_pub.publish(msg)

    def engage_offboard_mode(self) -> None:
        self.publish_vehicle_command(
            VehicleCommand.VEHICLE_CMD_DO_SET_MODE,
            1.0,
            6.0,
        )
        self.get_logger().info("APP_OK: sent OFFBOARD mode command")

    def arm(self) -> None:
        self.publish_vehicle_command(
            VehicleCommand.VEHICLE_CMD_COMPONENT_ARM_DISARM,
            1.0,
        )
        self.get_logger().info("APP_OK: sent ARM command")

    def land(self) -> None:
        self.publish_vehicle_command(
            getattr(VehicleCommand, "VEHICLE_CMD_NAV_LAND", 21),
        )
        self.get_logger().info("APP_OK: sent LAND command")

    def is_offboard_active(self) -> bool:
        return (
            self.vehicle_status is not None
            and self.vehicle_status.nav_state == VehicleStatus.NAVIGATION_STATE_OFFBOARD
        )

    def is_armed(self) -> bool:
        return (
            self.vehicle_status is not None
            and self.vehicle_status.arming_state == VehicleStatus.ARMING_STATE_ARMED
        )

    def set_state(
        self,
        new_state: MissionState,
        duration_sec: Optional[float] = None,
    ) -> None:
        self.state = new_state
        self.state_deadline_sec = None
        if duration_sec is not None:
            self.state_deadline_sec = self.now_sec() + duration_sec
        self.get_logger().info(f"APP_OK: state -> {new_state.value}")

    def square_waypoints(self) -> List[Tuple[float, float]]:
        side = self.square_side_length_m
        return [
            (self.home_x, self.home_y),
            (self.home_x + side, self.home_y),
            (self.home_x + side, self.home_y + side),
            (self.home_x, self.home_y + side),
            (self.home_x, self.home_y),
        ]

    def mission_setpoint(self) -> Tuple[float, float, float]:
        if self.mission_type == "hover" or self.mission_start_sec is None:
            return self.home_x, self.home_y, self.target_z

        waypoints = self.square_waypoints()
        segment_count = len(waypoints) - 1
        elapsed = max(self.now_sec() - self.mission_start_sec, 0.0)
        total_duration = segment_count * self.square_leg_duration_sec
        cycle_duration = total_duration * self.square_repeat_count

        if elapsed >= cycle_duration:
            return self.home_x, self.home_y, self.target_z

        cycle_elapsed = elapsed % total_duration
        segment_index = min(
            int(cycle_elapsed / self.square_leg_duration_sec), segment_count - 1
        )
        segment_elapsed = cycle_elapsed - segment_index * self.square_leg_duration_sec
        alpha = min(max(segment_elapsed / self.square_leg_duration_sec, 0.0), 1.0)

        start_x, start_y = waypoints[segment_index]
        end_x, end_y = waypoints[segment_index + 1]
        x = start_x + alpha * (end_x - start_x)
        y = start_y + alpha * (end_y - start_y)
        return x, y, self.target_z

    def mission_duration_sec(self) -> float:
        if self.mission_type == "hover":
            return self.hover_hold_sec
        segment_count = len(self.square_waypoints()) - 1
        return segment_count * self.square_leg_duration_sec * self.square_repeat_count

    def should_finish_mission(self) -> bool:
        if self.mission_start_sec is None:
            return False
        return (self.now_sec() - self.mission_start_sec) >= self.mission_duration_sec()

    def maybe_request_mode_transitions(self) -> None:
        if self.setpoint_counter < self.prestream_count:
            return

        now_sec = self.now_sec()

        if self.state in {MissionState.PRESTREAM, MissionState.REQUEST_OFFBOARD}:
            self.set_state(MissionState.REQUEST_OFFBOARD)
            if not self.is_offboard_active():
                if now_sec - self.last_offboard_request_sec >= self.command_retry_sec:
                    self.engage_offboard_mode()
                    self.last_offboard_request_sec = now_sec
                return

        if self.state == MissionState.REQUEST_OFFBOARD and self.is_offboard_active():
            self.set_state(MissionState.REQUEST_ARM)

        if self.state == MissionState.REQUEST_ARM:
            if not self.is_armed():
                if now_sec - self.last_arm_request_sec >= self.command_retry_sec:
                    self.arm()
                    self.last_arm_request_sec = now_sec
                return
            self.set_state(MissionState.TAKEOFF_HOLD, self.takeoff_hold_sec)

    def update_state_machine(self) -> None:
        self.maybe_request_mode_transitions()

        if self.state == MissionState.TAKEOFF_HOLD and self.state_deadline_sec is not None:
            if self.now_sec() >= self.state_deadline_sec:
                self.mission_start_sec = self.now_sec()
                self.set_state(MissionState.MISSION)

        elif self.state == MissionState.MISSION and self.should_finish_mission():
            if self.post_mission_hold_sec > 0.0:
                self.set_state(MissionState.POST_MISSION_HOLD, self.post_mission_hold_sec)
            elif self.auto_land:
                self.set_state(MissionState.REQUEST_LAND)
            else:
                self.set_state(MissionState.COMPLETE)

        elif (
            self.state == MissionState.POST_MISSION_HOLD
            and self.state_deadline_sec is not None
            and self.now_sec() >= self.state_deadline_sec
        ):
            if self.auto_land:
                self.set_state(MissionState.REQUEST_LAND)
            else:
                self.set_state(MissionState.COMPLETE)

        elif self.state == MissionState.REQUEST_LAND:
            now_sec = self.now_sec()
            if now_sec - self.last_land_request_sec >= self.command_retry_sec:
                self.land()
                self.last_land_request_sec = now_sec

            if self.vehicle_status is not None and not self.is_armed():
                self.set_state(MissionState.COMPLETE)

    def active_setpoint(self) -> Tuple[float, float, float]:
        if self.state == MissionState.MISSION:
            return self.mission_setpoint()
        return self.home_x, self.home_y, self.target_z

    def timer_callback(self) -> None:
        self.publish_offboard_control_mode()
        sp_x, sp_y, sp_z = self.active_setpoint()
        self.publish_position_setpoint(sp_x, sp_y, sp_z, self.target_yaw)

        if self.setpoint_counter < self.prestream_count + 1:
            self.setpoint_counter += 1

        self.update_state_machine()

        if self.local_position is not None and self.setpoint_counter % 40 == 0:
            self.get_logger().info(
                "APP_OK: tracking "
                f"state={self.state.value}, "
                f"pos=({self.local_position.x:.2f}, {self.local_position.y:.2f}, {self.local_position.z:.2f}), "
                f"sp=({sp_x:.2f}, {sp_y:.2f}, {sp_z:.2f})"
            )
        elif self.enable_debug_trace and self.setpoint_counter % 20 == 0:
            self.get_logger().info(
                f"APP_OK: tracking state={self.state.value}, sp=({sp_x:.2f}, {sp_y:.2f}, {sp_z:.2f})"
            )


def main(args=None) -> None:
    rclpy.init(args=args)
    node = StandardMissionNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info("APP_OK: shutting down standard mission node")
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
