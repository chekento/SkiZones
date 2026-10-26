#!/usr/bin/env python3
"""Export a debug APK using isolated editor preferences and a local debug key.

Requires Godot 4.5.1 + matching export templates, JDK 17 and Android SDK 35.
Never edits the developer's normal Godot settings or creates a release key.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    # Other desktop platforms can export the same preset through Godot's editor.
    if not sys.platform.startswith("linux"):
        sys.exit("Use Godot's editor to export on Windows/macOS; see docs/ANDROID.md.")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--output", default="build/android/SkiZones-debug.apk")
    args = parser.parse_args()
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    java = os.environ.get("JAVA_HOME")
    if not sdk or not java:
        sys.exit("Set ANDROID_HOME (SDK 35) and JAVA_HOME (JDK 17) first. See docs/ANDROID.md.")
    sdk, java = Path(sdk).resolve(), Path(java).resolve()
    suffix = ".exe" if os.name == "nt" else ""
    required = [sdk / "platform-tools" / ("adb" + suffix), java / "bin" / ("keytool" + suffix), sdk / "build-tools" / "35.0.0" / ("zipalign" + suffix)]
    for path in required:
        if not path.exists():
            sys.exit(f"Missing build dependency: {path}")
    output = (ROOT / args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    config = ROOT / "build" / "export-config"
    (ROOT / "build" / ".gdignore").write_text("", encoding="utf-8")
    settings_dir = config / "godot"
    settings_dir.mkdir(parents=True, exist_ok=True)
    key = config / "skizones-debug.keystore"
    if not key.exists():
        subprocess.run([str(required[1]), "-genkeypair", "-noprompt", "-keystore", str(key), "-alias", "androiddebugkey", "-storepass", "android", "-keypass", "android", "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-dname", "CN=Android Debug,O=Android,C=US"], check=True)
    values = {
        "export/android/android_sdk_path": str(sdk),
        "export/android/java_sdk_path": str(java),
        "export/android/debug_keystore": str(key),
        "export/android/debug_keystore_user": "androiddebugkey",
        "export/android/debug_keystore_pass": "android",
    }
    text = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    text += "".join(f"{name} = {json.dumps(value)}\n" for name, value in values.items())
    (settings_dir / "editor_settings-4.5.tres").write_text(text, encoding="utf-8")
    env = os.environ.copy()
    env["XDG_CONFIG_HOME"] = str(config)
    subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--editor", "--import", "--quit"], env=env, check=True)
    subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--export-debug", "Android", str(output)], env=env, check=True)
    if not output.exists() or output.stat().st_size < 1000000:
        sys.exit("Godot did not produce a valid-sized APK.")
    print(f"Debug APK ready: {output}")


if __name__ == "__main__":
    main()
