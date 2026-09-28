import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Must come after the Android plugin; consumes app/google-services.json.
    id("com.google.gms.google-services")
}

// The Google Maps key is needed at manifest-merge time, long before Dart runs,
// so it is read here from the same `config/keys.env` that feeds --dart-define
// and the iOS xcconfig. One source, three consumers, no key text duplicated.
val appKeys = Properties().apply {
    val keysFile = rootProject.file("../config/keys.env")
    if (keysFile.exists()) {
        keysFile.inputStream().use { load(it) }
    } else {
        logger.warn(
            "config/keys.env not found — maps will render blank. " +
                "Copy config/keys.example.env to config/keys.env."
        )
    }
}

// The ML Kit barcode/labeling models transitively pull the deprecated
// `firebase-iid`, whose classes now live in `firebase-messaging`, causing a
// duplicate-class failure. firebase-iid is obsolete, so drop it everywhere.
configurations.all {
    exclude(group = "com.google.firebase", module = "firebase-iid")
}

android {
    namespace = "com.sixamfreshuser.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must match `package_name` in android/app/google-services.json and
        // the package restriction on the Google Maps key.
        applicationId = "com.sixamfreshuser.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Consumed by AndroidManifest.xml as the MAPS_API_KEY placeholder.
        manifestPlaceholders["MAPS_API_KEY"] =
            appKeys.getProperty("MAPS_API_KEY") ?: ""
    }

    // Release signing, read from android/key.properties, which is gitignored and
    // never committed. Absent, the release build falls back to the debug key so
    // `flutter run --release` still works on a fresh clone -- but a debug-signed
    // APK cannot be uploaded to Play, and cannot be upgraded over an existing
    // install signed with the real key.
    val keystoreProperties = Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "android/key.properties not found — signing the release build with the " +
                        "DEBUG key. Fine for testing; Play Store uploads will be rejected."
                )
                signingConfigs.getByName("debug")
            }
            // Shrink only when a real signing setup exists, so debug-key test
            // builds stay quick to produce.
            isMinifyEnabled = hasReleaseKeystore
            isShrinkResources = hasReleaseKeystore
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
