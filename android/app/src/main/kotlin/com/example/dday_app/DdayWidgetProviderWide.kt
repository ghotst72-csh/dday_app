package com.forgeapps.tickday

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
import java.util.Locale
import java.text.SimpleDateFormat
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
                val lang = widgetData.getString("widget_lang", Locale.getDefault().language) ?: "ko"
                val hasFirst = bindRow(context, views, appWidgetId, widgetData, 1, R.id.widget_wide_row_1, R.id.widget_wide_dday_1, R.id.widget_wide_title_1, R.id.widget_wide_progress_1, R.id.widget_wide_remain_1, R.id.widget_wide_message_1, defaultTitle(lang), "D-Day", "TickDay")
                val hasSecond = bindRow(context, views, appWidgetId, widgetData, 2, R.id.widget_wide_row_2, R.id.widget_wide_dday_2, R.id.widget_wide_title_2, R.id.widget_wide_progress_2, R.id.widget_wide_remain_2, R.id.widget_wide_message_2, secondDefaultTitle(lang), "D+", "TickDay")
                views.setViewVisibility(R.id.widget_wide_divider, if (hasSecond) View.VISIBLE else View.GONE)
                if (!hasFirst && !hasSecond) views.setViewVisibility(R.id.widget_wide_row_1, View.VISIBLE)
                views.setTextViewText(R.id.widget_wide_updated_at, updatedText(lang))
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (_: Exception) {
                val fallback = RemoteViews(context.packageName, R.layout.dday_widget_wide)
                fallback.setTextViewText(R.id.widget_wide_dday_1, "D-Day")
                fallback.setTextViewText(R.id.widget_wide_title_1, "TickDay")
                val fallbackLang = Locale.getDefault().language
                fallback.setTextViewText(R.id.widget_wide_remain_1, refreshWidgetText(fallbackLang))
                fallback.setTextViewText(R.id.widget_wide_message_1, defaultMessage(fallbackLang))
                fallback.setProgressBar(R.id.widget_wide_progress_1, 100, 0, false)
                fallback.setTextViewText(R.id.widget_wide_updated_at, updatedText(fallbackLang))
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
        progressViewId: Int,
        remainViewId: Int,
        messageViewId: Int,
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
        val lang = widgetData.getString("${prefix}lang", Locale.getDefault().language) ?: "ko"
        val targetMillis = widgetData.getLongCompat("${prefix}target_millis", 0L)
        val createdMillis = widgetData.getLongCompat("${prefix}created_millis", 0L)
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
        val effectiveTargetMillis = effectiveTargetMillis(targetMillis, repeatType, month, day, hour, minute)
        val dday = if (effectiveTargetMillis > 0L) ddayText(effectiveTargetMillis) else storedDday.ifEmpty { defaultDday }
        val remain = if (effectiveTargetMillis > 0L) remainText(effectiveTargetMillis, lang) else storedRemain.ifEmpty { defaultRemain }
        val title = storedTitle.ifEmpty { defaultTitle }
        val message = if (effectiveTargetMillis > 0L) emotionMessage(title, effectiveTargetMillis, lang) else defaultMessage(lang)
        val progress = progressPercent(createdMillis, effectiveTargetMillis)
        views.setTextViewText(ddayViewId, dday)
        views.setTextViewText(titleViewId, widgetTitleText(title, 17))
        views.setTextViewText(remainViewId, remain)
        views.setTextViewText(messageViewId, message)
        views.setProgressBar(progressViewId, 100, progress, false)

        // ✅ 위젯 색상 안전 적용: HomeWidget 캐시 타입이 Int/Long으로 섞여도 크래시 방지
        val color = widgetData.getIntCompat("${prefix}color", 0xFF111827.toInt())
        views.setTextColor(ddayViewId, color)
        views.setTextColor(titleViewId, color)
        views.setTextColor(remainViewId, color)
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            data = Uri.parse("tickday://widget/$itemId")
        }
        val pendingIntent = PendingIntent.getActivity(context, appWidgetId * 10 + index, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(rowId, pendingIntent)
        return true
    }


    private fun widgetTitleText(title: String, maxLength: Int): String {
        val clean = title.replace(Regex("\\s+"), " ").trim()
        if (clean.length <= maxLength) return clean
        return clean.take(maxLength).trimEnd() + "…"
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
        if (diff <= 0L) return when (lang) { "en" -> "Today"; "ja" -> "今日です"; "vi" -> "Hôm nay"; else -> "오늘입니다" }
        val days = TimeUnit.MILLISECONDS.toDays(diff)
        val hours = TimeUnit.MILLISECONDS.toHours(diff) % 24
        return when (lang) {
            "en" -> when { days <= 0L -> "Today · ${hours}h left"; days == 1L -> "Tomorrow · ${hours}h left"; else -> "${days} days left" }
            "ja" -> when { days <= 0L -> "今日 · あと${hours}時間"; days == 1L -> "明日 · あと${hours}時間"; else -> "あと${days}日" }
            "vi" -> when { days <= 0L -> "Hôm nay · còn ${hours} giờ"; days == 1L -> "Ngày mai · còn ${hours} giờ"; else -> "Còn ${days} ngày" }
            else -> when { days <= 0L -> "오늘 · ${hours}시간 남음"; days == 1L -> "내일 · ${hours}시간 남음"; else -> "${days}일 남음" }
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

        val dayMood = when {
            days == 0 -> "today"
            days <= 2 -> "soon"
            days <= 7 -> "week"
            days <= 30 -> "month"
            else -> "later"
        }

        val categoryMessages = categoryMessages(category, lang)
        val moodMessages = moodMessages(dayMood, lang)
        val messages = categoryMessages + moodMessages
        return messages.random()
    }

    private fun categoryMessages(category: String, lang: String): List<String> {
        return when (lang) {
            "en" -> when (category) {
                "birthday" -> listOf(
                    "A celebration is coming 🎂",
                    "Birthday smiles are getting closer ✨",
                    "A warm wish is waiting 💜",
                    "The candles are almost ready 🎉",
                    "Someone special deserves joy today",
                    "A happy memory is on its way",
                    "Prepare a little surprise 🎁",
                    "A sweet birthday moment is near",
                    "Soon, the room will feel brighter 🌟",
                    "A day full of smiles is coming",
                    "Make space for warm wishes 🎂",
                    "The birthday mood is starting 💜"
                )
                "travel" -> listOf(
                    "Your trip is getting closer ✈️",
                    "A new view is waiting for you 🌊",
                    "Pack a little excitement today 🧳",
                    "Adventure is just ahead ✨",
                    "The road is calling softly 🌿",
                    "Soon, your routine will become a memory",
                    "A fresh breeze is coming your way",
                    "Get ready for a beautiful escape",
                    "Your next scene is almost here 📸",
                    "The map is quietly opening",
                    "A lighter heart is waiting there",
                    "Travel days always arrive faster than expected"
                )
                "anniversary" -> listOf(
                    "A special day is near 💜",
                    "A precious memory is coming back ✨",
                    "Another meaningful moment awaits",
                    "Your warm anniversary is on its way 🌷",
                    "Soon, you will remember why it mattered",
                    "A quiet memory is glowing again",
                    "A day worth keeping is getting closer",
                    "That beautiful feeling is returning",
                    "A heartwarming date is almost here",
                    "Some days deserve to be remembered",
                    "The story continues beautifully 💜",
                    "A little nostalgia is already near"
                )
                "exam" -> listOf(
                    "You have got this 📚",
                    "Just a little more focus 💪",
                    "Your effort is adding up ✨",
                    "Keep going, you are almost there 🔥",
                    "One steady step at a time 🌿",
                    "Believe in what you prepared",
                    "Calm focus will carry you through",
                    "Every small review still counts",
                    "Your future self will thank you",
                    "Breathe, then try one more page",
                    "You are stronger than the pressure",
                    "Let your practice become confidence"
                )
                else -> listOf(
                    "One step closer today 💜",
                    "The wait is getting shorter ✨",
                    "Something meaningful is on the way",
                    "Today moved you a little closer 🙂",
                    "Take it slow and steady 🌿",
                    "The day is waiting quietly",
                    "Small days become special memories",
                    "Your moment is coming at its own pace",
                    "Keep this day gently in mind",
                    "Time is quietly doing its work",
                    "A little excitement is building",
                    "Not far to go now"
                )
            }
            "ja" -> when (category) {
                "birthday" -> listOf(
                    "お祝いの日が近いです🎂",
                    "笑顔の日が近づいています✨",
                    "あたたかい願いが待っています💜",
                    "キャンドルの準備はもうすぐ🎉",
                    "大切な人に喜びを届ける日です",
                    "幸せな思い出が近づいています",
                    "小さなサプライズを準備しましょう🎁",
                    "やさしい誕生日の瞬間が近いです",
                    "部屋が明るくなる日が来ます🌟",
                    "笑顔いっぱいの日が近いです",
                    "あたたかい言葉を用意しましょう🎂",
                    "誕生日の気分が始まっています💜"
                )
                "travel" -> listOf(
                    "旅の日が近づいています✈️",
                    "新しい景色が待っています🌊",
                    "少しずつ楽しみを詰めましょう🧳",
                    "冒険はもうすぐそこです✨",
                    "道がそっと呼んでいます🌿",
                    "日常が思い出に変わる日が来ます",
                    "新しい風が近づいています",
                    "素敵な逃避行の準備をしましょう",
                    "次の景色はもうすぐです📸",
                    "地図が静かに開いています",
                    "軽い心が待っています",
                    "旅の日は思ったより早く来ます"
                )
                "anniversary" -> listOf(
                    "大切な日が近いです💜",
                    "思い出の日が戻ってきます✨",
                    "また意味のある瞬間が待っています",
                    "あたたかい記念日が近づいています🌷",
                    "なぜ大切だったのか思い出す日です",
                    "静かな思い出がまた光っています",
                    "残しておきたい日が近いです",
                    "あの美しい気持ちが戻ってきます",
                    "心あたたまる日がもうすぐです",
                    "覚えておきたい日があります",
                    "物語はきれいに続いています💜",
                    "少し懐かしい気持ちが近づいています"
                )
                "exam" -> listOf(
                    "きっと大丈夫です📚",
                    "あと少し集中しましょう💪",
                    "努力はちゃんと積み重なっています✨",
                    "ここまで来たなら大丈夫🔥",
                    "一歩ずつ落ち着いて進みましょう🌿",
                    "準備した自分を信じて",
                    "落ち着いた集中が力になります",
                    "小さな復習もまだ力になります",
                    "未来の自分が感謝します",
                    "深呼吸してもう一ページ",
                    "プレッシャーよりあなたは強いです",
                    "練習を自信に変えましょう"
                )
                else -> listOf(
                    "今日も一歩近づきました💜",
                    "待つ時間が少し短くなりました✨",
                    "意味のある日が近づいています",
                    "今日も少し前に進みました🙂",
                    "ゆっくり着実に準備しましょう🌿",
                    "その日は静かに待っています",
                    "小さな日々が特別な思い出になります",
                    "あなたの瞬間は自然な速さで来ます",
                    "この日をそっと覚えておきましょう",
                    "時間が静かに進んでいます",
                    "少しずつ楽しみが増えています",
                    "もうそんなに遠くありません"
                )
            }
            "vi" -> when (category) {
                "birthday" -> listOf(
                    "Ngày chúc mừng đang đến 🎂",
                    "Nụ cười sinh nhật đang gần hơn ✨",
                    "Một lời chúc ấm áp đang chờ 💜",
                    "Những ngọn nến gần sẵn sàng rồi 🎉",
                    "Một người đặc biệt xứng đáng được vui",
                    "Một kỷ niệm hạnh phúc đang đến",
                    "Chuẩn bị một bất ngờ nhỏ nhé 🎁",
                    "Khoảnh khắc sinh nhật ngọt ngào sắp đến",
                    "Căn phòng sẽ sớm sáng hơn 🌟",
                    "Một ngày đầy nụ cười đang tới",
                    "Hãy chuẩn bị những lời chúc ấm áp 🎂",
                    "Không khí sinh nhật bắt đầu rồi 💜"
                )
                "travel" -> listOf(
                    "Chuyến đi đang gần hơn ✈️",
                    "Một khung cảnh mới đang chờ bạn 🌊",
                    "Hôm nay hãy gói thêm chút háo hức 🧳",
                    "Cuộc phiêu lưu ở ngay phía trước ✨",
                    "Con đường đang khẽ gọi 🌿",
                    "Sắp tới, thói quen sẽ thành kỷ niệm",
                    "Một làn gió mới đang đến",
                    "Chuẩn bị cho một chuyến trốn thật đẹp",
                    "Khung cảnh tiếp theo sắp hiện ra 📸",
                    "Tấm bản đồ đang lặng lẽ mở ra",
                    "Một trái tim nhẹ hơn đang chờ ở đó",
                    "Ngày đi luôn đến nhanh hơn ta nghĩ"
                )
                "anniversary" -> listOf(
                    "Ngày đặc biệt đang đến 💜",
                    "Một kỷ niệm quý giá đang trở lại ✨",
                    "Một khoảnh khắc ý nghĩa khác đang chờ",
                    "Ngày kỷ niệm ấm áp đang gần hơn 🌷",
                    "Bạn sẽ sớm nhớ vì sao nó quan trọng",
                    "Một kỷ niệm dịu dàng lại sáng lên",
                    "Một ngày đáng giữ gìn đang đến",
                    "Cảm giác đẹp ấy đang quay lại",
                    "Một ngày ấm lòng sắp tới",
                    "Có những ngày rất đáng được nhớ",
                    "Câu chuyện vẫn tiếp tục thật đẹp 💜",
                    "Một chút hoài niệm đã ở rất gần"
                )
                "exam" -> listOf(
                    "Bạn làm được mà 📚",
                    "Tập trung thêm một chút nữa thôi 💪",
                    "Nỗ lực của bạn đang tích lũy ✨",
                    "Tiếp tục nhé, bạn gần tới rồi 🔥",
                    "Từng bước vững vàng thôi 🌿",
                    "Hãy tin vào điều bạn đã chuẩn bị",
                    "Sự bình tĩnh sẽ đưa bạn đi qua",
                    "Mỗi lần ôn nhỏ vẫn có giá trị",
                    "Bạn của tương lai sẽ cảm ơn bạn",
                    "Hít thở rồi thêm một trang nữa",
                    "Bạn mạnh hơn áp lực này",
                    "Biến luyện tập thành tự tin nhé"
                )
                else -> listOf(
                    "Hôm nay lại gần hơn một bước 💜",
                    "Thời gian chờ đang ngắn lại ✨",
                    "Một điều ý nghĩa đang trên đường tới",
                    "Hôm nay đã đưa bạn gần hơn một chút 🙂",
                    "Cứ chậm rãi và vững vàng 🌿",
                    "Ngày ấy đang lặng lẽ chờ bạn",
                    "Những ngày nhỏ sẽ thành kỷ niệm đẹp",
                    "Khoảnh khắc của bạn sẽ đến đúng nhịp",
                    "Hãy nhẹ nhàng giữ ngày này trong lòng",
                    "Thời gian đang âm thầm làm việc",
                    "Một chút háo hức đang lớn dần",
                    "Không còn xa nữa đâu"
                )
            }
            else -> when (category) {
                "birthday" -> listOf(
                    "축하할 날이 다가와요 🎂",
                    "생일의 웃음이 가까워져요 ✨",
                    "따뜻한 축하가 기다리고 있어요 💜",
                    "촛불 켤 시간이 가까워졌어요 🎉",
                    "소중한 사람에게 기쁨을 전할 날이에요",
                    "행복한 추억이 하나 더 생길 거예요",
                    "작은 서프라이즈를 준비해볼까요 🎁",
                    "달콤한 생일 순간이 다가와요",
                    "곧 방 안이 환해질 거예요 🌟",
                    "웃음 가득한 하루가 오고 있어요",
                    "따뜻한 한마디를 준비해요 🎂",
                    "생일 분위기가 벌써 시작됐어요 💜"
                )
                "travel" -> listOf(
                    "여행이 가까워지고 있어요 ✈️",
                    "새로운 풍경이 기다리고 있어요 🌊",
                    "오늘은 설렘을 조금 챙겨요 🧳",
                    "모험은 바로 앞에 있어요 ✨",
                    "길이 조용히 부르고 있어요 🌿",
                    "곧 일상이 추억으로 바뀔 거예요",
                    "새로운 바람이 다가오고 있어요",
                    "예쁜 탈출을 준비해볼까요",
                    "다음 장면이 곧 펼쳐져요 📸",
                    "지도가 조용히 열리고 있어요",
                    "가벼운 마음이 그곳에서 기다려요",
                    "여행 날짜는 늘 생각보다 빨리 와요"
                )
                "anniversary" -> listOf(
                    "소중한 날이 가까워져요 💜",
                    "귀한 기억이 다시 돌아오고 있어요 ✨",
                    "또 하나의 의미 있는 순간이 기다려요",
                    "따뜻한 기념일이 다가와요 🌷",
                    "왜 소중했는지 다시 떠올릴 날이에요",
                    "조용한 추억이 다시 빛나고 있어요",
                    "간직하고 싶은 하루가 가까워져요",
                    "그때의 예쁜 마음이 돌아오고 있어요",
                    "마음 따뜻한 날짜가 곧 와요",
                    "기억할 만한 날은 따로 있죠",
                    "이야기는 예쁘게 이어지고 있어요 💜",
                    "살짝 그리운 마음이 가까이 왔어요"
                )
                "exam" -> listOf(
                    "조금만 더 힘내요 📚",
                    "집중할 시간, 조금만 더요 💪",
                    "노력은 분명히 쌓이고 있어요 ✨",
                    "여기까지 왔으면 충분히 잘하고 있어요 🔥",
                    "한 걸음씩 차분하게 가요 🌿",
                    "준비한 자신을 믿어도 돼요",
                    "차분한 집중이 힘이 될 거예요",
                    "작은 복습도 아직 큰 도움이 돼요",
                    "미래의 내가 고마워할 거예요",
                    "숨 한 번 쉬고 한 페이지 더요",
                    "압박감보다 당신이 더 강해요",
                    "연습이 자신감이 되는 중이에요"
                )
                else -> listOf(
                    "오늘도 한 걸음 가까워졌어요 💜",
                    "기다림이 조금 짧아졌어요 ✨",
                    "의미 있는 날이 오고 있어요",
                    "오늘도 조금 더 가까워졌어요 🙂",
                    "천천히, 그래도 꾸준히 준비해요 🌿",
                    "그날은 조용히 기다리고 있어요",
                    "작은 하루들이 특별한 기억이 돼요",
                    "당신의 순간은 자기 속도로 오고 있어요",
                    "이 날을 마음속에 살짝 담아둬요",
                    "시간이 조용히 일을 하고 있어요",
                    "설렘이 조금씩 쌓이고 있어요",
                    "이제 그렇게 멀지 않아요"
                )
            }
        }
    }

    private fun moodMessages(dayMood: String, lang: String): List<String> {
        return when (lang) {
            "en" -> when (dayMood) {
                "today" -> listOf("Today is the day ✨", "The moment has arrived 💜", "Make today special 🌟", "It is finally here 🙂", "Let today be remembered 🎉", "This is the moment you saved")
                "soon" -> listOf("Almost there 💜", "Just a little longer ✨", "The moment is very close 🙂", "One more breath, almost there 🌿", "It is right around the corner", "The final wait has begun")
                "week" -> listOf("Getting closer every day ✨", "This week carries the excitement 💜", "The wait is getting shorter", "A little thrill is building 🌟", "Keep your heart ready", "Soon will become today")
                "month" -> listOf("There is time to prepare well 🌿", "Slowly getting closer", "The date is becoming real", "A calm kind of excitement is here", "Prepare at your own pace 🙂", "One month can pass quickly")
                else -> listOf("Plenty of time 🌿", "Let it wait beautifully", "Your day is resting in the future", "No rush, just remember it gently", "One day closer, every day ✨", "Good things can take their time")
            }
            "ja" -> when (dayMood) {
                "today" -> listOf("今日がその日です✨", "ついにこの瞬間です💜", "今日は特別に過ごしましょう🌟", "いよいよ来ました🙂", "今日を大切に残しましょう🎉", "待っていた瞬間です")
                "soon" -> listOf("もうすぐです💜", "あと少しだけ待ちましょう✨", "その瞬間はすぐそこです🙂", "深呼吸して、あと少し🌿", "もう目の前です", "最後の待ち時間が始まりました")
                "week" -> listOf("毎日少しずつ近づいています✨", "今週は少しわくわくします💜", "待つ時間が短くなっています", "楽しみがふくらんでいます🌟", "心の準備をしておきましょう", "もうすぐ今日になります")
                "month" -> listOf("まだゆっくり準備できます🌿", "少しずつ近づいています", "日付がだんだん現実になっています", "静かな楽しみが始まっています", "自分のペースで準備しましょう🙂", "一か月は意外と早いです")
                else -> listOf("まだ時間があります🌿", "きれいに待っていましょう", "その日は未来で休んでいます", "急がずそっと覚えておきましょう", "毎日一歩ずつ近づいています✨", "良いことには時間がかかります")
            }
            "vi" -> when (dayMood) {
                "today" -> listOf("Hôm nay là ngày đó ✨", "Khoảnh khắc đã đến rồi 💜", "Hãy làm hôm nay thật đặc biệt 🌟", "Cuối cùng cũng tới rồi 🙂", "Hãy để hôm nay thành kỷ niệm 🎉", "Đây là khoảnh khắc bạn đã giữ")
                "soon" -> listOf("Sắp đến rồi 💜", "Chờ thêm một chút nữa thôi ✨", "Khoảnh khắc ấy rất gần rồi 🙂", "Hít thở, gần tới rồi 🌿", "Nó ở ngay gần đây", "Khoảng chờ cuối đã bắt đầu")
                "week" -> listOf("Mỗi ngày lại gần hơn ✨", "Tuần này có chút háo hức 💜", "Thời gian chờ đang ngắn lại", "Niềm vui nhỏ đang lớn dần 🌟", "Hãy chuẩn bị trái tim nhé", "Sắp tới sẽ thành hôm nay")
                "month" -> listOf("Vẫn còn thời gian chuẩn bị thật tốt 🌿", "Đang gần hơn từng chút", "Ngày ấy đang trở nên thật hơn", "Một cảm giác háo hức nhẹ nhàng đã đến", "Chuẩn bị theo nhịp của bạn 🙂", "Một tháng có thể trôi rất nhanh")
                else -> listOf("Còn nhiều thời gian 🌿", "Hãy để nó chờ thật đẹp", "Ngày ấy đang nằm yên trong tương lai", "Không vội, chỉ cần nhớ nhẹ thôi", "Mỗi ngày lại gần hơn một chút ✨", "Điều tốt đẹp có thể cần thời gian")
            }
            else -> when (dayMood) {
                "today" -> listOf("오늘이 바로 그날이에요 ✨", "드디어 이 순간이 왔어요 💜", "오늘을 특별하게 남겨요 🌟", "드디어 기다리던 날이에요 🙂", "오늘은 기억에 남을 거예요 🎉", "아껴둔 순간이 열렸어요")
                "soon" -> listOf("거의 다 왔어요 💜", "조금만 더 기다리면 돼요 ✨", "그 순간이 아주 가까워요 🙂", "숨 한 번 쉬면 거의 도착이에요 🌿", "이제 바로 코앞이에요", "마지막 기다림이 시작됐어요")
                "week" -> listOf("매일 조금씩 가까워져요 ✨", "이번 주는 괜히 설레요 💜", "기다림이 점점 짧아져요", "작은 설렘이 커지고 있어요 🌟", "마음의 준비를 해둬요", "곧 오늘이 될 거예요")
                "month" -> listOf("아직 예쁘게 준비할 시간이 있어요 🌿", "천천히 가까워지고 있어요", "그 날짜가 점점 현실이 돼요", "잔잔한 설렘이 시작됐어요", "내 속도로 준비해도 괜찮아요 🙂", "한 달은 생각보다 빨리 지나가요")
                else -> listOf("아직 여유가 있어요 🌿", "예쁘게 기다려도 좋아요", "그날은 미래에서 쉬고 있어요", "서두르지 말고 살짝 기억해요", "매일 하루씩 가까워지고 있어요 ✨", "좋은 일은 천천히 와도 좋아요")
            }
        }
    }
    private fun updatedText(lang: String): String {
        val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(System.currentTimeMillis())
        return when (lang) {
            "en" -> "Updated · $time"
            "ja" -> "更新 · $time"
            "vi" -> "Đã cập nhật · $time"
            else -> "갱신됨 · $time"
        }
    }

    private fun defaultMessage(lang: String): String = when (lang) { "en" -> "Add your first event"; "ja" -> "最初の予定を追加しましょう"; "vi" -> "Thêm sự kiện đầu tiên"; else -> "첫 일정을 등록해보세요" }
    private fun defaultTitle(lang: String): String = when (lang) { "en" -> "Add an event"; "ja" -> "予定を追加してください"; "vi" -> "Thêm sự kiện"; else -> "일정을 등록하세요" }
    private fun secondDefaultTitle(lang: String): String = when (lang) { "en" -> "Add another event"; "ja" -> "2つ目の予定を追加してください"; "vi" -> "Thêm sự kiện thứ hai"; else -> "두 번째 일정을 추가하세요" }
    private fun refreshWidgetText(lang: String): String = when (lang) { "en" -> "Open the app to refresh the widget"; "ja" -> "アプリを開いてウィジェットを更新してください"; "vi" -> "Mở ứng dụng để cập nhật widget"; else -> "앱을 열어 위젯을 갱신하세요" }
    private fun progressPercent(createdMillis: Long, targetMillis: Long): Int { if (createdMillis <= 0L || targetMillis <= 0L) return 0; val total = targetMillis - createdMillis; val elapsed = System.currentTimeMillis() - createdMillis; if (total <= 0L) return 100; return ((elapsed.toDouble() / total.toDouble()) * 100.0).toInt().coerceIn(0,100) }
    private fun daysUntil(targetMillis: Long): Long { val now = Calendar.getInstance(); val today = Calendar.getInstance().apply { set(now.get(Calendar.YEAR), now.get(Calendar.MONTH), now.get(Calendar.DAY_OF_MONTH), 0, 0, 0); set(Calendar.MILLISECOND, 0) }; val target = Calendar.getInstance().apply { timeInMillis = targetMillis; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }; return TimeUnit.MILLISECONDS.toDays(target.timeInMillis - today.timeInMillis) }
    private fun SharedPreferences.getLongCompat(key: String, defaultValue: Long): Long = try { getLong(key, defaultValue) } catch (_: ClassCastException) { getInt(key, defaultValue.toInt()).toLong() }
    private fun SharedPreferences.getIntCompat(key: String, defaultValue: Int): Int = try { getInt(key, defaultValue) } catch (_: ClassCastException) { getLong(key, defaultValue.toLong()).toInt() }
}
