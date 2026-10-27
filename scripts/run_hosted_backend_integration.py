"""
run_hosted_backend_integration.py
Purpose: Run shipped Swift services and real cron checks against explicitly provisioned development fixtures.
Notes: Accepts seven synthetic accounts and a public key only; never provisions accounts or sends email.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from run_native_platform_tests import select_simulator


def run_awake(command, **options):
    """Prevent idle/system sleep only during a bounded test, leaving the screen lock unchanged."""
    wake = None
    if sys.platform == "darwin":
        wake = subprocess.Popen(["/usr/bin/caffeinate", "-is", "-t", str(options["timeout"] + 30)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        return subprocess.run(command, **options)
    finally:
        if wake is not None:
            if wake.poll() is None:
                wake.terminate()
            wake.wait(timeout=5)


def validate_fixture(path):
    """Reject other hosts, real account addresses, duplicate identities, and nonprivate credential files."""
    if path.stat().st_mode & 0o077:
        raise ValueError("Fixture credentials must have private file permissions (chmod 600).")
    fixture = json.loads(path.read_text())
    accounts = fixture["accounts"]
    if (fixture["url"] != "https://jdwrtscsjilmnurmhrez.supabase.co"
            or not fixture["marker"].startswith("hosted-review-") or len(accounts) != 7
            or len({account["id"] for account in accounts}) != 7
            or not all(account["email"].startswith("hosted-review-")
                       and account["email"].endswith("@example.test")
                       and len(account["password"]) >= 32 for account in accounts)):
        raise ValueError("Only isolated synthetic fixtures on the approved development host are accepted.")


def main():
    """Require an executed native test, then verify real timer opening without calling pairing generation."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--platform", choices=("mac", "ios"), default="mac")
    parser.add_argument("--simulator-id")
    parser.add_argument("--derived-data", type=Path, default=Path("/tmp/team-check-in-current-review"))
    args = parser.parse_args()
    fixture_path = args.fixture.resolve()
    root = Path(__file__).resolve().parent.parent
    if fixture_path.is_relative_to(root):
        raise ValueError("Keep hosted fixture credentials outside the repository.")
    validate_fixture(fixture_path)
    settings = (root / "Config.xcconfig").read_text()
    match = re.search(r"^SUPABASE_PUBLISHABLE_KEY\s*=\s*(sb_publishable_\S+)\s*$", settings, re.MULTILINE)
    if not match:
        raise ValueError("Configure the development public publishable key in ignored Config.xcconfig.")
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(("SUPABASE_", "APNS_", "TEAM_CHECK_IN_", "TEST_RUNNER_TEAM_CHECK_IN_"))}
    prefix = "TEST_RUNNER_" if args.platform == "ios" else ""
    environment[prefix + "TEAM_CHECK_IN_HOSTED_FIXTURE"] = str(fixture_path)
    environment[prefix + "TEAM_CHECK_IN_LOCAL_ANON_KEY"] = match[1]
    if args.platform == "ios":
        device = select_simulator(args.simulator_id)
        command = ["xcodebuild", "-project", "TeamCheckIn.xcodeproj", "-scheme", "TeamCheckIn",
                   "-destination", "platform=iOS Simulator,id=" + device["udid"],
                   "-derivedDataPath", str(args.derived_data), "-parallel-testing-enabled", "NO",
                   "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_IDENTITY=-", "test",
                   "-only-testing:TeamCheckInNativeTests/NativeBackendIntegrationTests"]
    else:
        command = ["swift", "test", "--filter", "NativeBackendIntegrationTests"]
    log = Path("/tmp/team-check-in-hosted-" + args.platform + ".log")
    with log.open("w") as output:
        log.chmod(0o600)
        result = run_awake(command, cwd=root, env=environment, stdout=output,
                                stderr=subprocess.STDOUT, timeout=420)
    if result.returncode or not re.search(r"Test liveServicesPreserveAccountPairPhotoAndWarmupPrivacy\(\) passed", log.read_text()):
        raise RuntimeError("Hosted native integration did not execute successfully. Inspect " + str(log))
    environment["TEAM_CHECK_IN_HOSTED_FIXTURE"] = str(fixture_path)
    environment["TEAM_CHECK_IN_HOSTED_PUBLIC_KEY"] = match[1]
    run_awake(["node", "--test", "backend/hostedSchedule.integration.test.mjs"],
                   cwd=root, env=environment, timeout=320, check=True)
    print("Hosted Swift and scheduled-game checks passed. Native log: " + str(log))


if __name__ == "__main__":
    main()
