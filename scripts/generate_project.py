#!/usr/bin/env python3
"""Generate the dependency-free Xcode project. Run from any directory."""
import hashlib
import json
from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "BlazeFlow.xcodeproj"
OBJECTS = {}


def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def obj(identifier, isa, **fields):
    key = uid(identifier)
    OBJECTS[key] = {"isa": isa, **fields}
    return key


def plist(path, value):
    (ROOT / path).write_bytes(plistlib.dumps(value, sort_keys=False))


def encode(value, level=0):
    if isinstance(value, dict):
        lines = ["{"]
        for key, item in value.items():
            lines.append("\t" * (level + 1) + f"{json.dumps(key)} = {encode(item, level + 1)};")
        return "\n".join(lines) + "\n" + "\t" * level + "}"
    if isinstance(value, list):
        return "(" + ", ".join(encode(item, level) for item in value) + ")"
    return json.dumps(str(value))


def configs(name, settings):
    children = []
    for mode in ["Debug", "Release"]:
        build_settings = dict(settings)
        build_settings["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if mode == "Debug" else "-O"
        build_settings["DEBUG_INFORMATION_FORMAT"] = "dwarf" if mode == "Debug" else "dwarf-with-dsym"
        if mode == "Debug":
            build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) DEBUG"
        children.append(obj(f"{name}.{mode}", "XCBuildConfiguration", name=mode, buildSettings=build_settings))
    return obj(f"{name}.configs", "XCConfigurationList", buildConfigurations=children,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


base_info = {
    "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
    "CFBundleExecutable": "$(EXECUTABLE_NAME)",
    "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": "$(PRODUCT_NAME)",
    "CFBundleShortVersionString": "1.0",
    "CFBundleVersion": "1",
    "FocusAppGroup": "$(FOCUS_APP_GROUP)",
}
plist("BlazeFlow/Info.plist", {
    **base_info, "CFBundleDisplayName": "Blaze Flow", "CFBundlePackageType": "APPL",
    "LSRequiresIPhoneOS": True, "UILaunchScreen": {},
    "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
    "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False},
})
plist("FocusMonitor/Info.plist", {
    **base_info, "CFBundlePackageType": "XPC!",
    "NSExtension": {
        "NSExtensionPointIdentifier": "com.apple.deviceactivity.monitor-extension",
        "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).FocusMonitor",
    },
})
for target in ["BlazeFlow", "FocusMonitor"]:
    plist(f"{target}/{target}.entitlements", {
        "com.apple.developer.family-controls": True,
        "com.apple.security.application-groups": ["$(FOCUS_APP_GROUP)"],
    })
    plist(f"{target}/PrivacyInfo.xcprivacy", {
        "NSPrivacyTracking": False,
        "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyAccessedAPITypes": [{
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": ["1C8F.1"],
        }],
    })

file_refs = {}
file_types = {".swift": "sourcecode.swift", ".plist": "text.plist.xml",
              ".entitlements": "text.plist.entitlements", ".xcprivacy": "text.xml"}
for folder in ["BlazeFlow", "Shared", "FocusMonitor", "BlazeFlowTests"]:
    for path in sorted((ROOT / folder).iterdir()):
        if path.suffix not in file_types:
            continue
        relative = str(path.relative_to(ROOT))
        file_refs[relative] = obj(relative, "PBXFileReference", path=relative,
                                  sourceTree="<group>", lastKnownFileType=file_types[path.suffix])

products = {}
for name, suffix, kind in [("BlazeFlow", "app", "wrapper.application"),
                           ("FocusMonitor", "appex", "wrapper.app-extension"),
                           ("BlazeFlowTests", "xctest", "wrapper.cfbundle")]:
    products[name] = obj(f"product.{name}", "PBXFileReference", path=f"{name}.{suffix}",
                         sourceTree="BUILT_PRODUCTS_DIR", explicitFileType=kind, includeInIndex=0)

targets = {}
for name in ["FocusMonitor", "BlazeFlow", "BlazeFlowTests"]:
    sources = [p for p in file_refs if p.endswith(".swift") and
               (p.startswith(name + "/") or (p.startswith("Shared/") and name != "BlazeFlowTests"))]
    builds = [obj(f"build.{name}.{p}", "PBXBuildFile", fileRef=file_refs[p]) for p in sources]
    phases = [obj(f"{name}.sources", "PBXSourcesBuildPhase", buildActionMask=2147483647,
                  files=builds, runOnlyForDeploymentPostprocessing=0)]
    phases.append(obj(f"{name}.frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647,
                      files=[], runOnlyForDeploymentPostprocessing=0))
    resources = []
    privacy = f"{name}/PrivacyInfo.xcprivacy"
    if privacy in file_refs:
        resources.append(obj(f"resource.{name}", "PBXBuildFile", fileRef=file_refs[privacy]))
    phases.append(obj(f"{name}.resources", "PBXResourcesBuildPhase", buildActionMask=2147483647,
                      files=resources, runOnlyForDeploymentPostprocessing=0))
    dependencies = []
    dependency = {"BlazeFlow": "FocusMonitor", "BlazeFlowTests": "BlazeFlow"}.get(name)
    if dependency:
        proxy = obj(f"{name}.proxy", "PBXContainerItemProxy", containerPortal=uid("project"),
                    proxyType=1, remoteGlobalIDString=targets[dependency], remoteInfo=dependency)
        dependencies.append(obj(f"{name}.dependency", "PBXTargetDependency",
                                target=targets[dependency], targetProxy=proxy))
    if name == "BlazeFlow":
        embed = obj("embed.monitor", "PBXBuildFile", fileRef=products["FocusMonitor"],
                    settings={"ATTRIBUTES": ["RemoveHeadersOnCopy", "CodeSignOnCopy"]})
        phases.append(obj("embed.extensions", "PBXCopyFilesBuildPhase", buildActionMask=2147483647,
                          dstPath="", dstSubfolderSpec=13, files=[embed], name="Embed App Extensions",
                          runOnlyForDeploymentPostprocessing=0))
    settings = {
        "PRODUCT_NAME": "$(TARGET_NAME)", "CODE_SIGN_STYLE": "Automatic",
        "PRODUCT_BUNDLE_IDENTIFIER": "$(BASE_BUNDLE_IDENTIFIER)" + ("" if name == "BlazeFlow" else f".{name}"),
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "GENERATE_INFOPLIST_FILE": "NO" if name != "BlazeFlowTests" else "YES",
    }
    if name != "BlazeFlowTests":
        settings.update({"INFOPLIST_FILE": f"{name}/Info.plist",
                         "CODE_SIGN_ENTITLEMENTS": f"{name}/{name}.entitlements"})
    if name == "FocusMonitor":
        settings.update({"APPLICATION_EXTENSION_API_ONLY": "YES", "SKIP_INSTALL": "YES",
                         "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]})
    if name == "BlazeFlowTests":
        settings.update({"TEST_HOST": "$(BUILT_PRODUCTS_DIR)/BlazeFlow.app/BlazeFlow",
                         "BUNDLE_LOADER": "$(TEST_HOST)"})
    product_type = {"BlazeFlow": "application", "FocusMonitor": "app-extension", "BlazeFlowTests": "bundle.unit-test"}[name]
    targets[name] = obj(f"target.{name}", "PBXNativeTarget", name=name, productName=name,
                        productReference=products[name], productType=f"com.apple.product-type.{product_type}",
                        buildConfigurationList=configs(name, settings), buildPhases=phases,
                        buildRules=[], dependencies=dependencies)

product_group = obj("products", "PBXGroup", name="Products", children=list(products.values()), sourceTree="<group>")
main_group = obj("main", "PBXGroup", children=list(file_refs.values()) + [product_group], sourceTree="<group>")
project_configs = configs("project", {
    "BASE_BUNDLE_IDENTIFIER": "com.example.BlazeFlow", "FOCUS_APP_GROUP": "group.$(BASE_BUNDLE_IDENTIFIER)",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    "SUPPORTS_MACCATALYST": "NO", "CLANG_ENABLE_MODULES": "YES", "ENABLE_TESTABILITY": "YES",
})
root_id = obj("project", "PBXProject", attributes={"LastUpgradeCheck": "1600"},
              buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0",
              developmentRegion="en", knownRegions=["en", "Base"], mainGroup=main_group,
              productRefGroup=product_group, projectDirPath="", projectRoot="", targets=list(targets.values()))
PROJECT.mkdir(exist_ok=True)
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode({
    "archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": OBJECTS, "rootObject": root_id,
}) + "\n")
scheme = PROJECT / "xcshareddata/xcschemes"
scheme.mkdir(parents=True, exist_ok=True)


def reference(name, suffix):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[name]}" BuildableName="{name}.{suffix}" BlueprintName="{name}" ReferencedContainer="container:BlazeFlow.xcodeproj"/>'


app_ref = reference("BlazeFlow", "app")
test_ref = reference("BlazeFlowTests", "xctest")
(scheme / "BlazeFlow.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print("Generated BlazeFlow.xcodeproj with app, Screen Time extension, and test targets.")
