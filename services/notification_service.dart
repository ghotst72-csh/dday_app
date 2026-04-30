import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _notification = FlutterLocalNotificationsPlugin();

  static Future init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: android);

    await _notification.initialize(settings);
  }

  static Future scheduleDdayNotification({
    required int id,
    required String title,
    required DateTime targetDate,
  }) async {
    final now = DateTime.now();

    // D-1
    final dMinus1 = targetDate.subtract(const Duration(days: 1));

    if (dMinus1.isAfter(now)) {
      await _notification.zonedSchedule(
        id,
        "내일 일정",
        "$title D-1 입니다",
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
      );
    }

    // D-Day
    if (targetDate.isAfter(now)) {
      await _notification.zonedSchedule(
        id + 10000,
        "오늘 일정",
        "$title D-Day 입니다",
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
      );
    }
  }
}