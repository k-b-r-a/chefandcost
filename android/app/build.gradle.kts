import java.io.FileInputStream
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

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.chefandcost.app"
    // Google Play requires targeting Android 16 (API 36) or higher.
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Dynamically derive supported Android locale filters from lib/l10n/app_*.arb
    val supportedLocales = rootProject.file("../lib/l10n")
        .listFiles { f -> f.name.startsWith("app_") && f.name.endsWith(".arb") }
        ?.map { f ->
            val code = f.name.removePrefix("app_").removeSuffix(".arb")
            if (code.contains("_")) "b+${code.replace("_", "+")}" else code
        }
        ?.sorted()
        ?: listOf("en", "es")

    defaultConfig {
        applicationId = "com.chefandcost.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    androidResources {
        localeFilters += supportedLocales
    }

    signingConfigs {
        getByName("debug") {
            enableV1Signing = true
            enableV2Signing = true
        }
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")?.trim()
            keyPassword = keystoreProperties.getProperty("keyPassword")?.trim()
            val storeFilePath = keystoreProperties.getProperty("storeFile")?.trim()
            storeFile = if (!storeFilePath.isNullOrEmpty()) rootProject.file(storeFilePath) else null
            storePassword = keystoreProperties.getProperty("storePassword")?.trim()
            enableV1Signing = false
            enableV2Signing = true
            enableV3Signing = true
            enableV4Signing = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            ndk {
                debugSymbolLevel = "FULL"
            }

            val releaseSigning = signingConfigs.getByName("release")
            val hasValidReleaseKeystore = releaseSigning.storeFile != null &&
                releaseSigning.storeFile!!.exists() &&
                !releaseSigning.keyAlias.isNullOrBlank() &&
                !releaseSigning.keyPassword.isNullOrBlank() &&
                !releaseSigning.storePassword.isNullOrBlank()

            val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
                it.contains("Release", ignoreCase = true) || it.contains("Bundle", ignoreCase = true)
            }

            if (hasValidReleaseKeystore) {
                signingConfig = releaseSigning
            } else if (isReleaseBuildRequested && project.findProperty("allowDebugSignedRelease") != "true") {
                throw GradleException(
                    "Release build aborted: android/key.properties or keystore file is missing/incomplete. " +
                    "Configure android/key.properties (or pass -PallowDebugSignedRelease=true for local R8 testing only)."
                )
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "/META-INF/DEPENDENCIES"
            )
        }
        jniLibs {
            // AGP 8.5+ 16 KB page size alignment requirement: keep uncompressed native libs
            useLegacyPackaging = false
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("androidx.profileinstaller:profileinstaller:1.4.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Google Play Integrity API (StandardIntegrityManager & Classic Integrity)
    implementation("com.google.android.play:integrity:1.4.0")

    // Kotlin Coroutines for asynchronous Task handling
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
}

flutter {
    source = "../.."
}
