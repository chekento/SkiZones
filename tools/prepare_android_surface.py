"""Build a narrow, reproducible Java surface-lifecycle fix over official Godot JNI.

The original GLSurfaceView source is Apache-2.0; see tools/android/LICENSE.
Only that class family changes. All other classes and native libraries remain
from the SHA-512-verified official Godot 4.5.2 Android source template.
"""
import hashlib
import io
import os
from pathlib import Path
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.5.2.stable"
SOURCE_URL = "https://raw.githubusercontent.com/godotengine/godot/4.5.2-stable/platform/android/java/lib/src/org/godotengine/godot/gl/GLSurfaceView.java"
SOURCE_SHA256 = "15d56bda1cf68e72bb3b48f8e2b0cd6a57dfab9832a674a6f2b4ce82b2f44dbb"
PREFIX = "org/godotengine/godot/gl/GLSurfaceView"


def rewrite_archive(original, target, replacements):
    with zipfile.ZipFile(original) as source, zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as output:
        for entry in source.infolist():
            output.writestr(entry, replacements.get(entry.filename, source.read(entry.filename)))


def prepare(sdk: Path, java: Path):
    patch = ROOT / "tools/android/GLSurfaceView-lifecycle.patch"
    stamp = SOURCE_SHA256 + ":" + hashlib.sha256(patch.read_bytes()).hexdigest()
    build = ROOT / "android/build"
    marker = build / ".skizones-surface-fix"
    if marker.exists() and marker.read_text() == stamp:
        return
    data = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    template = data / "godot/export_templates" / VERSION / "android_source.zip"
    if not template.is_file():
        raise RuntimeError(f"Install matching official Android source template first: {template}")
    ownership = build / ".skizones-managed-build"
    if build.exists() and not ownership.exists() and (build / "build.gradle").exists():
        raise RuntimeError("The Android build folder is not managed by this preparation script; preserve its custom files.")
    build.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(template) as archive:
        archive.extractall(build)
    ownership.write_text(VERSION)
    (build / ".gdignore").write_text("")
    (build.parent / ".build_version").write_text(VERSION + "\n")
    (build / "gradlew").chmod(0o755)
    work = ROOT / "build/android-surface-fix"
    work.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(SOURCE_URL, timeout=45) as response:
        source = response.read()
    if hashlib.sha256(source).hexdigest() != SOURCE_SHA256:
        raise RuntimeError("Pinned GLSurfaceView source does not match the reviewed baseline")
    source_file = work / "GLSurfaceView.java"
    source_file.write_bytes(source)
    subprocess.run(["patch", "--batch", str(source_file), str(patch)], check=True)
    classes = work / "classes"
    classes.mkdir(exist_ok=True)
    dependencies = work / "official-classes.jar"
    with zipfile.ZipFile(build / "libs/debug/godot-lib.template_debug.aar") as aar:
        dependencies.write_bytes(aar.read("classes.jar"))
    subprocess.run([str(java / "bin/javac"), "-source", "17", "-target", "17", "-encoding", "UTF-8",
                    "-classpath", os.pathsep.join([str(sdk / "platforms/android-35/android.jar"), str(dependencies)]),
                    "-d", str(classes), str(source_file)], check=True)
    compiled = {str(p.relative_to(classes)): p.read_bytes() for p in classes.rglob("*.class")}
    assert compiled and all(p.startswith(PREFIX) for p in compiled), "Unexpected compiled class family"
    for kind in ["debug", "release"]:
        aar = build / f"libs/{kind}/godot-lib.template_{kind}.aar"
        with zipfile.ZipFile(aar) as original:
            old_jar = original.read("classes.jar")
        with zipfile.ZipFile(io.BytesIO(old_jar)) as jar:
            family = {n for n in jar.namelist() if n.startswith(PREFIX) and n.endswith(".class")}
        assert family == set(compiled), "The reviewed patch must preserve the complete existing Java class family"
        new_jar = io.BytesIO()
        rewrite_archive(io.BytesIO(old_jar), new_jar, compiled)
        temporary = aar.with_suffix(".patched.aar")
        rewrite_archive(aar, temporary, {"classes.jar": new_jar.getvalue()})
        # Keep every native library byte-for-byte identical to its official ABI.
        with zipfile.ZipFile(aar) as old, zipfile.ZipFile(temporary) as new:
            for name in old.namelist():
                if name != "classes.jar":
                    assert old.read(name) == new.read(name), name
        temporary.replace(aar)
    marker.write_text(stamp)
    print(f"Patched native surface lifecycle: {len(compiled)} Java classes; official JNI and resources unchanged", flush=True)
