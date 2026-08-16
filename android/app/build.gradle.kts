import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Production signing is supplied only from a path OUTSIDE this repository.
// BUDGETSENSE_KEYSTORE_PROPERTIES must point to a 0600 properties file whose
// storeFile is also outside the checkout. Missing configuration deliberately
// creates an unsigned release artifact: never debug-sign a production variant.
val keystoreProperties = Properties()
val externalPropertiesPath = System.getenv("BUDGETSENSE_KEYSTORE_PROPERTIES")
val keystorePropertiesFile = externalPropertiesPath?.let(::File)
val hasReleaseKeystore = keystorePropertiesFile?.isFile == true
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile!!))
    val configuredKeystore = File(keystoreProperties["storeFile"] as String)
    val repositoryRoot = rootProject.projectDir.canonicalFile
    check(!configuredKeystore.canonicalFile.path.startsWith(repositoryRoot.path + File.separator)) {
        "Production keystore must be outside the repository."
    }
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
        // Spelled out rather than taken from `flutter.versionName` because
        // pubspec.yaml must hold a three-segment semver ("0.1.0") while the
        // public release is named "0.1". Kept in step with AppInfo.version by
        // scripts/release_preflight.sh.
        versionName = "0.1"
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
