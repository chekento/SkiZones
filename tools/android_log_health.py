"""Classify engine errors without filtering any error out of acceptance."""
import re


def engine_errors(log):
    lines = log.splitlines()
    result = []
    for index, line in enumerate(lines):
        if not (("E godot" in line and "ERROR:" in line) or
                re.search(r"\bE\s+godot\s*:\s*ERROR:", line)):
            continue
        context = lines[max(0, index - 4):index + 5]
        text = "\n".join(context).lower()
        category = "engine"
        if any(key in text for key in ("audio_driver", "audiotrack", "audioflinger", "opensl")):
            category = "audio"
        elif any(key in text for key in ("renderer", "rendering", "vulkan", "opengl", "egl_")):
            category = "graphics"
        result.append({"line": index + 1, "category": category,
                       "error": line, "context": context})
    return result
