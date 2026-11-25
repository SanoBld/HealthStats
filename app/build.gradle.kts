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
        resourceConfigurations += listOf("en", "fr")
    }

    // Same signature on every build, so updates install over the old app.
    // Put the old debug.keystore in app/. If it is missing, Gradle uses its default debug key.
    signingConfigs {
        create("shared") {
            val ks = file("debug.keystore")
            if (ks.exists()) {
                storeFile = ks
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName(if (file("debug.keystore").exists()) "shared" else "debug")
        }
        release {
            signingConfig = signingConfigs.getByName(if (file("debug.keystore").exists()) "shared" else "debug")
            isMinifyEnabled = true
            isShrinkResources = true
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
