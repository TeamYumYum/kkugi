import json
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from run_macos import collect_evidence, evidence_name

class CaptureTests(unittest.TestCase):
    def test_exact_and_xcode_suffix_names(self):
        expected = {"login-initial-1x.png"}
        uuid = "12345678-1234-1234-1234-123456789abc"
        for name in ["login-initial-1x.png", f"login-initial-1x.png_0_{uuid}.png", f"login-initial-1x_1_{uuid}.png"]:
            self.assertEqual(evidence_name(name, expected), "login-initial-1x.png")
        for name in ["../login-initial-1x.png", "login-initial-1x.png_extra.png", "unknown.png"]:
            self.assertIsNone(evidence_name(name, expected))

    def test_missing_duplicate_and_outside_attachments_fail(self):
        for mode in ["missing", "duplicate", "outside"]:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "image.png").write_bytes(b"fixture")
                entry = {"suggestedHumanReadableName": "login-initial-1x.png", "exportedFileName": "image.png"}
                entries = [] if mode == "missing" else [entry, entry] if mode == "duplicate" else [dict(entry, exportedFileName="../outside.png")]
                (root / "manifest.json").write_text(json.dumps(entries))
                with self.assertRaises(ValueError):
                    collect_evidence(root, root / "captures", {"login-initial-1x.png"})

if __name__ == "__main__":
    unittest.main()
