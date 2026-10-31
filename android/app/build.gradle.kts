import java.util.Properties

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
        // flutter_local_notifications (the daily reminder) needs library
        // desugaring for its scheduled notifications on older Android.
        isCoreLibraryDesugaringEnabled = true
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

    // The acoustic model stays uncompressed in the app, so ONNX Runtime
    // reads it in place (QuranAcousticModelChannel maps it) instead of a
    // 91 MB copy in app storage. The download is compressed anyway.
    androidResources.noCompress += "onnx"
    // The ready-made databases are compressed already (zlib, xz): stored
    // as they are, not deflated a second time (unpacked once more on start).
    androidResources.noCompress += listOf("zlib", "xz")

    // A reduced ONNX Runtime (only the acoustic model's operators, arm64;
    // tool/onnxruntime/build_reduced.sh): 15.9 MB instead of 33.0 MB. Used
    // when built locally — the folder is not in git — and takes precedence
    // over the Maven package's native libraries, whose Java API it matches
    // (same version). Without it, the stock library is packaged. (Briefly
    // set aside on 2026-10-29 for a crash that turned out to be R8's —
    // proguard-rules.pro.)
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

    // The Play upload key: android/key.properties (never in git — see
    // android/.gitignore) names the keystore and its passwords. Without it a
    // release is signed with the debug key, which Google Play rejects.
    val keyProperties = rootProject.file("key.properties")
    val upload = keyProperties.isFile
    if (upload) {
        val key = Properties().apply { keyProperties.inputStream().use { load(it) } }
        signingConfigs.create("upload") {
            storeFile = rootProject.file(key.getProperty("storeFile"))
            storePassword = key.getProperty("storePassword")
            keyAlias = key.getProperty("keyAlias")
            keyPassword = key.getProperty("keyPassword")
        }
    } else {
        logger.warn("android/key.properties not found: release builds use the debug key (not for Google Play)")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (upload) "upload" else "debug")
            // R8 keeps what JNI looks up by name (ONNX Runtime's classes).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    // ships as a Flutter asset (assets/models/), extracted on first use.
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.30.0")
    // Unpacks the ready-made Quran databases (xz; BundledDatabaseChannel).
    implementation("org.tukaani:xz:1.10")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Every ABI Flutter builds for gets ONNX Runtime, so recitation is checked
// on 32-bit phones (armeabi-v7a) and x86_64 devices too — slower there,
// but there (owner's decision, 2026-10-29). Play sends each phone only its
// own: the stock library adds ~9 MB to a 32-bit phone's download, ~13 MB
// to an x86_64's; arm64 keeps the reduced one. (32-bit x86: no Flutter
// build, so no runtime.)
// A build for chosen processors (`flutter build apk --target-platform
// android-arm64`) packages only their native libraries — the plugins' too
// (ONNX Runtime ships every ABI): ~60 MB less for arm64.
val chosenAbis = (project.findProperty("target-platform") as String?)
    ?.split(",")
    ?.map {
        when (it.trim()) {
            "android-arm64" -> "arm64-v8a"
            "android-arm" -> "armeabi-v7a"
            "android-x64" -> "x86_64"
            "android-x86" -> "x86"
            else -> it.trim()
        }
    }

androidComponents {
    if (chosenAbis != null) {
        onVariants { variant ->
            variant.packaging.jniLibs.excludes.addAll(
                listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
                    .filter { it !in chosenAbis }
                    .map { "lib/$it/**" },
            )
        }
    }
    onVariants(selector().withBuildType("release")) { variant ->
        variant.packaging.jniLibs.excludes.add("lib/x86/libonnxruntime*.so")
    }
}

// The Quran's JSON datasets: the phone installs the same data as ready-made
// databases (assets/quran/db/), so they're left out of Flutter's assets in
// the app — only the web imports them.
tasks.withType<Copy>().matching { it.name.startsWith("copyFlutterAssets") }.configureEach {
    exclude(
        "**/assets/quran/quran_dataset.json",
        "**/assets/quran/mushaf/**",
        "**/assets/quran/translations/**",
        "**/assets/quran/tafsir/**",
        "**/assets/quran/wbw/**",
    )
}
