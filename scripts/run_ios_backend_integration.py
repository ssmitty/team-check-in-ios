"""
run_ios_backend_integration.py
Purpose: Run real local account/private-data integration inside the signed simulator app with Keychain storage.
Notes: A test-bundle-only loopback adapter is used; shipped HTTPS/ATS and app configuration are unchanged.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.parse import urlparse
from run_native_platform_tests import select_simulator


def main():
    """Validate isolation, pass only the public key to XCTest, and require an executed integration result."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator-id")
    parser.add_argument("--derived-data", type=Path, default=Path("/tmp/team-check-in-native-build"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    status = subprocess.run(["supabase", "status", "-o", "json"], cwd=root,
                            capture_output=True, text=True, check=True, timeout=20)
    config = json.loads(status.stdout)
    target = urlparse(config["API_URL"])
    if (target.scheme, target.hostname, target.port) != ("http", "127.0.0.1", 54321):
        raise RuntimeError("Integration requires the isolated loopback stack.")
    device = select_simulator(args.simulator_id)
    environment = os.environ.copy()
    for name in ("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEY", "SUPABASE_ACCESS_TOKEN", "APNS_PRIVATE_KEY"):
        environment.pop(name, None)
    environment["TEST_RUNNER_TEAM_CHECK_IN_LOCAL_INTEGRATION"] = "1"
    environment["TEST_RUNNER_TEAM_CHECK_IN_LOCAL_ANON_KEY"] = config["ANON_KEY"]
    log = Path("/tmp/team-check-in-ios-backend-integration.log")
    with log.open("w") as output:
        result = subprocess.run([
            "xcodebuild", "-project", "TeamCheckIn.xcodeproj", "-scheme", "TeamCheckIn",
            "-destination", "platform=iOS Simulator,id=" + device["udid"],
            "-derivedDataPath", str(args.derived_data), "-parallel-testing-enabled", "NO",
            "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_IDENTITY=-", "test",
            "-only-testing:TeamCheckInNativeTests/NativeBackendIntegrationTests",
        ], cwd=root, env=environment, stdout=output, stderr=subprocess.STDOUT, timeout=420)
    output = log.read_text()
    if result.returncode or not re.search(r"Test liveServicesPreserveAccountPairPhotoAndWarmupPrivacy\(\) passed", output):
        raise RuntimeError("Native integration did not pass as an executed test; inspect " + str(log))
    print("Real local iOS service/Keychain integration passed. Log: " + str(log))


if __name__ == "__main__":
    main()
