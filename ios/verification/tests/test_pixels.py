import json
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pixels import Image, SIGNATURE, chunk, compare, paeth, read_png, write_png


class PixelTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)

    def image(self, name, rgba=b"\x10\x20\x30\xff", width=1, height=1):
        path = self.root / name
        write_png(path, Image(width, height, rgba))
        return path

    def test_identical_distinct_files(self):
        a, b = self.image("a.png"), self.image("b.png")
        result = compare(a, b, self.root / "report")
        self.assertEqual(result["status"], "identical")
        self.assertEqual(result["changedPixels"], 0)
        self.assertEqual(result["pixels"], 1)
        self.assertEqual(result["maxAbsoluteRGBA"], [0, 0, 0, 0])

    def test_one_channel_one_pixel_and_bounds(self):
        a = self.image("a.png", b"\0\0\0\xff" * 4, 2, 2)
        b = self.image("b.png", b"\0\0\0\xff" * 3 + b"\x0a\0\0\xff", 2, 2)
        result = compare(a, b, self.root / "report")
        self.assertEqual(result["status"], "differences-found")
        self.assertEqual(result["changedPixels"], 1)
        self.assertEqual(result["changedFraction"], .25)
        self.assertEqual(result["changedBoundsInclusive"], [1, 1, 1, 1])
        self.assertEqual(result["meanAbsoluteRGBA"], [2.5, 0, 0, 0])
        self.assertEqual(result["maxAbsoluteRGBA"], [10, 0, 0, 0])
        self.assertEqual(read_png(self.root / "report/difference.png").rgba[-4:], b"\x0a\0\0\xff")
        self.assertEqual((self.root / "report/android.png").read_bytes(), a.read_bytes())

    def test_alpha_differences_are_not_hidden(self):
        result = compare(self.image("a.png"), self.image("b.png", b"\x10\x20\x30\xfe"), self.root / "report")
        self.assertEqual(result["changedPixels"], 1)
        self.assertEqual(result["maxAbsoluteRGBA"], [0, 0, 0, 1])

    def test_missing_mismatched_and_same_path_fail(self):
        a = self.image("a.png")
        with self.assertRaises(FileNotFoundError):
            compare(a, self.root / "missing.png", self.root / "report")
        with self.assertRaisesRegex(ValueError, "sizes differ"):
            compare(a, self.image("wide.png", b"\0" * 8, 2), self.root / "report")
        with self.assertRaisesRegex(ValueError, "different files"):
            compare(a, a, self.root / "report")
        self.assertFalse((self.root / "report").exists())

    def test_bad_checksum_and_truncated_png_fail(self):
        p = self.image("a.png")
        original = p.read_bytes()
        p.write_bytes(original[:-4])
        with self.assertRaises(ValueError):
            read_png(p)
        corrupt = bytearray(original); corrupt[20] ^= 1; p.write_bytes(corrupt)
        with self.assertRaisesRegex(ValueError, "checksum"):
            read_png(p)

    def test_color_metadata_mismatch_fails(self):
        for tag, a, b in [(b"gAMA", struct.pack(">I", 45455), struct.pack(">I", 100000)),
                          (b"cHRM", bytes(32), bytes([1]) * 32)]:
            with self.subTest(tag=tag):
                left, right = self.image("left.png"), self.image("right.png")
                for path, payload in [(left, a), (right, b)]:
                    data = path.read_bytes()
                    path.write_bytes(data[:33] + chunk(tag, payload) + data[33:])
                with self.assertRaisesRegex(ValueError, "color metadata differ"):
                    compare(left, right, self.root / "report")
                self.assertFalse((self.root / "report").exists())

    def test_all_png_filters_decode_same_samples(self):
        # Two rows exercise prior-row and prior-pixel prediction independently.
        rows = [bytes([10, 20, 30, 255, 50, 60, 70, 128]), bytes([90, 80, 70, 255, 60, 50, 40, 128])]
        for filter_type in range(5):
            encoded = bytearray(); previous = bytes(8)
            for row in rows:
                encoded.append(filter_type)
                for i, value in enumerate(row):
                    left, up, upper_left = (row[i - 4] if i >= 4 else 0), previous[i], (previous[i - 4] if i >= 4 else 0)
                    predictors = [0, left, up, (left + up) // 2, paeth(left, up, upper_left)]
                    encoded.append((value - predictors[filter_type]) & 255)
                previous = row
            p = self.root / f"filter-{filter_type}.png"
            p.write_bytes(SIGNATURE + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 2, 8, 6, 0, 0, 0))
                          + chunk(b"IDAT", zlib.compress(encoded)) + chunk(b"IEND", b""))
            self.assertEqual(read_png(p).rgba, b"".join(rows))


if __name__ == "__main__":
    unittest.main()
