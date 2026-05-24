package com.forgeapps.tickday

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AlarmActivity : Activity() {
    companion object {
        private const val LOG_TAG = "TickDayAlarm"
        private val LOG_TIME_FORMAT = SimpleDateFormat("HH:mm:ss", Locale.US)

        private fun log(stage: String, message: String = "") {
            val time = LOG_TIME_FORMAT.format(Date())
            Log.i(LOG_TAG, "[$LOG_TAG][$time][$stage] ${message.trim()}")
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var ringtone: Ringtone? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        log("Activity", "onCreate")

        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
        log("Activity", "window flags added")

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "tickday:alarm_activity"
        )
        wakeLock?.acquire(30_000L)

        setContentView(R.layout.activity_alarm)

        val titleView = findViewById<TextView>(R.id.alarmTitle)
        val bodyView = findViewById<TextView>(R.id.alarmBody)
        val openButton = findViewById<Button>(R.id.btnOpen)
        val closeButton = findViewById<Button>(R.id.btnClose)

        val titleText = intent.getStringExtra("title") ?: "TickDay 알림"
        val bodyText = intent.getStringExtra("body") ?: "확인할 일정이 있습니다."
        val memoText = intent.getStringExtra("memo")
        titleView.text = titleText
        bodyView.text = bodyText

        val scheduleId = intent.getStringExtra("schedule_id")
        log("Activity", "intent extras schedule_id=$scheduleId title=$titleText body=$bodyText memo=${memoText ?: "null"}")

        // 강한 알람 모드 — FlutterSharedPreferences에서 읽기
        val strongAlarmMode = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.tickday_strong_alarm_mode", false)
        if (strongAlarmMode) {
            try {
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ringtone = RingtoneManager.getRingtone(applicationContext, soundUri)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    ringtone?.isLooping = true
                }
                ringtone?.play()
            } catch (_: Exception) {}
        }

        openButton.setOnClickListener {
            stopRingtone()
            val itemId = if (scheduleId != null) {
                getSharedPreferences("tickday_alarms", Context.MODE_PRIVATE)
                    .getString("item_id_$scheduleId", null)
            } else null

            val mainIntent = Intent(this@AlarmActivity, MainActivity::class.java)
            mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (itemId != null) {
                mainIntent.data = Uri.parse("tickday://widget/$itemId")
            }
            startActivity(mainIntent)
            finish()
        }

        closeButton.setOnClickListener {
            stopRingtone()
            finish()
        }

        Handler(Looper.getMainLooper()).postDelayed({
            if (!isFinishing) {
                stopRingtone()
                finish()
            }
        }, 30_000L)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        log("Activity", "onNewIntent")
        if (intent == null) {
            log("Activity", "onNewIntent received null intent")
            return
        }
        val titleText = intent.getStringExtra("title") ?: "TickDay 알림"
        val bodyText = intent.getStringExtra("body") ?: "확인할 일정이 있습니다."
        val memoText = intent.getStringExtra("memo")
        val scheduleId = intent.getStringExtra("schedule_id")
        log("Activity", "onNewIntent extras schedule_id=$scheduleId title=$titleText body=$bodyText memo=${memoText ?: "null"}")
    }

    private fun stopRingtone() {
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
    }

    override fun onDestroy() {
        stopRingtone()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        super.onDestroy()
    }
}
