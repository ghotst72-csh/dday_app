package com.forgeapps.tickday

import android.appwidget.AppWidgetManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.app.KeyguardManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableLockScreenDisplay()
        super.onCreate(savedInstanceState)
    }

    override fun onResume() {
        super.onResume()
        enableLockScreenDisplay()
    }

    private fun enableLockScreenDisplay() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(KeyguardManager::class.java)
            keyguardManager?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    private val channelName = "tickday/widget_deeplink"
    private var methodChannel: MethodChannel? = null
    private var alarmChannel: MethodChannel? = null
    private var initialWidgetItemId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeInitialWidgetItemId" -> {
                    val id = initialWidgetItemId
                    initialWidgetItemId = null
                    result.success(id)
                }
                "requestPinHomeWidget" -> {
                    val provider = call.argument<String>("provider") ?: "DdayWidgetProvider"
                    result.success(requestPinHomeWidget(provider))
                }
                else -> result.notImplemented()
            }
        }
        alarmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tickday/alarm")
        alarmChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: return@setMethodCallHandler result.error("INVALID", "alarmId missing", null)
                    val triggerAtMillis = call.argument<Long>("triggerAtMillis") ?: return@setMethodCallHandler result.error("INVALID", "triggerAtMillis missing", null)
                    val title = call.argument<String?>("title")
                    val body = call.argument<String?>("body")
                    val itemId = call.argument<String?>("itemId")
                    if (itemId != null) {
                        getSharedPreferences("tickday_alarms", MODE_PRIVATE)
                            .edit().putString("item_id_$alarmId", itemId).apply()
                    }
                    val intent = Intent(this, AlarmReceiver::class.java).apply {
                        putExtra("schedule_id", alarmId.toString())
                        putExtra("title", title)
                        putExtra("body", body)
                    }
                    val pendingIntent = PendingIntent.getBroadcast(this, alarmId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val alarmManager = getSystemService(AlarmManager::class.java)
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                    result.success(null)
                }
                "cancelAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: return@setMethodCallHandler result.error("INVALID", "alarmId missing", null)
                    getSharedPreferences("tickday_alarms", MODE_PRIVATE)
                        .edit().remove("item_id_$alarmId").apply()
                    val intent = Intent(this, AlarmReceiver::class.java)
                    val pendingIntent = PendingIntent.getBroadcast(this, alarmId, intent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
                    pendingIntent?.let {
                        val alarmManager = getSystemService(AlarmManager::class.java)
                        alarmManager.cancel(it)
                        it.cancel()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        handleWidgetIntent(intent, fromColdStart = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent(intent, fromColdStart = false)
    }

    private fun handleWidgetIntent(intent: Intent?, fromColdStart: Boolean) {
        val itemId = extractWidgetItemId(intent) ?: return
        if (fromColdStart || methodChannel == null) {
            initialWidgetItemId = itemId
        } else {
            methodChannel?.invokeMethod("openWidgetItem", itemId)
        }
    }

    private fun extractWidgetItemId(intent: Intent?): String? {
        val data: Uri = intent?.data ?: return null
        if (data.scheme != "tickday" || data.host != "widget") return null
        val id = data.lastPathSegment ?: return null
        return id.takeIf { it.isNotBlank() }
    }

    private fun requestPinHomeWidget(provider: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false

        val appWidgetManager = getSystemService(AppWidgetManager::class.java) ?: return false
        if (!appWidgetManager.isRequestPinAppWidgetSupported) return false

        val component = when (provider) {
            "DdayWidgetProviderWide" -> ComponentName(this, DdayWidgetProviderWide::class.java)
            else -> ComponentName(this, DdayWidgetProvider::class.java)
        }

        return try {
            appWidgetManager.requestPinAppWidget(component, null, null)
        } catch (_: Exception) {
            false
        }
    }
}
