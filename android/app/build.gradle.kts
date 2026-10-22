import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: copy android/key.properties.example to android/key.properties and add your keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists().also { exists ->
    if (exists) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }
}

android {
    namespace = "com.example.high_school"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "r2a.high_school"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: error("key.properties: missing keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: error("key.properties: missing keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                    ?: error("key.properties: missing storePassword")
                val storeFileProp = keystoreProperties.getProperty("storeFile")
                    ?: error("key.properties: missing storeFile (path relative to android/)")
                storeFile = rootProject.file(storeFileProp)
            }
        }
    }

    buildTypes {
        release {
            // Play Store requires a release keystore — create android/key.properties (see key.properties.example).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// Apply Google Services only when Firebase config is present (optional FCM).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Fail Play-bound release builds if signing is not configured (avoids debug-signed AAB uploads).
afterEvaluate {
    listOf("bundleRelease", "assembleRelease").forEach { taskName ->
        tasks.findByName(taskName)?.doFirst {
            if (!hasReleaseKeystore) {
                throw org.gradle.api.GradleException(
                    """
                    Release signing is not configured — the AAB would be debug-signed and Google Play will reject it.

                    Do this once:
                    1. Copy android/key.properties.example to android/key.properties
                    2. Run keytool to create android/upload-keystore.jks (see comments in the example file)
                    3. Fill storePassword, keyPassword, keyAlias, and storeFile in key.properties

                    Then run: flutter build appbundle --release
                    """.trimIndent(),
                )
            }
        }
    }
}
