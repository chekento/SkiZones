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


## Signed in-place updater (0.17)

`UpdateBridge.java` and `UpdateFileProvider.java` are app-owned additions compiled alongside the two reviewed Godot Java patches. Only the app-private `cache/skizones-update/` directory is exposed through the non-exported FileProvider with temporary read grants. Internet and `REQUEST_INSTALL_PACKAGES` enable the explicit download/installation flow; no storage or uninstall permission is requested.

The bridge checks the exact cache path, file size, SHA-256, package, higher Android version code and equality of the installed APK signing certificates. It then opens the per-source installation permission or Android installer. GDScript saves the active resort and session before handoff. All JNI libraries remain unchanged. The build verifies its signer against the preceding public APK; Android CI exercises an actual higher-code installer update with four persisted careers and rejects a separately re-signed fixture.

References: [Android FileProvider](https://developer.android.com/reference/androidx/core/content/FileProvider), [PackageManager](https://developer.android.com/reference/android/content/pm/PackageManager), [Godot JavaClassWrapper and AndroidRuntime](https://docs.godotengine.org/en/4.5/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html).
