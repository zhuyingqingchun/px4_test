#!/usr/bin/env python3
from typing import Optional

import rclpy
from geometry_msgs.msg import Twist, TwistStamped
from rclpy.node import Node


class TwistToTwistStampedBridge(Node):
    def __init__(self) -> None:
        super().__init__("twist_to_twist_stamped_bridge")

        self.declare_parameter("input_topic", "/ugv/cmd_vel_unstamped")
        self.declare_parameter("output_topic", "/cmd_vel")
        self.declare_parameter("frame_id", "base_link")

        input_topic = self.get_parameter("input_topic").get_parameter_value().string_value
        output_topic = self.get_parameter("output_topic").get_parameter_value().string_value
        self.frame_id = self.get_parameter("frame_id").get_parameter_value().string_value

        self.publisher = self.create_publisher(TwistStamped, output_topic, 10)
        self.subscription = self.create_subscription(
            Twist,
            input_topic,
            self._callback,
            10,
        )

        self.get_logger().info(
            f"APP_OK: bridge {input_topic} (Twist) -> {output_topic} (TwistStamped)"
        )

    def _callback(self, msg: Twist) -> None:
        stamped = TwistStamped()
        stamped.header.stamp = self.get_clock().now().to_msg()
        stamped.header.frame_id = self.frame_id
        stamped.twist = msg
        self.publisher.publish(stamped)


def main(args: Optional[list[str]] = None) -> None:
    rclpy.init(args=args)
    node = TwistToTwistStampedBridge()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info("APP_OK: shutting down twist bridge")
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
