plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.healthstats.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        // Clé de signature committée dans le repo : même signature à chaque build => mise à jour sans désinstaller.
        // rootProject.file() resolves relative to the android/ directory.
        create("localDebug") {
            storeFile     = rootProject.file("debug.keystore")
            storePassword = "android"
            keyAlias      = "androiddebugkey"
            keyPassword   = "android"
        }
    }

    defaultConfig {
        applicationId = "com.healthstats.app"
        minSdk        = 26 // Health Connect
        targetSdk     = flutter.targetSdkVersion
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName
    }

    buildTypes {
        // Both debug and release use the same committed keystore,
        // so every APK produced (locally or on CI) has an identical signature.
        debug {
            signingConfig = signingConfigs.getByName("localDebug")
        }
        release {
            signingConfig = signingConfigs.getByName("localDebug")
            isShrinkResources = false
            isMinifyEnabled   = false
        }
    }
}

dependencies {
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}

flutter {
    source = "../.."
}