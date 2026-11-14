#!/usr/bin/env python3
"""Prepare versioned APK downloads and their checksum after a verified export."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile
from check_android_versions import project_version, validate_apk_identity

ROOT = Path(__file__).resolve().parents[1]


def main():
    version, code = project_version(ROOT)
    source = ROOT / "build/android/SkiZones.apk"
    if not source.is_file():
        raise SystemExit("Export and verify the APK before preparing the download.")
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk:
        raise SystemExit("Set ANDROID_HOME or ANDROID_SDK_ROOT to verify the compiled APK identity.")
    aapt = Path(sdk) / "build-tools/35.0.0/aapt2"
    badging = subprocess.check_output([str(aapt), "dump", "badging", str(source)], text=True)
    validate_apk_identity(badging, version, code)
    with zipfile.ZipFile(source) as archive:
        resource = "assets/assets/access/entrances.json"
        if resource not in archive.namelist() or archive.read(resource) != (ROOT / "assets/access/entrances.json").read_bytes():
            raise SystemExit("The APK is missing the current bundled map-entrance data.")
        for region in ("braunlage", "filzmoos", "kitzbuehel", "seiseralm"):
            for suffix in (".json", "-network.json"):
                name = region + suffix
                member = "assets/assets/geodata/towns/" + name
                expected = ROOT / "assets" / "geodata" / "towns" / name
                if not expected.is_file() or member not in archive.namelist():
                    raise SystemExit("Android package is missing a pinned real town/road graph: " + member)
                if archive.read(member) != expected.read_bytes():
                    raise SystemExit("Android has stale or corrupted town data: " + name)
            venue = region + ".json"
            venue_member = "assets/assets/geodata/mountain-venues/" + venue
            venue_source = ROOT / "assets" / "geodata" / "mountain-venues" / venue
            if not venue_source.is_file() or venue_member not in archive.namelist():
                raise SystemExit("Android missing the vetted piste-adjacent hospitality data: " + venue)
            if archive.read(venue_member) != venue_source.read_bytes():
                raise SystemExit("Android has stale mountainside OSM hospitality data: " + venue)
    folder = ROOT / "build/release"
    folder.mkdir(parents=True, exist_ok=True)
    apk = folder / f"SkiZones-{version}-android-arm64.apk"
    shutil.copy2(source, apk)
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    apk.with_suffix(".apk.sha256").write_text(f"{digest}  {apk.name}\n", encoding="utf-8")
    manifest = {"app": "SkiZones", "version": version, "version_code": code, "package": "cloud.kosch.skizones", "architecture": "arm64-v8a", "build_type": "release", "file_name": apk.name, "size_bytes": apk.stat().st_size, "sha256": digest, "commit": os.environ.get("GITHUB_SHA")}
    patch = ROOT / "tools/android/GLSurfaceView-lifecycle.patch"
    manifest["android_surface_patch_sha256"] = hashlib.sha256(patch.read_bytes()).hexdigest()
    manifest["android_input_patch_sha256"] = hashlib.sha256((ROOT / "tools/android/InputEventRunnable-touch-release.patch").read_bytes()).hexdigest()
    signing = ROOT / "build/android/update-signing.json"
    if signing.is_file():
        manifest["update_signing"] = json.loads(signing.read_text())
    manifest["android_app_info_bridge_sha256"] = hashlib.sha256((ROOT / "tools/android/AppInfoBridge.java").read_bytes()).hexdigest()
    manifest["update_mode"] = "browser"
    manifest["compiled_identity_verified"] = True
    security = ROOT / "build/android/apk-security.json"
    if security.is_file():
        manifest["security_review"] = json.loads(security.read_text())
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if os.environ.get("GITHUB_OUTPUT"):
        with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as output:
            output.write(f"version={version}\n")
    print(f"Prepared {apk.name} ({apk.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
