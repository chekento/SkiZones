#!/usr/bin/env python3
"""SkiZones optional CC0 longform importer. Intended for a reviewed branch only.

Import is build-time, never an APK background network call. Source listings are
individually inspected for CC0 before adding them to the candidate manifest.
No file is accepted without measured duration, Ogg encoding and SHA records.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "assets/music/cc0/library.json"
CANDIDATES = ROOT / "assets/music/cc0/longform_candidates_029.json"
DEST = ROOT / "assets/music/cc0"
MAX_BYTES = 35 * 1024 * 1024
MIN_DURATION, MAX_DURATION = 180.0, 480.0

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def git_sha1(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()

def probe(path: Path) -> float:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a:0",
         "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, text=True, check=True, timeout=35)
    return float(result.stdout.strip())

def import_source(song: dict, work: Path) -> tuple[Path, bytes, float, str]:
    addr = str(song["file_url"])
    target = urllib.parse.urlparse(addr)
    if target.scheme != "https" or target.hostname != "opengameart.org" or not target.path.startswith("/sites/default/files/"):
        raise ValueError("Source host or path is not on the reviewed allowlist")
    req = urllib.request.Request(addr, headers={"User-Agent":"Mozilla/5.0 (compatible; SkiZones-License-Audit/1.0)", "Accept":"audio/*"})
    with urllib.request.urlopen(req, timeout=90) as response:
        raw = response.read(MAX_BYTES + 1)
    if not 100_000 < len(raw) <= MAX_BYTES:
        raise ValueError(f"Unexpected raw asset size {len(raw)}")
    origin = work / ("source" + Path(target.path).suffix)
    origin.write_bytes(raw)
    seconds = probe(origin)
    if not MIN_DURATION <= seconds <= MAX_DURATION:
        raise ValueError(f"Duration {seconds:.1f}s outside long-form acceptance (180–480s)")
    output = work / "verified.ogg"
    subprocess.run(
        ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", str(origin),
         "-map", "0:a:0", "-vn", "-c:a", "libvorbis", "-qscale:a", "3",
         "-ar", "44100", "-ac", "2", str(output)],
        check=True, timeout=130)
    encoded = output.read_bytes()
    if not encoded.startswith(b"OggS") or len(encoded) <= 100_000:
        raise ValueError("Transcode does not contain a reasonable Ogg stream")
    measured = probe(output)
    if abs(measured - seconds) > 2.5 or not MIN_DURATION <= measured <= MAX_DURATION:
        raise ValueError(f"Transcoded duration does not match source: {measured:.1f}s / {seconds:.1f}s")
    return output, encoded, measured, sha256(raw)

def main() -> int:
    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        raise RuntimeError("Install ffmpeg and ffprobe first")
    manifest = json.loads(CANDIDATES.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    all_ids = {item["id"] for items in catalog["stations"].values() for item in items}
    accepted = 0
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        for song in manifest["tracks"]:
            uid = song["id"]
            dest = DEST / f"{uid}.ogg"
            if uid in all_ids:
                print("EXISTS", uid)
                continue
            if dest.exists():
                print("UNTRACKED FILE", uid, "- rejecting until explicitly reconciled")
                failures.append(uid)
                continue
            try:
                work = Path(tmp) / uid
                work.mkdir(parents=True)
                temp_out, payload, seconds, origin_sha = import_source(song, work)
                record = {
                    "id": uid, "title":song["title"], "artist":song["artist"],
                    "file":f"res://assets/music/cc0/{uid}.ogg",
                    "style":song["style"], "license":"CC0-1.0",
                    "license_url":"https://creativecommons.org/publicdomain/zero/1.0/",
                    "source_url":song["source_url"], "source_file_url":song["file_url"],
                    "source_sha256":origin_sha,"transcoded_sha256":sha256(payload),
                    "duration_seconds":round(seconds,2), "duration_verified":True,
                    "mountain_moment":song["moment"],"sport_fit":"both",
                    "playlist_reuse":True,"curation_tag":"longform-verified",
                    "mirror":{"repository":"chekento/SkiZones","commit":"import-029",
                              "path":f"assets/music/cc0/{uid}.ogg",
                              "git_blob_sha1":git_sha1(payload),"bytes":len(payload)}
                }
                final = dest.with_suffix(".ogg.tmp")
                final.write_bytes(payload)
                os.replace(final,dest)
                for station in song["stations"]:
                    if station not in catalog["stations"]:
                        raise ValueError("Unknown destination station " + str(station))
                    catalog["stations"][station].append(record.copy())
                accepted += 1
                print("VERIFIED_LONGFORM|%s|%.1f|%d|%s" % (uid,seconds,len(payload),song["source_url"]))
            except Exception as exc:
                failures.append(uid)
                print("SKIPPED_SOURCE|%s|%s" % (uid,str(exc)),file=sys.stderr)
    if accepted:
        catalog["version"]=max(7,int(catalog.get("version",0))+1)
        catalog["longform_import_note"]="Only tracks whose original sources were actually downloaded and measured >=180 seconds were added. Per-asset source and output hashes are recorded."
        CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("IMPORTED",accepted,"SKIPPED",len(failures),failures)
    if not accepted and failures: return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
