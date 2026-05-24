package com.forgeapps.tickday

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "tickday_native_alarm_v2"
        private const val LOG_TAG = "TickDayAlarm"
        private val LOG_TIME_FORMAT = SimpleDateFormat("HH:mm:ss", Locale.US)

        private fun log(stage: String, message: String = "") {
            val time = LOG_TIME_FORMAT.format(Date())
            Log.i(LOG_TAG, "[$LOG_TAG][$time][$stage] ${message.trim()}")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        log("Receiver", "onReceive")
        val scheduleId = intent.getStringExtra("schedule_id")
        val title = intent.getStringExtra("title") ?: "TickDay 알림"
        val body = intent.getStringExtra("body") ?: "확인할 일정이 있습니다."

        val memo = intent.getStringExtra("memo")
        val alarmIntent = Intent(context, AlarmActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra("schedule_id", scheduleId)
            putExtra("title", title)
            putExtra("body", body)
            if (memo != null) putExtra("memo", memo)
        }
        log("Receiver", "startActivity attempt")
        try {
            context.startActivity(alarmIntent)
            log("Receiver", "startActivity success")
        } catch (ex: Exception) {
            log("Receiver", "startActivity failed: ${ex.javaClass.simpleName}: ${ex.message ?: "unknown"}")
            // Direct activity launch may fail on some devices/OS versions.
            // Notification/fullScreenIntent should still be shown.
        }

        // Android 10+ fullScreenIntent 경로 (잠금화면 포함 신뢰성 보장)
        val requestCode = scheduleId?.toIntOrNull() ?: 0
        val fullScreenPi = PendingIntent.getActivity(
            context, requestCode, alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        ensureChannel(context)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPi, true)
            .setContentIntent(fullScreenPi)
            .setAutoCancel(true)
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(requestCode, notification)
        log("Receiver", "notify called requestCode=$requestCode")
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return

        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val audioAttr = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(CHANNEL_ID, "TickDay 알람", NotificationManager.IMPORTANCE_MAX).apply {
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            enableVibration(true)
            enableLights(true)
            setSound(alarmUri, audioAttr)
        }
        nm.createNotificationChannel(channel)
    }
}
