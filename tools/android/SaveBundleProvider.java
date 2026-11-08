package cloud.kosch.skizones;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.List;

/** A single-purpose read-only bridge for files copied to the app cache. */
public final class SaveBundleProvider extends ContentProvider {
    @Override public boolean onCreate() { return true; }

    private File checked(Uri uri) throws FileNotFoundException {
        if (getContext() == null ||
                !uri.getAuthority().equals(getContext().getPackageName() + ".savebundle")) {
            throw new FileNotFoundException("invalid authority");
        }
        List<String> parts = uri.getPathSegments();
        if (parts.size() != 1 || !parts.get(0).matches("skizones-support-[0-9a-f]{32}\\.zip")) {
            throw new FileNotFoundException("invalid support archive");
        }
        try {
            File root = new File(getContext().getCacheDir(), "skizones-support").getCanonicalFile();
            File file = new File(root, parts.get(0)).getCanonicalFile();
            if (!root.equals(file.getParentFile()) || !file.isFile()) {
                throw new FileNotFoundException("archive unavailable");
            }
            return file;
        } catch (IOException ex) {
            throw new FileNotFoundException("archive unavailable");
        }
    }

    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) throw new FileNotFoundException("read only");
        return ParcelFileDescriptor.open(checked(uri), ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override public String getType(Uri uri) { return "application/zip"; }

    @Override public Cursor query(Uri uri, String[] projection, String selection,
                                  String[] selectionArgs, String sortOrder) {
        try {
            File file = checked(uri);
            String[] columns = projection == null
                    ? new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE} : projection;
            MatrixCursor result = new MatrixCursor(columns, 1);
            Object[] row = new Object[columns.length];
            for (int i = 0; i < columns.length; i++) {
                if (OpenableColumns.DISPLAY_NAME.equals(columns[i])) row[i] = "SkiZones-Support.zip";
                else if (OpenableColumns.SIZE.equals(columns[i])) row[i] = file.length();
            }
            result.addRow(row);
            return result;
        } catch (FileNotFoundException ex) { return null; }
    }

    @Override public Uri insert(Uri uri, ContentValues values) { return null; }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] args) { return 0; }
    @Override public int delete(Uri uri, String selection, String[] args) { return 0; }
}
