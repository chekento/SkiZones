#!/usr/bin/env bash
set -euo pipefail

# Official pinned binaries, verified against the official SHA-512 manifest.
version=4.5.1
target="${SKIZONES_TOOLS_DIR:-${RUNNER_TEMP:-/tmp}/skizones-godot}"
mkdir -p "$target" "$target/downloads"
cd "$target/downloads"
base="https://github.com/godotengine/godot-builds/releases/download/${version}-stable"
editor="Godot_v${version}-stable_linux.x86_64.zip"
templates="Godot_v${version}-stable_export_templates.tpz"
for item in "$editor" "$templates" SHA512-SUMS.txt; do
  curl --fail --location --retry 3 --silent --show-error "$base/$item" --output "$item"
done
sha512sum --ignore-missing --check SHA512-SUMS.txt
unzip -oq "$editor" -d "$target"
chmod +x "$target/Godot_v${version}-stable_linux.x86_64"
template_target="$target/share/godot/export_templates/${version}.stable"
mkdir -p "$template_target"
unzip -joq "$templates" templates/android_debug.apk templates/android_release.apk templates/version.txt -d "$template_target"
rm "$editor" "$templates"
printf 'Godot installed at %s\n' "$target"
