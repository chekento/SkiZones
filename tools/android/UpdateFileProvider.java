package cloud.kosch.skizones;
/** A unique provider avoids conflict with Godot plugins using FileProvider. */
public final class UpdateFileProvider extends androidx.core.content.FileProvider {
    public UpdateFileProvider() { super(); }
}
