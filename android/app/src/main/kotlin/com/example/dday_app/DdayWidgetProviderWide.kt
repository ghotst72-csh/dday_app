package com.example.dday_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import java.util.concurrent.TimeUnit

class DdayWidgetProviderWide : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.dday_widget_wide)

                val hasFirst = bindRow(
                    context = context,
                    views = views,
                    appWidgetId = appWidgetId,
                    widgetData = widgetData,
                    index = 1,
                    rowId = R.id.widget_wide_row_1,
                    ddayViewId = R.id.widget_wide_dday_1,
                    titleViewId = R.id.widget_wide_title_1,
                    remainViewId = R.id.widget_wide_remain_1,
                    defaultTitle = "일정을 등록하세요",
                    defaultDday = "D-Day",
                    defaultRemain = "TickDay"
                )

                val hasSecond = bindRow(
                    context = context,
                    views = views,
                    appWidgetId = appWidgetId,
                    widgetData = widgetData,
                    index = 2,
                    rowId = R.id.widget_wide_row_2,
                    ddayViewId = R.id.widget_wide_dday_2,
                    titleViewId = R.id.widget_wide_title_2,
                    remainViewId = R.id.widget_wide_remain_2,
                    defaultTitle = "두 번째 일정을 추가하세요",
                    defaultDday = "D+",
                    defaultRemain = "TickDay"
                )

                views.setViewVisibility(R.id.widget_wide_divider, if (hasSecond) View.VISIBLE else View.GONE)
                if (!hasFirst && !hasSecond) {
                    views.setViewVisibility(R.id.widget_wide_row_1, View.VISIBLE)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (_: Exception) {
                val fallback = RemoteViews(context.packageName, R.layout.dday_widget_wide)
                fallback.setTextViewText(R.id.widget_wide_dday_1, "D-Day")
                fallback.setTextViewText(R.id.widget_wide_title_1, "TickDay")
                fallback.setTextViewText(R.id.widget_wide_remain_1, "앱을 열어 위젯을 갱신하세요")
                fallback.setViewVisibility(R.id.widget_wide_divider, View.GONE)
                fallback.setViewVisibility(R.id.widget_wide_row_2, View.GONE)
                appWidgetManager.updateAppWidget(appWidgetId, fallback)
            }
        }
    }

    private fun bindRow(
        context: Context,
        views: RemoteViews,
        appWidgetId: Int,
        widgetData: SharedPreferences,
        index: Int,
        rowId: Int,
        ddayViewId: Int,
        titleViewId: Int,
        remainViewId: Int,
        defaultTitle: String,
        defaultDday: String,
        defaultRemain: String
    ): Boolean {
        val prefix = "widget_wide_${index}_"
        val itemId = widgetData.getString("${prefix}item_id", "") ?: ""
        val storedTitle = widgetData.getString("${prefix}title", "") ?: ""
        val storedDday = widgetData.getString("${prefix}dday", "") ?: ""
        val storedRemain = widgetData.getString("${prefix}remain", "") ?: ""
        val repeatType = widgetData.getString("${prefix}repeat_type", "none") ?: "none"
        val targetMillis = widgetData.getLongCompat("${prefix}target_millis", 0L)
        val month = widgetData.getIntCompat("${prefix}month", 0)
        val day = widgetData.getIntCompat("${prefix}day", 0)
        val hour = widgetData.getIntCompat("${prefix}hour", 0)
        val minute = widgetData.getIntCompat("${prefix}minute", 0)

        val hasRealItem = itemId.isNotEmpty() || storedTitle.isNotEmpty() || targetMillis > 0L

        if (index == 2 && !hasRealItem) {
            views.setViewVisibility(rowId, View.GONE)
            return false
        }

        views.setViewVisibility(rowId, View.VISIBLE)

        val effectiveTargetMillis = effectiveTargetMillis(
            targetMillis = targetMillis,
            repeatType = repeatType,
            month = month,
            day = day,
            hour = hour,
            minute = minute
        )

        val dday = if (effectiveTargetMillis > 0L) ddayText(effectiveTargetMillis) else storedDday.ifEmpty { defaultDday }
        val remain = if (effectiveTargetMillis > 0L) remainText(effectiveTargetMillis) else storedRemain.ifEmpty { defaultRemain }
        val title = storedTitle.ifEmpty { defaultTitle }

        views.setTextViewText(ddayViewId, dday)
        views.setTextViewText(titleViewId, title)
        views.setTextViewText(remainViewId, remain)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            data = Uri.parse("tickday://widget/$itemId")
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId * 10 + index,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(rowId, pendingIntent)
        return true
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
        val diff = targetMillis - System.currentTimeMillis()
        if (diff <= 0L) return "오늘입니다"
        val days = TimeUnit.MILLISECONDS.toDays(diff)
        val hours = TimeUnit.MILLISECONDS.toHours(diff) % 24
        return if (days <= 0L) "${hours}시간 남음" else "${days}일 남음"
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
        return TimeUnit.MILLISECONDS.toDays(target.timeInMillis - today.timeInMillis)
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
