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
    public static void clearLegacyUpdateCache(Activity activity) {
        File folder = new File(activity.getCacheDir(), "skizones-update");
        File apk = new File(folder, "update.apk");
        if (apk.isFile()) apk.delete();
        if (folder.isDirectory()) folder.delete();
    }
}
