#!/usr/bin/env python3
"""Generate saves with pinned original releases, then load them with this tree.

Only core source is extracted: the fantasy starter uses procedural terrain.
Each subprocess has a deadline; source logs and fixture hashes survive failures.
"""
import argparse
import hashlib
import io
import json
import os
import re
from pathlib import Path
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--partition", type=int, default=0)
    parser.add_argument("--partitions", type=int, default=1)
    parser.add_argument("--output", type=Path, default=ROOT / "build/historical-saves")
    args = parser.parse_args()
    assert 0 <= args.partition < args.partitions
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    selected = json.loads((ROOT / "tests/historical_releases_0382.json").read_text())[args.partition::args.partitions]
    env = dict(os.environ, SKIZONES_EARLY_FIXTURES=str(output), XDG_DATA_HOME=str(output / "skizones-test-historical"))
    results = []

    def execute(command, cwd, name):
        result = subprocess.run(command, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        (output / name).write_text(result.stdout)
        if result.returncode or "SCRIPT ERROR:" in result.stdout or "RESULT:" not in result.stdout:
            raise RuntimeError(f"{name}: exit {result.returncode}\n{result.stdout[-5000:]}")

    for entry in selected:
        tag, commit = entry["tag"], entry["commit"]
        version = tag.removeprefix("v")
        print(f"VERIFY {tag} {commit[:12]}", flush=True)
        resolved = subprocess.check_output(["git", "rev-list", "-n1", tag], cwd=ROOT, text=True).strip()
        assert resolved == commit, f"Historical tag moved: {tag}"
        env["SKIZONES_FIXTURE_RELEASE"] = version
        with tempfile.TemporaryDirectory(prefix="skizones-original-") as temporary:
            original = Path(temporary)
            paths = ["src", "project.godot"]
            for resource in ["translations", "assets/geodata", "assets/access"]:
                if subprocess.check_output(["git", "ls-tree", "--name-only", commit, resource], cwd=ROOT).strip():
                    paths.append(resource)
            config = subprocess.check_output(["git", "show", f"{commit}:project.godot"], cwd=ROOT, text=True)
            for resource in re.findall(r'boot_splash/image="res://([^"\n]+)"', config):
                paths.append(resource)
            archive = subprocess.check_output(["git", "archive", commit, *paths], cwd=ROOT)
            with tarfile.open(fileobj=io.BytesIO(archive)) as source:
                source.extractall(original, filter="data")
            execute([args.godot, "--headless", "--path", str(original), "--language", "de", "--script", str(ROOT / "tests/generate_release_save_0382.gd")], original, version + "-generate.log")
        env["SKIZONES_VERIFY_RELEASES"] = version
        execute([args.godot, "--headless", "--path", str(ROOT), "--language", "de", "--script", "tests/released_save_compat_0382.gd"], ROOT, version + "-restore.log")
        results.append(dict(entry, sha256=hashlib.sha256((output / (version + ".json")).read_bytes()).hexdigest(), passed=True))
        (output / f"results-{args.partition}.json").write_text(json.dumps(results, indent=2) + "\n")
        print(f"PASS {version}: original generation and seven restoration checks", flush=True)
    print(f"RESULT: {len(results)} original releases passed; 0 failed", flush=True)


if __name__ == "__main__":
    main()
