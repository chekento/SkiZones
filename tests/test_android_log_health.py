import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from android_log_health import engine_errors


class AndroidEngineErrors(unittest.TestCase):
    def test_audio_start_preserves_original_error_and_context(self):
        log = ('01:37:53 E AudioFlinger: uid not found: 10216\n'
               '01:37:53 E godot   : ERROR: Condition "res != 0" is true.\n'
               '01:37:53 E godot   : at: start (platform/android/audio_driver_opensl.cpp:159)')
        errors = engine_errors(log)
        self.assertEqual(len(errors), 1)
        self.assertEqual(errors[0]["category"], "audio")
        self.assertIn('Condition "res != 0"', errors[0]["error"])
        self.assertIn('uid not found', errors[0]["context"][0])

    def test_unknown_errors_still_fail_and_graphics_are_identified(self):
        self.assertEqual(engine_errors('E godot: ERROR: unexpected engine state')[0]['category'], 'engine')
        self.assertEqual(engine_errors('E godot: ERROR: invalid render target\nE godot: at: renderer_gl.cpp')[0]['category'], 'graphics')

    def test_other_processes_and_normal_engine_messages_are_not_errors(self):
        self.assertEqual(engine_errors('E other: ERROR: unrelated\nI godot: ERROR: example text\nE godot: Normal message'), [])


if __name__ == '__main__':
    unittest.main()
