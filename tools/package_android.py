#!/usr/bin/env python3
"""Prepare versioned APK downloads and their checksum after a verified export."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    version = re.search(r'^config/version="(\d+\.\d+\.\d+)"$', project, re.MULTILINE)
    export_version = re.search(r'^version/name="(\d+\.\d+\.\d+)"$', preset, re.MULTILINE)
    code = re.search(r'^version/code=(\d+)$', preset, re.MULTILINE)
    if not version or not export_version or not code or version[1] != export_version[1]:
        raise SystemExit("Project and Android export versions must match.")
    version = version[1]
    source = ROOT / "build/android/SkiZones.apk"
    if not source.is_file():
        raise SystemExit("Export and verify the APK before preparing the download.")
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
    manifest = {"app": "SkiZones", "version": version, "version_code": int(code[1]), "package": "cloud.kosch.skizones", "architecture": "arm64-v8a", "build_type": "release", "file_name": apk.name, "size_bytes": apk.stat().st_size, "sha256": digest, "commit": os.environ.get("GITHUB_SHA")}
    patch = ROOT / "tools/android/GLSurfaceView-lifecycle.patch"
    manifest["android_surface_patch_sha256"] = hashlib.sha256(patch.read_bytes()).hexdigest()
    manifest["android_input_patch_sha256"] = hashlib.sha256((ROOT / "tools/android/InputEventRunnable-touch-release.patch").read_bytes()).hexdigest()
    signing = ROOT / "build/android/update-signing.json"
    if signing.is_file():
        manifest["update_signing"] = json.loads(signing.read_text())
    manifest["android_app_info_bridge_sha256"] = hashlib.sha256((ROOT / "tools/android/AppInfoBridge.java").read_bytes()).hexdigest()
    manifest["update_mode"] = "browser"
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
