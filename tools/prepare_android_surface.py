"""Build pinned Java surface-lifecycle and final-touch fixes over official JNI.

GLSurfaceView retains Apache-2.0; input dispatch retains Godot's MIT notice.
Only the reviewed surface and input-dispatch families change. Other classes and JNI remain
from the SHA-512-verified official Godot 4.5.2 Android source template.
"""
import hashlib
import io
import os
import re
import shutil
from pathlib import Path
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.5.2.stable"
SOURCE_URL = "https://raw.githubusercontent.com/godotengine/godot/4.5.2-stable/platform/android/java/lib/src/org/godotengine/godot/gl/GLSurfaceView.java"
SOURCE_SHA256 = "15d56bda1cf68e72bb3b48f8e2b0cd6a57dfab9832a674a6f2b4ce82b2f44dbb"
PREFIX = "org/godotengine/godot/gl/GLSurfaceView"
INPUT_URL = "https://raw.githubusercontent.com/godotengine/godot/4.5.2-stable/platform/android/java/lib/src/org/godotengine/godot/input/InputEventRunnable.java"
INPUT_SHA256 = "041ef748632b7f7b1c3607576ab110260114c67ffddf461597de0d206b2da117"
UPDATE_PREFIX = "cloud/kosch/skizones/Update"
INPUT_PREFIX = "org/godotengine/godot/input/InputEventRunnable"


def rewrite_archive(original, target, replacements):
    with zipfile.ZipFile(original) as source, zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as output:
        names = set(source.namelist())
        for entry in source.infolist():
            output.writestr(entry, replacements.get(entry.filename, source.read(entry.filename)))
        for name, content in replacements.items():
            if name not in names:
                output.writestr(name, content)


def prepare(sdk: Path, java: Path):
    patch = ROOT / "tools/android/GLSurfaceView-lifecycle.patch"
    input_patch = ROOT / "tools/android/InputEventRunnable-touch-release.patch"
    stamp = ":".join([SOURCE_SHA256, hashlib.sha256(patch.read_bytes()).hexdigest(), INPUT_SHA256,
                      hashlib.sha256(input_patch.read_bytes()).hexdigest(),
                      hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                      hashlib.sha256((ROOT / "tools/android/UpdateBridge.java").read_bytes()).hexdigest(),
                      hashlib.sha256((ROOT / "tools/android/UpdateFileProvider.java").read_bytes()).hexdigest(), "assetsPaths-sdk36"])
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
    # A runtime system-theme overlay changes Android's asset paths. Godot draws
    # its own UI and handles this configuration without destroying its engine.
    manifest = build / "AndroidManifest.xml"
    text, count = re.subn(r'(android:configChanges=")([^"]+)(")',
                         lambda m: m[1] + m[2] + "|assetsPaths" + m[3], manifest.read_text())
    assert count == 1
    text = text.replace("    <application", '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />\n    <application', 1)
    provider = '''        <provider android:name="cloud.kosch.skizones.UpdateFileProvider"
            android:authorities="${applicationId}.updates" android:exported="false" android:grantUriPermissions="true">
            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/skizones_update_paths" />
        </provider>
'''
    text = text.replace("    </application>", provider + "    </application>")
    manifest.write_text(text)
    paths = build / "res/xml/skizones_update_paths.xml"
    paths.parent.mkdir(parents=True, exist_ok=True)
    paths.write_text('<paths xmlns:android="http://schemas.android.com/apk/res/android"><cache-path name="updates" path="skizones-update/" /></paths>\n')
    config = build / "config.gradle"
    text = config.read_text()
    assert "androidGradlePlugin: '8.6.1'" in text and "compileSdk         : 35" in text
    config.write_text(text.replace("androidGradlePlugin: '8.6.1'", "androidGradlePlugin: '8.9.1'")
                      .replace("compileSdk         : 35", "compileSdk         : 36"))
    (build / ".gdignore").write_text("")
    (build.parent / ".build_version").write_text(VERSION + "\n")
    (build / "gradlew").chmod(0o755)
    work = ROOT / "build/android-surface-fix"
    work.mkdir(parents=True, exist_ok=True)
    source_files = [ROOT / "tools/android/UpdateBridge.java", ROOT / "tools/android/UpdateFileProvider.java"]
    for name, url, digest, diff in [("GLSurfaceView.java", SOURCE_URL, SOURCE_SHA256, patch),
                                     ("InputEventRunnable.java", INPUT_URL, INPUT_SHA256, input_patch)]:
        with urllib.request.urlopen(url, timeout=45) as response:
            source = response.read()
        if hashlib.sha256(source).hexdigest() != digest:
            raise RuntimeError(f"Pinned {name} source differs from the reviewed baseline")
        path = work / name
        path.write_bytes(source)
        subprocess.run(["patch", "--batch", str(path), str(diff)], check=True)
        source_files.append(path)
    # Only compile-time API declarations. The original AndroidX runtime remains
    # a normal Gradle dependency; none of these stubs enters the patched AAR.
    compile_only = work / "compile-only"
    declarations = {
        "androidx/core/content/FileProvider.java": "package androidx.core.content; public class FileProvider { public FileProvider() {} public static android.net.Uri getUriForFile(android.content.Context context, String authority, java.io.File file) { return null; } }",
        "androidx/annotation/NonNull.java": "package androidx.annotation; @java.lang.annotation.Retention(java.lang.annotation.RetentionPolicy.CLASS) public @interface NonNull {}",
        "androidx/annotation/Nullable.java": "package androidx.annotation; @java.lang.annotation.Retention(java.lang.annotation.RetentionPolicy.CLASS) public @interface Nullable {}",
        "androidx/core/util/Pools.java": "package androidx.core.util; public final class Pools { public interface Pool<T> { T acquire(); boolean release(T instance); } }",
    }
    for name, text in declarations.items():
        path = compile_only / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        source_files.append(path)
    classes = work / "classes"
    if classes.exists():
        shutil.rmtree(classes)
    classes.mkdir(exist_ok=True)
    dependencies = work / "official-classes.jar"
    with zipfile.ZipFile(build / "libs/debug/godot-lib.template_debug.aar") as aar:
        dependencies.write_bytes(aar.read("classes.jar"))
    subprocess.run([str(java / "bin/javac"), "-source", "17", "-target", "17", "-encoding", "UTF-8",
                    "-classpath", os.pathsep.join([str(sdk / "platforms/android-35/android.jar"), str(dependencies)]),
                    "-d", str(classes), *map(str, source_files)], check=True)
    compiled = {str(p.relative_to(classes)): p.read_bytes() for p in classes.rglob("*.class")
                if str(p.relative_to(classes)).startswith((PREFIX, INPUT_PREFIX, UPDATE_PREFIX))}
    assert compiled and any(p.startswith(INPUT_PREFIX) for p in compiled), "Missing input patch classes"
    for kind in ["debug", "release"]:
        aar = build / f"libs/{kind}/godot-lib.template_{kind}.aar"
        with zipfile.ZipFile(aar) as original:
            old_jar = original.read("classes.jar")
        with zipfile.ZipFile(io.BytesIO(old_jar)) as jar:
            family = {n for n in jar.namelist() if n.startswith((PREFIX, INPUT_PREFIX, UPDATE_PREFIX)) and n.endswith(".class")}
        assert family <= set(compiled), "The complete existing Java class families must be replaced"
        assert all(p.startswith((INPUT_PREFIX, UPDATE_PREFIX)) for p in set(compiled) - family), "Only input helpers and the app update bridge may be added"
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
    print(f"Patched Android surface/input: {len(compiled)} Java classes; official JNI and resources unchanged", flush=True)
