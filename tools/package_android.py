#!/usr/bin/env python3
"""Prepare versioned APK downloads and their checksum after a verified export."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

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
    source = ROOT / "build/android/SkiZones-debug.apk"
    if not source.is_file():
        raise SystemExit("Export and verify the APK before preparing the download.")
    folder = ROOT / "build/release"
    folder.mkdir(parents=True, exist_ok=True)
    apk = folder / f"SkiZones-{version}-android-arm64.apk"
    shutil.copy2(source, apk)
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    apk.with_suffix(".apk.sha256").write_text(f"{digest}  {apk.name}\n", encoding="utf-8")
    manifest = {"app": "SkiZones", "version": version, "version_code": int(code[1]), "package": "cloud.kosch.skizones", "architecture": "arm64-v8a", "build_type": "debug", "file_name": apk.name, "size_bytes": apk.stat().st_size, "sha256": digest, "commit": os.environ.get("GITHUB_SHA")}
    patch = ROOT / "tools/android/GLSurfaceView-lifecycle.patch"
    manifest["android_surface_patch_sha256"] = hashlib.sha256(patch.read_bytes()).hexdigest()
    manifest["android_input_patch_sha256"] = hashlib.sha256((ROOT / "tools/android/InputEventRunnable-touch-release.patch").read_bytes()).hexdigest()
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if os.environ.get("GITHUB_OUTPUT"):
        with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as output:
            output.write(f"version={version}\n")
    print(f"Prepared {apk.name} ({apk.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
