#!/usr/bin/env python3
"""Check the shipped gettext catalog, placeholders and source-message coverage."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
TECHNICAL = {"Color", "Label", "Button", "Control", "Node3D", "VBoxContainer", "RichTextLabel",
             "OptionButton", "PopupMenu", "Window", "LineEdit", "AcceptDialog", "CheckBox",
             "CheckButton", "ScrollContainer", "MultiMeshInstance3D", "Android", "Godot",
             "AndroidRuntime", "Accept: application/vnd.github+json", "User-Agent: SkiZones/",
             "Dummy", "FileAccess", "Main", "Snow", "SKI", "N", "SkiZones"}

def catalog():
    result, key = {}, None
    for line in (ROOT / "translations/en.po").read_text().splitlines():
        if line.startswith("msgid "):
            key = json.loads(line[6:])
        elif line.startswith("msgstr ") and key:
            assert key not in result, f"Duplicate message: {key}"
            result[key] = json.loads(line[7:])
    return result

def main():
    messages = catalog()
    errors = []
    placeholders = re.compile(r"%(?:[-+0]*\d*(?:\.\d+)?)?[sdf]")
    for source, translated in messages.items():
        if not translated.strip(): errors.append(f"Empty translation: {source}")
        before = placeholders.findall(source.replace("%%", ""))
        after = placeholders.findall(translated.replace("%%", ""))
        if before != after: errors.append(f"Changed format placeholders: {source}")
    strings = re.compile(r'"(?:\\.|[^"\\])*"')
    for path in (ROOT / "src").rglob("*.gd"):
        for match in strings.finditer(path.read_text()):
            try: value = json.loads(match.group())
            except ValueError: continue
            if value in TECHNICAL or value.startswith(("res://", "user://", "http")) or "shader_type" in value: continue
            if not re.search(r"[a-zA-ZäöüÄÖÜß]", value): continue
            candidate = re.search(r"[äöüÄÖÜß]", value) or " " in value or re.fullmatch(r"[A-Z][a-zA-Z]+", value)
            if candidate and value not in messages:
                errors.append(f"Uncatalogued message in {path.relative_to(ROOT)}: {value}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"LOCALIZATION: {len(messages)} messages; placeholders and source coverage verified")

if __name__ == "__main__":
    main()
