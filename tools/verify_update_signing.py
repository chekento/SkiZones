#!/usr/bin/env python3
"""Refuse to publish an APK that cannot replace the preceding public install."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "https://api.github.com/repos/chekento/SkiZones"


def main():
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "SkiZones-build"}
    token = os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(REPOSITORY + "/releases?per_page=100", headers=headers)
    with urllib.request.urlopen(request, timeout=45) as response:
        releases = json.load(response)
    builds = []
    for release in releases:
        match = re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)", release["tag_name"])
        if not match or release["draft"]:
            continue
        for asset in release["assets"]:
            if asset["name"] == "SkiZones-" + release["tag_name"][1:] + "-android-arm64.apk":
                builds.append((tuple(map(int, match.groups())), release, asset))
    if not builds:
        raise SystemExit("No previous public ARM64 installation was available to verify update continuity.")
    _, release, asset = max(builds, key=lambda item: item[0])
    url = asset["browser_download_url"]
    expected = "https://github.com/chekento/SkiZones/releases/download/" + release["tag_name"] + "/" + asset["name"]
    if url != expected:
        raise SystemExit("Unexpected previous-release download URL")
    previous = ROOT / "build/android/previous-public.apk"
    # Public download: do not forward the API token to redirect/CDN hosts.
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "SkiZones-build"}), timeout=90) as response:
        with previous.open("wb") as stream:
            while block := response.read(1024 * 1024):
                stream.write(block)
    signer = Path(os.environ["ANDROID_HOME"]) / "build-tools/35.0.0/apksigner"

    def certificate(apk):
        output = subprocess.check_output([str(signer), "verify", "--print-certs", str(apk)], text=True)
        values = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-f]+)", output)
        if len(values) != 1:
            raise SystemExit("The update requires exactly one verified APK signer")
        return values[0]

    old = certificate(previous)
    current = certificate(ROOT / "build/android/SkiZones-debug.apk")
    if old != current:
        raise SystemExit("Signing identity changed: this APK cannot preserve the previous installation. Restore the existing signing key before publishing.")
    evidence = {"previous_version": release["tag_name"], "previous_sha256": hashlib.sha256(previous.read_bytes()).hexdigest(), "signer_sha256": current, "same_signer": True}
    (ROOT / "build/android/update-signing.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print("PASS In-place update signing identity matches " + release["tag_name"] + ": " + current)


if __name__ == "__main__":
    main()
