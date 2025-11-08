plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("org.jetbrains.kotlin.android")
}

// Lee propiedades definidas por Flutter / local.properties y conviértelas al tipo correcto
val flutterVersionCode: Int =
    (project.findProperty("flutter.versionCode") ?: "1").toString().toInt()

val flutterVersionName: String =
    (project.findProperty("flutter.versionName") ?: "1.0.0").toString()

val flutterMinSdk: Int =
    (project.findProperty("flutter.minSdkVersion") ?: "23").toString().toInt()

android {
    namespace = "pe.unfv.mype_finanzas"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "pe.unfv.mype_finanzas"

        minSdk = maxOf(flutterMinSdk, 29)
        targetSdk = 36

        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // cámbialo por tu firma real cuando tengas keystore de release
            signingConfig = signingConfigs.getByName("debug")
            // minifyEnabled = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    // ruta a la raíz del proyecto Flutter
    source = "../.."
}
