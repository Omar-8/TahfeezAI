package ai.tahfeez.tahfeez_ai

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (a FlutterActivity): the recitation audio's media
// session runs on this activity's engine.
class MainActivity : AudioServiceActivity() {
    private var liveSpeech: LiveSpeechRecognizerChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liveSpeech = LiveSpeechRecognizerChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        QuranAcousticModelChannel.attach(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        // On-device recitation AI keeps the screen on while listening: with
        // it off, the app is moved to the slow cores (ScreenAwake in Dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tahfeez/screen")
            .setMethodCallHandler { call, result ->
                if (call.method == "keepOn") {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        // A recitation mistake noticed: a short vibration (the device's
        // vibrator, not the touch-feedback setting) or a soft beep.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tahfeez/alert")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "vibrate" -> {
                        val ms = (call.arguments as? Int ?: 120).toLong()
                        vibrator()?.let { v ->
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                v.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE))
                            } else {
                                @Suppress("DEPRECATION")
                                v.vibrate(ms)
                            }
                        }
                        result.success(null)
                    }
                    "beep" -> {
                        val gen = tones ?: ToneGenerator(AudioManager.STREAM_NOTIFICATION, 35)
                            .also { tones = it }
                        gen.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** A short, soft beep for a recitation mistake (created on first use). */
    private var tones: ToneGenerator? = null

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        tones?.release()
        tones = null
        liveSpeech?.dispose()
        liveSpeech = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
