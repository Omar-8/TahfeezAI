package ai.tahfeez.tahfeez_ai

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.tukaani.xz.XZInputStream
import java.io.BufferedInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.zip.InflaterInputStream

/**
 * Unpacks a ready-made Quran database — a zlib- (the main ones) or
 * xz-compressed (the meaning packs) Flutter asset (assets/quran/db/) — into
 * a file, for BundledDatabaseInstaller in Dart:
 * streamed (xz's standard level needs ~9 MB to unpack), on a background
 * thread, hashing what it writes. Returns the SHA-256, in hex.
 */
object BundledDatabaseChannel {
    fun attach(context: Context, messenger: BinaryMessenger) {
        val main = Handler(Looper.getMainLooper())
        MethodChannel(messenger, "tahfeez/bundled_db").setMethodCallHandler { call, result ->
            if (call.method != "unpack") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val asset = call.argument<String>("asset")!!
            val dest = call.argument<String>("dest")!!
            Thread {
                try {
                    val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
                    val digest = MessageDigest.getInstance("SHA-256")
                    context.assets.open(key).use { raw ->
                        val buffered = BufferedInputStream(raw, 1 shl 16)
                        // The main databases are zlib (quick, native); the
                        // meaning packs xz (smaller).
                        val unpacking = if (asset.endsWith(".zlib")) {
                            InflaterInputStream(buffered)
                        } else {
                            XZInputStream(buffered)
                        }
                        unpacking.use { input ->
                            FileOutputStream(dest).use { out ->
                                val buffer = ByteArray(1 shl 16)
                                while (true) {
                                    val n = input.read(buffer)
                                    if (n < 0) break
                                    digest.update(buffer, 0, n)
                                    out.write(buffer, 0, n)
                                }
                                out.fd.sync()
                            }
                        }
                    }
                    val hash = digest.digest().joinToString("") { "%02x".format(it) }
                    main.post { result.success(hash) }
                } catch (e: Throwable) {
                    // A full phone shows here as "ENOSPC (No space left on device)".
                    main.post { result.error("unpack", e.toString(), null) }
                }
            }.start()
        }
    }
}
