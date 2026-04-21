from glob import glob
from setuptools import setup

package_name = "air_ground_playground"

setup(
    name=package_name,
    version="0.1.0",
    packages=[package_name],
    data_files=[
        ("share/ament_index/resource_index/packages", [f"resource/{package_name}"]),
        (f"share/{package_name}", ["package.xml"]),
        (f"share/{package_name}/launch", glob("launch/*.launch.py")),
        (f"share/{package_name}/config", glob("config/*.yaml")),
        (f"share/{package_name}", ["README_minimal_platform.md"]),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="your_name",
    maintainer_email="you@example.com",
    description="Minimal air-ground playground package for PX4 + ROS 2 workspaces",
    license="MIT",
    entry_points={
        "console_scripts": [
            "ground_robot_commander = air_ground_playground.ground_robot_commander:main",
        ],
    },
)
