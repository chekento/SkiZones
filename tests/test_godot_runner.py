import subprocess
import sys
from pathlib import Path
import unittest

RUNNER = Path(__file__).resolve().parents[1] / "tools/run_godot_test.py"


class StrictGodotErrors(unittest.TestCase):
    def run_fixture(self, text, strict=True):
        command = [sys.executable, str(RUNNER)]
        if strict:
            command.append("--strict-engine-errors")
        command += ["--", sys.executable, "-c", "print(" + repr(text) + ")"]
        return subprocess.run(command, capture_output=True, text=True).returncode

    def test_passing_summary_does_not_mask_late_resource_or_shader_errors(self):
        for error in ("ERROR: Canvas resources leaked", "SHADER ERROR: Compilation failed", "USER ERROR: Unexpected state"):
            with self.subTest(error=error):
                self.assertNotEqual(self.run_fixture("RESULT: 90 passed; 0 failed\n" + error), 0)

    def test_success_and_nonfatal_driver_warnings_remain_accepted(self):
        self.assertEqual(self.run_fixture("WARNING: V-Sync is unavailable\nRESULT: 90 passed; 0 failed"), 0)

    def test_optional_strictness_preserves_existing_intentional_error_fixtures(self):
        self.assertEqual(self.run_fixture("ERROR: Expected negative fixture\nRESULT: 1 passed; 0 failed", strict=False), 0)

    def test_missing_or_failed_summary_still_fails(self):
        for text in ("Godot stopped before the summary", "RESULT: 90 passed; 1 failed"):
            with self.subTest(text=text):
                self.assertNotEqual(self.run_fixture(text), 0)


if __name__ == "__main__":
    unittest.main()
