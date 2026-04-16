from setuptools import setup

package_name = "my_px4_offboard"

setup(
    name=package_name,
    version="0.0.1",
    packages=[package_name],
    data_files=[
        ("share/ament_index/resource_index/packages", [f"resource/{package_name}"]),
        (f"share/{package_name}", ["package.xml"]),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="your_name",
    maintainer_email="you@example.com",
    description="Minimal ROS 2 Python offboard example for PX4",
    license="MIT",
    entry_points={
        "console_scripts": [
            "offboard_takeoff_hover = my_px4_offboard.offboard_takeoff_hover:main",
            "offboard_trajectory = my_px4_offboard.offboard_trajectory:main",
        ],
    },
)
