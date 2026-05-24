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
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class AlarmActivity : Activity() {

    companion object {
        private const val AREA = "Activity"
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var ringtone: Ringtone? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AlarmTrace.enter(AREA, "onCreate")

        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
        AlarmTrace.step(AREA, "window flags set: SHOW_WHEN_LOCKED|TURN_SCREEN_ON|KEEP_SCREEN_ON")

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "tickday:alarm_activity"
        )
        wakeLock?.acquire(30_000L)
        AlarmTrace.step(AREA, "wakeLock acquired")

        setContentView(R.layout.activity_alarm)

        val titleView = findViewById<TextView>(R.id.alarmTitle)
        val bodyView = findViewById<TextView>(R.id.alarmBody)
        val openButton = findViewById<Button>(R.id.btnOpen)
        val closeButton = findViewById<Button>(R.id.btnClose)

        val titleText = intent.getStringExtra("title") ?: "TickDay 알림"
        val bodyText = intent.getStringExtra("body") ?: "확인할 일정이 있습니다."
        val memoText = intent.getStringExtra("memo")
        val scheduleId = intent.getStringExtra("schedule_id")
        titleView.text = titleText
        bodyView.text = bodyText
        AlarmTrace.state(AREA, "intent.scheduleId", scheduleId)
        AlarmTrace.state(AREA, "intent.title", titleText)
        AlarmTrace.state(AREA, "intent.body", bodyText)
        AlarmTrace.state(AREA, "intent.memo", memoText ?: "null")

        val strongAlarmMode = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.tickday_strong_alarm_mode", false)
        AlarmTrace.state(AREA, "strongAlarmMode", strongAlarmMode)

        if (strongAlarmMode) {
            try {
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ringtone = RingtoneManager.getRingtone(applicationContext, soundUri)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    ringtone?.isLooping = true
                }
                ringtone?.play()
                AlarmTrace.step(AREA, "ringtone play (strong alarm mode)")
            } catch (ex: Exception) {
                AlarmTrace.fail(AREA, "ringtone play failed", ex)
            }
        }

        openButton.setOnClickListener {
            AlarmTrace.step(AREA, "btnOpen clicked")
            stopRingtone()
            val itemId = if (scheduleId != null) {
                getSharedPreferences("tickday_alarms", Context.MODE_PRIVATE)
                    .getString("item_id_$scheduleId", null)
            } else null
            AlarmTrace.state(AREA, "openBtn.itemId", itemId ?: "null")

            val mainIntent = Intent(this@AlarmActivity, MainActivity::class.java)
            mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (itemId != null) {
                mainIntent.data = Uri.parse("tickday://widget/$itemId")
                AlarmTrace.step(AREA, "opening main with deeplink tickday://widget/$itemId")
            } else {
                AlarmTrace.step(AREA, "opening main without deeplink")
            }
            startActivity(mainIntent)
            finish()
        }

        closeButton.setOnClickListener {
            AlarmTrace.step(AREA, "btnClose clicked")
            stopRingtone()
            finish()
        }

        Handler(Looper.getMainLooper()).postDelayed({
            if (!isFinishing) {
                AlarmTrace.step(AREA, "auto-dismiss after 30s")
                stopRingtone()
                finish()
            }
        }, 30_000L)

        AlarmTrace.success(AREA, "onCreate complete")
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        AlarmTrace.enter(AREA, "onNewIntent")
        if (intent == null) {
            AlarmTrace.step(AREA, "onNewIntent null intent")
            return
        }
        val titleText = intent.getStringExtra("title") ?: "TickDay 알림"
        val bodyText = intent.getStringExtra("body") ?: "확인할 일정이 있습니다."
        val memoText = intent.getStringExtra("memo")
        val scheduleId = intent.getStringExtra("schedule_id")
        AlarmTrace.state(AREA, "onNewIntent.scheduleId", scheduleId)
        AlarmTrace.state(AREA, "onNewIntent.title", titleText)
        AlarmTrace.state(AREA, "onNewIntent.body", bodyText)
        AlarmTrace.state(AREA, "onNewIntent.memo", memoText ?: "null")
    }

    private fun stopRingtone() {
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
        AlarmTrace.step(AREA, "ringtone stopped")
    }

    override fun onDestroy() {
        AlarmTrace.enter(AREA, "onDestroy")
        stopRingtone()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        super.onDestroy()
    }
}
