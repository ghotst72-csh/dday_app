package com.forgeapps.tickday

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "tickday/widget_deeplink"
    private var methodChannel: MethodChannel? = null
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
