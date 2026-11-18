from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from button_layout import compare


class ButtonLayoutTests(unittest.TestCase):
    def test_one_pixel_and_missing_button(self):
        reference = {"case": "home", "viewport": [100, 100], "buttons": {"a": [1, 1, 5, 5], "b": [5, 5, 9, 9]}}
        actual = {**reference, "buttons": {"a": [1, 2, 5, 5]}}
        self.assertEqual(set(compare(reference, actual)["changed"]), {"a", "b"})
        self.assertEqual(compare(reference, reference)["status"], "identical")

    def test_viewport_and_empty_capture(self):
        reference = {"case": "home", "viewport": [100, 100], "buttons": {"a": [1, 1, 5, 5]}}
        for changes in [{"viewport": [90, 100]}, {"buttons": {}}, {"buttons": {"a": [0, 1, 0, 2]}}]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                compare(reference, {**reference, **changes})
