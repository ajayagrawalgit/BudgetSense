package com.budgetsense.budgetsense

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FlutterFragmentActivity (rather than FlutterActivity) is required by
// local_auth so the biometric / device-credential prompt can attach to a
// FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {

    private var channel: MethodChannel? = null
    private var hapticsChannel: MethodChannel? = null
    private var installerChannel: MethodChannel? = null
    private var storageChannel: MethodChannel? = null

    /** Action carried by the launching intent (e.g. from the quick-add widget),
     *  waiting to be consumed by Flutter once it is ready. */
    private var pendingLaunchAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Block screenshots, screen recording, and hide the app's contents in
        // the recent-apps thumbnail. Finance data should never leak this way.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pendingLaunchAction = actionFrom(intent)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidgets" -> {
                        @Suppress("UNCHECKED_CAST")
                        val data = call.arguments as? Map<String, Any?> ?: emptyMap()
                        writeAndRefresh(data)
                        result.success(null)
                    }
                    "consumeLaunchAction" -> {
                        val action = pendingLaunchAction
                        pendingLaunchAction = null
                        result.success(action)
                    }
                    "setScreenSecure" -> {
                        // Toggle FLAG_SECURE at runtime so the user can opt out
                        // of screenshot / screen-recording protection. Secure by
                        // default (set in onCreate); Flutter reconciles this to
                        // the persisted preference on startup.
                        val secure = call.arguments as? Boolean ?: true
                        if (secure) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // A dedicated channel for crisp haptics. Flutter's built-in
        // HapticFeedback routes through View.performHapticFeedback, which many
        // Android devices render as nothing (or ignore when the system "touch
        // vibration" toggle is off). Driving the Vibrator directly with
        // predefined effects gives reliable, subtle feedback instead.
        hapticsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HAPTICS_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "haptic") {
                    performHaptic(call.arguments as? String ?: "selection")
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }

        // In-app update installer (sideloaded builds). Hands a downloaded,
        // already-SHA-256-verified APK to the OS installer via a FileProvider
        // URI. Nothing installs silently: Android shows its own confirm dialog.
        installerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTALLER_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canRequestInstalls())
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.success("failed")
                        } else {
                            result.success(installApk(path))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Shared-storage access for local backups written to a top-level
        // BudgetSense_Backup folder. On Android 11+ this is the one-time
        // "All files access" grant; on older versions the classic write
        // permission.
        storageChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STORAGE_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                    "requestAllFilesAccess" -> {
                        requestAllFilesAccess()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** True when the app may write to top-level shared storage. */
    private fun hasAllFilesAccess(): Boolean {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
                Environment.isExternalStorageManager()
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                ContextCompat.checkSelfPermission(
                    this,
                    android.Manifest.permission.WRITE_EXTERNAL_STORAGE,
                ) == PackageManager.PERMISSION_GRANTED
            else -> true
        }
    }

    /** Routes the user to grant storage access. Non-blocking; Dart re-checks. */
    private fun requestAllFilesAccess() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    STORAGE_REQUEST_CODE,
                )
            }
        } catch (t: Throwable) {
            Log.e(TAG, "requestAllFilesAccess failed", t)
        }
    }

    /** Whether this app may request package installs ("install unknown apps"). */
    private fun canRequestInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    /** Launches the system installer, or routes to the permission screen. */
    private fun installApk(path: String): String {
        return try {
            if (!canRequestInstalls()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName"),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                }
                return "needsPermission"
            }
            val file = File(path)
            if (!file.exists()) return "failed"
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            "launched"
        } catch (t: Throwable) {
            Log.e(TAG, "install failed", t)
            "failed"
        }
    }

    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    /** Manufacturers whose vibration motors need a stronger nudge than our
     *  default tuning to actually turn on (see [performHaptic]'s doc comment).
     *  Reported specifically for Motorola; kept as a set so more can be added
     *  if the same silent-haptics report comes in for another OEM. */
    private val _weakMotorManufacturer: Boolean by lazy {
        Build.MANUFACTURER.contains("motorola", ignoreCase = true)
    }

    private val _minAmplitudeFloor: Int
        get() = if (_weakMotorManufacturer) 200 else 0

    private val _durationFloorMs: Long
        get() = if (_weakMotorManufacturer) 40L else 0L

    /** Fires a short, purposeful vibration mapped from the semantic kind sent by
     *  the Dart [Haptics] helper (selection / confirm / impact / warning).
     *
     *  Deliberately uses `createOneShot` / a waveform rather than predefined
     *  effects (EFFECT_TICK etc.), because predefined effects are silent no-ops
     *  on many OEM devices. A one-shot with an explicit amplitude physically
     *  drives the motor everywhere. Durations are kept short but above the
     *  ~15ms perceptibility floor so they can actually be felt.
     *
     *  Some OEMs (Motorola in particular, across several Moto G / Edge models)
     *  ship ERM vibration motors with a much higher "won't even spin" floor
     *  than the mid-range amplitudes we use elsewhere: our normal 100-160
     *  amplitude at ~20-30ms is genuinely below their motor's turn-on
     *  threshold, so nothing is felt even though the call succeeds with no
     *  error. [_minAmplitudeFloor] and [_durationFloorMs] raise both amplitude
     *  and duration on those manufacturers so the pulse actually clears the
     *  motor's start-up threshold; every other OEM keeps the original tuning. */
    private fun performHaptic(kind: String) {
        try {
            val v = vibrator
            if (v == null || !v.hasVibrator()) {
                Log.d(TAG, "haptic '$kind' skipped: no vibrator on this device")
                return
            }

            val ms = (when (kind) {
                "selection" -> 20L
                "confirm" -> 30L
                "impact" -> 45L
                "warning" -> 60L
                else -> 20L
            }).coerceAtLeast(_durationFloorMs)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val amplitude = if (v.hasAmplitudeControl()) {
                    val tuned = when (kind) {
                        "selection" -> 100
                        "confirm" -> 160
                        "impact" -> 220
                        "warning" -> 255
                        else -> 100
                    }
                    tuned.coerceAtLeast(_minAmplitudeFloor)
                } else {
                    // Device can't vary strength: let the system pick a sane one.
                    VibrationEffect.DEFAULT_AMPLITUDE
                }

                val effect = if (kind == "warning") {
                    // A crisp double tap for the rare warning cue.
                    VibrationEffect.createWaveform(longArrayOf(0, ms, 55, ms), -1)
                } else {
                    VibrationEffect.createOneShot(ms, amplitude)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val attrs = VibrationAttributes.Builder()
                        .setUsage(VibrationAttributes.USAGE_TOUCH)
                        .build()
                    v.vibrate(effect, attrs)
                } else {
                    v.vibrate(effect)
                }
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(ms)
            }
            Log.d(TAG, "haptic '$kind' fired (${ms}ms)")
        } catch (t: Throwable) {
            Log.e(TAG, "haptic '$kind' failed", t)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = actionFrom(intent)
        if (action != null) {
            // App is already alive: deliver the action right away, and also keep
            // it pending in case Flutter queries on the next resume.
            pendingLaunchAction = action
            channel?.invokeMethod("onWidgetAction", action)
        }
    }

    private fun actionFrom(intent: Intent?): String? {
        return intent?.getStringExtra(WidgetSupport.EXTRA_ACTION)
    }

    private fun writeAndRefresh(data: Map<String, Any?>) {
        val editor = WidgetSupport.prefs(this).edit()
        for ((key, value) in data) {
            editor.putString(key, value?.toString() ?: "")
        }
        editor.apply()
        WidgetSupport.updateAll(this)
    }

    companion object {
        private const val TAG = "BudgetSenseHaptics"
        private const val CHANNEL = "com.budgetsense.budgetsense/widgets"
        private const val HAPTICS_CHANNEL = "com.budgetsense.budgetsense/haptics"
        private const val INSTALLER_CHANNEL =
            "com.budgetsense.budgetsense/installer"
        private const val STORAGE_CHANNEL =
            "com.budgetsense.budgetsense/storage"
        private const val STORAGE_REQUEST_CODE = 9021
    }
}
