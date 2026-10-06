import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key lives in android/key.properties (gitignored). Without it a
// release build fails rather than quietly shipping with the debug key; set
// PETLOOP_ALLOW_DEBUG_SIGNED_RELEASE=true (or -Ppetloop.allowDebugSignedRelease=true)
// for a local `flutter run --release` that is never distributed.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}
val hasReleaseKey = keyPropertiesFile.exists()
val allowDebugSignedRelease =
    System.getenv("PETLOOP_ALLOW_DEBUG_SIGNED_RELEASE") == "true" ||
        (findProperty("petloop.allowDebugSignedRelease") as String?) == "true"

fun releaseKeyProperty(name: String): String =
    keyProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("android/key.properties is missing '$name'.")

android {
    namespace = "com.limi.pet_companion"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications schedules with java.time, which older
        // Android versions get through desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.limi.pet_companion"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = releaseKeyProperty("keyAlias")
                keyPassword = releaseKeyProperty("keyPassword")
                storeFile = rootProject.file(releaseKeyProperty("storeFile"))
                storePassword = releaseKeyProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseKey -> signingConfigs.getByName("release")
                allowDebugSignedRelease -> signingConfigs.getByName("debug")
                else -> null
            }
        }
    }
}

// Checked when a release variant is actually built, so debug builds and
// IDE syncs work without the key.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        if (!hasReleaseKey && !allowDebugSignedRelease) {
            throw GradleException(
                "Release signing is not configured. Create android/key.properties " +
                    "(storeFile, storePassword, keyAlias, keyPassword); see " +
                    "https://docs.flutter.dev/deployment/android#configure-signing-in-gradle. " +
                    "For a local, never-distributed release run set " +
                    "PETLOOP_ALLOW_DEBUG_SIGNED_RELEASE=true.",
            )
        }
        if (!hasReleaseKey) {
            logger.warn("WARNING: this release build is signed with the DEBUG key. Do not distribute it.")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
