#!/usr/bin/env python3
"""Refuse to publish an APK that cannot replace the preceding public install."""
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import time
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
    # A public APK is ~175 MB; a single CDN read timeout must not discard
    # an otherwise valid release. Resume partial downloads where supported.
    # Never pass GH_TOKEN to the public download/CDN redirect.
    expected_size = int(asset["size"])
    if expected_size <= 0:
        raise SystemExit("The previous public APK has an invalid release size")
    for attempt in range(1, 7):
        offset = previous.stat().st_size if previous.exists() else 0
        if offset == expected_size:
            break
        if offset > expected_size:
            previous.unlink()
            offset = 0
        download_headers = {"User-Agent": "SkiZones-build"}
        if offset:
            download_headers["Range"] = "bytes=%d-" % offset
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=download_headers), timeout=180) as response:
                # A server may ignore Range and send the full object.
                status = response.status
                if offset and status != 206:
                    offset = 0
                if status == 206:
                    content_range = response.headers.get("Content-Range", "")
                    if not content_range.startswith("bytes %d-" % offset):
                        raise RuntimeError("Unexpected public APK Content-Range: " + content_range)
                with previous.open("ab" if offset else "wb") as stream:
                    while block := response.read(256 * 1024):
                        stream.write(block)
            if previous.stat().st_size == expected_size:
                break
            print("Previous public APK download incomplete: %d / %d bytes" % (previous.stat().st_size, expected_size), flush=True)
        except (OSError, RuntimeError, socket.timeout) as error:
            print("Previous APK download attempt %d/6 interrupted: %s" % (attempt, error), flush=True)
        if attempt < 6:
            time.sleep(min(attempt * 2, 10))
    if not previous.exists() or previous.stat().st_size != expected_size:
        raise SystemExit("Cannot verify update signing: public APK download remained incomplete after retries")
    signer = Path(os.environ["ANDROID_HOME"]) / "build-tools/35.0.0/apksigner"

    def certificate(apk):
        output = subprocess.check_output([str(signer), "verify", "--print-certs", str(apk)], text=True)
        values = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-f]+)", output)
        if len(values) != 1:
            raise SystemExit("The update requires exactly one verified APK signer")
        return values[0]

    old = certificate(previous)
    current = certificate(ROOT / "build/android/SkiZones.apk")
    if old != current:
        raise SystemExit("Signing identity changed: this APK cannot preserve the previous installation. Restore the existing signing key before publishing.")
    evidence = {"previous_version": release["tag_name"], "previous_sha256": hashlib.sha256(previous.read_bytes()).hexdigest(), "signer_sha256": current, "same_signer": True}
    (ROOT / "build/android/update-signing.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print("PASS In-place update signing identity matches " + release["tag_name"] + ": " + current)


if __name__ == "__main__":
    main()
