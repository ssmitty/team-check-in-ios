"""
run_native_platform_tests.py
Purpose: Verify shipped secure storage and photo processing in an ad-hoc signed iPhone simulator app.
Exports: main
Notes: Uses an installed runtime and temporary derived data; never downloads or uses Apple credentials.
"""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def select_simulator(requested):
    """Choose an available iOS 17+ iPhone, or validate the caller's exact device identifier."""
    inventory = json.loads(subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"], text=True, timeout=20))
    candidates = []
    for runtime, devices in inventory["devices"].items():
        if ".iOS-" not in runtime:
            continue
        version = tuple(int(part) for part in runtime.split(".iOS-")[-1].split("-"))
        if version[0] < 17:
            continue
        for device in devices:
            if device.get("isAvailable") and (
                    "iPhone" in device["name"] or device["name"] == "Team Check-in Prototype"):
                candidates.append((version, device))
    if requested:
        matches = [device for _, device in candidates if device["udid"] == requested]
        if not matches:
            raise RuntimeError("Requested simulator is not an available iOS 17+ iPhone.")
        return matches[0]
    if not candidates:
        raise RuntimeError("Install an iOS 17+ simulator in Xcode before native testing.")
    candidates.sort(key=lambda item: (item[0], item[1]["name"]), reverse=True)
    return candidates[0][1]


def main():
    """Run the app-hosted Apple API contracts with signing and a bounded test duration."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator-id")
    parser.add_argument("--include-ui", action="store_true", help="Also run demo flows and the unsuppressed welcome accessibility audit.")
    parser.add_argument("--derived-data", type=Path, default=Path(tempfile.gettempdir()) / "team-check-in-native-build")
    arguments = parser.parse_args()
    device = select_simulator(arguments.simulator_id)
    root = Path(__file__).resolve().parent.parent
    derived = arguments.derived_data
    print("Native platform tests on " + device["name"], flush=True)
    command = [
        "xcodebuild", "-project", "TeamCheckIn.xcodeproj", "-scheme", "TeamCheckIn",
        "-destination", "platform=iOS Simulator,id=" + device["udid"],
        "-derivedDataPath", str(derived), "-parallel-testing-enabled", "NO",
        "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_IDENTITY=-", "test",
    ]
    if not arguments.include_ui:
        command.append("-only-testing:TeamCheckInNativeTests")
    subprocess.run(command, cwd=root, check=True, timeout=420)


if __name__ == "__main__":
    main()
