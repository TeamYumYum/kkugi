import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from run_macos import GALLERY_TEST, collect_evidence, evidence_name, prepare_in_parallel, suite_configuration

class CaptureTests(unittest.TestCase):
    def test_preparation_preserves_first_error_and_stops_siblings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            slow = [sys.executable, "-c", "import sys,time;time.sleep(12);print('finished')"]
            failed = [sys.executable, "-c", "import sys;print('failed preparation');sys.exit(7)"]
            with self.assertRaises(subprocess.CalledProcessError) as caught:
                prepare_in_parallel([(slow, root / "slow.log"), (failed, root / "failure.log")])
            self.assertEqual(caught.exception.returncode, 7)
            self.assertEqual((root / "failure.log").read_text().strip(), "failed preparation")
            self.assertEqual((root / "slow.log").read_text(), "")

    def test_partition_preserves_tests_and_separate_evidence(self):
        core_flags, core = suite_configuration("core")
        gallery_flags, gallery = suite_configuration("gallery")
        self.assertEqual(core_flags, ["-skip-testing:" + GALLERY_TEST])
        self.assertEqual(gallery_flags, ["-only-testing:" + GALLERY_TEST])
        self.assertEqual(suite_configuration("all"), ([], core | gallery))
        self.assertFalse(core & gallery)
        required_ui = """
            home inbox-empty chat profile profile-edit body-edit withdrawal meal-add food-search meal-photo system-photo-picker
            inbox meal-detail meal-edit schedule workout-history exercise-records workout-recorder routine-detail
            routine-editor exercise-search target-calorie weight diet-streak workout-streak badges weekly-report
            workout-detail routine-list routine-recommend ai-survey-full ai-survey ai-result exercise-pick
        """.split()
        self.assertEqual(gallery, {f"{name}-full.png" for name in required_ui})
        expected_core = {"home-overlay.json", "login-initial-full.json"}
        expected_core.update(f"{name}-full.png" for name in
                             "login-initial review-login onboarding-nickname onboarding-goal meal-day workout coaching growth".split())
        expected_core.update(f"{name}-3x.png" for name in """
            onboarding-nickname onboarding-goal onboarding-body onboarding-meet meal-recognizing
            meal-recognition-failed meal-photo-confirm meal-confirm workout-finish
        """.split())
        expected_core.update(f"login-{state}-{scale}x.{ext}"
                             for state in ("initial", "recent-kakao", "kakao-busy", "google-busy", "error")
                             for scale in (1, 3) for ext in ("png", "json"))
        self.assertEqual(core, expected_core)
        with self.assertRaises(ValueError):
            suite_configuration("unknown")
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
