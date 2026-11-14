import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from check_android_versions import project_version, validate_versions

PROJECT = 'config_version=5\n[application]\nconfig/version="0.42.0"\n'
PRESETS = '''[preset.0]
name="Android"
platform="Android"
[preset.0.options]
version/name="0.42.0"
version/code=57
[preset.1]
platform="Linux"
[preset.1.options]
version/name="unrelated"
[preset.2]
name="Android lifecycle test"
platform="Android"
[preset.2.options]
version/name="0.42.0"
version/code=57
'''


class AndroidVersionConsistency(unittest.TestCase):
    def test_both_android_presets_match_ignoring_desktop(self):
        self.assertEqual(validate_versions(PROJECT, PRESETS), ("0.42.0", 57))

    def test_stale_lifecycle_name_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "preset.2 version/name"):
            validate_versions(PROJECT, PRESETS.replace('version/name="0.42.0"', 'version/name="0.41.1"', 2).replace('version/name="0.41.1"', 'version/name="0.42.0"', 1))

    def test_stale_lifecycle_code_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "same version/code"):
            validate_versions(PROJECT, PRESETS.replace("version/code=57", "version/code=56", 1))

    def test_invalid_or_missing_version_fields_are_rejected(self):
        for bad in ("0", "-1", "57.0", "2100000001", ""):
            with self.subTest(code=bad), self.assertRaises(ValueError):
                validate_versions(PROJECT, PRESETS.replace("version/code=57", "version/code=" + bad))
        with self.assertRaises(ValueError):
            validate_versions(PROJECT, PRESETS.replace('version/name="0.42.0"', ""))

    def test_missing_android_preset_or_options_are_rejected(self):
        with self.assertRaises(ValueError):
            validate_versions(PROJECT, '[preset.0]\nplatform="Linux"\n')
        with self.assertRaises(ValueError):
            validate_versions(PROJECT, '[preset.0]\nplatform="Android"\n')

    def test_project_requires_one_semantic_version(self):
        for bad in ("", PROJECT.replace("0.42.0", "dev"), PROJECT + 'config/version="0.42.0"\n'):
            with self.subTest(project=bad), self.assertRaises(ValueError):
                validate_versions(bad, PRESETS)

    def test_checked_in_project_is_consistent(self):
        version, code = project_version()
        self.assertRegex(version, r"^\d+\.\d+\.\d+$")
        self.assertGreater(code, 0)


if __name__ == "__main__":
    unittest.main()
