package ai.tahfeez.tahfeez_ai

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

// Whether a call is on (ringing, in a call, a VoIP call): the recitation
// pauses for it. Read from the audio mode, which needs no phone permission
// (the call state would need READ_PHONE_STATE). The recorder no longer
// pauses for audio focus, which the app's own playback took for good.
object CallStateChannel {
    fun attach(context: Context, messenger: BinaryMessenger) {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        EventChannel(messenger, "tahfeez/call").setStreamHandler(Watcher(audio))
    }

    private fun inCall(mode: Int): Boolean =
        mode == AudioManager.MODE_RINGTONE ||
            mode == AudioManager.MODE_IN_CALL ||
            mode == AudioManager.MODE_IN_COMMUNICATION ||
            // MODE_CALL_SCREENING, MODE_CALL_REDIRECT,
            // MODE_COMMUNICATION_REDIRECT (Android 11–12+).
            mode in 4..6

    private class Watcher(private val audio: AudioManager) : EventChannel.StreamHandler {
        private val main = Handler(Looper.getMainLooper())
        private var sink: EventChannel.EventSink? = null
        private var last: Boolean? = null
        private var listener: Any? = null

        private fun emit(mode: Int) {
            val now = inCall(mode)
            if (now == last) return
            last = now
            sink?.success(now)
        }

        // Before Android 12 (no mode listener): looked at every second.
        private val poll = object : Runnable {
            override fun run() {
                emit(audio.mode)
                main.postDelayed(this, 1000)
            }
        }

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            sink = events
            last = null
            emit(audio.mode)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val l = AudioManager.OnModeChangedListener { mode -> main.post { emit(mode) } }
                audio.addOnModeChangedListener(main::post, l)
                listener = l
            } else {
                main.postDelayed(poll, 1000)
            }
        }

        override fun onCancel(arguments: Any?) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (listener as? AudioManager.OnModeChangedListener)?.let {
                    audio.removeOnModeChangedListener(it)
                }
            } else {
                main.removeCallbacks(poll)
            }
            listener = null
            sink = null
        }
    }
}
