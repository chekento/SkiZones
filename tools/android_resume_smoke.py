"""Exercise real Android activities, native surfaces and a saved game on an emulator."""
import argparse
import io
import hashlib
import xml.etree.ElementTree as ET
import json
import math
import subprocess
import time
from pathlib import Path
from PIL import Image, ImageStat

PACKAGE = "cloud.kosch.skizones"


def adb(*args, timeout=20):
    try:
        return subprocess.run(["adb", *args], check=True, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, timeout=timeout).stdout
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        # Preserve ADB's actual installation or device error in CI logs.
        if isinstance(exc, subprocess.CalledProcessError):
            print(f"ADB failed ({' '.join(args)}): "
                  f"{exc.stdout.decode(errors='replace') if exc.stdout else ''} "
                  f"{exc.stderr.decode(errors='replace') if exc.stderr else ''}",
                  flush=True)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--wrong-signer-apk", type=Path, required=True)
    parser.add_argument("--update-apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    # Derive actual installed APK code and a synthetic newer patch release.
    import re
    root = Path(__file__).resolve().parents[1]
    presets = (root / "export_presets.cfg").read_text(encoding="utf-8")
    codes = [int(code) for code in re.findall(r"(?m)^version/code=(\d+)$", presets)]
    assert codes and len(set(codes)) == 1, "Android presets have inconsistent version codes"
    installed_code = codes[0]
    project = (root / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'(?m)^config/version="(\d+\.\d+\.\d+)"$', project)
    assert match, "Missing semantic app version in project.godot"
    version_parts = [int(part) for part in match.group(1).split(".")]
    update_version = f"{version_parts[0]}.{version_parts[1]}.{version_parts[2] + 1}"
    args.output.mkdir(parents=True, exist_ok=True)
    health_path = None
    evidence = []

    def health():
        nonlocal health_path
        if health_path is None:
            paths = adb("shell", "run-as", PACKAGE, "find", "files", "-name", "lifecycle-ci.json").decode().splitlines()
            health_path = next(p.strip() for p in paths if p.startswith("files/") and ".." not in p.split("/"))
        return json.loads(adb("shell", "run-as", PACKAGE, "cat", health_path))

    def wait_for(predicate, seconds=75):
        deadline = time.monotonic() + seconds
        last = None
        while time.monotonic() < deadline:
            try:
                last = health()
                if predicate(last):
                    return last
            except (subprocess.SubprocessError, ValueError, StopIteration):
                pass
            time.sleep(0.5)
        raise AssertionError(f"Android game did not reach the expected playable state: {last}")

    def capture(label, state):
        activity = adb("shell", "dumpsys", "activity", "activities").decode(errors="replace")
        assert any(PACKAGE in line and ("mResumedActivity" in line or "topResumedActivity" in line)
                   for line in activity.splitlines()), "The game activity is not in the foreground"
        # Game state can be ready before SurfaceFlinger has presented the first
        # frame (especially while the emulator compiles fresh shader programs).
        # Require real pixels within a bounded deadline, never accept a splash.
        deadline = time.monotonic() + 30
        lit = 0.0
        mean = 0.0
        unique_colors = 0
        while True:
            try:
                # ADB can deliver a truncated PNG while Android redraws a new
                # 3D surface. Retry a corrupt capture; never treat it as a
                # successful frame or disable Pillow's integrity checks.
                data = adb("exec-out", "screencap", "-p")
                with Image.open(io.BytesIO(data)) as source:
                    source.load()
                    image = source.convert("RGB").resize((128, 72))
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                if time.monotonic() >= deadline:
                    raise AssertionError(
                        f"Android screenshot remained unavailable for {label}: {error}"
                    ) from error
                time.sleep(0.5)
                continue
            pixels = list(image.get_flattened_data())
            lit = sum(sum(pixel) > 30 for pixel in pixels) / len(pixels)
            mean = sum(ImageStat.Stat(image).mean) / 3
            unique_colors = len(set(pixels))
            (args.output / f"{label}.png").write_bytes(data)
            if lit > 0.65 and mean > 18 and unique_colors > 300:
                break
            if time.monotonic() >= deadline:
                break
            time.sleep(0.5)
        assert lit > 0.65 and mean > 18 and unique_colors > 300, \
            f"The resumed game is black or blank: lit={lit}, mean={mean}, colors={unique_colors}"
        state = health()
        assert state["render_scale"] == 1.0, "The Android world render target must remain full-screen"
        evidence.append(dict(case=label, lit_fraction=lit, mean_brightness=mean, state=state))
        (args.output / "evidence.json").write_text(json.dumps(evidence, indent=2))
        print(f"PASS Android {label}: visible frame, minute {state['minute']}, {len(state['guests'])} guests", flush=True)

    try:
        adb("install", "-r", str(args.apk.resolve()), timeout=120)
        # A first-run system tutorial can cover either a game or its splash and
        # must not be mistaken for proof that the game itself is rendering.
        adb("shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed")
        component = adb("shell", "cmd", "package", "resolve-activity", "--brief", "-a",
                        "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", PACKAGE).decode().splitlines()[-1].strip()
        assert component.startswith(PACKAGE + "/"), component

        def launch():
            # Use the same MAIN/LAUNCHER intent as the app icon and require
            # an actual foreground activity, rather than am's exit code.
            # The Android 36 emulator may block on am start -W despite accepting
            # a launcher intent. Verify the actual resumed activity separately.
            deadline = time.monotonic() + 60
            result = b""
            activity = ""
            while time.monotonic() < deadline:
                try:
                    result = adb("shell", "am", "start", "-a", "android.intent.action.MAIN",
                                 "-c", "android.intent.category.LAUNCHER", "-n", component, timeout=15)
                    activity = adb("shell", "dumpsys", "activity", "activities",
                                   timeout=15).decode(errors="replace")
                    if any(PACKAGE in line and ("mResumedActivity" in line or "topResumedActivity" in line)
                           for line in activity.splitlines()):
                        return
                except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as exc:
                    result = str(exc).encode()
                time.sleep(1)
            (args.output / "failed-launch.txt").write_bytes(result)
            (args.output / "failed-launch-activities.txt").write_text(activity)
            try:
                (args.output / "failed-launch-package.txt").write_bytes(adb("shell", "dumpsys", "package", PACKAGE))
            except subprocess.SubprocessError:
                pass
            raise AssertionError("Android did not foreground the installed game: " + result.decode(errors="replace"))

        def playable(state):
            return not state["background"] and state["camera"] and state["guests"] and not state["paused"]

        launch()
        state = wait_for(lambda s: playable(s) and s.get("frames", 0) >= 5 and s["minute"] > 560)
        assert {"ski", "snowboard", "snowblade"}.issubset(state["sports"])
        capture("launch", state)
        if int(adb("shell", "getprop", "ro.build.version.sdk")) >= 36:
            # The new public assetsPaths flag prevents system theme/navigation
            # overlays from destroying an otherwise live Godot activity.
            overlays = adb("shell", "cmd", "overlay", "list", "--user", "0").decode()
            navigation = [line for line in overlays.splitlines() if "com.android.internal.systemui.navbar." in line]
            current = next(line.split()[-1] for line in navigation if line.strip().startswith("[x]"))
            choices = [line.split()[-1] for line in navigation if any(name in line for name in ("navbar.threebutton", "navbar.gestural"))]
            alternative = next(name for name in choices if name != current)
            before = state
            for overlay in [alternative, current]:
                adb("shell", "cmd", "overlay", "enable-exclusive", "--user", "0", "--category", overlay)
                state = wait_for(lambda s: playable(s) and s["boot"] == before["boot"]
                                 and s.get("frames", 0) >= before["frames"] + 3)
                before = state
            capture("system-overlay", state)
        for index in range(8):
            before = state
            adb("shell", "input", "keyevent", "KEYCODE_HOME")
            time.sleep(3)
            launch()
            state = wait_for(lambda s: playable(s) and s["resumes"] > before["resumes"]
                             and s.get("frames", 0) >= before["frames"] + 3
                             and s["minute"] > before["minute"])
            assert state["boot"] == before["boot"], "A short app switch unexpectedly restarted the process"
            assert state["minute"] >= before["minute"] and before["guests"][0] in state["guests"]
            capture(f"resume-{index + 1}", state)

        before = state
        adb("shell", "input", "keyevent", "KEYCODE_SLEEP")
        time.sleep(3)
        adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
        adb("shell", "wm", "dismiss-keyguard")
        launch()
        state = wait_for(lambda s: playable(s) and s["resumes"] > before["resumes"])
        assert state["minute"] >= before["minute"]
        capture("screen-wake", state)

        before = state
        adb("shell", "input", "keyevent", "KEYCODE_HOME")
        time.sleep(3)
        adb("shell", "am", "force-stop", PACKAGE)
        launch()
        state = wait_for(lambda s: playable(s) and s["boot"] != before["boot"]
                         and s.get("frames", 0) >= 5)
        assert state["day"] == before["day"] and state["minute"] >= before["minute"]
        assert before["guests"][0] in state["guests"], "Process recreation lost the saved guest identities"
        capture("restored-process", state)
        # Drive genuine Android pixels, including Godot's viewport stretch.
        request_path = health_path.rsplit("/", 1)[0] + "/picking-ci.json"
        for mode in range(4):
            request_file = args.output / "picking-request.json"
            request_file.write_text(json.dumps(dict(mode=mode)))
            adb("push", str(request_file), "/data/local/tmp/skizones-picking.json")
            adb("shell", "run-as", PACKAGE, "cp", "/data/local/tmp/skizones-picking.json", request_path)
            state = wait_for(lambda s: s.get("picking", {}).get("mode") == mode)
            x, y = state["picking"]["screen"]
            adb("shell", "input", "tap", str(round(x)), str(round(y)))
            state = wait_for(lambda s: len(s.get("picking", {}).get("point", [])) == 2)
            hit = state["picking"]
            assert math.dist(hit["point"], hit["target"]) < 0.75, hit
            assert hit["handle_hit"], "The waypoint handle is offset from the physical Android tap"
            capture(f"picking-mode-{mode}", state)
            # Check the rendered grip itself, not only the controller's hit test.
            # A safe-area inset used to move the drawing while hit-testing passed.
            frame = Image.open(args.output / f"picking-mode-{mode}.png").convert("RGB")
            grip = [(px, py) for px in range(round(x) - 8, round(x) + 9)
                    for py in range(round(y) - 8, round(y) + 9)
                    if 0 <= px < frame.width and 0 <= py < frame.height]
            dark = sum(max(abs(a - b) for a, b in zip(frame.getpixel(pos), (23, 55, 68))) < 45
                       for pos in grip)
            assert dark > len(grip) * 0.20, "The visible waypoint grip is displaced from the Android tap"
            dx, dy = hit["destination_screen"]
            adb("shell", "input", "swipe", str(round(x)), str(round(y)),
                str(round(dx)), str(round(dy)), "350")
            state = wait_for(lambda s: len(s.get("picking", {}).get("point", [])) == 2
                             and math.dist(s["picking"]["point"], hit["destination"]) < 0.9)
            capture(f"dragging-mode-{mode}", state)
        adb("shell", "run-as", PACKAGE, "rm", request_path)
        # In main-only releases the normal resort remains the active session.
        # Scenario-specific assets and UI are not exercised by this gate.
        assert state["map"] == "sonnenhang", "A scenario replaced the main-mode session"
        # Exercise the real browser handoff, then Android package replacement.
        # Four careers must survive both operations byte-for-byte.
        update_request_path = health_path.rsplit("/", 1)[0] + "/update-ci.json"
        request_file = args.output / "update-request.json"

        def update_request(data):
            request_file.write_text(json.dumps(data))
            adb("push", str(request_file), "/data/local/tmp/skizones-update-request.json")
            adb("shell", "run-as", PACKAGE, "cp", "/data/local/tmp/skizones-update-request.json", update_request_path)

        update_request(dict(action="prepare"))
        state = wait_for(lambda s: s.get("update_test") == "prepared", seconds=180)
        assert state["slot"] == 3 and state["money"] == 234563 and state["installed_code"] == installed_code, state
        save_folder = health_path.rsplit("/", 1)[0]
        saved_files = [f"career_{slot}_{name}.json" for slot in range(1, 5)
                       for name in ("sonnenhang", "passport", "index")]
        def saved_hash(name):
            content = adb("shell", "run-as", PACKAGE, "cat", save_folder + "/" + name)
            if name.endswith("_index.json"):
                metadata = json.loads(content)
                metadata.pop("saved_at", None)  # A pre-install autosave updates this timestamp.
                content = json.dumps(metadata, sort_keys=True).encode()
            return hashlib.sha256(content).hexdigest()

        before_files = {name: saved_hash(name) for name in saved_files}
        capture("four-careers-before-update", state)
        candidate = args.update_apk.read_bytes()
        digest = hashlib.sha256(candidate).hexdigest()
        package_info = adb("shell", "dumpsys", "package", PACKAGE).decode()
        assert "android.permission.REQUEST_INSTALL_PACKAGES" not in package_info, "The app still requests installation privileges"
        update_request(dict(action="open-browser", sha256=digest, size=len(candidate)))
        state = wait_for(lambda s: s.get("update_test") == "browser_opened")
        assert state["update_url"] == f"https://github.com/chekento/SkiZones/releases/tag/v{update_version}", state
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline:
            activities = adb("shell", "dumpsys", "activity", "activities").decode()
            resumed = [line.lower() for line in activities.splitlines() if "mResumedActivity" in line or "topResumedActivity" in line]
            if any(any(word in line for word in ["chrome", "browser", "resolveractivity"]) for line in resumed):
                break
            time.sleep(0.5)
        else:
            raise AssertionError("The official release link did not open a browser or Android browser chooser")
        (args.output / "github-browser-handoff.png").write_bytes(adb("exec-out", "screencap", "-p"))
        adb("shell", "input", "keyevent", "KEYCODE_HOME")
        launch()
        state = wait_for(lambda s: not s["background"] and s["slot"] == 3 and s["installed_code"] == installed_code)
        capture("browser-return-four-careers", state)
        assert before_files == {name: saved_hash(name) for name in saved_files}, "Browser handoff changed a career"
        adb("shell", "run-as", PACKAGE, "rm", "-f", update_request_path)
        # Installation is owned by Android, outside SkiZones. These rejection
        # fixtures verify data preservation; they are not a Play Protect verdict.
        rejected = subprocess.run(["adb", "install", "-r", str(args.wrong_signer_apk.resolve())], capture_output=True, timeout=120)
        assert rejected.returncode != 0 and b"INSTALL_FAILED_UPDATE_INCOMPATIBLE" in rejected.stdout + rejected.stderr, rejected.stdout + rejected.stderr
        launch()
        state = wait_for(lambda s: not s["background"] and s["installed_code"] == installed_code)
        capture("system-rejects-different-signer", state)
        corrupt = args.output / "corrupt-test.apk"
        corrupt.write_bytes(candidate[:100000])
        rejected = subprocess.run(["adb", "install", "-r", str(corrupt)], capture_output=True, timeout=120)
        assert rejected.returncode != 0 and any(reason in rejected.stdout + rejected.stderr for reason in [b"INSTALL_FAILED_INVALID_APK", b"INSTALL_PARSE_FAILED"]), rejected.stdout + rejected.stderr
        launch()
        state = wait_for(lambda s: not s["background"] and s["installed_code"] == installed_code)
        capture("system-rejects-corruption", state)
        assert before_files == {name: saved_hash(name) for name in saved_files}, "Rejected replacement changed a career"
        # An ordinary Android package update stops the running process. Move
        # the game out of the foreground and release its GLES surface before
        # the emulator replaces the APK. This must NOT remove app data.
        adb("shell", "input", "keyevent", "KEYCODE_HOME")
        adb("shell", "am", "force-stop", PACKAGE)
        adb("install", "-r", str(args.update_apk.resolve()), timeout=120)
        adb("shell", "input", "keyevent", "KEYCODE_HOME")
        launch()
        state = wait_for(lambda s: s.get("installed_code") == installed_code + 1 and s.get("frames", 0) >= 5, seconds=180)
        assert state["slot"] == 3 and state["money"] == 234563 and state["day"] == 13 and state["paused"], state
        after_files = {name: saved_hash(name) for name in saved_files}
        assert before_files == after_files, "An in-place Android update changed a career save, unlock file or index"
        capture("updated-four-careers-restored", state)
        adb("shell", "run-as", PACKAGE, "rm", "-f", update_request_path)
        logs = adb("logcat", "-d").decode(errors="replace")
        assert "SkiZonesSurface" in logs, "The patched native surface lifecycle was not exercised"
        assert "SkiZonesInput" in logs, "The final Android touch sample was not preserved before native release"
        assert "SCRIPT ERROR" not in logs and "FATAL EXCEPTION" not in logs, "Android reported a script or activity crash"
        assert not any("E godot" in line and "ERROR:" in line for line in logs.splitlines()), \
            "Android reported a renderer or engine error"
        print(f"ANDROID RESUME: {len(evidence)} real activity/surface checks passed", flush=True)
    finally:
        for name, command in [
            ("final-activities.txt", ("shell", "dumpsys", "activity", "activities")),
            ("final-package.txt", ("shell", "dumpsys", "package", PACKAGE)),
            ("final-screen.png", ("exec-out", "screencap", "-p")),
        ]:
            try:
                (args.output / name).write_bytes(adb(*command))
            except subprocess.SubprocessError:
                pass
        try:
            (args.output / "logcat.txt").write_bytes(adb("logcat", "-d"))
        except subprocess.SubprocessError:
            pass


if __name__ == "__main__":
    main()
