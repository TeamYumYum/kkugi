"""Prepare a reviewable, explicit allow-list publication tree. Never pushes anything."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

APP_FILES = [
    "ios/.gitignore", "ios/README.md", "ios/scripts/project.py", "ios/Kkugi/Info.plist",
    "ios/Kkugi.xcodeproj/project.pbxproj", "ios/Kkugi.xcodeproj/xcshareddata/xcschemes/Kkugi.xcscheme",
    "ios/Kkugi/Resources/asset-manifest.json",
]
VERIFY_FILES = [
    ".github/workflows/ios-visual.yml", "ios/verification/README.md", "ios/verification/package.py",
    "ios/verification/run_macos.py", "ios/verification/pixels.py",
    "ios/verification/tests/test_capture.py", "ios/verification/tests/test_pixels.py", "ios/verification/tests/test_package.py",
]
ASSET_DESTINATIONS = {
    "Fonts/noto_sans_kr_variable.ttf", "ThirdParty/NotoSansKR-OFL.txt",
    "Images/member_login_garden_back.webp", "Images/member_login_garden_front.webp",
    "Images/member_google_g_logo.png", "Images/kkugi_g_character_wave.webp",
}


def checked_file(root: Path, relative: str) -> Path:
    path = root / relative
    if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"Missing or unsafe publication file: {relative}")
    if any(part.startswith(".env") or part in {"Local.xcconfig", "local.properties", "google-services.json"} for part in path.parts):
        raise ValueError(f"Private configuration is forbidden: {relative}")
    return path


def collect(app_root: Path, verification_root: Path) -> list[tuple[Path, str, str]]:
    selected = [(checked_file(app_root, name), name, "app") for name in APP_FILES]
    for directory in ["ios/Kkugi", "ios/KkugiTests", "ios/KkugiUITests"]:
        sources = sorted((app_root / directory).rglob("*.swift"))
        if not sources:
            raise ValueError(f"Missing Swift source group: {directory}")
        selected += [(checked_file(app_root, p.relative_to(app_root).as_posix()), p.relative_to(app_root).as_posix(), "app") for p in sources]
    resource_base = "ios/Kkugi/Resources/"
    assets = json.loads((app_root / resource_base / "asset-manifest.json").read_text(encoding="utf-8"))
    if {item["destination"] for item in assets["files"]} != ASSET_DESTINATIONS:
        raise ValueError("Asset manifest must list exactly the approved login assets and license")
    for item in assets["files"]:
        relative = resource_base + item["destination"]
        # The manifest may only select bundled images, fonts, and license text.
        dest = Path(item["destination"])
        if dest.is_absolute() or ".." in dest.parts or dest.parts[0] not in {"Images", "Fonts", "ThirdParty"} or dest.suffix not in {".webp", ".png", ".ttf", ".txt"}:
            raise ValueError("Unsafe asset destination")
        path = checked_file(app_root, relative)
        if hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
            raise ValueError(f"Asset checksum mismatch: {relative}")
        selected.append((path, relative, "app"))
    selected += [(checked_file(verification_root, name), name, "verification") for name in VERIFY_FILES]
    names = [name for _, name, _ in selected]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate publication path")
    return selected


def prepare(app_root: Path, verification_root: Path, output: Path) -> dict:
    if output.exists():
        raise ValueError("Publication output already exists; use a fresh directory")
    files = collect(app_root, verification_root)
    manifest = {"status": "prepared-not-published", "files": []}
    output.mkdir(parents=True)
    for source, relative, origin in files:
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        manifest["files"].append({"path": relative, "origin": origin, "bytes": target.stat().st_size,
                                  "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    manifest["files"].sort(key=lambda item: item["path"])
    manifest["totalBytes"] = sum(item["bytes"] for item in manifest["files"])
    (output / "public-files.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-root", type=Path, required=True)
    parser.add_argument("--verification-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = prepare(args.app_root.resolve(), args.verification_root.resolve(), args.output.resolve())
    print(f"Prepared {len(result['files'])} files, {result['totalBytes']} bytes. No files were published.")


if __name__ == "__main__":
    main()
