"""
run_swift_backend_integration.py
Purpose: Enable the Swift service suite against the isolated local backend without printing credentials.
Notes: Only the anonymous client key enters the test process; no service credential is supplied.
"""
import json
import os
import subprocess
from urllib.parse import urlparse
from pathlib import Path


def main():
    """Validate the local stack and run the real Swift transport suite with bounded execution."""
    root = Path(__file__).resolve().parent.parent
    result = subprocess.run(["supabase", "status", "-o", "json"], cwd=root, capture_output=True, text=True, timeout=20, check=True)
    config = json.loads(result.stdout)
    target = urlparse(config["API_URL"])
    if target.scheme != "http" or target.hostname != "127.0.0.1" or target.port != 54321:
        raise RuntimeError("Integration requires the isolated loopback stack.")
    environment = os.environ.copy()
    environment["TEAM_CHECK_IN_LOCAL_INTEGRATION"] = "1"
    environment["TEAM_CHECK_IN_LOCAL_ANON_KEY"] = config["ANON_KEY"]
    subprocess.run(["swift", "test", "--filter", "NativeBackendIntegrationTests"], cwd=root, env=environment, timeout=180, check=True)


if __name__ == "__main__":
    main()
