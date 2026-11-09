package cloud.kosch.skizones;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.database.Cursor;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Android Storage Access Framework document picker. Imports are ALWAYS staged
 * in app-private import-inbox, never committed to career/free saves here.
 * The Godot UI must inspect and explicitly confirm activation separately.
 */
public final class SaveImportActivity extends Activity {
    private static final int OPEN_REQUEST = 40;
    private static final long MAX_SOURCE = 150000000L;
    private static final long MAX_ENTRY = 64000000L;
    private static final long MAX_TOTAL = 140000000L;
    private static final int MAX_FILES = 12;
    private String token;
    private File inbox;
    private File directory;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        token = getIntent().getStringExtra("token");
        if (token == null || !token.matches("[0-9a-f]{32}")) { finish(); return; }
        inbox = new File(getFilesDir(), "import-inbox");
        directory = new File(inbox, token);
        if (!inbox.isDirectory() && !inbox.mkdirs()) { finish(); return; }
        if (!directory.mkdir()) { publish("storage_unavailable", new JSONArray()); finish(); return; }
        Intent pick = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        pick.setType("*/*");
        pick.addCategory(Intent.CATEGORY_OPENABLE);
        pick.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json", "application/zip",
                "application/x-zip-compressed", "application/octet-stream", "text/plain"});
        try {
            startActivityForResult(pick, OPEN_REQUEST);
        } catch (RuntimeException ex) {
            publish("picker_unavailable", new JSONArray());
            finish();
        }
    }

    private static String digest(byte[] content) {
        try {
            MessageDigest hash = MessageDigest.getInstance("SHA-256");
            return hex(hash.digest(content));
        } catch (Exception ex) { return ""; }
    }

    private static String hex(byte[] bytes) {
        StringBuilder out = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) out.append(String.format(java.util.Locale.ROOT, "%02x", value & 255));
        return out.toString();
    }

    private static String sha256(File file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream in = new FileInputStream(file)) {
            byte[] buffer = new byte[65536];
            int size;
            while ((size = in.read(buffer)) != -1) digest.update(buffer, 0, size);
        }
        return hex(digest.digest());
    }

    private String displayName(Uri uri) {
        String display = "selected-document";
        try (Cursor result = getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (result != null && result.moveToFirst() && !result.isNull(0)) display = result.getString(0);
        } catch (RuntimeException ignored) { /* Name is informative only. */ }
        String safe = display.replaceAll("[^a-zA-Z0-9._-]", "_");
        return safe.substring(0, Math.min(safe.length(), 80));
    }

    private static long copyLimited(InputStream in, File target, long maximum) throws IOException {
        long length = 0;
        try (FileOutputStream out = new FileOutputStream(target)) {
            byte[] buffer = new byte[65536];
            int count;
            while ((count = in.read(buffer)) != -1) {
                length += count;
                if (length > maximum) throw new IOException("size_limit");
                out.write(buffer, 0, count);
            }
            out.getFD().sync();
        }
        return length;
    }

    private static boolean isSaveEntry(String name) {
        // Only paths used by SkiZones' exported support ZIPs are accepted.
        // No archive entry is ever extracted to a path derived from its name.
        // Support archives can include .json, .bak, .tmp, .bak.tmp and
        // forensic suffixes (.broken, .before-repair, .before-staging).
        // A strict internal entry name is enough: we never use it as an
        // output path, only as a display label, and validate every JSON
        // payload with Godot's checksum/restore model before activation.
        return name.matches("files/[0-9]{2}-[a-zA-Z0-9._-]{1,120}") && name.contains(".json");
    }

    private void importZip(File archive, JSONArray files) throws Exception {
        long total = 0;
        int entries = 0;
        int scanned = 0;
        boolean diagnosticSeen = false;
        try (ZipInputStream zip = new ZipInputStream(new FileInputStream(archive))) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                String name = entry.getName();
                if (++scanned > MAX_FILES + 1) throw new IOException("too_many_archive_entries");
                if (entry.isDirectory() || !("diagnostic.json".equals(name) || isSaveEntry(name)))
                    throw new IOException("invalid_archive_entry");
                if ("diagnostic.json".equals(name)) {
                    if (diagnosticSeen) throw new IOException("duplicate_diagnostic");
                    diagnosticSeen = true;
                    // Read and discard the optional metadata, but bound it too.
                    byte[] discard = new byte[4096];
                    long n = 0;
                    int count;
                    while ((count = zip.read(discard)) != -1) {
                        n += count;
                        if (n > 1000000) throw new IOException("oversized_report");
                    }
                } else {
                    if (++entries > MAX_FILES || entry.getSize() > MAX_ENTRY)
                        throw new IOException("too_many_or_oversized_files");
                    File saved = new File(directory, String.format(java.util.Locale.ROOT, "%02d.json", entries - 1));
                    long length = copyLimited(zip, saved, MAX_ENTRY);
                    total += length;
                    if (length == 0 || total > MAX_TOTAL) throw new IOException("archive_size_limit");
                    JSONObject item = new JSONObject();
                    item.put("name", saved.getName());
                    item.put("source", name.substring(6));
                    item.put("bytes", length);
                    item.put("sha256", sha256(saved));
                    files.put(item);
                }
                zip.closeEntry();
            }
        }
        if (entries == 0) throw new IOException("empty_archive");
    }

    private void publish(String status, JSONArray files) {
        try {
            JSONObject state = new JSONObject().put("version", 1).put("token", token)
                    .put("status", status).put("files", files);
            byte[] bytes = state.toString().getBytes(StandardCharsets.UTF_8);
            File staged = new File(inbox, "latest.json.tmp");
            try (FileOutputStream out = new FileOutputStream(staged)) {
                out.write(bytes);
                out.getFD().sync();
            }
            File target = new File(inbox, "latest.json");
            if (!staged.renameTo(target)) {
                // Replacement semantics differ across Android filesystems.
                // The prior inbox status is not a career save; replacing it is safe.
                if (!target.delete() || !staged.renameTo(target))
                    throw new IOException("inbox_status_commit");
            }
        } catch (Exception ignored) { /* UI reports timeout without modifying player saves. */ }
    }

    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        JSONArray files = new JSONArray();
        if (request != OPEN_REQUEST) { finish(); return; }
        if (result != RESULT_OK || data == null || data.getData() == null) {
            publish("cancelled", files); finish(); return;
        }
        // Storage providers and ZIP decompression can take several seconds.
        // Never block Android's UI thread (which must continue to paint and
        // respond to the system picker while the private inbox is prepared).
        Uri selected = data.getData();
        new Thread(() -> importDocument(selected), "SkiZones-SaveImport").start();
    }

    private void importDocument(Uri uri) {
        JSONArray files = new JSONArray();
        File input = new File(directory, "selected.bin");
        try {
            String display = displayName(uri);
            try (InputStream stream = getContentResolver().openInputStream(uri)) {
                if (stream == null || copyLimited(stream, input, MAX_SOURCE) == 0)
                    throw new IOException("empty_document");
            }
            byte[] header = new byte[4];
            try (FileInputStream in = new FileInputStream(input)) {
                if (in.read(header) < 4) throw new IOException("truncated_document");
            }
            if (header[0] == 'P' && header[1] == 'K' && header[2] == 3 && header[3] == 4) {
                importZip(input, files);
            } else {
                File raw = new File(directory, "00.json");
                if (input.length() > MAX_ENTRY || !input.renameTo(raw))
                    throw new IOException("raw_size_limit");
                files.put(new JSONObject().put("name", "00.json").put("source", display)
                        .put("bytes", raw.length()).put("sha256", sha256(raw)));
            }
            publish("ready", files);
        } catch (Exception ex) {
            // Truncated, oversize or invalid import: no career is touched.
            publish("invalid_document", new JSONArray());
        } finally {
            input.delete();
            runOnUiThread(this::finish);
        }
    }
}
