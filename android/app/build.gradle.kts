plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.sch.cbt.mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.sch.cbt.mobile"
        // Support Android 7.0 (API 24) or newer
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/*.version",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "DebugProbesKt.bin"
            )
        }
    }

    signingConfigs {
        create("release") {
            var rawAlias = System.getenv("KEY_ALIAS")?.trim()
            var rawKeyPass = System.getenv("KEY_PASSWORD")?.trim()
            var rawStorePass = System.getenv("KEYSTORE_PASSWORD")?.trim()

            if (rawStorePass.isNullOrEmpty() || rawStorePass == "cbtpassword123") {
                rawStorePass = "xTdBdMtxKjjF9n8V"
            }
            if (rawKeyPass.isNullOrEmpty() || rawKeyPass == "cbtpassword123") {
                rawKeyPass = "xTdBdMtxKjjF9n8V"
            }
            if (rawAlias.isNullOrEmpty() || rawAlias == "cbtkey") {
                rawAlias = "sdntd3cbt"
            }

            keyAlias = rawAlias
            keyPassword = rawKeyPass
            storeFile = file("cbt-release.jks")
            storePassword = rawStorePass
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
            enableV4Signing = false
        }
    }

    buildTypes {
        release {
            val releaseKeystore = file("cbt-release.jks")
            if (releaseKeystore.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
