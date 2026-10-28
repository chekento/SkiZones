"""Exercise real Android activities, native surfaces and a saved game on an emulator."""
import argparse
import io
import json
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
        data = adb("exec-out", "screencap", "-p")
        (args.output / f"{label}.png").write_bytes(data)
        image = Image.open(io.BytesIO(data)).convert("RGB").resize((128, 72))
        pixels = list(image.getdata())
        lit = sum(sum(pixel) > 30 for pixel in pixels) / len(pixels)
        mean = sum(ImageStat.Stat(image).mean) / 3
        assert lit > 0.65 and mean > 18 and len(set(pixels)) > 300, \
            f"The resumed game is black or blank: lit={lit}, mean={mean}"
        evidence.append(dict(case=label, lit_fraction=lit, mean_brightness=mean, state=state))
        (args.output / "evidence.json").write_text(json.dumps(evidence, indent=2))
        print(f"PASS Android {label}: visible frame, minute {state['minute']}, {len(state['guests'])} guests", flush=True)

    try:
        adb("install", "-r", str(args.apk.resolve()), timeout=120)
        component = adb("shell", "cmd", "package", "resolve-activity", "--brief", "-a",
                        "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", PACKAGE).decode().splitlines()[-1].strip()
        assert component.startswith(PACKAGE + "/"), component

        def launch():
            adb("shell", "am", "start", "-W", "-n", component, timeout=60)

        def playable(state):
            return not state["background"] and state["camera"] and state["guests"] and not state["paused"]

        launch()
        state = wait_for(playable)
        assert {"ski", "snowboard", "snowblade"}.issubset(state["sports"])
        capture("launch", state)
        for index in range(4):
            before = state
            adb("shell", "input", "keyevent", "KEYCODE_HOME")
            time.sleep(3)
            launch()
            state = wait_for(lambda s: playable(s) and s["resumes"] > before["resumes"])
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
        state = wait_for(lambda s: playable(s) and s["boot"] != before["boot"])
        assert state["day"] == before["day"] and state["minute"] >= before["minute"]
        assert before["guests"][0] in state["guests"], "Process recreation lost the saved guest identities"
        capture("restored-process", state)
        logs = adb("logcat", "-d").decode(errors="replace")
        assert "SCRIPT ERROR" not in logs and "FATAL EXCEPTION" not in logs, "Android reported a script or activity crash"
        print("ANDROID RESUME: 7 real activity/surface checks passed", flush=True)
    finally:
        try:
            (args.output / "logcat.txt").write_bytes(adb("logcat", "-d"))
        except subprocess.SubprocessError:
            pass


if __name__ == "__main__":
    main()
