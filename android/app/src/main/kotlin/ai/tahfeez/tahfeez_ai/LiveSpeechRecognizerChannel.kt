package ai.tahfeez.tahfeez_ai

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.OutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Streaming speech recognition for live recitation (Milestone R2), backing
 * the Dart `AndroidSpeechLiveRecognizer`.
 *
 * On API 33+ the recognizer is fed the app's own microphone PCM (the same
 * stream the session records) through a pipe (`EXTRA_AUDIO_SOURCE`) in a
 * segmented session, so recording and recognition share one microphone.
 * Below API 33 the recognizer opens the microphone itself and is restarted
 * after every utterance.
 *
 * Events sent to Dart are maps with a `type` of `status`, `partial`,
 * `final` or `error`.
 */
class LiveSpeechRecognizerChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methods = MethodChannel(messenger, "tahfeez/live_speech")
    private val events = EventChannel(messenger, "tahfeez/live_speech/events")
    private val main = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var audioOut: OutputStream? = null
    private var audioIn: ParcelFileDescriptor? = null
    private var writer: ExecutorService? = null

    private var running = false
    private var generation = 0
    private var language = "ar-SA"
    private var sampleRate = 16000
    private var channels = 1
    private var feedAudio = false
    private var preferOnDevice = false
    private var consecutiveErrors = 0

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    fun dispose() {
        stopRun(cancel = true)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(availability())
            "start" -> {
                language = call.argument<String>("language") ?: "ar-SA"
                sampleRate = call.argument<Int>("sampleRate") ?: 16000
                channels = call.argument<Int>("channels") ?: 1
                preferOnDevice = call.argument<Boolean>("preferOnDevice") ?: false
                feedAudio = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                startRun()
                result.success(mapOf("feedsAudio" to feedAudio))
            }
            "feed" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes != null) feed(bytes)
                result.success(null)
            }
            "stop" -> {
                stopRun(cancel = false)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun availability(): Map<String, Any> {
        val available = SpeechRecognizer.isRecognitionAvailable(context)
        val onDevice = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        return mapOf(
            "available" to available,
            "onDevice" to onDevice,
            "feedsAudio" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU),
            "sdk" to Build.VERSION.SDK_INT,
        )
    }

    private fun emit(event: Map<String, Any?>) {
        main.post { sink?.success(event) }
    }

    private fun status(status: String, detail: String? = null) =
        emit(mapOf("type" to "status", "status" to status, "detail" to detail))

    private fun startRun() {
        stopRun(cancel = true)
        running = true
        consecutiveErrors = 0
        status("starting", modeDetail())
        startSegment()
    }

    private fun modeDetail(): String {
        val source = if (feedAudio) "app audio (shared mic)" else "own mic"
        val engine = if (preferOnDevice) "on-device" else "default service"
        return "$engine, $source, $language"
    }

    /** Starts one recognizer session; called again after each one ends. */
    private fun startSegment() {
        if (!running) return
        val gen = ++generation
        releaseRecognizer(cancel = true)

        val useOnDevice = preferOnDevice &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        val r = if (useOnDevice) {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } else {
            SpeechRecognizer.createSpeechRecognizer(context)
        }
        recognizer = r
        r.setRecognitionListener(Listener(gen))

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
        }

        if (feedAudio && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val pipe = ParcelFileDescriptor.createPipe()
            audioIn = pipe[0]
            audioOut = ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])
            writer = Executors.newSingleThreadExecutor()
            intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, pipe[0])
            intent.putExtra(
                RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, sampleRate)
            intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, channels)
            // Keep one recognition session open for as long as audio keeps
            // arriving, reporting each finished segment separately.
            intent.putExtra(
                RecognizerIntent.EXTRA_SEGMENTED_SESSION,
                RecognizerIntent.EXTRA_AUDIO_SOURCE,
            )
        }

        try {
            r.startListening(intent)
        } catch (e: Exception) {
            emit(mapOf("type" to "error", "message" to "startListening failed: ${e.message}", "recoverable" to false))
            stopRun(cancel = true)
        }
    }

    private fun feed(bytes: ByteArray) {
        val out = audioOut ?: return
        val w = writer ?: return
        w.execute {
            try {
                out.write(bytes)
            } catch (_: IOException) {
                // The recognizer closed its end (segment ended); the next
                // segment gets a fresh pipe.
            }
        }
    }

    private fun closeAudio() {
        val out = audioOut
        val w = writer
        val input = audioIn
        audioOut = null
        writer = null
        audioIn = null
        if (w != null) {
            // Close after any queued writes, so the recognizer sees the end
            // of the audio and finalizes it.
            w.execute {
                try {
                    out?.close()
                } catch (_: IOException) {
                }
                try {
                    input?.close()
                } catch (_: IOException) {
                }
            }
            w.shutdown()
        } else {
            try {
                input?.close()
            } catch (_: IOException) {
            }
        }
    }

    private fun releaseRecognizer(cancel: Boolean) {
        closeAudio()
        val r = recognizer ?: return
        recognizer = null
        try {
            if (cancel) r.cancel()
        } catch (_: Exception) {
        }
        r.destroy()
    }

    private fun stopRun(cancel: Boolean) {
        if (!running && recognizer == null) return
        running = false
        if (cancel) {
            generation++
            releaseRecognizer(cancel = true)
            status("stopped")
            return
        }
        // Graceful: end the audio and let the recognizer deliver its last
        // result, then tear down (or give up after a short grace period).
        val gen = generation
        closeAudio()
        try {
            recognizer?.stopListening()
        } catch (_: Exception) {
        }
        main.postDelayed({
            if (generation == gen && !running) {
                generation++
                releaseRecognizer(cancel = true)
                status("stopped")
            }
        }, 3000)
    }

    private fun restartSoon(reason: String, delayMs: Long) {
        if (!running) return
        status("restarting", reason)
        val gen = generation
        main.postDelayed({
            if (running && generation == gen) startSegment()
        }, delayMs)
    }

    private fun textOf(bundle: Bundle?): String? {
        val texts = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        return texts?.firstOrNull()
    }

    private inner class Listener(private val gen: Int) : RecognitionListener {
        private fun current() = gen == generation

        override fun onReadyForSpeech(params: Bundle?) {
            if (!current()) return
            consecutiveErrors = 0
            status("listening", modeDetail())
        }

        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}

        override fun onPartialResults(partialResults: Bundle?) {
            if (!current()) return
            val stable = textOf(partialResults) ?: ""
            // Google's recognizer splits a partial into a stable prefix and
            // a still-changing tail.
            val unstable = partialResults
                ?.getStringArrayList("android.speech.extra.UNSTABLE_TEXT")
                ?.firstOrNull() ?: ""
            val text = listOf(stable, unstable).filter { it.isNotBlank() }.joinToString(" ")
            if (text.isNotBlank()) {
                emit(mapOf("type" to "partial", "text" to text, "t" to SystemClock.elapsedRealtime()))
            }
        }

        override fun onSegmentResults(segmentResults: Bundle) {
            if (!current()) return
            deliverFinal(segmentResults)
        }

        override fun onEndOfSegmentedSession() {
            if (!current()) return
            if (running) restartSoon("segmented session ended", 50) else finishStop()
        }

        override fun onResults(results: Bundle?) {
            if (!current()) return
            deliverFinal(results)
            if (running) restartSoon("utterance ended", 50) else finishStop()
        }

        override fun onError(error: Int) {
            if (!current()) return
            if (!running) {
                finishStop()
                return
            }
            when (error) {
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                    restartSoon("no speech", 50)
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS,
                SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
                SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
                SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT -> {
                    emit(mapOf("type" to "error", "message" to errorName(error), "recoverable" to false))
                    running = false
                    generation++
                    releaseRecognizer(cancel = true)
                    status("error", errorName(error))
                }
                else -> {
                    consecutiveErrors++
                    emit(mapOf("type" to "error", "message" to errorName(error), "recoverable" to true))
                    if (consecutiveErrors > 5) {
                        running = false
                        generation++
                        releaseRecognizer(cancel = true)
                        status("error", "giving up after repeated ${errorName(error)}")
                    } else {
                        restartSoon(errorName(error), 300L * consecutiveErrors)
                    }
                }
            }
        }

        private fun deliverFinal(bundle: Bundle?) {
            val text = textOf(bundle) ?: return
            if (text.isBlank()) return
            val confidence = bundle
                ?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                ?.firstOrNull()
            emit(
                mapOf(
                    "type" to "final",
                    "text" to text,
                    "confidence" to confidence?.toDouble(),
                    "t" to SystemClock.elapsedRealtime(),
                ),
            )
        }

        private fun finishStop() {
            generation++
            releaseRecognizer(cancel = false)
            status("stopped")
        }
    }

    private fun errorName(code: Int): String = when (code) {
        SpeechRecognizer.ERROR_AUDIO -> "audio error"
        SpeechRecognizer.ERROR_CLIENT -> "client error"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "insufficient permissions"
        SpeechRecognizer.ERROR_NETWORK -> "network error"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "network timeout"
        SpeechRecognizer.ERROR_NO_MATCH -> "no match"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "recognizer busy"
        SpeechRecognizer.ERROR_SERVER -> "server error"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "speech timeout"
        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "too many requests"
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "server disconnected"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "Arabic not supported by the recognizer"
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "Arabic recognition unavailable"
        SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT -> "cannot check support"
        else -> "error $code"
    }
}
