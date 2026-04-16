# 项目结构报告

## 概述

本项目是一个 PX4 + ROS 2 + Gazebo 的集成开发环境，包含自定义的 offboard 控制包和会话管理脚本。

## 目录结构

```
/home/tz/PX4_pro/
├── .git/                      # Git 仓库配置
├── .gitignore                 # Git 忽略规则
├── LICENSE                    # MIT 许可证
├── README.md                  # 项目主说明文档
├── Documents/                 # QGroundControl 文档（未提交）
├── Micro-XRCE-DDS-Agent/      # Micro XRCE-DDS Agent（未提交）
├── patch/                     # 补丁文件（未提交）
├── px4_ros2_ws/               # ROS2 工作区（部分提交）
├── px4_session_logs/          # 会话日志（未提交）
├── px4sh/                     # 会话管理脚本（已提交）
└── PX4-Autopilot/             # PX4 飞控源码（外部依赖，未提交）
```

## 已提交到 Git 的内容

### 1. px4sh/ - 会话管理脚本

#### 核心脚本
- **start.sh** - 启动完整会话（MicroXRCEAgent → PX4/Gazebo → QGC → ROS）
- **stop.sh** - 停止所有服务
- **restart.sh** - 重启会话
- **status.sh** - 检查服务状态
- **common.sh** - 公共函数库

#### 辅助脚本
- **px4ctl.sh** - PX4 控制脚本
- **read_logs.sh** - 读取日志
- **stream_log.sh** - 流式日志
- **show_alert_context.sh** - 显示警报上下文
- **status_check.sh** - 状态检查
- **clean_cache.sh** - 清理缓存

#### 配置文件
- **config.env.example** - 配置模板（推荐提交）
- **config.env** - 本地配置（已忽略，不提交）

