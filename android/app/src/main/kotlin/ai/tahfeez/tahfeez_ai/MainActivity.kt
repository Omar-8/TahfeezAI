package ai.tahfeez.tahfeez_ai

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        liveSpeech?.dispose()
        liveSpeech = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
