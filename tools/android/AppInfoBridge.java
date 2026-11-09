package cloud.kosch.skizones;
import android.app.Activity;
import android.content.pm.PackageInfo;
import android.os.Build;
import java.io.File;
import org.json.JSONObject;
/** Own version information only. No APK download, installer or package permissions. */
public final class AppInfoBridge {
    public static String installedInfo(Activity activity) {
        try {
            PackageInfo info = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0);
            long code = Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
            return new JSONObject().put("code", code).put("version", info.versionName).toString();
        } catch (Exception e) { return "{}"; }
    }
    /**
     * Copy only an app-private support archive into a short-lived cache and
     * share it via a read-only ContentProvider URI. Never export implicitly.
     */
    public static String shareSaveBundle(Activity activity, String filePath) {
        try {
            if (activity == null || filePath == null) return "activity_missing";
            File source = new File(filePath).getCanonicalFile();
            File ownFiles = activity.getFilesDir().getCanonicalFile();
            if (!source.getPath().startsWith(ownFiles.getPath() + File.separator)
                    || !source.isFile() || !source.getName().endsWith(".zip")
                    || source.length() <= 0 || source.length() > 170000000L) {
                return "invalid_private_archive";
            }
            File folder = new File(activity.getCacheDir(), "skizones-support");
            if (!folder.isDirectory() && !folder.mkdirs()) return "cache_unavailable";
            // Android's chooser may open a previously shared URI after this
            // function returns. Keep recent copies, but prune abandoned ones
            // so repeated support attempts cannot fill the private cache and
            // subsequently break the game's ordinary save writes.
            File[] previous = folder.listFiles();
            long now = System.currentTimeMillis();
            if (previous != null) for (File item : previous) {
                if (item.isFile()
                        && item.getName().matches("skizones-support-[0-9a-f]{32}\\.zip")
                        && now - item.lastModified() > 24L * 60 * 60 * 1000L) {
                    item.delete();
                }
            }
            if (folder.getUsableSpace() < source.length() + 4L * 1024 * 1024) {
                return "insufficient_cache_space";
            }
            File exported = new File(folder, "skizones-support-" +
                    java.util.UUID.randomUUID().toString().replace("-", "") + ".zip");
            try (java.io.InputStream in = new java.io.FileInputStream(source);
                 java.io.OutputStream out = new java.io.FileOutputStream(exported)) {
                byte[] buf = new byte[65536];
                int count;
                while ((count = in.read(buf)) != -1) out.write(buf, 0, count);
                out.flush();
            } catch (Exception copyError) {
                exported.delete(); // A partial ZIP must not consume save space.
                return "cache_copy_failed";
            }
            if (source.length() != exported.length()) {
                exported.delete();
                return "copy_incomplete";
            }
            android.net.Uri uri = new android.net.Uri.Builder()
                    .scheme("content").authority(activity.getPackageName() + ".savebundle")
                    .appendPath(exported.getName()).build();
            android.content.Intent send = new android.content.Intent(android.content.Intent.ACTION_SEND);
            send.setType("application/zip");
            send.putExtra(android.content.Intent.EXTRA_STREAM, uri);
            send.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION);
            send.setClipData(android.content.ClipData.newUri(activity.getContentResolver(), "SkiZones recovery", uri));
            activity.runOnUiThread(() -> {
                try {
                    activity.startActivity(android.content.Intent.createChooser(send, "SkiZones: Sicherung teilen"));
                } catch (RuntimeException ignored) {
                    // Preserve the ZIP inside user:// even if no chooser is available.
                }
            });
            return "ok";
        } catch (Exception e) {
            return "share_failed";
        }
    }
    /**
     * Start the OS document picker. Returns an opaque token consumed by
     * the in-game read-only importer; no save is changed until confirmation.
     */
    public static String selectSaveImport(Activity activity) {
        if (activity == null) return "";
        String token = java.util.UUID.randomUUID().toString().replace("-", "");
        try {
            android.content.Intent intent = new android.content.Intent(activity, SaveImportActivity.class);
            intent.putExtra("token", token);
            activity.runOnUiThread(() -> {
                try {
                    activity.startActivity(intent);
                } catch (RuntimeException ignored) {
                    // Return a real failure to Godot instead of leaving a
                    // picker token pending until the 180-second UI timeout.
                    try {
                        File inbox = new File(activity.getFilesDir(), "import-inbox");
                        if (!inbox.isDirectory() && !inbox.mkdirs()) return;
                        JSONObject failed = new JSONObject().put("version", 1)
                                .put("token", token).put("status", "picker_unavailable")
                                .put("files", new org.json.JSONArray());
                        File staged = new File(inbox, "latest.json.tmp");
                        try (java.io.FileOutputStream out = new java.io.FileOutputStream(staged)) {
                            out.write(failed.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
                            out.getFD().sync();
                        }
                        File target = new File(inbox, "latest.json");
                        if (!staged.renameTo(target) && target.delete()) staged.renameTo(target);
                    } catch (Exception ignoredAgain) { /* Never touch a career save. */ }
                }
            });
            return token;
        } catch (RuntimeException ignored) { return ""; }
    }
    public static void clearLegacyUpdateCache(Activity activity) {
        File folder = new File(activity.getCacheDir(), "skizones-update");
        File apk = new File(folder, "update.apk");
        if (apk.isFile()) apk.delete();
        if (folder.isDirectory()) folder.delete();
    }
}
