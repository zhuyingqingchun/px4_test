#!/usr/bin/env python3
"""
PX4 实时位置可视化脚本
订阅 /fmu/out/vehicle_local_position_v1，实时显示 3D 轨迹
"""

import argparse
import sys
import time
from datetime import datetime

import rclpy
from rclpy.node import Node
from px4_msgs.msg import VehicleLocalPosition
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import numpy as np


class PositionPlotter(Node):
    def __init__(self, csv_path=None):
        super().__init__('px4_position_plotter')
        
        self.csv_path = csv_path
        self.x_list = []
        self.y_list = []
        self.z_up_list = []  # z_up = -z (更直观的向上)
        self.start_time = None
        
        # 创建 CSV 文件（如果有指定）
        self.csv_file = None
        if self.csv_path:
            self.csv_file = open(self.csv_path, 'w')
            self.csv_file.write('timestamp,x,y,z,z_up\n')
        
        # 订阅话题
        self.subscription = self.create_subscription(
            VehicleLocalPosition,
            '/fmu/out/vehicle_local_position_v1',
            self.listener_callback,
            10)
        
        self.get_logger().info('Position plotter started. Waiting for data...')
    
    def listener_callback(self, msg):
        if self.start_time is None:
            self.start_time = time.time()
        
        # PX4 本地坐标：x/y 平面，z 向下为正
        # 为了更直观，我们把 z 转成 z_up = -z（向上为正）
        x = msg.x
        y = msg.y
        z = msg.z
        z_up = -z  # 转换为更直观的向上坐标
        
        self.x_list.append(x)
        self.y_list.append(y)
        self.z_up_list.append(z_up)
        
        # 打印实时坐标
        elapsed = time.time() - self.start_time
        print(f'\r[Time {elapsed:.2f}s] x={x:7.2f} y={y:7.2f} z_up={z_up:7.2f} (pts: {len(self.x_list)})', end='')
        
        # 写入 CSV
        if self.csv_file:
            self.csv_file.write(f'{msg.timestamp},{x},{y},{z},{z_up}\n')
    
    def close(self):
        if self.csv_file:
            self.csv_file.close()
        self.get_logger().info(f'\nSaved {len(self.x_list)} points')


def main(args=None):
    parser = argparse.ArgumentParser(description='PX4 Live Position Plotter')
    parser.add_argument('--csv', type=str, help='Save trajectory to CSV file')
    parser.add_argument('--no-plot', action='store_true', help='Only print coordinates, no plot')
    parsed_args = parser.parse_args(args)
    
    rclpy.init(args=args)
    plotter = PositionPlotter(csv_path=parsed_args.csv)
    
    try:
        if parsed_args.no_plot:
            # 只打印，不绘图
            rclpy.spin(plotter)
        else:
            # 启动实时绘图
            fig = plt.figure(figsize=(12, 8))
            ax = fig.add_subplot(111, projection='3d')
            
            line, = ax.plot([], [], [], 'b-', linewidth=2, label='Trajectory')
            point, = ax.plot([], [], [], 'ro', markersize=8, label='Current')
            start_point, = ax.plot([0], [0], [0], 'go', markersize=10, label='Start')
            
            ax.set_xlabel('X (m)')
            ax.set_ylabel('Y (m)')
            ax.set_zlabel('Z_up (m)')  # 使用 z_up 更直观
            ax.set_title('PX4 Vehicle Local Position - 3D Trajectory')
            ax.legend()
            ax.grid(True)
            
            # 初始视角
            ax.view_init(elev=20, azim=45)
            
            def init():
                line.set_data([], [])
                line.set_3d_properties([])
                point.set_data([], [])
                point.set_3d_properties([])
                return line, point
            
            def update(frame):
                if len(plotter.x_list) > 0:
                    line.set_data(plotter.x_list, plotter.y_list)
                    line.set_3d_properties(plotter.z_up_list)
                    
                    if len(plotter.x_list) > 0:
                        point.set_data([plotter.x_list[-1]], [plotter.y_list[-1]])
                        point.set_3d_properties([plotter.z_up_list[-1]])
                    
                    # 自动调整坐标轴范围
                    all_x = plotter.x_list + [0]
                    all_y = plotter.y_list + [0]
                    all_z = plotter.z_up_list + [0]
                    
                    ax.set_xlim(min(all_x) - 1, max(all_x) + 1)
                    ax.set_ylim(min(all_y) - 1, max(all_y) + 1)
                    ax.set_zlim(min(all_z) - 1, max(all_z) + 1)
                
                return line, point
            
            ani = FuncAnimation(fig, update, init_func=init, interval=100, blit=False, cache_frame_data=False)
            
            print("Close the plot window to exit...")
            plt.show()
    
    except KeyboardInterrupt:
        pass
    finally:
        plotter.close()
        plotter.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
