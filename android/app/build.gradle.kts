import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

fun requireReleaseSigningProperty(name: String): String {
    return keystoreProperties[name] as? String
        ?: error(
            "Release signing requires '$name' in android/key.properties. " +
                "Release builds must not fall back to the debug key. See android/SIGNING.md."
        )
}

fun validateReleaseSigningConfig() {
    if (!keystorePropertiesFile.exists()) {
        error(
            "Release signing requires android/key.properties. " +
                "Release builds must not fall back to the debug key. See android/SIGNING.md."
        )
    }
    requireReleaseSigningProperty("storeFile")
    requireReleaseSigningProperty("storePassword")
    requireReleaseSigningProperty("keyAlias")
    requireReleaseSigningProperty("keyPassword")
}

android {
    namespace = "com.mostafaazab.estimation"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.mostafaazab.estimation"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = requireReleaseSigningProperty("keyAlias")
                keyPassword = requireReleaseSigningProperty("keyPassword")
                storeFile = file(requireReleaseSigningProperty("storeFile"))
                storePassword = requireReleaseSigningProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (releaseBuildRequested) {
                validateReleaseSigningConfig()
            }
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
