#!/usr/bin/env python3
"""Audit the actual public APK. This is not a Google Play Protect verdict."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--aapt', default=str(Path(os.environ.get('ANDROID_HOME', '')) / 'build-tools/35.0.0/aapt2'))
    args = parser.parse_args()
    permissions = subprocess.check_output([args.aapt, 'dump', 'permissions', str(args.apk)], text=True)
    names = sorted(set(re.findall(r"uses-permission[^:]*: name='([^']+)'", permissions)))
    allowed = {'android.permission.INTERNET', 'android.permission.ACCESS_NETWORK_STATE', 'android.permission.VIBRATE', 'cloud.kosch.skizones.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'}
    assert set(names) <= allowed, f'Unexpected permissions: {set(names) - allowed}'
    assert 'android.permission.INTERNET' in names
    manifest = subprocess.check_output([args.aapt, 'dump', 'xmltree', str(args.apk), '--file', 'AndroidManifest.xml'], text=True)
    for line in manifest.splitlines():
        if 'android:debuggable' in line:
            assert '0xffffffff' not in line and 'true' not in line, 'Public APK must not be debuggable'
    assert 'cloud.kosch.skizones.UpdateFileProvider' not in manifest
    # Recovery files are shared only by a non-exported, read-only provider.
    assert 'cloud.kosch.skizones.SaveBundleProvider' in manifest, 'Missing secure Android save-export provider'
    assert 'cloud.kosch.skizones.SaveImportActivity' in manifest, 'Missing private Android save-import activity'
    with zipfile.ZipFile(args.apk) as archive:
        assert archive.testzip() is None
        dex = b''.join(archive.read(n) for n in archive.namelist() if re.fullmatch(r'classes\d*\.dex', n))
        for name in [b'UpdateBridge', b'UpdateFileProvider']:
            assert b'Lcloud/kosch/skizones/' + name + b';' not in dex, 'Retired installer code remains'
        assert b'Lcloud/kosch/skizones/AppInfoBridge;' in dex
        assert b'Lcloud/kosch/skizones/SaveBundleProvider;' in dex, 'Save-export provider absent from APK bytecode'
        assert b'Lcloud/kosch/skizones/SaveImportActivity;' in dex, 'Save-import picker absent from APK bytecode'
    report = {'permissions': names, 'debuggable': False, 'installer_permission': False, 'apk_installer_provider': False, 'update_mode': 'browser', 'sha256': hashlib.sha256(args.apk.read_bytes()).hexdigest(), 'play_protect_classification': 'not_independently_verified'}
    (args.apk.parent / 'apk-security.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Public release APK verified: minimal permissions, no app installer, not debuggable. Google classification not independently verified.')


if __name__ == '__main__':
    main()
