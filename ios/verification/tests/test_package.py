import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from package import APP_FILES, ASSET_DESTINATIONS, VERIFY_FILES, checked_file, prepare


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / "app"
        self.verification = self.root / "verification"
        self.out = self.root / "publish"
        for parent, names in [(self.app, APP_FILES), (self.verification, VERIFY_FILES)]:
            for name in names:
                p = parent / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(b"fixture")
        for directory in ["ios/Kkugi", "ios/KkugiTests", "ios/KkugiUITests"]:
            p = self.app / directory / "Fixture.swift"; p.parent.mkdir(parents=True, exist_ok=True); p.write_text("// fixture\n")
        assets = []
        for relative in ASSET_DESTINATIONS:
            p = self.app / "ios/Kkugi/Resources" / relative
            p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(relative.encode())
            assets.append({"destination": relative, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()})
        self.manifest = self.app / "ios/Kkugi/Resources/asset-manifest.json"
        self.manifest.write_text(json.dumps({"files": assets}))

    def test_allow_list_excludes_private_configuration_and_history(self):
        for relative in [".env", ".git/config", "ios/Local.xcconfig", "backend/private.txt", "ios/artifacts/user.png"]:
            p = self.app / relative; p.parent.mkdir(parents=True, exist_ok=True); p.write_text("PRIVATE_FIXTURE")
        result = prepare(self.app, self.verification, self.out)
        names = {f["path"] for f in result["files"]}
        self.assertNotIn(".env", names)
        self.assertNotIn(".git/config", names)
        self.assertNotIn("ios/Local.xcconfig", names)
        self.assertNotIn("ios/artifacts/user.png", names)
        self.assertTrue((self.out / ".github/workflows/ios-visual.yml").exists())
        for record in result["files"]:
            self.assertEqual(hashlib.sha256((self.out / record["path"]).read_bytes()).hexdigest(), record["sha256"])

    def test_missing_source_does_not_create_output(self):
        (self.app / "ios/Kkugi/Fixture.swift").unlink()
        with self.assertRaisesRegex(ValueError, "Missing Swift"):
            prepare(self.app, self.verification, self.out)
        self.assertFalse(self.out.exists())

    def test_asset_tampering_and_extra_asset_fail(self):
        data = json.loads(self.manifest.read_text())
        original = self.manifest.read_text()
        data["files"][0]["sha256"] = "0" * 64
        self.manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "checksum"):
            prepare(self.app, self.verification, self.out)
        data = json.loads(original)
        data["files"].append({"destination": "../../.env", "sha256": "0" * 64})
        self.manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "approved"):
            prepare(self.app, self.verification, self.out)
        self.assertFalse(self.out.exists())

    def test_existing_output_is_preserved(self):
        self.out.mkdir(); sentinel = self.out / "keep.txt"; sentinel.write_text("keep")
        with self.assertRaisesRegex(ValueError, "already exists"):
            prepare(self.app, self.verification, self.out)
        self.assertEqual(sentinel.read_text(), "keep")

    def test_file_outside_source_root_is_rejected(self):
        outside = self.root / "outside.swift"; outside.write_text("not public")
        with self.assertRaisesRegex(ValueError, "unsafe"):
            checked_file(self.app, "../outside.swift")


if __name__ == "__main__":
    unittest.main()
