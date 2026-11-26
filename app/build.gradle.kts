plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Values given by CI: -PappVersion=1.2.3 -PappBuild=42 -PgithubRepo=user/repo
val appVersion = providers.gradleProperty("appVersion").getOrElse("0.1.0")
val appBuild = providers.gradleProperty("appBuild").map { it.toInt() }.getOrElse(1)
val githubRepo = providers.gradleProperty("githubRepo").getOrElse("SanoBld/HealthStats")

android {
    namespace = "com.healthstats.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.healthstats.app"
        minSdk = 26 // Health Connect
        targetSdk = 35
        versionCode = appBuild
        versionName = appVersion
        buildConfigField("String", "GITHUB_REPO", "\"$githubRepo\"")
        androidResources.localeFilters += listOf("en", "fr")
    }

    // Same signature on every build, so updates install over the old app.
    // app/debug.keystore is committed to the repo on purpose: CI runners are empty machines and
    // would otherwise create a new random debug key at each run (= "app not installed" on update).
    signingConfigs {
        create("shared") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("shared")
        }
        release {
            signingConfig = signingConfigs.getByName("shared")
            // R8 is off: a shrunk release build crashed at start. Turn it back on only with a logcat to test it.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // One APK per CPU + one universal APK
    // Names: app-arm64-v8a-release.apk, app-universal-release.apk ... (the in-app updater needs these names)
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.compose.animation)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.health.connect)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.osmdroid)

    testImplementation(libs.junit)
}
