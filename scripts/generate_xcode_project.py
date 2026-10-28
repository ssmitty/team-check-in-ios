"""
generate_xcode_project.py

Purpose: Generate the dependency-free prototype Xcode project from Swift sources.
Exports: main
Notes: Stable identifiers preserve readable project diffs as files are added.
"""

from hashlib import sha256
from pathlib import Path
import json
from xcode_ui_target import add_ui_target
from xcode_native_test_target import add_native_test_target


def identifier(name: str) -> str:
    """Return a stable Xcode object identifier for a named project element."""
    return sha256(name.encode()).hexdigest()[:24].upper()


def main() -> None:
    """Write a shared app scheme and an Xcode project containing all app sources."""
    root = Path(__file__).resolve().parent.parent
    sources = sorted((root / "TeamCheckIn").rglob("*.swift"))
    objects = []

    def add(name: str, contents: str) -> str:
        key = identifier(name)
        objects.append(f"{key} = {{ {contents} }};")
        return key

    config_ref = add("Config.xcconfig", 'isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = BuildConfig.xcconfig; sourceTree = "<group>";')
    references, builds = [config_ref], []
    for path in sources:
        relative = path.relative_to(root).as_posix()
        ref = add(relative, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {json.dumps(relative)}; sourceTree = "<group>";')
        references.append(ref)
        builds.append(add(relative + ":build", f"isa = PBXBuildFile; fileRef = {ref};"))

    ui_references, ui_builds = [], []
    for path in sorted((root / "TeamCheckInUITests").rglob("*.swift")):
        relative = path.relative_to(root).as_posix()
        ref = add(relative, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {json.dumps(relative)}; sourceTree = "<group>";')
        ui_references.append(ref)
        ui_builds.append(add(relative + ":build", f"isa = PBXBuildFile; fileRef = {ref};"))
    native_references, native_builds = [], []
    native_sources = sorted((root / "TeamCheckInNativeTests").rglob("*.swift")) + [
        root / "TeamCheckInTests/LocalBackendFixture.swift",
        root / "TeamCheckInTests/HostedBackendFixture.swift",
        root / "TeamCheckInTests/NativeBackendIntegrationTests.swift",
    ]
    for path in native_sources:
        relative = path.relative_to(root).as_posix()
        ref = add(relative, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {json.dumps(relative)}; sourceTree = "<group>";')
        native_references.append(ref)
        native_builds.append(add(relative + ":build", f"isa = PBXBuildFile; fileRef = {ref};"))
    native_product = add("nativeTestProduct", 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = TeamCheckInNativeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
    ui_product = add("uiProduct", 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = TeamCheckInUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
    product = add("product", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = TeamCheckIn.app; sourceTree = BUILT_PRODUCTS_DIR;')
    products = add("products", f'isa = PBXGroup; name = Products; children = ({product},{ui_product},{native_product},); sourceTree = "<group>";')
    add("root", 'isa = PBXGroup; children = (' + ','.join(references + ui_references + native_references + [products]) + ',); sourceTree = "<group>";')
    source_phase = add("sources", 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(builds) + ',); runOnlyForDeploymentPostprocessing = 0;')
    frameworks = add("frameworks", 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    resources = add("resources", 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    project_configs, app_configs = [], []
    for configuration in ["Debug", "Release"]:
        conditions = "DEBUG" if configuration == "Debug" else ""
        testability = "YES" if configuration == "Debug" else "NO"
        project_configs.append(add("project:" + configuration,
            f'isa = XCBuildConfiguration; name = {configuration}; buildSettings = {{ SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; CLANG_ENABLE_MODULES = YES; ENABLE_TESTABILITY = {testability}; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "{conditions}"; }};'))
        app_configs.append(add("app:" + configuration,
            f'isa = XCBuildConfiguration; name = {configuration}; baseConfigurationReference = {config_ref}; buildSettings = {{ PRODUCT_NAME = TeamCheckIn; PRODUCT_BUNDLE_IDENTIFIER = dev.ssmitty.TeamCheckIn; INFOPLIST_FILE = TeamCheckIn/Resources/Info.plist; SWIFT_VERSION = 6.0; SWIFT_STRICT_CONCURRENCY = complete; SWIFT_OPTIMIZATION_LEVEL = "' + ('-Onone' if configuration == 'Debug' else '-O') + '"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; ENABLE_PREVIEWS = YES; };'))
    project_config = add("projectConfigs", 'isa = XCConfigurationList; buildConfigurations = (' + ','.join(project_configs) + ',); defaultConfigurationName = Release;')
    app_config = add("appConfigs", 'isa = XCConfigurationList; buildConfigurations = (' + ','.join(app_configs) + ',); defaultConfigurationName = Release;')
    target = add("appTarget", f'isa = PBXNativeTarget; buildConfigurationList = {app_config}; buildPhases = ({source_phase},{frameworks},{resources},); buildRules = (); dependencies = (); name = TeamCheckIn; productName = TeamCheckIn; productReference = {product}; productType = "com.apple.product-type.application";')
    ui_target = add_ui_target(add, target, ui_builds, ui_product, identifier)
    native_target = add_native_test_target(add, target, native_builds, native_product, identifier)
    project = add("project", f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2630; }}; buildConfigurationList = {project_config}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base,); mainGroup = {identifier("root")}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},{ui_target},{native_target},);')
    destination = root / "TeamCheckIn.xcodeproj"
    destination.mkdir(exist_ok=True)
    (destination / "project.pbxproj").write_text('// !$*UTF8*$!\n// Purpose: Define the native prototype app build. Generated by scripts/generate_xcode_project.py.\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {project}; }}\n')
    schemes = destination / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="TeamCheckIn.app" BlueprintName="TeamCheckIn" ReferencedContainer="container:TeamCheckIn.xcodeproj"/>'
    ui_reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_target}" BuildableName="TeamCheckInUITests.xctest" BlueprintName="TeamCheckInUITests" ReferencedContainer="container:TeamCheckIn.xcodeproj"/>'
    native_reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{native_target}" BuildableName="TeamCheckInNativeTests.xctest" BlueprintName="TeamCheckInNativeTests" ReferencedContainer="container:TeamCheckIn.xcodeproj"/>'
    (schemes / "TeamCheckIn.xcscheme").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<!-- Purpose: Share the prototype build and launch scheme. -->\n<Scheme LastUpgradeVersion="2630" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">' + reference + '</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">' + ui_reference + '</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">' + native_reference + '</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">' + ui_reference + '</TestableReference><TestableReference skipped="NO">' + native_reference + '</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">' + reference + '</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">' + reference + '</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>\n')
    print(f"Generated project with {len(sources)} Swift source files.")


if __name__ == "__main__":
    main()
