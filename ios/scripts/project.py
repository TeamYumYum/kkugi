#!/usr/bin/env python3
"""Generate the Xcode project; --check never writes files."""
from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
from pathlib import Path
from xml.etree import ElementTree as ET

IOS = Path(__file__).resolve().parents[1]


def identifier(name: str) -> str:
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def openstep(value: object, depth: int = 0) -> str:
    indent = "\t" * depth
    if isinstance(value, dict):
        lines = [f"{indent}\t{json.dumps(key)} = {openstep(item, depth + 1)};" for key, item in value.items()]
        return "{\n" + "\n".join(lines) + "\n" + indent + "}"
    if isinstance(value, list):
        return "(\n" + "\n".join(f"{indent}\t{openstep(item, depth + 1)}," for item in value) + "\n" + indent + ")"
    return json.dumps(str(value), ensure_ascii=False)


def generate() -> dict[Path, bytes]:
    objects: dict[str, dict] = {}

    def add(object_name: str, **properties: object) -> str:
        key = identifier(object_name)
        if key in objects:
            raise ValueError(f"Duplicate project object: {object_name}")
        objects[key] = properties
        return key

    def configs(name: str, values: dict) -> str:
        entries = []
        for mode in ("Debug", "Release"):
            settings = dict(values)
            if name == "project" and mode == "Debug":
                settings["ONLY_ACTIVE_ARCH"] = "YES"
            if name == "Kkugi":
                settings["KKUGI_APS_ENVIRONMENT"] = "development" if mode == "Debug" else "production"
            if name == "project":
                settings.update({
                    "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)" if mode == "Debug" else "$(inherited)",
                    "ENABLE_TESTABILITY": "YES" if mode == "Debug" else "NO",
                })
            entries.append(add(f"{name}-{mode}", isa="XCBuildConfiguration", name=mode, buildSettings=settings))
        return add(f"{name}-configs", isa="XCConfigurationList", buildConfigurations=entries,
                   defaultConfigurationIsVisible=0, defaultConfigurationName="Release")

    project_configs = configs("project", {
        "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "SWIFT_STRICT_CONCURRENCY": "complete", "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    })
    packages = []
    social_products = []
    for repo, version, product in [
        ("google/GoogleSignIn-iOS", "9.2.0", "GoogleSignIn"),
        ("kakao/kakao-ios-sdk", "2.30.0", "KakaoSDKUser"),
        ("firebase/firebase-ios-sdk", "11.15.0", "FirebaseMessaging"),
    ]:
        package = add(repo, isa="XCRemoteSwiftPackageReference", repositoryURL=f"https://github.com/{repo}.git",
                      requirement={"kind": "exactVersion", "version": version})
        packages.append(package)
        social_products.append(add(product, isa="XCSwiftPackageProductDependency", package=package, productName=product))
    children = []
    products = []
    targets = []
    for name, directory, kind in [
        ("Kkugi", "Kkugi", "application"),
        ("KkugiTests", "KkugiTests", "bundle.unit-test"),
        ("KkugiUITests", "KkugiUITests", "bundle.ui-testing"),
    ]:
        sources = []
        file_refs = []
        for path in sorted((IOS / directory).rglob("*.swift")):
            relative = path.relative_to(IOS).as_posix()
            ref = add(relative, isa="PBXFileReference", lastKnownFileType="sourcecode.swift", path=relative, sourceTree="SOURCE_ROOT")
            file_refs.append(ref)
            sources.append(add(relative + "-build", isa="PBXBuildFile", fileRef=ref))
        if not sources:
            raise ValueError(f"No Swift sources in {directory}")
        resources = []
        if name == "Kkugi":
            for folder in ["Images", "Fonts", "ThirdParty"]:
                resource_ref = add("resources-" + folder, isa="PBXFileReference", lastKnownFileType="folder", path="Kkugi/Resources/" + folder, sourceTree="SOURCE_ROOT")
                file_refs.append(resource_ref)
                resources.append(add("resources-build-" + folder, isa="PBXBuildFile", fileRef=resource_ref))
        children.append(add(name + "-group", isa="PBXGroup", children=file_refs, name=name, sourceTree="<group>"))
        extension = "app" if name == "Kkugi" else "xctest"
        file_type = "wrapper.application" if name == "Kkugi" else "wrapper.cfbundle"
        product = add(name + "-product", isa="PBXFileReference", explicitFileType=file_type,
                      includeInIndex=0, path=f"{name}.{extension}", sourceTree="BUILT_PRODUCTS_DIR")
        products.append(product)
        phases = []
        framework_files = [add(ref + "-link", isa="PBXBuildFile", productRef=ref)
                           for ref in social_products] if name == "Kkugi" else []
        for phase, isa, files in [("sources", "PBXSourcesBuildPhase", sources), ("frameworks", "PBXFrameworksBuildPhase", framework_files),
                                  ("resources", "PBXResourcesBuildPhase", resources)]:
            phases.append(add(name + "-" + phase, isa=isa, buildActionMask=2147483647, files=files, runOnlyForDeploymentPostprocessing=0))
        settings = {
            "FRAMEWORK_SEARCH_PATHS": ["$(inherited)", "$(SRCROOT)/../shared-ui/build/xcode-frameworks/$(CONFIGURATION)/$(SDK_NAME)", "$(TARGET_BUILD_DIR)/$(FRAMEWORKS_FOLDER_PATH)"],
            "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.kkugi.ios" + ("" if name == "Kkugi" else "." + name),
            "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "TARGETED_DEVICE_FAMILY": "1",
            "CODE_SIGN_STYLE": "Automatic", "GENERATE_INFOPLIST_FILE": "YES",
            "MARKETING_VERSION": "0.1.0", "CURRENT_PROJECT_VERSION": "1",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"],
        }
        dependencies = []
        if name == "Kkugi":
            phases.insert(0, add("shared-ui-build", isa="PBXShellScriptBuildPhase",
                name="Build shared UI", shellPath="/bin/sh", files=[], inputPaths=[], outputPaths=[],
                alwaysOutOfDate=1, runOnlyForDeploymentPostprocessing=0, buildActionMask=2147483647,
                shellScript='set -eu\ncd "$SRCROOT/.."\n./android/gradlew -p shared-ui embedAndSignAppleFrameworkForXcode\n'))
            settings["ENABLE_USER_SCRIPT_SANDBOXING"] = "NO"
            settings["OTHER_LDFLAGS"] = ["$(inherited)", "-framework", "KkugiRenderer"]
            settings["CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]"] = "Kkugi/Kkugi.entitlements"
            settings.update({"INFOPLIST_FILE": "Kkugi/Info.plist", "INFOPLIST_KEY_CFBundleDisplayName": "꾸기",
                             "INFOPLIST_KEY_UILaunchScreen_Generation": "YES", "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES"})
        else:
            proxy = add(name + "-proxy", isa="PBXContainerItemProxy", containerPortal=identifier("project"), proxyType=1,
                        remoteGlobalIDString=identifier("Kkugi-target"), remoteInfo="Kkugi")
            dependencies.append(add(name + "-dependency", isa="PBXTargetDependency", target=identifier("Kkugi-target"), targetProxy=proxy))
            if name == "KkugiTests":
                settings.update({"BUNDLE_LOADER": "$(TEST_HOST)", "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Kkugi.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Kkugi"})
            else:
                settings["TEST_TARGET_NAME"] = "Kkugi"
        targets.append(add(name + "-target", isa="PBXNativeTarget", buildConfigurationList=configs(name, settings),
                           packageProductDependencies=social_products if name == "Kkugi" else [],
                           buildPhases=phases, buildRules=[], dependencies=dependencies, name=name, productName=name,
                           productReference=product, productType="com.apple.product-type." + kind))
    product_group = add("products", isa="PBXGroup", children=products, name="Products", sourceTree="<group>")
    root_group = add("root-group", isa="PBXGroup", children=children + [product_group], sourceTree="<group>")
    project = add("project", isa="PBXProject", attributes={"LastUpgradeCheck": "1600", "BuildIndependentTargetsInParallel": "YES"},
                  buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0", developmentRegion="ko",
                  hasScannedForEncodings=0, knownRegions=["ko", "en", "Base"], mainGroup=root_group,
                  packageReferences=packages, productRefGroup=product_group, projectDirPath="", projectRoot="", targets=targets)
    pbx = {"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project}

    def reference(parent: ET.Element, name: str) -> None:
        ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=identifier(name + "-target"),
                      BuildableName=name + (".app" if name == "Kkugi" else ".xctest"), BlueprintName=name,
                      ReferencedContainer="container:Kkugi.xcodeproj")

    scheme = ET.Element("Scheme", LastUpgradeVersion="1600", version="1.3")
    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
    reference(entry, "Kkugi")
    test = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                         selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
    testables = ET.SubElement(test, "Testables")
    for name in ("KkugiTests", "KkugiUITests"):
        reference(ET.SubElement(testables, "TestableReference", skipped="NO", parallelizable="NO"), name)
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                           selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO",
                           ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", debugServiceExtension="internal", allowLocationSimulation="YES")
    reference(ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0"), "Kkugi")
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    ET.indent(scheme)
    info = {
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1",
        "CFBundleDevelopmentRegion": "ko", "CFBundleDisplayName": "꾸기",
        "CADisableMinimumFrameDurationOnPhone": True,
        "NSCameraUsageDescription": "식사 사진을 찍어 음식 기록에 사용합니다.",
        "GIDClientID": "$(KKUGI_GOOGLE_IOS_CLIENT_ID)", "GIDServerClientID": "$(KKUGI_GOOGLE_SERVER_CLIENT_ID)",
        "KkugiKakaoAppKey": "$(KKUGI_KAKAO_NATIVE_APP_KEY)",
        "LSApplicationQueriesSchemes": ["kakaokompassauth", "kakaolink"],
        "FirebaseAppDelegateProxyEnabled": False, "FirebaseMessagingAutoInitEnabled": False,
        "KkugiFirebaseAppID": "$(KKUGI_FIREBASE_APP_ID)", "KkugiFirebaseSenderID": "$(KKUGI_FIREBASE_SENDER_ID)",
        "KkugiFirebaseProjectID": "$(KKUGI_FIREBASE_PROJECT_ID)", "KkugiFirebaseAPIKey": "$(KKUGI_FIREBASE_API_KEY)",
        "CFBundleURLTypes": [
            {"CFBundleURLName": "google", "CFBundleURLSchemes": ["$(KKUGI_GOOGLE_REVERSED_CLIENT_ID)"]},
            {"CFBundleURLName": "kakao", "CFBundleURLSchemes": ["kakao$(KKUGI_KAKAO_NATIVE_APP_KEY)"]},
        ],
        "KkugiAPIBaseURL": "$(KKUGI_API_BASE_URL)",
        "UIAppFonts": ["Fonts/noto_sans_kr_variable.ttf"],
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "UIUserInterfaceStyle": "Light", "UIApplicationSupportsIndirectInputEvents": True,
    }
    return {
        IOS / "Kkugi.xcodeproj/project.pbxproj": ("// !$*UTF8*$!\n" + openstep(pbx) + "\n").encode(),
        IOS / "Kkugi.xcodeproj/xcshareddata/xcschemes/Kkugi.xcscheme": ET.tostring(scheme, encoding="utf-8", xml_declaration=True) + b"\n",
        IOS / "Kkugi/Info.plist": plistlib.dumps(info, sort_keys=True),
        IOS / "Kkugi/Kkugi.entitlements": plistlib.dumps({"aps-environment": "$(KKUGI_APS_ENVIRONMENT)"}),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = []
    for path, content in generate().items():
        if args.check:
            if not path.exists() or path.read_bytes() != content:
                stale.append(str(path.relative_to(IOS)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    if stale:
        raise SystemExit("Stale generated files: " + ", ".join(stale))
    print("Xcode project is current" if args.check else "Generated Xcode project, scheme, and Info.plist")


if __name__ == "__main__":
    main()
