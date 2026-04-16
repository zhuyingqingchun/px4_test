#!/usr/bin/env python3
import math
from typing import Optional

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


class OffboardTakeoffHover(Node):
    def __init__(self) -> None:
        super().__init__("offboard_takeoff_hover")

        # Parameters
        self.declare_parameter("takeoff_height_m", 5.0)
        self.declare_parameter("yaw_deg", 0.0)
        self.declare_parameter("setpoint_rate_hz", 10.0)
        self.declare_parameter("prestream_count", 10)

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

        self.target_z = -abs(self.takeoff_height_m)  # NED: upward is negative z
        self.target_yaw = math.radians(self.yaw_deg)

        # State from PX4
        self.local_position: Optional[VehicleLocalPosition] = None
        self.vehicle_status: Optional[VehicleStatus] = None
        self.latest_command_ack: Optional[VehicleCommandAck] = None

        # Hold current XY if possible
        self.home_xy_locked = False
        self.hold_x = 0.0
        self.hold_y = 0.0

        # Offboard handshake state
        self.setpoint_counter = 0
        self.offboard_mode_sent = False
        self.arm_sent = False
        self.last_offboard_request_sec = -1.0
        self.last_arm_request_sec = -1.0
        self.command_retry_sec = 1.0

        qos_profile = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )

        # Publishers
        self.offboard_control_mode_pub = self.create_publisher(
            OffboardControlMode, "/fmu/in/offboard_control_mode", qos_profile
        )
        self.trajectory_setpoint_pub = self.create_publisher(
            TrajectorySetpoint, "/fmu/in/trajectory_setpoint", qos_profile
        )
        self.vehicle_command_pub = self.create_publisher(
            VehicleCommand, "/fmu/in/vehicle_command", qos_profile
        )

        # Subscribers
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

        # Timer
        period = 1.0 / self.setpoint_rate_hz
        self.timer = self.create_timer(period, self.timer_callback)

        self.get_logger().info("APP_OK: hover node started")
        self.get_logger().info(
            f"APP_OK: hover config takeoff_height_m={self.takeoff_height_m:.2f}, "
            f"target_z={self.target_z:.2f}, "
            f"yaw_deg={self.yaw_deg:.1f}, "
            f"rate={self.setpoint_rate_hz:.1f} Hz"
        )

    def now_us(self) -> int:
        return int(self.get_clock().now().nanoseconds / 1000)

    def now_sec(self) -> float:
        return self.get_clock().now().nanoseconds / 1e9

    def local_position_callback(self, msg: VehicleLocalPosition) -> None:
        self.local_position = msg

        if not self.home_xy_locked:
            # Lock the first valid XY as hover point
            self.hold_x = float(msg.x)
            self.hold_y = float(msg.y)
            self.home_xy_locked = True
            self.get_logger().info(
                f"APP_OK: locked hover XY at x={self.hold_x:.2f}, y={self.hold_y:.2f}"
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
        # Same command pattern used in the PX4 ROS 2 offboard example
        self.publish_vehicle_command(
            VehicleCommand.VEHICLE_CMD_DO_SET_MODE,
            1.0,  # custom mode enabled
            6.0,  # PX4 offboard main mode
        )
        self.get_logger().info("APP_OK: sent OFFBOARD mode command")

    def arm(self) -> None:
        self.publish_vehicle_command(
            VehicleCommand.VEHICLE_CMD_COMPONENT_ARM_DISARM,
            1.0,
        )
        self.get_logger().info("APP_OK: sent ARM command")

    def timer_callback(self) -> None:
        # Always keep offboard heartbeat alive
        self.publish_offboard_control_mode()

        # Always keep sending the desired position setpoint
        self.publish_position_setpoint(
            self.hold_x,
            self.hold_y,
            self.target_z,
            self.target_yaw,
        )

        nav_state = self.vehicle_status.nav_state if self.vehicle_status else None
        arming_state = self.vehicle_status.arming_state if self.vehicle_status else None
        now_sec = self.now_sec()

        # PX4 requires some setpoints before switching to offboard and arming.
        # Retry commands because preflight status can become valid after the first attempt.
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

        # Optional periodic status print
        if self.local_position is not None and self.setpoint_counter % 20 == 0:
            self.get_logger().info(
                f"APP_OK: tracking "
                f"nav_state={self.vehicle_status.nav_state if self.vehicle_status else 'na'}, "
                f"arming_state={self.vehicle_status.arming_state if self.vehicle_status else 'na'}, "
                f"x={self.local_position.x:.2f}, "
                f"y={self.local_position.y:.2f}, "
                f"z={self.local_position.z:.2f} | "
                f"Target: x={self.hold_x:.2f}, y={self.hold_y:.2f}, z={self.target_z:.2f}"
            )


def main(args=None) -> None:
    rclpy.init(args=args)
    node = OffboardTakeoffHover()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info("APP_OK: shutting down hover node")
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
