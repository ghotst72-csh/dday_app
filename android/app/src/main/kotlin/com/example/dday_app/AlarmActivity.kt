package com.forgeapps.tickday

import android.animation.Animator
import android.animation.AnimatorInflater
import android.animation.AnimatorSet
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import java.util.Locale

class AlarmActivity : Activity() {

    companion object {
        private const val AREA = "Activity"
    }

    override fun attachBaseContext(newBase: Context) {
        val prefs = newBase.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val langCode = prefs.getString("flutter.tickday_locale", null)
        if (langCode != null) {
            val locale = Locale(langCode)
            val config = Configuration(newBase.resources.configuration)
            config.setLocale(locale)
            AlarmTrace.step(AREA, "attachBaseContext: applying locale=$langCode")
            super.attachBaseContext(newBase.createConfigurationContext(config))
        } else {
            AlarmTrace.step(AREA, "attachBaseContext: no stored locale, using system default")
            super.attachBaseContext(newBase)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var ringtone: Ringtone? = null
    private var currentScheduleId: String? = null
    private val uiAnimators = mutableListOf<Animator>()

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

        val openButton = findViewById<Button>(R.id.btnOpen)
        val closeButton = findViewById<Button>(R.id.btnClose)

        startUiAnimations(openButton)
        bindAlarmViews(intent)

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
            val scheduleId = currentScheduleId
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

        setIntent(intent)
        bindAlarmViews(intent)
    }

    private fun bindAlarmViews(sourceIntent: Intent) {
        val titleView = findViewById<TextView>(R.id.alarmTitle)
        val bodyView = findViewById<TextView>(R.id.alarmBody)
        val memoView = findViewById<TextView>(R.id.alarmMemo)

        val titleText = sourceIntent.getStringExtra("title") ?: "TickDay 알림"
        val bodyText = sourceIntent.getStringExtra("body") ?: "확인할 일정이 있습니다."
        val memoText = sourceIntent.getStringExtra("memo")
        val scheduleId = sourceIntent.getStringExtra("schedule_id")
        currentScheduleId = scheduleId

        markActivityStarted(scheduleId)

        titleView.text = titleText
        bodyView.text = bodyText

        if (!memoText.isNullOrBlank()) {
            memoView.text = memoText
            memoView.visibility = View.VISIBLE
            AlarmTrace.step(AREA, "memo visible")
        } else {
            memoView.text = ""
            memoView.visibility = View.GONE
            AlarmTrace.step(AREA, "memo hidden")
        }

        AlarmTrace.state(AREA, "intent.scheduleId", scheduleId)
        AlarmTrace.state(AREA, "intent.title", titleText)
        AlarmTrace.state(AREA, "intent.body", bodyText)
        AlarmTrace.state(AREA, "intent.memo", memoText ?: "null")
    }

    private fun markActivityStarted(scheduleId: String?) {
        if (scheduleId == null) return
        try {
            getSharedPreferences("tickday_alarms", Context.MODE_PRIVATE)
                .edit()
                .putBoolean("alarm_activity_started_$scheduleId", true)
                .apply()
            AlarmTrace.step(AREA, "startup flag set alarm_activity_started_$scheduleId")
        } catch (ex: Exception) {
            AlarmTrace.fail(AREA, "startup flag set failed", ex)
        }
    }

    private fun clearActivityStarted(scheduleId: String?) {
        if (scheduleId == null) return
        try {
            getSharedPreferences("tickday_alarms", Context.MODE_PRIVATE)
                .edit()
                .putBoolean("alarm_activity_started_$scheduleId", false)
                .apply()
            AlarmTrace.step(AREA, "startup flag cleared alarm_activity_started_$scheduleId")
        } catch (ex: Exception) {
            AlarmTrace.fail(AREA, "startup flag clear failed", ex)
        }
    }

    private fun startUiAnimations(confirmBtn: Button) {
        try {
            val glowPurple = findViewById<View>(R.id.glowPurple)
            val glowBlue = findViewById<View>(R.id.glowBlue)
            val alarmCard = findViewById<View>(R.id.alarmCard)

            // Card starts invisible so entrance animation has clean starting state
            alarmCard.alpha = 0f

            AnimatorInflater.loadAnimator(this, R.animator.alarm_glow_breathe).also {
                it.setTarget(glowPurple); it.start(); uiAnimators.add(it)
            }
            AnimatorInflater.loadAnimator(this, R.animator.alarm_glow_breathe_alt).also {
                it.setTarget(glowBlue); it.start(); uiAnimators.add(it)
            }
            (AnimatorInflater.loadAnimator(this, R.animator.alarm_card_enter) as AnimatorSet).also {
                it.setTarget(alarmCard); it.start(); uiAnimators.add(it)
            }
            AnimatorInflater.loadAnimator(this, R.animator.alarm_btn_pulse).also {
                it.setTarget(confirmBtn); it.start(); uiAnimators.add(it)
            }
        } catch (_: Exception) {}
    }

    private fun stopRingtone() {
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
        AlarmTrace.step(AREA, "ringtone stopped")
    }

    override fun onDestroy() {
        AlarmTrace.enter(AREA, "onDestroy")
        stopRingtone()
        uiAnimators.forEach { it.cancel() }
        uiAnimators.clear()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        clearActivityStarted(currentScheduleId)
        super.onDestroy()
    }
}
