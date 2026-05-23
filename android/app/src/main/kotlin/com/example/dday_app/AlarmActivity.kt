package com.forgeapps.tickday

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlarmActivity : Activity() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "tickday:alarm_activity"
        )
        wakeLock?.acquire(30_000L)

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        keyguardManager.requestDismissKeyguard(this, null)

        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.gravity = Gravity.CENTER
        root.setPadding(48, 48, 48, 48)

        val title = TextView(this)
        title.text = "TickDay Alarm"
        title.textSize = 24f
        title.gravity = Gravity.CENTER

        val openButton = Button(this)
        openButton.text = "확인"
        openButton.setOnClickListener {
            val mainIntent = Intent(this@AlarmActivity, MainActivity::class.java)
            mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            mainIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            mainIntent.putExtra("from_alarm", true)
            mainIntent.putExtra("schedule_id", intent.getStringExtra("schedule_id"))
            mainIntent.putExtra("alarm_title", intent.getStringExtra("alarm_title"))
            startActivity(mainIntent)
            finish()
        }

        val closeButton = Button(this)
        closeButton.text = "닫기"
        closeButton.setOnClickListener {
            finish()
        }

        root.addView(title)
        root.addView(openButton)
        root.addView(closeButton)
        setContentView(root)

        Handler(Looper.getMainLooper()).postDelayed({
            if (!isFinishing) finish()
        }, 30_000L)
    }

    override fun onDestroy() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        super.onDestroy()
    }
}
