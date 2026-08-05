import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by a gitignored `android/key.properties` file so no
// secrets ever land in version control. When it is absent (e.g. a fresh clone
// or CI without secrets) we fall back to debug signing so the project still
// builds - the release APK is simply not distributable until a key is provided.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
namespace = "com.budgetsense.budgetsense"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.budgetsense.budgetsense"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signing policy (production-honest):
            //   - If android/key.properties + keystore are present, sign with the
            //     real upload/release key.
            //   - If they are absent, DO NOT debug-sign a release. Leave it
            //     unsigned so the artifact's status is never misrepresented as
            //     production-ready. `flutter build apk --release` then emits
            //     app-release-unsigned.apk. For local `flutter run --release`,
            //     provide a key.properties (see docs/RELEASE_CHECKLIST.md).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                null
            }
            // R8 minification / resource-shrinking is intentionally OFF: reflection
            // in flutter_local_notifications and drift can break at runtime, which
            // a build cannot catch. Keep rules are staged in proguard-rules.pro;
            // enable these two flags only after an on-device smoke test.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

dependencies {
    // Required by flutter_local_notifications for core library desugaring.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
