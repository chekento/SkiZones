#!/usr/bin/env python3
"""Reject divergent app/lifecycle versions before export or APK packaging."""
import configparser
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def validate_versions(project: str, presets: str) -> tuple[str, int]:
    matches = re.findall(r'^config/version="(\d+\.\d+\.\d+)"$', project, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError("Project must declare exactly one semantic app version")
    version = matches[0]
    config = configparser.ConfigParser(interpolation=None)
    config.read_string(presets)
    android = [section for section in config.sections()
               if re.fullmatch(r"preset\.\d+", section)
               and config[section].get("platform") == '"Android"']
    if not android:
        raise ValueError("No Android export presets found")
    codes = []
    for section in android:
        options = section + ".options"
        if options not in config:
            raise ValueError(f"{section} has no Android options")
        if config[options].get("version/name") != f'"{version}"':
            raise ValueError(f"{section} version/name must match project version {version}")
        code = config[options].get("version/code", "")
        if not re.fullmatch(r"[1-9]\d*", code) or int(code) > 2100000000:
            raise ValueError(f"{section} has an invalid Android version/code")
        codes.append(int(code))
    if len(set(codes)) != 1:
        raise ValueError("All Android export presets must use the same version/code")
    return version, codes[0]


def project_version(root: Path = ROOT) -> tuple[str, int]:
    return validate_versions((root / "project.godot").read_text(encoding="utf-8"),
                             (root / "export_presets.cfg").read_text(encoding="utf-8"))


if __name__ == "__main__":
    version, code = project_version()
    print(f"Android export versions agree: {version} (code {code})")
