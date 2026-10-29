#!/usr/bin/env python3
"""Require a completed test summary as well as a successful Godot process."""
import argparse
import os
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--timeout", type=int, default=180)
parser.add_argument("command", nargs=argparse.REMAINDER)
args = parser.parse_args()
command = args.command
if command and command[0] == "--": command.pop(0)
if not command: parser.error("Provide the Godot command after --")
try:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                            timeout=args.timeout, env=os.environ)
except subprocess.TimeoutExpired as error:
    output = error.stdout or b""
    print(output.decode(errors="replace") if isinstance(output, bytes) else output, flush=True)
    raise SystemExit("Godot test did not complete before its timeout")
print(result.stdout, end="", flush=True)
summary = re.findall(r"(?:RESULT|LIFE|PLANNING|JUNCTIONS|PLAZAS|COMFORT|CUSTOMIZATION|CYCLE|MOMENTUM|SPORTS|SCENE|REGIONS|SERVICES|I18N|SURFACES|WORLDS|OPERATIONS): (\d+) passed; (\d+) failed", result.stdout)
failed = result.returncode or not summary or any(int(item[1]) for item in summary)
failed = failed or "SCRIPT ERROR" in result.stdout or "Parse Error" in result.stdout
raise SystemExit(1 if failed else 0)