#### 文档
- **README.md** - px4sh 说明文档
- **会话.md** - 中文说明文档
- **docs/** - 详细文档目录

### 2. px4_ros2_ws/src/my_px4_offboard/ - 自定义 offboard 控制包

#### Python 包
- **my_px4_offboard/__init__.py** - 包初始化
- **my_px4_offboard/offboard_takeoff_hover.py** - 起飞悬停控制
- **my_px4_offboard/offboard_trajectory.py** - 轨迹跟随控制

#### 配置文件
- **package.xml** - ROS2 包配置
- **setup.cfg** - Python 配置
- **setup.py** - Python 构建脚本

#### 资源文件
- **resource/my_px4_offboard** - 资源文件

### 3. 文档
- **README.md** - 项目主说明文档
- **LICENSE** - MIT 许可证

### 4. 配置
- **.gitignore** - Git 忽略规则

## 未提交到 Git 的内容

### 1. px4_ros2_ws/ - ROS2 工作区
- **build/** - 编译中间文件
- **install/** - 安装文件
- **log/** - 构建日志
- **src/px4_msgs/** - PX4 消息定义（第三方依赖）
- **src/px4_ros_com/** - PX4 ROS 通信（第三方依赖）

### 2. px4_session_logs/ - 会话日志
- 包含每次会话的日志文件
- 包含 px4.log, agent.log, qgc.log, ros_app.log 等
- 包含 alerts 和 summary 文件

### 3. Micro-XRCE-DDS-Agent/ - DDS 代理
- 第三方依赖
- Fast DDS 实现

### 4. Documents/ - QGroundControl 文档
- QGC 的配置和数据文件

### 5. patch/ - 补丁文件
- **px4_relative_paths_fix.patch** - 路径解析补丁
- **px4_start_patch_report.md** - 补丁报告
- **new.md** - 新增文档

### 6. PX4-Autopilot/ - PX4 飞控源码
- PX4 官方飞控代码
- 外部 Git 仓库

## 文件统计

### 已提交文件统计

| 目录 | 文件数 | 说明 |
|------|--------|------|
| px4sh/ | 18 | 会话管理脚本（包括 config.env.example） |
| px4_ros2_ws/src/my_px4_offboard/ | 8 | 自定义 offboard 控制包 |
| 根目录文档 | 3 | README.md, LICENSE, .gitignore |
| **总计** | **29** | 已提交文件 |

### px4sh/ 脚本详细统计

| 类型 | 文件数 | 说明 |
|------|--------|------|
| 核心脚本 | 5 | start.sh, stop.sh, restart.sh, status.sh, common.sh |
| 辅助脚本 | 7 | px4ctl.sh, read_logs.sh, stream_log.sh, show_alert_context.sh, status_check.sh, clean_cache.sh, restart.sh |
| 文档 | 2 | README.md, 会话.md |
| 配置 | 1 | config.env.example |
| **px4sh/ 总计** | **15** | |

### px4_ros2_ws/src/my_px4_offboard/ 详细统计

| 类型 | 文件数 | 说明 |
|------|--------|------|
| Python 模块 | 3 | __init__.py, offboard_takeoff_hover.py, offboard_trajectory.py |
| 配置文件 | 3 | package.xml, setup.cfg, setup.py |
| 资源文件 | 1 | resource/my_px4_offboard |
| **my_px4_offboard/ 总计** | **7** | |

## 依赖关系

### 外部依赖（需用户自行配置）
1. **PX4-Autopilot/** - PX4 飞控源码
   - 位置：`~/PX4-Autopilot/` 或在 config.env 中配置
   - 用途：飞控固件编译和仿真

2. **px4_msgs/** - PX4 ROS 2 消息定义
   - 位置：`px4_ros2_ws/src/px4_msgs/`
   - 用途：定义 PX4 与 ROS 2 之间的消息接口

3. **px4_ros_com/** - PX4 ROS 2 通信示例
   - 位置：`px4_ros2_ws/src/px4_ros_com/`
   - 用途：提供 offboard 控制等示例代码

4. **Micro-XRCE-DDS-Agent** - DDS 代理
   - 位置：`Micro-XRCE-DDS-Agent/`
   - 用途：PX4 与 ROS 2 之间的通信桥梁

### 内部依赖
- **px4sh/common.sh** 被所有 px4sh 脚本引用
- **config.env.example** 作为配置模板，用户需复制为 config.env

## 启动流程

### 完整启动顺序
```
1. Micro-XRCE-DDS Agent (DDS 通信代理)
2. PX4 + Gazebo (飞控 + 仿真器)
3. QGroundControl (地面站)
4. ROS 2 / offboard control (控制节点)
```

### 启动脚本功能
- **start.sh** - 按顺序启动所有服务
- **stop.sh** - 停止所有服务
- **restart.sh** - 重启服务

## 配置说明

### config.env.example 模板
包含以下配置项：
- 会话和路径配置
- 仿真器配置（PX4_TARGET, HEADLESS）
- Agent 配置
- ROS 2 配置
- QGC 配置
- 等待时间配置
- 日志和清理配置

### 路径解析
- 支持相对路径（如 `../PX4-Autopilot`）
- 支持绝对路径（如 `/home/user/PX4-Autopilot`）
- 支持 home 目录路径（如 `~/PX4-Autopilot`）

## 安全注意事项

### 已处理的安全问题
1. **config.env** - 包含本机路径，已从 Git 中移除
2. **.gitignore** - 正确配置，忽略敏感文件
3. **Gazebo 重复启动** - 添加了进程检测机制
4. **Agent 检查** - 改为条件触发，可跳过

### 建议
1. 不要将包含真实路径的 config.env 提交到公开仓库
2. 确保 config.env.example 作为模板保留
3. 定期检查 .gitignore 确保敏感文件不会被提交

## 版本控制

### Git 分支
- **main** - 主分支（推荐使用）
- **master** - 旧分支（已废弃）

### 提交历史
- 最新 commit: "common.sh: add resolve_path for relative paths; start.sh: improve Gazebo management"
- 总计: 3 个提交

## 使用建议

### 对于新用户
1. 复制 config.env.example 到 config.env
2. 根据实际情况修改路径配置
3. 确保所有外部依赖已克隆
4. 运行 start.sh 启动会话

### 对于开发者
1. 修改 px4sh 脚本后测试
2. 更新 config.env.example 如果添加了新配置
3. 确保 README.md 与代码保持同步

## 总结

本项目结构清晰，专注于：
1. **自定义 offboard 控制** - px4_ros2_ws/src/my_px4_offboard/
2. **会话管理** - px4sh/
3. **文档** - README.md, docs/

已提交的内容：
- ✅ 29 个文件
- ✅ 100% 为源代码和配置
- ✅ 无敏感信息
- ✅ 无第三方依赖

未提交的内容：
- ⏭️ 构建文件（可重新生成）
- ⏭️ 日志文件（可重新生成）
- ⏭️ 第三方依赖（用户自行配置）
- ⏭️ 本地配置（用户自行配置）
