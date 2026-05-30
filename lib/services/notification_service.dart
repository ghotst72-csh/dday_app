import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _notification = FlutterLocalNotificationsPlugin();

  static Future<String> _langCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('tickday_locale') ?? 'ko';
  }

  static String _titleD1(String lang) {
    switch (lang) {
      case 'en': return 'Tomorrow';
      case 'ja': return '明日の予定';
      case 'vi': return 'Lịch ngày mai';
      default:   return '내일 일정';
    }
  }

  static String _bodyD1(String title, String lang) {
    switch (lang) {
      case 'en': return '$title is tomorrow (D-1)';
      case 'ja': return '$title まで残り1日です';
      case 'vi': return '$title còn 1 ngày nữa (D-1)';
      default:   return '$title D-1 입니다';
    }
  }

  static String _titleDDay(String lang) {
    switch (lang) {
      case 'en': return 'Today';
      case 'ja': return '今日の予定';
      case 'vi': return 'Lịch hôm nay';
      default:   return '오늘 일정';
    }
  }

  static String _bodyDDay(String title, String lang) {
    switch (lang) {
      case 'en': return 'Today is $title (D-Day)!';
      case 'ja': return '今日は $title です (D-Day)!';
      case 'vi': return 'Hôm nay là $title (D-Day)!';
      default:   return '$title D-Day 입니다';
    }
  }

  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notification.initialize(settings);
  }

  // ✅ 복수형 (main.dart 호환용)
  static Future<void> scheduleDdayNotifications({
    required int id,
    required String title,
    required DateTime targetDate,
  }) async {
    await scheduleDdayNotification(
      id: id,
      title: title,
      targetDate: targetDate,
    );
  }

  // ✅ 실제 알림
  static Future<void> scheduleDdayNotification({
    required int id,
    required String title,
    required DateTime targetDate,
  }) async {
    final now = DateTime.now();
    final lang = await _langCode();

    // D-1
    final dMinus1 = targetDate.subtract(const Duration(days: 1));

    if (dMinus1.isAfter(now)) {
      await _notification.zonedSchedule(
        id,
        _titleD1(lang),
        _bodyD1(title, lang),
        tz.TZDateTime.from(dMinus1, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dday_channel',
            'Dday 알림',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // D-Day
    if (targetDate.isAfter(now)) {
      await _notification.zonedSchedule(
        id + 10000,
        _titleDDay(lang),
        _bodyDDay(title, lang),
        tz.TZDateTime.from(targetDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dday_channel',
            'Dday 알림',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
