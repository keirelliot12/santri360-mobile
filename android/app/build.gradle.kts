import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// White-label: nilai tenant dari `--dart-define-from-file=tenants/<slug>/config.json`
// (Flutter meneruskannya ke Gradle sebagai `dart-defines`, base64 per entri).
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.map { String(Base64.getDecoder().decode(it)).split("=", limit = 2) }
        ?.filter { it.size == 2 }
        ?.associate { it[0] to it[1] }
        ?: emptyMap()

val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("Release") }
if (isReleaseBuild && dartDefines["APP_ID"].isNullOrBlank()) {
    throw GradleException(
        "Build rilis wajib --dart-define-from-file=tenants/<slug>/config.json (APP_ID kosong).",
    )
}

// Upload key per tenant dari env (CI: GitHub Environment per tenant).
val keystorePath: String? = System.getenv("ANDROID_KEYSTORE_PATH")

android {
    namespace = "id.santri360.santri360"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true // label app per tenant via resValue
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = dartDefines["APP_ID"] ?: "id.santri360.santri360"
        resValue("string", "app_name", dartDefines["APP_NAME"] ?: "Santri360")
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePath != null) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Tanpa keystore (lokal) jatuh ke debug key; CI rilis memaksa keystore ada.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
