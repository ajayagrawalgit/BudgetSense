# ProGuard / R8 keep rules for BudgetSense.
#
# NOTE: R8 minification is currently DISABLED in build.gradle.kts. These rules
# are staged so that enabling `isMinifyEnabled = true` (after an on-device smoke
# test) does not silently break plugins that rely on reflection.

# Flutter engine.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# flutter_local_notifications uses Gson via reflection to (de)serialize the
# scheduled-notification models - stripping these fields breaks reminders.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# drift / sqlite3 native bindings.
-keep class org.sqlite.** { *; }
-keep class com.tekartik.** { *; }
-dontwarn org.sqlite.**

# local_auth (biometric) and AndroidX security bits.
-keep class androidx.biometric.** { *; }

# Keep annotated native methods.
-keepclasseswithmembernames class * {
    native <methods>;
}
