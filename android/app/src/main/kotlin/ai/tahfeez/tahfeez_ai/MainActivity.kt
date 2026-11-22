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

    // The prayer reminders' sound being chosen in Android's picker.
    private var pendingSound: MethodChannel.Result? = null

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
        // A call (ringing, in a call, VoIP): the recitation pauses.
        CallStateChannel.attach(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        // The ready-made Quran databases, unpacked at the first start.
        BundledDatabaseChannel.attach(
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
                } else if (call.method == "appSettings") {
                    // The microphone refused for good: the app's own page in
                    // the system settings, where it can be allowed.
                    try {
                        startActivity(
                            android.content.Intent(
                                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.fromParts("package", packageName, null),
                            ).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
        // Prayer times' sound: one of the phone's (alarms, ringtones,
        // notifications), from Android's own picker (owner, 2026-11-21).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tahfeez/sound")
            .setMethodCallHandler { call, result ->
                if (call.method != "pick") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val intent = android.content.Intent(
                    android.media.RingtoneManager.ACTION_RINGTONE_PICKER,
                ).apply {
                    putExtra(
                        android.media.RingtoneManager.EXTRA_RINGTONE_TYPE,
                        android.media.RingtoneManager.TYPE_ALL,
                    )
                    putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                    putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
                    call.argument<String>("current")?.let {
                        putExtra(
                            android.media.RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                            android.net.Uri.parse(it),
                        )
                    }
                }
                pendingSound?.success(null)
                pendingSound = result
                try {
                    startActivityForResult(intent, SOUND_PICKER)
                } catch (e: Exception) {
                    pendingSound = null
                    result.success(null)
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
                    // A page recited to its end: two soft taps.
                    "pageDone" -> {
                        vibrator()?.let { v ->
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val amplitude = if (v.hasAmplitudeControl()) 70 else VibrationEffect.DEFAULT_AMPLITUDE
                                v.vibrate(
                                    VibrationEffect.createWaveform(
                                        longArrayOf(0, 18, 110, 26),
                                        intArrayOf(0, amplitude, 0, amplitude),
                                        -1,
                                    ),
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                v.vibrate(longArrayOf(0, 18, 110, 26), -1)
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

    @Deprecated("Android's sound picker answers here.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SOUND_PICKER) return
        val result = pendingSound ?: return
        pendingSound = null
        val key = android.media.RingtoneManager.EXTRA_RINGTONE_PICKED_URI
        val uri: android.net.Uri? = if (resultCode != RESULT_OK || data == null) {
            null
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            data.getParcelableExtra(key, android.net.Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            data.getParcelableExtra(key)
        }
        if (uri == null) {
            result.success(null)
            return
        }
        val title = try {
            android.media.RingtoneManager.getRingtone(this, uri)?.getTitle(this)
        } catch (e: Exception) {
            null
        }
        result.success(mapOf("uri" to uri.toString(), "title" to (title ?: "")))
    }

    companion object {
        private const val SOUND_PICKER = 4711
    }
}
