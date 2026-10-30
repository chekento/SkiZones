"""Exercise real Android activities, native surfaces and a saved game on an emulator."""
import argparse
import io
import json
import math
import subprocess
import time
from pathlib import Path
from PIL import Image, ImageStat

PACKAGE = "cloud.kosch.skizones"


def adb(*args, timeout=20):
    return subprocess.run(["adb", *args], check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=timeout).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
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
        while True:
            data = adb("exec-out", "screencap", "-p")
            (args.output / f"{label}.png").write_bytes(data)
            image = Image.open(io.BytesIO(data)).convert("RGB").resize((128, 72))
            pixels = list(image.get_flattened_data())
            lit = sum(sum(pixel) > 30 for pixel in pixels) / len(pixels)
            mean = sum(ImageStat.Stat(image).mean) / 3
            if lit > 0.65 and mean > 18 and len(set(pixels)) > 300:
                break
            if time.monotonic() >= deadline:
                break
            time.sleep(0.5)
        assert lit > 0.65 and mean > 18 and len(set(pixels)) > 300, \
            f"The resumed game is black or blank: lit={lit}, mean={mean}"
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
            adb("shell", "am", "start", "-W", "-n", component, timeout=60)

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
        # Verify bundled real-map resources and worker-based loading in Android.
        scenario_path = health_path.rsplit("/", 1)[0] + "/scenario-ci.json"
        scenario_file = args.output / "scenario-request.json"
        scenario_file.write_text(json.dumps(dict(map="braunlage")))
        adb("push", str(scenario_file), "/data/local/tmp/skizones-scenario.json")
        adb("shell", "run-as", PACKAGE, "cp", "/data/local/tmp/skizones-scenario.json", scenario_path)
        state = wait_for(lambda s: s.get("scenario") == "ready" and s["map"] == "braunlage", seconds=180)
        assert state["lifts"] == 9 and state["pistes"] == 26 and state["elevation"] > 500
        assert state["guests"] and state["staff"] > 0, state
        capture("real-wurmberg", state)
        before = state
        adb("shell", "input", "keyevent", "KEYCODE_HOME")
        time.sleep(2)
        adb("shell", "am", "force-stop", PACKAGE)
        launch()
        state = wait_for(lambda s: s["boot"] != before["boot"] and s["map"] == "braunlage"
                         and s.get("scenario") == "ready" and s.get("frames", 0) >= 5, seconds=180)
        assert state["paused"] and state["guests"] == before["guests"] and state["staff"] == before["staff"]
        capture("restored-real-wurmberg", state)
        logs = adb("logcat", "-d").decode(errors="replace")
        assert "SkiZonesSurface" in logs, "The patched native surface lifecycle was not exercised"
        assert "SkiZonesInput" in logs, "The final Android touch sample was not preserved before native release"
        assert "SCRIPT ERROR" not in logs and "FATAL EXCEPTION" not in logs, "Android reported a script or activity crash"
        assert not any("E godot" in line and "ERROR:" in line for line in logs.splitlines()), \
            "Android reported a renderer or engine error"
        print(f"ANDROID RESUME: {len(evidence)} real activity/surface checks passed", flush=True)
    finally:
        try:
            (args.output / "logcat.txt").write_bytes(adb("logcat", "-d"))
        except subprocess.SubprocessError:
            pass


if __name__ == "__main__":
    main()
