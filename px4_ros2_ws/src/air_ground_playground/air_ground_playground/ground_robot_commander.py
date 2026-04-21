#!/usr/bin/env python3
import math
from typing import Optional

import rclpy
from geometry_msgs.msg import Twist
from rclpy.node import Node
from std_msgs.msg import Bool


class GroundRobotCommander(Node):
    def __init__(self) -> None:
        super().__init__("ground_robot_commander")

        self.declare_parameter("cmd_vel_topic", "/ugv/cmd_vel")
        self.declare_parameter("profile", "square")
        self.declare_parameter("timer_rate_hz", 10.0)
        self.declare_parameter("use_enable_topic", False)
        self.declare_parameter("enable_topic", "/playground/rover_enabled")
        self.declare_parameter("start_delay_sec", 6.0)
        self.declare_parameter("publish_idle_before_start", True)
        self.declare_parameter("linear_speed_mps", 0.2)
        self.declare_parameter("angular_speed_rps", 1.57)
        self.declare_parameter("square_side_length_m", 0.6)
        self.declare_parameter("out_and_back_distance_m", 1.0)
        self.declare_parameter("repeat_count", 1)
        self.declare_parameter("auto_stop", True)
        self.declare_parameter("publish_zero_on_shutdown", True)

        self.cmd_vel_topic = self.get_parameter("cmd_vel_topic").value
        self.profile = str(self.get_parameter("profile").value).strip().lower()
        self.timer_rate_hz = float(self.get_parameter("timer_rate_hz").value)
        self.use_enable_topic = bool(self.get_parameter("use_enable_topic").value)
        self.enable_topic = str(self.get_parameter("enable_topic").value)
        self.start_delay_sec = float(self.get_parameter("start_delay_sec").value)
        self.publish_idle_before_start = bool(
            self.get_parameter("publish_idle_before_start").value
        )
        self.linear_speed_mps = float(self.get_parameter("linear_speed_mps").value)
        self.angular_speed_rps = float(self.get_parameter("angular_speed_rps").value)
        self.square_side_length_m = float(
            self.get_parameter("square_side_length_m").value
        )
        self.out_and_back_distance_m = float(
            self.get_parameter("out_and_back_distance_m").value
        )
        self.repeat_count = int(self.get_parameter("repeat_count").value)
        self.auto_stop = bool(self.get_parameter("auto_stop").value)
        self.publish_zero_on_shutdown = bool(
            self.get_parameter("publish_zero_on_shutdown").value
        )

        if self.profile not in {"idle", "forward", "square", "out_and_back"}:
            raise ValueError(
                "profile must be one of: idle, forward, square, out_and_back"
            )
        if self.timer_rate_hz <= 0.0:
            raise ValueError("timer_rate_hz must be > 0")
        if self.linear_speed_mps <= 0.0 and self.profile != "idle":
            raise ValueError("linear_speed_mps must be > 0 for motion profiles")
        if self.angular_speed_rps <= 0.0 and self.profile in {"square", "out_and_back"}:
            raise ValueError("angular_speed_rps must be > 0 for turning profiles")
        if self.repeat_count < 1:
            raise ValueError("repeat_count must be >= 1")

        self.cmd_pub = self.create_publisher(Twist, self.cmd_vel_topic, 10)
        self.enable_sub: Optional[object] = None
        self.enable_topic_value = False
        if self.use_enable_topic:
            self.enable_sub = self.create_subscription(
                Bool,
                self.enable_topic,
                self.enable_callback,
                10,
            )

        self.launch_time_sec = self.now_sec()
        self.motion_start_sec: Optional[float] = None
        self.completed = False
        self.last_motion_label = ""

        period = 1.0 / self.timer_rate_hz
        self.timer = self.create_timer(period, self.timer_callback)

        self.get_logger().info(
            "APP_OK: ground robot commander started "
            f"profile={self.profile}, topic={self.cmd_vel_topic}, use_enable_topic={self.use_enable_topic}"
        )

    def now_sec(self) -> float:
        return self.get_clock().now().nanoseconds / 1e9

    def enable_callback(self, msg: Bool) -> None:
        self.enable_topic_value = bool(msg.data)
        self.get_logger().info(f"APP_OK: rover enable topic -> {self.enable_topic_value}")
        if self.enable_topic_value and self.motion_start_sec is None:
            self.motion_start_sec = self.now_sec()
        if not self.enable_topic_value and self.auto_stop:
            self.completed = True
            self.publish_zero_twist()

    def should_run(self) -> bool:
        if self.completed:
            return False
        if self.use_enable_topic:
            return self.enable_topic_value
        if self.motion_start_sec is None and self.now_sec() - self.launch_time_sec >= self.start_delay_sec:
            self.motion_start_sec = self.now_sec()
            self.get_logger().info("APP_OK: rover delay gate opened")
        return self.motion_start_sec is not None

    def mission_elapsed_sec(self) -> float:
        if self.motion_start_sec is None:
            return 0.0
        return max(self.now_sec() - self.motion_start_sec, 0.0)

    def square_leg_time(self) -> float:
        return self.square_side_length_m / self.linear_speed_mps

    def quarter_turn_time(self) -> float:
        return (math.pi / 2.0) / self.angular_speed_rps

    def mission_duration_sec(self) -> float:
        if self.profile == "idle":
            return 0.0
        if self.profile == "forward":
            return self.out_and_back_distance_m / self.linear_speed_mps
        if self.profile == "out_and_back":
            straight = self.out_and_back_distance_m / self.linear_speed_mps
            half_turn = math.pi / self.angular_speed_rps
            return self.repeat_count * (straight + half_turn + straight)
        single_square = 4.0 * (self.square_leg_time() + self.quarter_turn_time())
        return self.repeat_count * single_square

    def profile_twist(self) -> tuple[Twist, str]:
        twist = Twist()
        if self.profile == "idle":
            return twist, "idle"

        elapsed = self.mission_elapsed_sec()
        if self.auto_stop and elapsed >= self.mission_duration_sec():
            self.completed = True
            return twist, "complete"

        if self.profile == "forward":
            twist.linear.x = self.linear_speed_mps
            return twist, "forward"

        if self.profile == "out_and_back":
            straight = self.out_and_back_distance_m / self.linear_speed_mps
            half_turn = math.pi / self.angular_speed_rps
            cycle = straight + half_turn + straight
            phase = elapsed % cycle
            if phase < straight:
                twist.linear.x = self.linear_speed_mps
                return twist, "forward_leg"
            if phase < straight + half_turn:
                twist.angular.z = self.angular_speed_rps
                return twist, "u_turn"
            twist.linear.x = self.linear_speed_mps
            return twist, "return_leg"

        leg_time = self.square_leg_time()
        turn_time = self.quarter_turn_time()
        cycle = leg_time + turn_time
        square_phase = elapsed % (4.0 * cycle)
        edge_index = int(square_phase / cycle)
        edge_phase = square_phase - edge_index * cycle

        if edge_phase < leg_time:
            twist.linear.x = self.linear_speed_mps
            return twist, f"square_edge_{edge_index + 1}"

        twist.angular.z = self.angular_speed_rps
        return twist, f"square_turn_{edge_index + 1}"

    def publish_zero_twist(self) -> None:
        self.cmd_pub.publish(Twist())

    def timer_callback(self) -> None:
        if not self.should_run():
            if self.publish_idle_before_start:
                self.publish_zero_twist()
            return

        twist, label = self.profile_twist()
        self.cmd_pub.publish(twist)

        if label != self.last_motion_label:
            self.last_motion_label = label
            self.get_logger().info(f"APP_OK: rover motion -> {label}")

        if self.completed and self.auto_stop:
            self.publish_zero_twist()
            self.get_logger().info("APP_OK: rover mission complete")

    def destroy_node(self) -> bool:
        if self.publish_zero_on_shutdown:
            self.publish_zero_twist()
        return super().destroy_node()


def main(args=None) -> None:
    rclpy.init(args=args)
    node = GroundRobotCommander()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info("APP_OK: shutting down ground robot commander")
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
