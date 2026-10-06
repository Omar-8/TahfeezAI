plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ai.tahfeez.tahfeez_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ai.tahfeez.tahfeez_ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // A reduced ONNX Runtime (only the acoustic model's operators, arm64;
    // tool/onnxruntime/build_reduced.sh): 15.9 MB instead of 33.0 MB. Used
    // when built locally — the folder is not in git — and takes precedence
    // over the Maven package's native libraries, whose Java API it matches
    // (same version). Without it, the stock library is packaged.
    val reducedOrt = file("src/main/jniLibs-ort")
    if (reducedOrt.isDirectory) {
        sourceSets["main"].jniLibs.srcDir(reducedOrt)
        packaging.jniLibs.pickFirsts.addAll(
            listOf(
                "lib/arm64-v8a/libonnxruntime.so",
                "lib/arm64-v8a/libonnxruntime4j_jni.so",
            ),
        )
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // On-device Quran acoustic model (QuranAcousticModelChannel). The model
    // itself is never bundled; it is sideloaded on development devices.
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.30.0")
}

// The acoustic model needs a 64-bit ARM device (memory and speed), so a
// release ships ONNX Runtime for arm64-v8a only: ~25 MB less per other ABI
// in the bundle. Elsewhere the model reports itself unsupported. Debug and
// profile builds keep every ABI (emulators).
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        variant.packaging.jniLibs.excludes.addAll(
            listOf(
                "lib/armeabi-v7a/libonnxruntime*.so",
                "lib/x86_64/libonnxruntime*.so",
                "lib/x86/libonnxruntime*.so",
            ),
        )
    }
}
