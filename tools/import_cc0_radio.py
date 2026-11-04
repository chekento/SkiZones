#!/usr/bin/env python3
"""Import only the pinned, verified CC0 music tracks in library.json.

Safe to rerun. Requires standard-library Python 3 and GitHub download access.
No unverified source is downloaded dynamically by the Android game.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/music/cc0/library.json"
LIMIT = 12 * 1024 * 1024

def git_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + bytes([0]) + data).hexdigest()

def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    records = [track for playlist in manifest["stations"].values() for track in playlist]
    for track in records:
        assert track["license"] == "CC0-1.0", track["id"]
        source = track["mirror"]
        owner_repo = source["repository"]
        commit = source["commit"]
        source_path = urllib.parse.quote(source["path"], safe="/")
        url = f"https://raw.githubusercontent.com/{owner_repo}/{commit}/{source_path}"
        dest = ROOT / track["file"].removeprefix("res://")
        dest.parent.mkdir(parents=True, exist_ok=True)
        expected_bytes = int(source["bytes"])
        expected_hash = source["git_blob_sha1"]
        if dest.exists():
            data = dest.read_bytes()
            if len(data) == expected_bytes and git_sha(data) == expected_hash:
                print("VERIFIED", track["id"], len(data))
                continue
            raise RuntimeError(f"Existing music failed integrity check: {dest}")
        request = urllib.request.Request(url, headers={"User-Agent":"SkiZones-CC0-Importer/1.0"})
        with urllib.request.urlopen(request, timeout=70) as response:
            data = response.read(LIMIT + 1)
        if len(data) != expected_bytes or len(data) > LIMIT:
            raise RuntimeError(f"Size mismatch: {track['id']} received {len(data)} expected {expected_bytes}")
        if data[:4] != b"OggS":
            raise RuntimeError(f"Invalid Ogg Vorbis header: {track['id']}")
        if git_sha(data) != expected_hash:
            raise RuntimeError(f"Source blob SHA mismatch: {track['id']}")
        temp = dest.with_suffix(".ogg.partial")
        temp.write_bytes(data)
        os.replace(temp, dest)
        print("IMPORTED", track["id"], len(data))
    print(f"Imported/verified {len(records)} original CC0 tracks")
    return 0

if __name__ == "__main__":
    sys.exit(main())
