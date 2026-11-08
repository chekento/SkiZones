# Android surface lifecycle and touch-coordinate patches

The native Android 16 test reproduced a persistent black/frozen frame after a
short sequence of background/foreground transitions. The game loop stopped
because Godot's Java `GLSurfaceView` retained an abandoned EGL surface as bad.
Reactivating a Godot camera cannot repair that native state.

`GLSurfaceView-lifecycle.patch` applies to the exact SHA-256-checked Godot 4.5.2
source listed in `prepare_android_surface.py`. UI surface creation and resume
increment a generation. The rendering thread releases/rebinds an EGL surface
whose generation is stale, preserving its context and the game's resources.
A late swap or creation error from the previous surface cannot mark the new
surface bad. EGL work remains on the rendering thread; there is no retry loop,
reflection, process restart, simulated touch or replacement game state.

The existing `GLSurfaceView` and `InputEventRunnable` Java class families are
recompiled against Android SDK 35 and inserted into the official Godot Android AAR. The preparation verifies
that every other AAR member, including every native library, is byte-identical.
Gradle packages both the public ARM64 app and separate x86-64 test app with the
same patch. Eight real Home/return cycles, sleep/wake and saved process recreation
must pass on Android 11 and 16; logs must show that the patched resume ran.

The original source is Copyright (C) 2008 The Android Open Source Project,
licensed under Apache-2.0 (see [LICENSE](LICENSE)), with Godot's published changes:
https://github.com/godotengine/godot/blob/4.5.2-stable/platform/android/java/lib/src/org/godotengine/godot/gl/GLSurfaceView.java

SkiZones modifies the lifecycle generation handling described above. The full
original copyright/license header is retained in the patched compilation input.
The checked-in patch is deliberately narrow and rejects a different baseline.

The managed app manifest also handles Android `assetsPaths` configuration changes.
Otherwise a Material/navigation overlay can destroy a fresh activity while its
engine starts. This narrowly adds the public asset-path flag, using compile SDK
36 and its supported AGP 8.9.1 / existing Gradle 8.11.1; target SDK 35 and minimum
SDK 24 remain. The Android 16 test changes and restores an actual system overlay
while requiring the same process and advancing game frames. Native libraries are
compressed for the APK download, as in the earlier non-Gradle export.

## Final touch sample

The exact Godot 4.5.2 native input handler releases touches using its cached
last-motion positions. `ACTION_UP` and `ACTION_POINTER_UP` do not copy the
coordinates supplied with that release. Consequently a real Android swipe can
leave a construction point several screen pixels before its intended endpoint.
Reading the release coordinate in GDScript alone still receives that cached value.

`InputEventRunnable-touch-release.patch` forwards the actual Android release
coordinates to the unchanged native input handler as one final movement sample,
immediately before release and on the same dispatch thread. Gesture recognition
is not re-entered. Cancellation remains unchanged. Pointer-up also updates the
remaining contacts before the released finger is removed. A single diagnostic
message, `SkiZonesInput`, lets the emulator test verify the patched dispatch ran.

The original input source is SHA-256 pinned to
`041ef748632b7f7b1c3607576ab110260114c67ffddf461597de0d206b2da117`:
https://github.com/godotengine/godot/blob/4.5.2-stable/platform/android/java/lib/src/org/godotengine/godot/input/InputEventRunnable.java

Native cache behavior reviewed here:
https://github.com/godotengine/godot/blob/4.5.2-stable/platform/android/android_input_handler.cpp

Small AndroidX API declarations are used only while compiling this class.
Their class files are excluded from the replacement set; the existing AndroidX
runtime stays unchanged. The complete existing class families must be replaced;
only compiler-generated helpers inside the input family may be added. Every
native library and every unrelated AAR member remains byte-identical. The input
source retains its MIT header; the notice is packaged in
`assets/licenses/Godot-InputEventRunnable.txt`. Both ARM64 and test x86-64 exports
use this same preparation. The Android test still requires all four camera modes
to finish a genuine swipe within the existing target-position tolerance.


## Browser updates and own version information (0.18)

`AppInfoBridge.java` reads only this app's installed version/code and removes the retired updater's exact cache file. It does not download APKs, request installation privileges or launch an installer. The old `UpdateBridge.java`, APK `UpdateFileProvider.java`, provider declaration/XML and `REQUEST_INSTALL_PACKAGES` permission have been removed. The Godot JNI remains unchanged.

GDScript accepts this project's exact GitHub release/manifest URLs, saves the active resort and session, and asks the OS to open that release in a browser. Browser and Android own downloading and installation. The package and existing signing identity remain unchanged so in-place updates preserve saved careers.

The public APK uses release export without debuggability. `tools/verify_apk_security.py` checks its actual binary manifest, declared permissions, ZIP integrity and absence of the retired installer classes. Signature continuity with the preceding public APK is checked separately. Private emulator fixtures remain debuggable for `run-as` test access and are never published as the ARM64 download.

Android CI exercises a real browser/chooser handoff and return, rejects corrupted and foreign-signature replacement APKs through the Android package manager, and replaces a valid higher-code test APK while comparing all four career files. These checks do not establish a Google Play Protect clearance. See [reported warning and review status](../../docs/PLAY_PROTECT.md).

## 0.40 Android career diagnostics (release-blocking until device validation)

The Career/Free Save Manager offers **Diagnose-ZIP exportieren**. The game
collects existing primary JSON, `.bak`, historical read-only copies, and a
sanitized report, even when the primary JSON is malformed. Source bytes are
preserved and compared with the resulting ZIP. No save is migrated or modified
during export. The app attempts to open Android's standard sharing chooser;
the user explicitly selects a destination. This ZIP **contains the actual
private save data**, so it should only be sent to someone the user trusts.

The built-in `AppInfoBridge.shareSaveBundle` accepts only an existing ZIP
under the application's own files directory. It copies that ZIP into the
private cache and hands out a time-limited user-granted read-only `content://`
URI through `SaveBundleProvider`. The provider is **not exported** and
does not request broad external-storage access. The public APK security check
requires both the Java class and the manifest declaration.

Issue #102 remains OPEN until the affected Samsung 0.39.0/0.39.1 save
and backup have been exported, inspected and loaded through an actual
**in-place updated** 0.40 ARM64 APK. Synthetic historical tests, successful
Android compilation and ZIP tests alone are insufficient to claim recovery.
