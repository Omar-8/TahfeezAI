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
import io.flutter.FlutterInjector
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
 * The model ships in the app (`assets/models/`, a Flutter asset) and is
 * extracted once to `<files>/models/bundled/` — ONNX Runtime loads from a
 * file. A development build may instead have one sideloaded at
 * `<external files>/models/quran_acoustic.onnx` (adb push) or
 * `<files>/models/quran_acoustic.onnx` (run-as copy), which comes first.
 * Each sits with its manifest `quran_acoustic.json`. The file's SHA-256 must
 * match the manifest; a verified hash is remembered by size and
 * modification time, so the file is hashed once, not on every launch.
 */
class QuranAcousticModelChannel private constructor(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var env: OrtEnvironment? = null
    private var session: OrtSession? = null
    private var loadedProvider: String? = null

    /**
     * A streaming model's state (manifest "stream"): one direct buffer per
     * state input, the ONNX tensor reading it, the output that replaces it
     * after each chunk, and its starting values.
     */
    private class StreamSlot(
        val name: String,
        val buffer: FloatBuffer,
        val tensor: OnnxTensor,
        val initial: FloatArray?,
    )
    private var stream: List<StreamSlot>? = null

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
                    "streamReset" -> { streamReset(); null }
                    "streamRun" -> streamRun(
                        call.argument<FloatArray>("samples")!!,
                        call.argument<Boolean>("commit") ?: true,
                    )
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

    /** Where a sideloaded model may be (development builds). */
    private fun candidates(): List<File> = listOfNotNull(
        context.getExternalFilesDir(null)?.let { File(it, "models/$MODEL") },
        File(context.filesDir, "models/$MODEL"),
    )

    /** The model to use: a sideloaded one, else the bundled one. */
    private fun model(): File? = candidates().firstOrNull { it.isFile } ?: bundled()

    /**
     * The model shipped in the app, extracted to app storage (once per app
     * version: re-extracted when its size differs from the bundled
     * manifest's); `null` when the build has none.
     */
    private fun bundled(): File? {
        val loader = FlutterInjector.instance().flutterLoader()
        val assets = context.assets
        val manifestAsset = loader.getLookupKeyForAsset("assets/models/$MANIFEST")
        val modelAsset = loader.getLookupKeyForAsset("assets/models/$MODEL")
        val manifestText = try {
            assets.open(manifestAsset).bufferedReader().use { it.readText() }
        } catch (e: java.io.IOException) {
            return null
        }
        val dir = File(context.filesDir, "models/bundled")
        val model = File(dir, MODEL)
        val manifest = File(dir, MANIFEST)
        val bytes = JSONObject(manifestText).getLong("bytes")
        if (model.isFile && model.length() == bytes && manifest.isFile &&
            manifest.readText() == manifestText
        ) {
            return model
        }
        dir.mkdirs()
        val partial = File(dir, "$MODEL.part")
        assets.open(modelAsset).use { input ->
            partial.outputStream().use { input.copyTo(it, 1 shl 20) }
        }
        if (partial.length() != bytes) {
            partial.delete()
            throw IllegalStateException("Bundled model is ${partial.length()} bytes, manifest says $bytes")
        }
        if (!partial.renameTo(model)) throw IllegalStateException("Could not place the bundled model")
        manifest.writeText(manifestText)
        Log.i("TahfeezAcoustic", "extracted the bundled model ($bytes bytes)")
        return model
    }

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
        val model = model()
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

    /**
     * Threads for the model when the caller leaves it to us: the phone's fast cores
     * (every core faster than its slowest tier) less one, kept for the microphone and
     * the UI — 2 to 4. ONNX Runtime's own choice spreads the work onto the slow cores,
     * which hold the fast ones back: on a POCO F3 (4 fast + 4 slow) v3.6's 1.28 s
     * chunk took 1018 ms with it, 943 ms with 4 threads, 525 ms with 3, 688 ms with 2.
     */
    private fun fastCoreThreads(): Int {
        val speeds = (0 until Runtime.getRuntime().availableProcessors()).mapNotNull {
            File("/sys/devices/system/cpu/cpu$it/cpufreq/cpuinfo_max_freq")
                .takeIf { f -> f.canRead() }?.readText()?.trim()?.toLongOrNull()
        }
        if (speeds.isEmpty()) return 2
        val slowest = speeds.min()
        val fast = speeds.count { it > slowest }.let { if (it == 0) speeds.size else it }
        return (fast - 1).coerceIn(2, 4)
    }

    private fun load(provider: String, threads: Int): Map<String, Any?> {
        if (session != null && provider == loadedProvider) {
            return mapOf("provider" to loadedProvider, "loadMs" to 0, "cached" to true)
        }
        close()
        val model = model()
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
            setIntraOpNumThreads(if (threads > 0) threads else fastCoreThreads())
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
        manifest.optJSONObject("stream")?.let {
            stream = streamSlots(environment, it)
            streamReset()
        }
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

    /** The state buffers a streaming manifest describes (shapes, starting values). */
    private fun streamSlots(environment: OrtEnvironment, config: JSONObject): List<StreamSlot> {
        val shapes = config.getJSONObject("state")
        val initial = config.optJSONObject("initial") ?: JSONObject()
        return shapes.keys().asSequence().toList().sortedBy { order(it) }.map { name ->
            val dims = shapes.getJSONArray(name).let { a -> LongArray(a.length()) { a.getLong(it) } }
            val size = dims.fold(1L) { n, d -> n * d }.toInt()
            val buffer = java.nio.ByteBuffer.allocateDirect(size * 4)
                .order(java.nio.ByteOrder.nativeOrder()).asFloatBuffer()
            val start = initial.optJSONArray(name)?.let { flat(it) }
            StreamSlot(name, buffer, OnnxTensor.createTensor(environment, buffer, dims), start)
        }
    }

    /** The graph's state order (stream_model.STATE); unknown names last. */
    private fun order(name: String) = listOf("sums", "count", "kv", "conv", "akv", "aconv", "valid")
        .indexOf(name).let { if (it < 0) 99 else it }

    private fun flat(a: org.json.JSONArray): FloatArray {
        val out = ArrayList<Float>()
        fun walk(x: Any) {
            if (x is org.json.JSONArray) for (i in 0 until x.length()) walk(x.get(i))
            else out.add((x as Number).toFloat())
        }
        walk(a)
        return out.toFloatArray()
    }

    /** A new recitation: the state back to its starting values. */
    private fun streamReset() {
        val slots = stream ?: throw IllegalStateException("Not a streaming model")
        for (slot in slots) {
            slot.buffer.clear()
            val start = slot.initial
            if (start != null) {
                slot.buffer.put(start)
            } else {
                while (slot.buffer.hasRemaining()) slot.buffer.put(0f)
            }
            slot.buffer.rewind()
        }
    }

    /**
     * One chunk of a streaming model: [samples] (the chunk and the 240 samples
     * after it) with the state; with [commit], the state is replaced by the
     * graph's new one (without: a provisional look at a partial chunk, the
     * state left as it was).
     */
    private fun streamRun(samples: FloatArray, commit: Boolean): Map<String, Any?> {
        val s = session ?: throw IllegalStateException("Acoustic model not loaded")
        val slots = stream ?: throw IllegalStateException("Not a streaming model")
        val started = SystemClock.elapsedRealtime()
        val cpuStarted = Process.getElapsedCpuTime()
        OnnxTensor.createTensor(
            env!!,
            FloatBuffer.wrap(samples),
            longArrayOf(1, samples.size.toLong()),
        ).use { input ->
            val inputs = HashMap<String, OnnxTensor>()
            inputs["samples"] = input
            for (slot in slots) inputs[slot.name] = slot.tensor
            s.run(inputs).use { out ->
                val tensor = out.get("log_probs").get() as OnnxTensor
                val shape = tensor.info.shape
                val buffer = tensor.floatBuffer
                val logProbs = FloatArray(buffer.remaining())
                buffer.get(logProbs)
                if (commit) for (slot in slots) {
                    val next = (out.get("${slot.name}_out").get() as OnnxTensor).floatBuffer
                    slot.buffer.clear()
                    slot.buffer.put(next)
                    slot.buffer.rewind()
                }
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
        stream?.forEach { it.tensor.close() }
        stream = null
        session?.close()
        session = null
        loadedProvider = null
    }

}
