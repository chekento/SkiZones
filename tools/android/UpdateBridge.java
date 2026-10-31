package cloud.kosch.skizones;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.FileInputStream;
import java.security.MessageDigest;
import java.util.HashSet;
import java.util.Set;
import org.json.JSONObject;

/** App-private, signed, in-place updates. Never removes app data or uninstalls. */
public final class UpdateBridge {
    private static File cache(Activity activity) {
        File folder = new File(activity.getCacheDir(), "skizones-update");
        if (!folder.isDirectory() && !folder.mkdirs()) throw new IllegalStateException("cache");
        return new File(folder, "update.apk");
    }
    public static String cachePath(Activity activity) {
        try { return cache(activity).getCanonicalPath(); } catch (Exception e) { return ""; }
    }
    public static String installedInfo(Activity activity) {
        try {
            PackageInfo info = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0);
            return new JSONObject().put("code", code(info)).put("version", info.versionName).toString();
        } catch (Exception e) { return "{}"; }
    }
    private static long code(PackageInfo info) {
        return Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
    }
    private static Set<String> signers(PackageInfo info) {
        Signature[] signatures = Build.VERSION.SDK_INT >= 28
            ? (info.signingInfo == null ? null : info.signingInfo.getApkContentsSigners()) : info.signatures;
        Set<String> values = new HashSet<>();
        if (signatures != null) for (Signature signature : signatures) values.add(signature.toCharsString());
        return values;
    }
    public static String validate(Activity activity, String path, String hash, long size, long targetCode) {
        try {
            File apk = new File(path);
            if (!apk.getCanonicalPath().equals(cache(activity).getCanonicalPath())) return "path";
            if (apk.length() != size || size < 1000000 || size > 536870912) return "size";
            if (hash == null || !hash.matches("[0-9a-f]{64}")) return "hash";
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] buffer = new byte[65536];
            try (FileInputStream input = new FileInputStream(apk)) {
                int read;
                while ((read = input.read(buffer)) != -1) digest.update(buffer, 0, read);
            }
            StringBuilder actual = new StringBuilder();
            for (byte value : digest.digest()) actual.append(String.format(java.util.Locale.ROOT, "%02x", value & 255));
            if (!actual.toString().equals(hash)) return "hash";
            PackageManager manager = activity.getPackageManager();
            int flags = Build.VERSION.SDK_INT >= 28 ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
            PackageInfo current = manager.getPackageInfo(activity.getPackageName(), flags);
            PackageInfo update = manager.getPackageArchiveInfo(apk.getAbsolutePath(), flags);
            if (update == null || !activity.getPackageName().equals(update.packageName)) return "package";
            if (code(update) != targetCode || code(update) <= code(current)) return "version";
            Set<String> trusted = signers(current);
            if (trusted.isEmpty() || !trusted.equals(signers(update))) return "signature";
            return "ok";
        } catch (Exception e) { return "invalid"; }
    }
    public static String install(Activity activity, String path) {
        try {
            if (!new File(path).getCanonicalPath().equals(cache(activity).getCanonicalPath())) return "path";
            Intent intent;
            String action;
            if (Build.VERSION.SDK_INT >= 26 && !activity.getPackageManager().canRequestPackageInstalls()) {
                intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + activity.getPackageName()));
                action = "permission";
            } else {
                Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".updates", new File(path));
                intent = new Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                action = "installer";
            }
            // Keep Android's installer/settings out of the game's task. An
            // in-place update kills the game's root Activity; on Android 11
            // reusing that task can leave InstallSuccess in place of the game
            // even after Open or a launcher intent. The system flow needs its
            // own task so the replacement app can start a fresh game task.
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            // Do not report success before a launch can throw.
            activity.startActivity(intent);
            return action;
        } catch (Exception e) { return "unavailable"; }
    }
}
