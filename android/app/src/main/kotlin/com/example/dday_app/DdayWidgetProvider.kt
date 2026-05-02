package com.example.dday_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import java.util.concurrent.TimeUnit

class DdayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val title = widgetData.getString("widget_title", "일정을 등록하세요") ?: "일정을 등록하세요"
            val itemId = widgetData.getString("widget_item_id", "") ?: ""
            val repeatType = widgetData.getString("widget_repeat_type", "none") ?: "none"
            val targetMillis = widgetData.getLongCompat("widget_target_millis", 0L)
            val month = widgetData.getIntCompat("widget_month", 0)
            val day = widgetData.getIntCompat("widget_day", 0)
            val hour = widgetData.getIntCompat("widget_hour", 0)
            val minute = widgetData.getIntCompat("widget_minute", 0)

            val effectiveTargetMillis = effectiveTargetMillis(
                targetMillis = targetMillis,
                repeatType = repeatType,
                month = month,
                day = day,
                hour = hour,
                minute = minute
            )

            val dday = if (effectiveTargetMillis > 0L) ddayText(effectiveTargetMillis) else "D-Day"
            val remain = if (effectiveTargetMillis > 0L) remainText(effectiveTargetMillis) else "TickDay"

            val views = RemoteViews(context.packageName, R.layout.dday_widget)
            views.setTextViewText(R.id.widget_dday, dday)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_remain, remain)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                data = Uri.parse("tickday://widget/$itemId")
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun effectiveTargetMillis(
        targetMillis: Long,
        repeatType: String,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ): Long {
        if (repeatType != "yearly") return targetMillis
        if (month !in 1..12 || day !in 1..31) return targetMillis

        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.YEAR, now.get(Calendar.YEAR))
            set(Calendar.MONTH, month - 1)
            set(Calendar.DAY_OF_MONTH, day)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!target.after(now)) {
            target.add(Calendar.YEAR, 1)
        }
        return target.timeInMillis
    }

    private fun ddayText(targetMillis: Long): String {
        val days = daysUntil(targetMillis)
        return if (days == 0L) "D-Day" else "D-${kotlin.math.abs(days)}"
    }

    private fun remainText(targetMillis: Long): String {
        val now = System.currentTimeMillis()
        val diff = targetMillis - now
        if (diff <= 0L) return "오늘입니다"

        val days = TimeUnit.MILLISECONDS.toDays(diff)
        val hours = TimeUnit.MILLISECONDS.toHours(diff) % 24
        return when {
            days <= 0L -> "${hours}시간 남음"
            else -> "${days}일 남음"
        }
    }

    private fun daysUntil(targetMillis: Long): Long {
        val now = Calendar.getInstance()
        val today = Calendar.getInstance().apply {
            set(now.get(Calendar.YEAR), now.get(Calendar.MONTH), now.get(Calendar.DAY_OF_MONTH), 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val target = Calendar.getInstance().apply {
            timeInMillis = targetMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val diff = target.timeInMillis - today.timeInMillis
        return TimeUnit.MILLISECONDS.toDays(diff)
    }

    private fun SharedPreferences.getLongCompat(key: String, defaultValue: Long): Long {
        return try {
            getLong(key, defaultValue)
        } catch (_: ClassCastException) {
            getInt(key, defaultValue.toInt()).toLong()
        }
    }

    private fun SharedPreferences.getIntCompat(key: String, defaultValue: Int): Int {
        return try {
            getInt(key, defaultValue)
        } catch (_: ClassCastException) {
            getLong(key, defaultValue.toLong()).toInt()
        }
    }
}
