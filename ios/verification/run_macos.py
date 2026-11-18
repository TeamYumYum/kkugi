"""Run pinned Xcode/Simulator tests and export named PNG evidence. macOS only."""
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-18-5"
DEVICE_NAME = "iPhone 16"
CASES = ["login-initial", "login-recent-kakao", "login-kakao-busy", "login-google-busy", "login-error"]
GALLERY_TEST = "KkugiUITests/ScreenGalleryUITests"
GALLERY_SCREENS = """
home inbox-empty chat profile profile-edit body-edit withdrawal meal-add food-search meal-photo inbox meal-detail
meal-edit schedule workout-history exercise-records workout-recorder routine-detail routine-editor exercise-search
target-calorie weight diet-streak workout-streak badges weekly-report workout-detail routine-list routine-recommend
ai-survey-full ai-survey ai-result exercise-pick
""".split()


def suite_configuration(suite: str) -> tuple[list[str], set[str]]:
    gallery = {f"{case}-full.png" for case in GALLERY_SCREENS}
    core = {f"{case}-{scale}x.{suffix}" for case in CASES for scale in (1, 3) for suffix in ("png", "json")}
    core.update({"login-initial-full.png", "login-initial-full.json", "home-overlay.json"})
    core.update(f"{case}-full.png" for case in ("review-login", "onboarding-nickname", "onboarding-goal",
                                                "meal-day", "workout", "coaching", "growth"))
    core.update(f"onboarding-{step}-3x.png" for step in ("nickname", "goal", "body", "meet"))
    core.update(f"{case}-3x.png" for case in ("meal-recognizing", "meal-recognition-failed", "meal-photo-confirm",
                                               "meal-confirm", "workout-finish"))
    if suite == "core":
        return [f"-skip-testing:{GALLERY_TEST}"], core
    if suite == "gallery":
        return [f"-only-testing:{GALLERY_TEST}"], gallery
    if suite == "all":
        return [], core | gallery
    raise ValueError("Unknown XCTest suite")


def command(args: list[str], log: Path | None = None) -> str:
    if log:
        with log.open("w", encoding="utf-8") as stream:
            completed = subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, text=True)
        if completed.returncode:
            print(log.read_text(encoding="utf-8", errors="replace")[-12000:])
            raise subprocess.CalledProcessError(completed.returncode, args)
        return ""
    return subprocess.check_output(args, cwd=ROOT, text=True)


def named_attachments(node):
    if isinstance(node, dict):
        if "exportedFileName" in node and "suggestedHumanReadableName" in node:
            yield node
        for value in node.values():
            yield from named_attachments(value)
    elif isinstance(node, list):
        for value in node:
            yield from named_attachments(value)


def evidence_name(exported_name: str, expected: set[str]) -> str | None:
    if exported_name in expected:
        return exported_name
    uuid = r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"
    for name in sorted(expected):
        stem, suffix = name.rsplit(".", 1)
        # xcresulttool may retain the attachment's extension before its suffix.
        pattern = re.escape(stem) + r"(?:\." + re.escape(suffix) + r")?_\d+_" + uuid + r"\." + re.escape(suffix)
        if re.fullmatch(pattern, exported_name):
            return name
    return None


def collect_evidence(export: Path, captures: Path, expected: set[str]) -> None:
    manifest = json.loads((export / "manifest.json").read_text())
    captures.mkdir()
    found = set()
    for attachment in named_attachments(manifest):
        name = evidence_name(attachment["suggestedHumanReadableName"], expected)
        if name is None:
            continue
        source = export / attachment["exportedFileName"]
        if not source.resolve().is_relative_to(export.resolve()) or source.is_symlink() or name in found:
            raise ValueError("Unsafe or duplicate attachment")
        shutil.copyfile(source, captures / name)
        found.add(name)
    if found != expected:
        raise ValueError("Missing screenshot evidence: " + ", ".join(sorted(expected - found)))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--suite", choices=("all", "core", "gallery"), default="all")
    suite = parser.parse_args().suite
    selection, expected = suite_configuration(suite)
    if sys.platform != "darwin":
        raise SystemExit("Xcode rendering requires macOS; static checks are not a substitute")
    artifacts = ROOT / "ios/artifacts"
    artifacts.mkdir(parents=True, exist_ok=True)
    result = artifacts / "TestResults.xcresult"
    if result.exists():
        raise SystemExit("TestResults.xcresult already exists; preserve it and use a fresh workspace")
    version = command(["xcodebuild", "-version"]).strip()
    if not version.startswith("Xcode 16.4\n"):
        raise SystemExit(f"Expected Xcode 16.4, got {version}")
    devices = json.loads(command(["xcrun", "simctl", "list", "devices", "available", "--json"]))
    candidates = [d for d in devices["devices"].get(RUNTIME, []) if d["name"] == DEVICE_NAME and d.get("isAvailable")]
    if len(candidates) != 1:
        raise SystemExit("Expected exactly one available iPhone 16 on iOS 18.5; refusing runtime fallback")
    device = candidates[0]
    environment = {"xcode": version, "host": platform.platform(), "runtime": RUNTIME, "device": device,
                   "commit": os.environ.get("GITHUB_SHA", "unrecorded"), "suite": suite, "androidParity": "not-yet-compared"}
    (artifacts / "environment.json").write_text(json.dumps(environment, indent=2) + "\n")
    command([sys.executable, "ios/scripts/project.py", "--check"])
    command(["plutil", "-lint", "ios/Kkugi.xcodeproj/project.pbxproj", "ios/Kkugi/Info.plist"])
    if device["state"] != "Booted":
        command(["xcrun", "simctl", "boot", device["udid"]])
    command(["xcrun", "simctl", "bootstatus", device["udid"], "-b"])
    command(["xcrun", "simctl", "status_bar", device["udid"], "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100"])
    test_error = None
    try:
        command(["xcodebuild", "-project", "ios/Kkugi.xcodeproj", "-scheme", "Kkugi", "-destination", f"platform=iOS Simulator,id={device['udid']}",
                 "-derivedDataPath", "ios/DerivedData", "-resultBundlePath", str(result), "-parallel-testing-enabled", "NO",
                 "-maximum-concurrent-test-simulator-destinations", "1", *selection, "test", "CODE_SIGN_IDENTITY=-"], artifacts / "xcodebuild.log")
    except subprocess.CalledProcessError as error:
        test_error = error
    finally:
        products = ROOT / "ios/DerivedData/Build/Products/Debug-iphonesimulator"
        for name, relative in [("app-info.plist", "Kkugi.app/Info.plist"), ("tests-info.plist", "Kkugi.app/PlugIns/KkugiTests.xctest/Info.plist")]:
            source = products / relative
            if source.is_file():
                shutil.copyfile(source, artifacts / name)
                print(command(["plutil", "-p", str(source)]))
    export = artifacts / "attachments"
    command(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result), "--output-path", str(export)])
    collect_evidence(export, artifacts / "captures", expected)
    if test_error is not None:
        raise test_error
    summary = {"suite": suite, "commit": environment["commit"], "buildAndTests": "passed",
               "pngCaptures": sum(name.endswith(".png") for name in expected),
               "metadataFiles": sum(name.endswith(".json") for name in expected), "pixelParity": "not-yet-compared"}
    (artifacts / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
