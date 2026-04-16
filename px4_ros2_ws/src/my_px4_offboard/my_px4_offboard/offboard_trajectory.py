#!/usr/bin/env python3
import math
from typing import Optional, Tuple

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


class OffboardTrajectory(Node):
    def __init__(self) -> None:
        super().__init__("offboard_trajectory")

        self.declare_parameter("takeoff_height_m", 5.0)
        self.declare_parameter("yaw_deg", 0.0)
        self.declare_parameter("setpoint_rate_hz", 20.0)
        self.declare_parameter("prestream_count", 20)
        self.declare_parameter("initial_hover_sec", 5.0)
        self.declare_parameter("trajectory_type", "circle")
        self.declare_parameter("trajectory_radius_m", 2.0)
        self.declare_parameter("trajectory_period_sec", 20.0)

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
        self.initial_hover_sec = float(
            self.get_parameter("initial_hover_sec").get_parameter_value().double_value
        )
        self.trajectory_type = (
            self.get_parameter("trajectory_type").get_parameter_value().string_value
        ).strip().lower()
        self.trajectory_radius_m = float(
            self.get_parameter("trajectory_radius_m").get_parameter_value().double_value
        )
        self.trajectory_period_sec = float(
            self.get_parameter("trajectory_period_sec").get_parameter_value().double_value
        )

        if self.trajectory_type not in {"circle", "figure8"}:
            raise ValueError("trajectory_type must be one of: circle, figure8")

        self.target_z = -abs(self.takeoff_height_m)
        self.target_yaw = math.radians(self.yaw_deg)

        self.local_position: Optional[VehicleLocalPosition] = None
        self.vehicle_status: Optional[VehicleStatus] = None
        self.latest_command_ack: Optional[VehicleCommandAck] = None

        self.home_xy_locked = False
        self.home_x = 0.0
        self.home_y = 0.0

        self.setpoint_counter = 0
        self.offboard_mode_sent = False
        self.arm_sent = False
        self.phase = "prestream"
        self.trajectory_start_time: Optional[float] = None
        self.last_offboard_request_sec = -1.0
        self.last_arm_request_sec = -1.0
        self.command_retry_sec = 1.0

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

        self.get_logger().info("APP_OK: trajectory node started")
        self.get_logger().info(
            "APP_OK: trajectory config "
            f"type={self.trajectory_type}, radius={self.trajectory_radius_m:.2f} m, "
            f"period={self.trajectory_period_sec:.2f} s, target_z={self.target_z:.2f}"
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
        self.vehicle_status = msg

    def vehicle_command_ack_callback(self, msg: VehicleCommandAck) -> None:
        self.latest_command_ack = msg
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

    def desired_setpoint(self) -> Tuple[float, float, float]:
        if self.trajectory_start_time is None:
            return self.home_x, self.home_y, self.target_z

        t = self.now_sec() - self.trajectory_start_time
        omega = (2.0 * math.pi) / max(self.trajectory_period_sec, 0.1)
        phase = omega * t
        radius = self.trajectory_radius_m

        if self.trajectory_type == "circle":
            x = self.home_x + radius * math.cos(phase)
            y = self.home_y + radius * math.sin(phase)
        else:
            x = self.home_x + radius * math.sin(phase)
            y = self.home_y + 0.5 * radius * math.sin(2.0 * phase)

        return x, y, self.target_z

    def update_phase(self) -> None:
        if (
            self.phase == "prestream"
            and self.vehicle_status is not None
            and self.vehicle_status.nav_state == VehicleStatus.NAVIGATION_STATE_OFFBOARD
            and self.vehicle_status.arming_state == VehicleStatus.ARMING_STATE_ARMED
        ):
            self.phase = "takeoff_hold"
            self.trajectory_start_time = self.now_sec() + self.initial_hover_sec
            self.get_logger().info(
                f"APP_OK: entering takeoff hold for {self.initial_hover_sec:.1f} s"
            )
            return

        if self.phase == "takeoff_hold" and self.trajectory_start_time is not None:
            if self.now_sec() >= self.trajectory_start_time:
                self.phase = "trajectory"
                self.trajectory_start_time = self.now_sec()
                self.get_logger().info(
                    f"APP_OK: starting trajectory {self.trajectory_type}"
                )

    def timer_callback(self) -> None:
        self.publish_offboard_control_mode()

        if self.phase == "trajectory":
            sp_x, sp_y, sp_z = self.desired_setpoint()
        else:
            sp_x, sp_y, sp_z = self.home_x, self.home_y, self.target_z

        self.publish_position_setpoint(sp_x, sp_y, sp_z, self.target_yaw)

        nav_state = self.vehicle_status.nav_state if self.vehicle_status else None
        arming_state = self.vehicle_status.arming_state if self.vehicle_status else None
        now_sec = self.now_sec()

        if self.setpoint_counter >= self.prestream_count:
            if (
                nav_state != VehicleStatus.NAVIGATION_STATE_OFFBOARD
                and now_sec - self.last_offboard_request_sec >= self.command_retry_sec
            ):
                self.engage_offboard_mode()
                self.offboard_mode_sent = True
                self.last_offboard_request_sec = now_sec
            if (
                arming_state != VehicleStatus.ARMING_STATE_ARMED
                and now_sec - self.last_arm_request_sec >= self.command_retry_sec
            ):
                self.arm()
                self.arm_sent = True
                self.last_arm_request_sec = now_sec

        if self.setpoint_counter < self.prestream_count + 1:
            self.setpoint_counter += 1

        self.update_phase()

        if self.local_position is not None and self.setpoint_counter % 40 == 0:
            self.get_logger().info(
                "APP_OK: tracking "
                f"phase={self.phase}, "
                f"pos=({self.local_position.x:.2f}, {self.local_position.y:.2f}, {self.local_position.z:.2f}), "
                f"sp=({sp_x:.2f}, {sp_y:.2f}, {sp_z:.2f})"
            )


def main(args=None) -> None:
    rclpy.init(args=args)
    node = OffboardTrajectory()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info("APP_OK: shutting down trajectory node")
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
