plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ─────────────────────────────────────────────
// CAMBIA ESTA LÍNEA PARA ALTERNAR MODOS:
//   false = Audio App     (producción, la que usas)
//   true  = Audio App DEV (desarrollo, para probar)
// ─────────────────────────────────────────────
val isDev = false

android {
    namespace = "com.example.audio_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = if (isDev) "dev.lluis.mamusi.dev" else "dev.lluis.mamusi"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = if (isDev) "Audio App DEV" else "Audio App"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
