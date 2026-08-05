allprojects {
    repositories {
        // Local fallback for the Flutter engine artifacts when the proxy blocks
        // storage.googleapis.com/download.flutter.io (populated from the Gradle
        // cache). Declared first so it's preferred; harmless when unused.
        maven { url = uri("${rootDir}/flutter-engine-repo") }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Force every Android module (incl. plugins like file_picker) to compile
    // against SDK 36, which flutter_plugin_android_lifecycle requires. This
    // afterEvaluate MUST be registered before evaluationDependsOn below, or
    // Gradle throws "project is already evaluated".
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExtension =
                project.extensions.getByName("android")
                    as com.android.build.gradle.BaseExtension
            androidExtension.compileSdkVersion(36)
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
