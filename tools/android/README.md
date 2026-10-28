# Android surface lifecycle patch

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

Only the existing `GLSurfaceView` Java class family is recompiled against Android
SDK 35 and inserted into the official Godot Android AAR. The preparation verifies
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
