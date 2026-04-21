import unittest

from my_px4_offboard.trajectory_library import hover_point, out_and_back_trajectory, square_trajectory


class TrajectoryLibraryTest(unittest.TestCase):
    def test_hover_point_uses_given_values(self) -> None:
        point = hover_point(1.0, 2.0, -3.0, yaw_rad=0.5, dwell_s=4.0)
        self.assertEqual(point.x_m, 1.0)
        self.assertEqual(point.y_m, 2.0)
        self.assertEqual(point.z_m, -3.0)
        self.assertEqual(point.yaw_rad, 0.5)
        self.assertEqual(point.dwell_s, 4.0)

    def test_square_trajectory_generates_closed_loop(self) -> None:
        points = square_trajectory(
            center_x_m=0.0,
            center_y_m=0.0,
            altitude_m=2.0,
            side_length_m=1.0,
            dwell_s=1.5,
            yaw_rad=0.1,
            include_return_to_start=True,
        )
        self.assertEqual(len(points), 5)
        self.assertEqual(points[0], points[-1])
        self.assertTrue(all(point.z_m == -2.0 for point in points))

    def test_out_and_back_returns_to_start(self) -> None:
        points = out_and_back_trajectory(
            start_x_m=0.0,
            start_y_m=0.0,
            altitude_m=2.5,
            distance_x_m=3.0,
            dwell_s=1.0,
        )
        self.assertEqual(len(points), 3)
        self.assertEqual(points[0], points[-1])
        self.assertEqual(points[1].x_m, 3.0)
        self.assertEqual(points[1].z_m, -2.5)


if __name__ == '__main__':
    unittest.main()
