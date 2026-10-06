package ai.tahfeez.tahfeez_ai

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.nio.FloatBuffer
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * The on-device Quran acoustic model (`LocalQuranAcousticModel` in Dart):
 * ONNX Runtime, loaded once and reused for every window.
 *
 * The model is never bundled. A development build finds it sideloaded at
 * `<external files>/models/quran_acoustic.onnx` (adb push) or
 * `<files>/models/quran_acoustic.onnx` (run-as copy), with its manifest
 * `quran_acoustic.json` beside it. The file's SHA-256 must match the
 * manifest; a verified hash is remembered by size and modification time,
 * so the 386 MB file is hashed once, not on every launch.
 */
class QuranAcousticModelChannel private constructor(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var env: OrtEnvironment? = null
    private var session: OrtSession? = null
    private var loadedProvider: String? = null

    companion object {
        private const val MODEL = "quran_acoustic.onnx"
        private const val MANIFEST = "quran_acoustic.json"

        @Volatile private var instance: QuranAcousticModelChannel? = null

        /**
         * Serves the channel on [messenger]. One instance per process: the
         * loaded session (hundreds of MB, seconds to load) outlives activity
         * re-creation, and attaching again only replaces the handler — never
         * removed on an activity's clean-up, which can run after a new
         * activity attached to the same engine.
         */
        fun attach(context: Context, messenger: BinaryMessenger) {
            val handler = instance ?: synchronized(this) {
                instance ?: QuranAcousticModelChannel(context.applicationContext)
                    .also { instance = it }
            }
            MethodChannel(messenger, "tahfeez/quran_acoustic_model")
                .setMethodCallHandler(handler)
            Log.i("TahfeezAcoustic", "attached to $messenger")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.i("TahfeezAcoustic", "call ${call.method}")
        worker.execute {
            try {
                val value: Any? = when (call.method) {
                    "status" -> status()
                    "load" -> load(
                        call.argument<String>("provider") ?: "cpu",
                        call.argument<Int>("threads") ?: 0,
                    )
                    "run" -> run(call.argument<FloatArray>("samples")!!)
                    "unload" -> { close(); null }
                    "stats" -> stats()
                    else -> {
                        main.post { result.notImplemented() }
                        return@execute
                    }
                }
                main.post { result.success(value) }
            } catch (e: Throwable) {
                main.post { result.error("acoustic_model", e.message ?: "$e", null) }
            }
        }
    }

    private fun candidates(): List<File> = listOfNotNull(
        context.getExternalFilesDir(null)?.let { File(it, "models/$MODEL") },
        File(context.filesDir, "models/$MODEL"),
    )

    private fun manifestOf(model: File) = File(model.parentFile, MANIFEST)

    /** ONNX Runtime ships for 64-bit ARM only in release builds. */
    private fun runtimeAvailable(): Boolean = try {
        OrtEnvironment.getEnvironment()
        true
    } catch (e: UnsatisfiedLinkError) {
        false
    }

    private fun status(): Map<String, Any?> {
        if (!runtimeAvailable()) {
            return mapOf(
                "state" to "unsupported",
                "detail" to "needs a 64-bit ARM device (${Build.SUPPORTED_ABIS.joinToString()})",
            )
        }
        val searched = candidates()
        val model = searched.firstOrNull { it.isFile }
            ?: return mapOf(
                "state" to "absent",
                "searched" to searched.map { it.absolutePath },
            )
        val manifest = manifestOf(model)
        if (!manifest.isFile) {
            return mapOf(
                "state" to "invalid",
                "path" to model.absolutePath,
                "detail" to "No manifest ($MANIFEST) beside the model",
            )
        }
        return mapOf(
            "state" to if (session != null) "loaded" else "present",
            "path" to model.absolutePath,
            "bytes" to model.length(),
            "manifest" to manifest.readText(),
            "provider" to loadedProvider,
        )
    }

    private fun load(provider: String, threads: Int): Map<String, Any?> {
        if (session != null && provider == loadedProvider) {
            return mapOf("provider" to loadedProvider, "loadMs" to 0, "cached" to true)
        }
        close()
        val model = candidates().firstOrNull { it.isFile }
            ?: throw IllegalStateException("No acoustic model on this device")
        val manifest = JSONObject(manifestOf(model).readText())
        val started = SystemClock.elapsedRealtime()
        val expected = manifest.getString("sha256").lowercase()
        if (model.length() != manifest.getLong("bytes")) {
            throw IllegalStateException(
                "Model is ${model.length()} bytes, manifest says ${manifest.getLong("bytes")}",
            )
        }
        val hashStarted = SystemClock.elapsedRealtime()
        val actual = verifiedHash(model)
        val hashMs = SystemClock.elapsedRealtime() - hashStarted
        if (actual != expected) {
            throw IllegalStateException("Model SHA-256 $actual does not match the manifest")
        }
        val environment = OrtEnvironment.getEnvironment()
        val options = OrtSession.SessionOptions().apply {
            setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            if (threads > 0) setIntraOpNumThreads(threads)
            when (provider) {
                "nnapi" -> addNnapi()
                "xnnpack" -> addXnnpack(
                    mapOf("intra_op_num_threads" to "${if (threads > 0) threads else 4}"),
                )
                "cpu" -> {}
                else -> throw IllegalArgumentException("Unknown provider $provider")
            }
        }
        val sessionStarted = SystemClock.elapsedRealtime()
        session = environment.createSession(model.absolutePath, options)
        env = environment
        loadedProvider = provider
        val now = SystemClock.elapsedRealtime()
        return mapOf(
            "provider" to provider,
            "loadMs" to (now - started),
            "hashMs" to hashMs,
            "sessionMs" to (now - sessionStarted),
            "inputs" to session!!.inputNames.toList(),
            "outputs" to session!!.outputNames.toList(),
        )
    }

    /** SHA-256 of [model], computed once per size + modification time. */
    private fun verifiedHash(model: File): String {
        val key = "${model.absolutePath}:${model.length()}:${model.lastModified()}"
        val cache = File(context.filesDir, "models/verified.txt")
        if (cache.isFile) {
            val lines = cache.readLines()
            if (lines.size == 2 && lines[0] == key) return lines[1]
        }
        val digest = MessageDigest.getInstance("SHA-256")
        model.inputStream().buffered(1 shl 20).use { input ->
            val buffer = ByteArray(1 shl 20)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                digest.update(buffer, 0, n)
            }
        }
        val hash = digest.digest().joinToString("") { "%02x".format(it) }
        cache.parentFile?.mkdirs()
        cache.writeText("$key\n$hash")
        return hash
    }

    private fun run(samples: FloatArray): Map<String, Any?> {
        val s = session ?: throw IllegalStateException("Acoustic model not loaded")
        val environment = env!!
        val started = SystemClock.elapsedRealtime()
        val cpuStarted = Process.getElapsedCpuTime()
        OnnxTensor.createTensor(
            environment,
            FloatBuffer.wrap(samples),
            longArrayOf(1, samples.size.toLong()),
        ).use { input ->
            s.run(mapOf(s.inputNames.first() to input)).use { out ->
                val tensor = out.get(0) as OnnxTensor
                val shape = tensor.info.shape // [1, frames, classes]
                val buffer = tensor.floatBuffer
                val logProbs = FloatArray(buffer.remaining())
                buffer.get(logProbs)
                return mapOf(
                    "frames" to shape[1].toInt(),
                    "classes" to shape[2].toInt(),
                    "logProbs" to logProbs,
                    "ms" to (SystemClock.elapsedRealtime() - started),
                    "cpuMs" to (Process.getElapsedCpuTime() - cpuStarted),
                )
            }
        }
    }

    /** Memory, CPU time, battery and temperature, for measurements. */
    private fun stats(): Map<String, Any?> {
        val memory = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }
        val battery = context.registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED),
        )
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val manager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return mapOf(
            "pssKb" to memory.totalPss,
            "nativeHeapBytes" to Debug.getNativeHeapAllocatedSize(),
            "cpuMs" to Process.getElapsedCpuTime(),
            "batteryPercent" to if (level >= 0 && scale > 0) level * 100.0 / scale else null,
            "batteryMicroAmps" to manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW),
            "batteryTenthsC" to battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1),
            "cores" to Runtime.getRuntime().availableProcessors(),
        )
    }

    private fun close() {
        session?.close()
        session = null
        loadedProvider = null
    }

}
