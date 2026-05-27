package com.example.dday_app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.content.Intent
import com.forgeapps.tickday.R
import java.util.Locale

class FullScreenActivity : Activity() {

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(applyAppLocale(newBase))
    }

    private fun applyAppLocale(context: Context): Context {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        val code = prefs.getString("flutter.tickday_locale", null) ?: return context
        val locale = when (code) {
            "ko" -> Locale("ko", "KR")
            "en" -> Locale("en", "US")
            "ja" -> Locale("ja", "JP")
            "vi" -> Locale("vi", "VN")
            else -> return context
        }
        Locale.setDefault(locale)
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        return context.createConfigurationContext(config)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableLockScreenDisplay()
        super.onCreate(savedInstanceState)

        val title = intent.getStringExtra("title") ?: "TickDay"
        val body = intent.getStringExtra("body") ?: ""
        val payload = intent.getStringExtra("payload")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(56, 56, 56, 56)
            setBackgroundColor(Color.rgb(16, 24, 40))
        }

        val appName = TextView(this).apply {
            text = "TickDay"
            textSize = 22f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }

        val dday = TextView(this).apply {
            text = getString(R.string.alarm_badge)
            textSize = 56f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 36, 0, 18)
        }

        val titleView = TextView(this).apply {
            text = title
            textSize = 26f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 10)
        }

        val bodyView = TextView(this).apply {
            text = body
            textSize = 16f
            setTextColor(Color.rgb(186, 200, 255))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 36)
        }

        val confirmButton = Button(this).apply {
            text = getString(R.string.alarm_confirm)
            textSize = 17f
            setOnClickListener {
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                launchIntent?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    if (!payload.isNullOrBlank()) {
                        putExtra("payload", payload)
                    }
                }
                if (launchIntent != null) startActivity(launchIntent)
                finish()
            }
        }

        val closeButton = Button(this).apply {
            text = getString(R.string.alarm_close)
            textSize = 17f
            setOnClickListener { finish() }
        }

        root.addView(appName, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        root.addView(dday, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        root.addView(titleView, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        root.addView(bodyView, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        root.addView(confirmButton, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { bottomMargin = 18 })
        root.addView(closeButton, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))

        setContentView(root)
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

        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        )
    }
}
