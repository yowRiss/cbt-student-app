package id.sch.cbt.mobile

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.KeyEvent
import android.view.SearchEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "id.sch.cbt.mobile/security"
    private var isScreenOff: Boolean = false
    private var isSecurityModeActive: Boolean = false
    private var isExternalResourceAllowed: Boolean = false
    private var securityChannel: MethodChannel? = null

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    isScreenOff = true
                }
                Intent.ACTION_SCREEN_ON -> {
                    // Screen turned on
                }
                Intent.ACTION_USER_PRESENT -> {
                    isScreenOff = false
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    override fun onResume() {
        super.onResume()
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
            powerManager?.isInteractive ?: true
        } else {
            @Suppress("DEPRECATION")
            powerManager?.isScreenOn ?: true
        }
        if (isInteractive) {
            isScreenOff = false
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus && isSecurityModeActive && !isExternalResourceAllowed) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                powerManager?.isInteractive ?: true
            } else {
                @Suppress("DEPRECATION")
                powerManager?.isScreenOn ?: true
            }
            if (!isScreenOff && isInteractive) {
                // Focus was lost while screen is interactive (e.g., Google Assistant, Circle to Search, status bar pull, overlay, or unpinning app)
                // Notify Flutter to record violation, without forcibly trapping the user via startActivity loop
                securityChannel?.invokeMethod("onWindowFocusLost", null)
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isSecurityModeActive && !isExternalResourceAllowed) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_ASSIST,
                KeyEvent.KEYCODE_VOICE_ASSIST,
                KeyEvent.KEYCODE_SEARCH -> {
                    if (event.action == KeyEvent.ACTION_UP) {
                        securityChannel?.invokeMethod("onAssistAttempted", null)
                    }
                    return true // Block assistant key event
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onSearchRequested(): Boolean {
        if (isSecurityModeActive && !isExternalResourceAllowed) {
            securityChannel?.invokeMethod("onAssistAttempted", null)
            return false
        }
        return super.onSearchRequested()
    }

    override fun onSearchRequested(searchEvent: SearchEvent?): Boolean {
        if (isSecurityModeActive && !isExternalResourceAllowed) {
            securityChannel?.invokeMethod("onAssistAttempted", null)
            return false
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            super.onSearchRequested(searchEvent)
        } else {
            false
        }
    }

    override fun onProvideAssistData(data: Bundle?) {
        super.onProvideAssistData(data)
        if (isSecurityModeActive) {
            data?.clear() // Clear any screen context from being sent to Google Assistant / Circle to Search
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        securityChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecurityMode" -> {
                    isSecurityModeActive = call.argument<Boolean>("active") ?: false
                    result.success(true)
                }
                "setExternalResourceAllowed" -> {
                    isExternalResourceAllowed = call.argument<Boolean>("allowed") ?: false
                    result.success(true)
                }
                "enableSecureScreen" -> {
                    isSecurityModeActive = true
                    activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "disableSecureScreen" -> {
                    isSecurityModeActive = false
                    activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "keepScreenOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    if (enable) {
                        activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }
                "isScreenInteractive" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                        powerManager?.isInteractive ?: true
                    } else {
                        @Suppress("DEPRECATION")
                        powerManager?.isScreenOn ?: true
                    }
                    val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                    val isLocked = keyguardManager?.isKeyguardLocked ?: false

                    val active = !isScreenOff && isInteractive && !isLocked
                    result.success(active)
                }
                "startLockTask" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            startLockTask()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("LOCK_TASK_ERROR", e.localizedMessage, null)
                    }
                }
                "stopLockTask" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            stopLockTask()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("STOP_LOCK_ERROR", e.localizedMessage, null)
                    }
                }
                "openAssistSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_VOICE_INPUT_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
