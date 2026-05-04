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
import java.util.Locale
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
            val lang = widgetData.getString("widget_lang", Locale.getDefault().language) ?: "ko"
            val targetMillis = widgetData.getLongCompat("widget_target_millis", 0L)
            val createdMillis = widgetData.getLongCompat("widget_created_millis", 0L)
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
            val remain = if (effectiveTargetMillis > 0L) remainText(effectiveTargetMillis, lang) else "TickDay"
            val message = if (effectiveTargetMillis > 0L) emotionMessage(title, effectiveTargetMillis, lang) else defaultMessage(lang)
            val progress = progressPercent(createdMillis, effectiveTargetMillis)

            val views = RemoteViews(context.packageName, R.layout.dday_widget)
            views.setTextViewText(R.id.widget_dday, dday)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_remain, remain)
            views.setTextViewText(R.id.widget_message, message)
            views.setProgressBar(R.id.widget_progress, 100, progress, false)

            // ✅ 색상 적용
            val color = widgetData.getInt("widget_color", 0xFF111827.toInt())
            views.setTextColor(R.id.widget_dday, color)
            views.setTextColor(R.id.widget_title, color)
            views.setTextColor(R.id.widget_remain, color)

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

    private fun effectiveTargetMillis(targetMillis: Long, repeatType: String, month: Int, day: Int, hour: Int, minute: Int): Long {
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
        if (!target.after(now)) target.add(Calendar.YEAR, 1)
        return target.timeInMillis
    }

    private fun ddayText(targetMillis: Long): String {
        val days = daysUntil(targetMillis)
        return if (days == 0L) "D-Day" else "D-${kotlin.math.abs(days)}"
    }

    private fun remainText(targetMillis: Long, lang: String): String {
        val diff = targetMillis - System.currentTimeMillis()
        if (diff <= 0L) return when (lang) {
            "en" -> "Today"
            "ja" -> "今日です"
            "vi" -> "Hôm nay"
            else -> "오늘입니다"
        }
        val days = TimeUnit.MILLISECONDS.toDays(diff)
        val hours = TimeUnit.MILLISECONDS.toHours(diff) % 24
        return when (lang) {
            "en" -> when {
                days <= 0L -> "Today · ${hours}h left"
                days == 1L -> "Tomorrow · ${hours}h left"
                else -> "${days} days left"
            }
            "ja" -> when {
                days <= 0L -> "今日 · あと${hours}時間"
                days == 1L -> "明日 · あと${hours}時間"
                else -> "あと${days}日"
            }
            "vi" -> when {
                days <= 0L -> "Hôm nay · còn ${hours} giờ"
                days == 1L -> "Ngày mai · còn ${hours} giờ"
                else -> "Còn ${days} ngày"
            }
            else -> when {
                days <= 0L -> "오늘 · ${hours}시간 남음"
                days == 1L -> "내일 · ${hours}시간 남음"
                else -> "${days}일 남음"
            }
        }
    }

    private fun emotionMessage(title: String, targetMillis: Long, lang: String): String {
        val days = daysUntil(targetMillis).toInt()
        val lower = title.lowercase(Locale.getDefault())
        val category = when {
            lower.contains("생일") || lower.contains("birthday") || lower.contains("誕生日") || lower.contains("sinh nhật") -> "birthday"
            lower.contains("여행") || lower.contains("trip") || lower.contains("travel") || lower.contains("旅行") || lower.contains("du lịch") -> "travel"
            lower.contains("기념") || lower.contains("anniversary") || lower.contains("記念") || lower.contains("kỷ niệm") -> "anniversary"
            lower.contains("시험") || lower.contains("test") || lower.contains("exam") || lower.contains("試験") || lower.contains("thi") -> "exam"
            else -> "default"
        }
        return when (lang) {
            "en" -> when {
                days == 0 -> "Today is the day ✨"
                category == "birthday" -> "A celebration is coming 🎂"
                category == "travel" -> "Get ready to go ✈️"
                category == "anniversary" -> "A special day is near 💜"
                category == "exam" -> "You’ve got this 📚"
                days <= 2 -> "Almost there 💜"
                days <= 7 -> "Getting closer ✨"
                else -> "Plenty of time 🌿"
            }
            "ja" -> when {
                days == 0 -> "今日がその日です✨"
                category == "birthday" -> "お祝いの日が近いです🎂"
                category == "travel" -> "出発準備をしましょう✈️"
                category == "anniversary" -> "大切な日が近いです💜"
                category == "exam" -> "もう少し頑張って📚"
                days <= 2 -> "もうすぐです💜"
                days <= 7 -> "少しずつ近づいています✨"
                else -> "ゆっくり準備しましょう🌿"
            }
            "vi" -> when {
                days == 0 -> "Hôm nay là ngày đó ✨"
                category == "birthday" -> "Sắp đến ngày chúc mừng 🎂"
                category == "travel" -> "Chuẩn bị lên đường ✈️"
                category == "anniversary" -> "Ngày đặc biệt đang đến 💜"
                category == "exam" -> "Cố lên nhé 📚"
                days <= 2 -> "Sắp đến rồi 💜"
                days <= 7 -> "Đang gần hơn rồi ✨"
                else -> "Còn thời gian chuẩn bị 🌿"
            }
            else -> when {
                days == 0 -> "오늘이 바로 그날이에요 ✨"
                category == "birthday" -> "축하할 날이 다가와요 🎂"
                category == "travel" -> "떠날 준비, 거의 다 왔어요 ✈️"
                category == "anniversary" -> "소중한 날이 가까워져요 💜"
                category == "exam" -> "조금만 더 힘내요 📚"
                days <= 2 -> "조금만 더 기다려요 💜"
                days <= 7 -> "조금씩 가까워지고 있어요 ✨"
                else -> "천천히 준비해요 🌿"
            }
        }
    }

    private fun defaultMessage(lang: String): String = when (lang) {
        "en" -> "Add your first event"
        "ja" -> "最初の予定を追加しましょう"
        "vi" -> "Thêm sự kiện đầu tiên"
        else -> "첫 일정을 등록해보세요"
    }

    private fun progressPercent(createdMillis: Long, targetMillis: Long): Int {
        if (createdMillis <= 0L || targetMillis <= 0L) return 0
        val now = System.currentTimeMillis()
        val total = targetMillis - createdMillis
        val elapsed = now - createdMillis
        if (total <= 0L) return 100
        return ((elapsed.toDouble() / total.toDouble()) * 100.0).toInt().coerceIn(0, 100)
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

    private fun SharedPreferences.getLongCompat(key: String, defaultValue: Long): Long = try { getLong(key, defaultValue) } catch (_: ClassCastException) { getInt(key, defaultValue.toInt()).toLong() }
    private fun SharedPreferences.getIntCompat(key: String, defaultValue: Int): Int = try { getInt(key, defaultValue) } catch (_: ClassCastException) { getLong(key, defaultValue.toLong()).toInt() }
}
