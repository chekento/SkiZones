#!/usr/bin/env bash
# Ubuntu hosted runners can inherit a Microsoft apt feed that returns 404.
# It is unrelated to SkiZones; keep the runner's Ubuntu sources and install
# only its graphics-test dependencies, without touching project data.
set -euo pipefail
if command -v xvfb-run >/dev/null 2>&1 && ldconfig -p | grep -q 'libGL.so.1'; then
  echo "Virtual display and OpenGL already installed."
  exit 0
fi
for source in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
  if [[ -f "$source" ]] && grep -q 'packages.microsoft.com/ubuntu/24.04/prod' "$source"; then
    echo "Temporarily excluding stale Microsoft apt feed: $source"
    sudo mv "$source" "$source.skizones-disabled"
  fi
done
sudo apt-get update -qq -o Acquire::Retries=2 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30
sudo apt-get install -y -o Acquire::Retries=2 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 xvfb libgl1-mesa-dri
