package com.forgeapps.tickday

import android.app.KeyguardManager
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
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "tickday_native_alarm_v2"
        private const val AREA = "Receiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        AlarmTrace.enter(AREA, "onReceive")

        val scheduleId = intent.getStringExtra("schedule_id")
        val title = intent.getStringExtra("title") ?: "TickDay 알림"
        val body = intent.getStringExtra("body") ?: "확인할 일정이 있습니다."
        val memo = intent.getStringExtra("memo")
        AlarmTrace.state(AREA, "intent.scheduleId", scheduleId)
        AlarmTrace.state(AREA, "intent.title", title)
        AlarmTrace.state(AREA, "intent.body", body)
        AlarmTrace.state(AREA, "intent.memo", memo ?: "null")

        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        AlarmTrace.state(AREA, "screen.isInteractive", pm.isInteractive)
        AlarmTrace.state(AREA, "keyguard.isLocked", km.isKeyguardLocked)

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        AlarmTrace.state(AREA, "notifications.enabled", nm.areNotificationsEnabled())

        val alarmIntent = Intent(context, AlarmActivity::class.java).apply {
            action = "com.forgeapps.tickday.ALARM_${scheduleId ?: System.currentTimeMillis()}"
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            )
            putExtra("schedule_id", scheduleId)
            putExtra("title", title)
            putExtra("body", body)
            if (memo != null) putExtra("memo", memo)
        }
        AlarmTrace.state(AREA, "alarmIntent.action", alarmIntent.action)
        AlarmTrace.state(AREA, "alarmIntent.flags", alarmIntent.flags)

        val requestCode = System.currentTimeMillis().toInt()
        AlarmTrace.state(AREA, "requestCode", requestCode)

        val fullScreenPi = PendingIntent.getActivity(
            context, requestCode, alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        AlarmTrace.step(AREA, "fullScreenPi created")

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

        nm.notify(requestCode, notification)
        AlarmTrace.success(AREA, "notify called requestCode=$requestCode")

        // Fallback only: on some Samsung lock-screen states, direct Activity launch
        // from BroadcastReceiver may be ignored. Prefer fullScreenIntent first.
        AlarmTrace.step(AREA, "fallback startActivity attempt")
        try {
            context.startActivity(alarmIntent)
            AlarmTrace.success(AREA, "fallback startActivity ok")
        } catch (ex: Exception) {
            AlarmTrace.fail(AREA, "fallback startActivity failed", ex)
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) {
            AlarmTrace.step(AREA, "channel already exists id=$CHANNEL_ID")
            return
        }

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
        AlarmTrace.step(AREA, "channel created id=$CHANNEL_ID")
    }
}
