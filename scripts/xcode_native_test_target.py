"""
xcode_native_test_target.py
Purpose: Add app-hosted native tests to verify Apple APIs in the shipped app module.
Exports: add_native_test_target
"""


def add_native_test_target(add, app_target, builds, product, identifier):
    """Create a simulator unit bundle loaded into TeamCheckIn rather than a copied implementation."""
    configs = []
    for configuration in ["Debug", "Release"]:
        configs.append(add("nativeTests:" + configuration,
            f'isa = XCBuildConfiguration; name = {configuration}; buildSettings = {{ PRODUCT_NAME = TeamCheckInNativeTests; PRODUCT_BUNDLE_IDENTIFIER = dev.ssmitty.TeamCheckInNativeTests; GENERATE_INFOPLIST_FILE = YES; SWIFT_VERSION = 6.0; IPHONEOS_DEPLOYMENT_TARGET = 17.0; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; BUNDLE_LOADER = "$(TEST_HOST)"; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/TeamCheckIn.app/TeamCheckIn"; }};'))
    config_list = add("nativeTestConfigs", 'isa = XCConfigurationList; buildConfigurations = (' + ','.join(configs) + ',); defaultConfigurationName = Release;')
    phase = add("nativeTestSources", 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(builds) + ',); runOnlyForDeploymentPostprocessing = 0;')
    proxy = add("nativeTestProxy", f'isa = PBXContainerItemProxy; containerPortal = {identifier("project")}; proxyType = 1; remoteGlobalIDString = {app_target}; remoteInfo = TeamCheckIn;')
    dependency = add("nativeTestDependency", f'isa = PBXTargetDependency; target = {app_target}; targetProxy = {proxy};')
    return add("nativeTestTarget", f'isa = PBXNativeTarget; buildConfigurationList = {config_list}; buildPhases = ({phase},); buildRules = (); dependencies = ({dependency},); name = TeamCheckInNativeTests; productName = TeamCheckInNativeTests; productReference = {product}; productType = "com.apple.product-type.bundle.unit-test";')
