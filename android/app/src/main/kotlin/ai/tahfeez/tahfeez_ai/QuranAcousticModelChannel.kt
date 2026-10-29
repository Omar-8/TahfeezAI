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
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.FloatBuffer
import java.nio.channels.FileChannel
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * The on-device Quran acoustic model (`LocalQuranAcousticModel` in Dart):
 * ONNX Runtime, loaded once and reused for every window.
 *
 * The model ships in the app (`assets/models/`, a Flutter asset, stored
 * uncompressed — build.gradle.kts) and ONNX Runtime reads it from there,
 * mapped from the app's own file: no copy of it (91 MB) in app storage.
 * A development build may instead have one sideloaded at
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

        /** Runs after a load watched by the crash guard. */
        private const val GUARDED_RUNS = 3

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
                    "load" -> guarded("load") {
                        load(
                            call.argument<String>("provider") ?: "cpu",
                            call.argument<Int>("threads") ?: 0,
                        )
                    }
                    "run" -> firstRuns("run") { run(call.argument<FloatArray>("samples")!!) }
                    "streamReset" -> { streamReset(); null }
                    "streamRun" -> firstRuns("streamRun") {
                        streamRun(
                            call.argument<FloatArray>("samples")!!,
                            call.argument<Boolean>("commit") ?: true,
                        )
                    }
                    "resetGuard" -> { guardFile().delete(); null }
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

    /**
     * The model to use — a sideloaded file, else the bundled asset: what
     * it is, its manifest, and the bytes ONNX Runtime loads.
     */
    private class ModelSource(
        val path: String,
        val bytes: Long,
        val manifest: String?,
        /** Identifies this copy for the hash cache. */
        val key: String,
        /** A file's path, or the bundled model mapped in a direct buffer. */
        val load: () -> Any,
    )

    private fun model(): ModelSource? {
        candidates().firstOrNull { it.isFile }?.let { file ->
            val manifest = File(file.parentFile, MANIFEST)
            return ModelSource(
                path = file.absolutePath,
                bytes = file.length(),
                manifest = if (manifest.isFile) manifest.readText() else null,
                key = "${file.absolutePath}:${file.length()}:${file.lastModified()}",
                load = { file.absolutePath },
            )
        }
        return bundled()
    }

    /**
     * The model shipped in the app, read in place: the asset is stored
     * uncompressed, so it is a stretch of the app's own file, mapped (not
     * read into the Java heap) when loading; `null` when the build has none.
     * A copy an earlier version extracted is deleted (91 MB back).
     */
    private fun bundled(): ModelSource? {
        val loader = FlutterInjector.instance().flutterLoader()
        val assets = context.assets
        val manifestText = try {
            assets.open(loader.getLookupKeyForAsset("assets/models/$MANIFEST"))
                .bufferedReader().use { it.readText() }
        } catch (e: java.io.IOException) {
            return null
        }
        File(context.filesDir, "models/bundled").takeIf { it.isDirectory }?.deleteRecursively()
        val asset = loader.getLookupKeyForAsset("assets/models/$MODEL")
        val length = assets.openFd(asset).use { it.declaredLength }
        val installed = context.packageManager
            .getPackageInfo(context.packageName, 0).lastUpdateTime
        return ModelSource(
            path = "bundled:$asset",
            bytes = length,
            manifest = manifestText,
            key = "bundled:$length:$installed",
            load = {
                assets.openFd(asset).use { fd ->
                    FileInputStream(fd.fileDescriptor).channel.use { channel ->
                        channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
                    }
                }
            },
        )
    }

    /**
     * The crash guard: a native crash in ONNX Runtime (a phone's processor
     * it mishandles) takes the whole app down, every time recitation
     * starts. So each risky call — loading, and the first few runs after
     * it — leaves a mark while it runs, cleared when it returns (or
     * throws: an error, not a crash). A mark found at the next start means
     * the app died in one: [status] reports the model "crashed", off on
     * this phone until the user tries again ("resetGuard") or the app is
     * updated (the mark names the version it was made by).
     */
    private fun guardFile() = File(context.filesDir, "models/crash_guard.txt")

    private fun appStamp(): String =
        context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime.toString()

    private fun <T> guarded(phase: String, block: () -> T): T {
        val mark = guardFile()
        mark.parentFile?.mkdirs()
        mark.writeText("${appStamp()}\n$phase")
        try {
            return block()
        } finally {
            mark.delete()
        }
    }

    private var runsSinceLoad = 0

    private fun <T> firstRuns(phase: String, block: () -> T): T =
        if (runsSinceLoad < GUARDED_RUNS) {
            guarded(phase, block).also { runsSinceLoad++ }
        } else {
            block()
        }

    /** The phase the app died in last time (this version), else `null`. */
    private fun crashedIn(): String? {
        val mark = guardFile()
        if (!mark.isFile) return null
        val lines = mark.readLines()
        if (lines.firstOrNull() != appStamp()) {
            mark.delete()
            return null
        }
        return lines.getOrNull(1) ?: "?"
    }

    /** ONNX Runtime ships for every ABI but 32-bit x86 in release builds. */
    private fun runtimeAvailable(): Boolean = try {
        OrtEnvironment.getEnvironment()
        true
    } catch (e: UnsatisfiedLinkError) {
        false
    }

    private fun status(): Map<String, Any?> {
        crashedIn()?.let { phase ->
            return mapOf(
                "state" to "crashed",
                "detail" to "ONNX Runtime closed the app during $phase on " +
                    "${Build.MANUFACTURER} ${Build.MODEL} (${Build.HARDWARE}, " +
                    "Android ${Build.VERSION.RELEASE}, ${Build.SUPPORTED_ABIS.firstOrNull()})",
            )
        }
        // (Its native library loads here, the first time.)
        if (!guarded("start") { runtimeAvailable() }) {
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
        val manifest = model.manifest
            ?: return mapOf(
                "state" to "invalid",
                "path" to model.path,
                "detail" to "No manifest ($MANIFEST) beside the model",
            )
        return mapOf(
            "state" to if (session != null) "loaded" else "present",
            "path" to model.path,
            "bytes" to model.bytes,
            "manifest" to manifest,
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
        val manifest = JSONObject(
            model.manifest ?: throw IllegalStateException("No manifest ($MANIFEST) beside the model"),
        )
        val started = SystemClock.elapsedRealtime()
        val expected = manifest.getString("sha256").lowercase()
        if (model.bytes != manifest.getLong("bytes")) {
            throw IllegalStateException(
                "Model is ${model.bytes} bytes, manifest says ${manifest.getLong("bytes")}",
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
        runsSinceLoad = 0
        session = when (val bytes = model.load()) {
            is ByteBuffer -> environment.createSession(bytes, options)
            else -> environment.createSession(bytes as String, options)
        }
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

    /** SHA-256 of [model], computed once per copy (its [ModelSource.key]). */
    private fun verifiedHash(model: ModelSource): String {
        val cache = File(context.filesDir, "models/verified.txt")
        if (cache.isFile) {
            val lines = cache.readLines()
            if (lines.size == 2 && lines[0] == model.key) return lines[1]
        }
        val digest = MessageDigest.getInstance("SHA-256")
        when (val bytes = model.load()) {
            is ByteBuffer -> digest.update(bytes)
            else -> File(bytes as String).inputStream().buffered(1 shl 20).use { input ->
                val buffer = ByteArray(1 shl 20)
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    digest.update(buffer, 0, n)
                }
            }
        }
        val hash = digest.digest().joinToString("") { "%02x".format(it) }
        cache.parentFile?.mkdirs()
        cache.writeText("${model.key}\n$hash")
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
