"""
xcode_ui_target.py
Purpose: Add the isolated simulator UI test target to the dependency-free project generator.
Exports: add_ui_target
"""


def add_ui_target(add, app_target, ui_builds, ui_product, identifier):
    """Create UI runner settings and an explicit dependency on the app target."""
    ui_configs = []
    for configuration in ["Debug", "Release"]:
        ui_configs.append(add("ui:" + configuration,
            f'isa = XCBuildConfiguration; name = {configuration}; buildSettings = {{ PRODUCT_NAME = TeamCheckInUITests; PRODUCT_BUNDLE_IDENTIFIER = dev.ssmitty.TeamCheckInUITests; GENERATE_INFOPLIST_FILE = YES; SWIFT_VERSION = 6.0; IPHONEOS_DEPLOYMENT_TARGET = 17.0; TARGETED_DEVICE_FAMILY = 1; TEST_TARGET_NAME = TeamCheckIn; CODE_SIGN_STYLE = Automatic; }};'))
    ui_config = add("uiConfigs", 'isa = XCConfigurationList; buildConfigurations = (' + ','.join(ui_configs) + ',); defaultConfigurationName = Release;')
    ui_phase = add("uiSources", 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(ui_builds) + ',); runOnlyForDeploymentPostprocessing = 0;')
    proxy = add("uiProxy", f'isa = PBXContainerItemProxy; containerPortal = {identifier("project")}; proxyType = 1; remoteGlobalIDString = {app_target}; remoteInfo = TeamCheckIn;')
    dependency = add("uiDependency", f'isa = PBXTargetDependency; target = {app_target}; targetProxy = {proxy};')
    ui_target = add("uiTarget", f'isa = PBXNativeTarget; buildConfigurationList = {ui_config}; buildPhases = ({ui_phase},); buildRules = (); dependencies = ({dependency},); name = TeamCheckInUITests; productName = TeamCheckInUITests; productReference = {ui_product}; productType = "com.apple.product-type.bundle.ui-testing";')
    return ui_target
