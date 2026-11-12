import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing — loaded from an untracked android/key.properties (see
// .gitignore). Absent on CI/dev machines that only need debug builds, so
// signing config is only wired up when the file is actually present.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.decant.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications schedules with java.time on old Androids.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Play Store listing identity — com.decant.app was already taken by
        // another developer globally, so this app publishes under
        // com.buildable.decant instead. The Kotlin source package/namespace
        // stays com.decant.app; applicationId and namespace don't need to match.
        applicationId = "com.buildable.decant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // AdMob app ID (it ships inside the app, so it isn't a secret). Pass
        // the real one with -PADMOB_APP_ID=… or ORG_GRADLE_PROJECT_ADMOB_APP_ID;
        // without it the app uses Google's sample ID, and release builds
        // without ADMOB_REWARDED_ID load no ads anyway.
        manifestPlaceholders["admobAppId"] =
            (project.findProperty("ADMOB_APP_ID") as String?)
                ?.takeIf { it.isNotBlank() }
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    // 100 extra ambience/music loops ship as Play Asset Delivery packs that
    // Google Play downloads right after install (see android/*_pack).
    assetPacks += listOf(":ambient_pack", ":music_pack")

    buildTypes {
        release {
            // Falls back to the debug key if key.properties isn't present yet,
            // so `flutter run --release` still works before signing is set up.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.play:asset-delivery:2.2.2")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
