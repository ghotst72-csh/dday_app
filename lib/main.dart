import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_settings/app_settings.dart';
import 'package:home_widget/home_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;


const String _localePrefsKey = 'tickday_locale';
const String _splashSeenPrefsKey = 'tickday_splash_seen';
const String _firstGuideSeenPrefsKey = 'tickday_first_guide_seen';
const String _globalReminderEnabledKey = 'tickday_global_reminder_enabled';
const String _defaultAlarmMinutesKey = 'tickday_default_alarm_minutes';
const String _strongAlarmModeKey = 'tickday_strong_alarm_mode';
const String _todaySummaryEnabledKey = 'tickday_today_summary_enabled';
const String _todaySummaryHourKey = 'tickday_today_summary_hour';
const String _todaySummaryMinuteKey = 'tickday_today_summary_minute';
const String _widgetPinnedItemIdKey = 'tickday_widget_pinned_item_id';
const String _permanentlyDeletedWidgetIdsKey = 'tickday_permanently_deleted_widget_ids';
const String _privacyPolicyUrl = 'https://ghotst72-csh.github.io/tickday-policy/privacy.html';
const String _termsOfUseUrl = 'https://ghotst72-csh.github.io/tickday-terms/terms.html';
const int _todaySummaryNotificationId = 999101;
const int _todaySummaryScheduleDays = 7;
final ValueNotifier<Locale?> appLocaleNotifier = ValueNotifier<Locale?>(null);

Locale? _localeFromCode(String? code) {
  switch (code) {
    case 'ko':
      return const Locale('ko', 'KR');
    case 'en':
      return const Locale('en', 'US');
    case 'ja':
      return const Locale('ja', 'JP');
    case 'vi':
      return const Locale('vi', 'VN');
    default:
      return null;
  }
}

String _languageName(String code) {
  switch (code) {
    case 'ko':
      return '한국어';
    case 'en':
      return 'English';
    case 'ja':
      return '日本語';
    case 'vi':
      return 'Tiếng Việt';
    default:
      return 'System';
  }
}

class L {
  final Locale locale;
  const L(this.locale);

  static L of(BuildContext context) => L(Localizations.localeOf(context));

  bool get _ko => locale.languageCode == 'ko';
  bool get _ja => locale.languageCode == 'ja';
  bool get _vi => locale.languageCode == 'vi';

  String pick({required String ko, required String en, String? ja, String? vi}) {
    if (_ko) return ko;
    if (_ja) return ja ?? en;
    if (_vi) return vi ?? en;
    return en;
  }

  String get appTitle => pick(ko: 'TickDay', en: 'TickDay', ja: 'TickDay', vi: 'TickDay');
  String get subtitle => pick(
        ko: '소중한 날을 놓치지 마세요',
        en: 'Never miss your important days',
        ja: '大切な日を忘れない',
        vi: 'Đừng bỏ lỡ ngày quan trọng',
      );
  String get myEvents => pick(ko: '내 일정', en: 'My Events', ja: '予定', vi: 'Sự kiện');
  String get sortTimeLeft => pick(ko: '남은시간순', en: 'Time left', ja: '残り時間順', vi: 'Thời gian còn lại');
  String get sortCreated => pick(ko: '등록일순', en: 'Newest', ja: '登録日順', vi: 'Mới nhất');
  String get sortTitle => pick(ko: '제목순', en: 'Title', ja: 'タイトル順', vi: 'Tiêu đề');
  String get sortIcon => pick(ko: '종류별', en: 'Category', ja: 'カテゴリ', vi: 'Danh mục');
  String get sortRepeat => pick(ko: '반복우선', en: 'Repeat first', ja: '繰り返し優先', vi: 'Lặp lại trước');
  String get list => pick(ko: '목록', en: 'List', ja: 'リスト', vi: 'Danh sách');
  String get card => pick(ko: '카드', en: 'Cards', ja: 'カード', vi: 'Thẻ');
  String get firstEventTitle => pick(ko: '첫 일정을 등록해보세요', en: 'Create your first event', ja: '最初の予定を登録しましょう', vi: 'Tạo sự kiện đầu tiên');
  String get firstEventSubtitle => pick(ko: '생일, 기념일, 여행까지 한눈에 관리하세요.', en: 'Track birthdays, anniversaries, trips and more.', ja: '誕生日や記念日、旅行まで一目で管理。', vi: 'Theo dõi sinh nhật, kỷ niệm, chuyến đi và hơn thế nữa.');
  String get widgetNoticeTitle => pick(ko: '위젯 준비 중', en: 'Widget coming soon', ja: 'ウィジェット準備中', vi: 'Sắp có widget');
  String get widgetNoticeSubtitle => pick(ko: '홈 화면에서 바로 보는 D-day 위젯을 준비하고 있어요.', en: 'A home screen D-day widget is being prepared.', ja: 'ホーム画面で見られるD-dayウィジェットを準備中です。', vi: 'Widget D-day trên màn hình chính đang được chuẩn bị.');
  String get emptyTitle => pick(ko: '아직 등록된 일정이 없어요', en: 'No events yet', ja: 'まだ予定がありません', vi: 'Chưa có sự kiện');
  String get emptySubtitle => pick(ko: '오른쪽 아래 + 버튼으로 첫 일정을 등록해보세요.', en: 'Tap the + button to add your first event.', ja: '右下の＋ボタンで最初の予定を追加しましょう。', vi: 'Nhấn nút + để thêm sự kiện đầu tiên.');
  String get permissionTitle => pick(ko: '알림 설정 상태', en: 'Notification status', ja: '通知設定の状態', vi: 'Trạng thái thông báo');
  String get permissionOk => pick(ko: '핵심 정상', en: 'Ready', ja: '正常', vi: 'Sẵn sàng');
  String get permissionOkSubtitle => pick(ko: '기본 알림과 정확한 알람이 정상입니다.', en: 'Notifications and exact alarms are ready.', ja: '通知と正確なアラームは正常です。', vi: 'Thông báo và báo thức chính xác đã sẵn sàng.');
  String get repeatYearly => pick(ko: '매년', en: 'Yearly', ja: '毎年', vi: 'Hằng năm');
  String get settingsNeeded => pick(ko: '설정 필요', en: 'Setup needed', ja: '設定が必要', vi: 'Cần cài đặt');
  String get caution => pick(ko: '주의', en: 'Check', ja: '注意', vi: 'Chú ý');
  String get normal => pick(ko: '정상', en: 'OK', ja: '正常', vi: 'Ổn');
  String get later => pick(ko: '나중에', en: 'Later', ja: '後で', vi: 'Để sau');
  String get confirm => pick(ko: '확인', en: 'OK', ja: '確認', vi: 'OK');
  String get save => pick(ko: '저장', en: 'Save', ja: '保存', vi: 'Lưu');
  String get done => pick(ko: '완료', en: 'Done', ja: '完了', vi: 'Xong');
  String get edit => pick(ko: '편집', en: 'Edit', ja: '編集', vi: 'Sửa');
  String get delete => pick(ko: '삭제', en: 'Delete', ja: '削除', vi: 'Xóa');
  String get cancel => pick(ko: '취소', en: 'Cancel', ja: 'キャンセル', vi: 'Hủy');
  String get share => pick(ko: '공유', en: 'Share', ja: '共有', vi: 'Chia sẻ');
  String get copy => pick(ko: '복사본 만들기', en: 'Make a copy', ja: 'コピーを作成', vi: 'Tạo bản sao');
  String get noRepeat => pick(ko: '반복 안 함', en: 'No repeat', ja: '繰り返しなし', vi: 'Không lặp lại');
  String get yearlyRepeat => pick(ko: '매년 반복', en: 'Repeat yearly', ja: '毎年繰り返し', vi: 'Lặp lại hằng năm');
  String get titleFallback => pick(ko: '일정 제목', en: 'Event title', ja: '予定タイトル', vi: 'Tiêu đề sự kiện');
  String get titleNone => pick(ko: '제목 없음', en: 'Untitled', ja: 'タイトルなし', vi: 'Không có tiêu đề');
  String get memo => pick(ko: '메모', en: 'Memo', ja: 'メモ', vi: 'Ghi chú');
  String get noMemo => pick(ko: '메모 없음', en: 'No memo', ja: 'メモなし', vi: 'Không có ghi chú');
  String get date => pick(ko: '날짜', en: 'Date', ja: '日付', vi: 'Ngày');
  String get time => pick(ko: '시간', en: 'Time', ja: '時間', vi: 'Giờ');
  String get repeat => pick(ko: '반복', en: 'Repeat', ja: '繰り返し', vi: 'Lặp lại');
  String get reminder => pick(ko: '알림', en: 'Reminder', ja: '通知', vi: 'Nhắc nhở');
  String get newEvent => pick(ko: '새 일정', en: 'New event', ja: '新しい予定', vi: 'Sự kiện mới');
  String get editEvent => pick(ko: '일정 편집', en: 'Edit event', ja: '予定を編集', vi: 'Sửa sự kiện');
  String get decorate => pick(ko: '꾸미기', en: 'Customize', ja: 'カスタマイズ', vi: 'Tùy chỉnh');
  String get icon => pick(ko: '아이콘', en: 'Icon', ja: 'アイコン', vi: 'Biểu tượng');
  String get color => pick(ko: '색상', en: 'Color', ja: '色', vi: 'Màu sắc');
  String get addHomeWidget => pick(ko: '홈 위젯 추가하기', en: 'Add home widget', ja: 'ホームウィジェットを追加', vi: 'Thêm widget màn hình chính');
  String get smallWidget => pick(ko: '작은 위젯', en: 'Small widget', ja: '小さいウィジェット', vi: 'Widget nhỏ');
  String get wideWidget => pick(ko: '넓은 위젯', en: 'Wide widget', ja: '横長ウィジェット', vi: 'Widget rộng');
  String get todayIsTheDay => pick(ko: '오늘이 바로 그날이에요', en: 'Today is the day', ja: '今日はその日です', vi: 'Hôm nay là ngày đó');
  String get slowlyPrepare => pick(ko: '천천히 준비해요 🌿', en: 'Take your time preparing 🌿', ja: 'ゆっくり準備しましょう 🌿', vi: 'Cứ từ từ chuẩn bị 🌿');
  String get almostThere => pick(ko: '곧 만날 순간이에요 💜', en: 'The moment is almost here 💜', ja: 'もうすぐその瞬間です 💜', vi: 'Khoảnh khắc ấy sắp đến rồi 💜');
}


class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static void Function(String payload)? onNotificationClick;
  static String? _launchPayload;

  static String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'dday_alarm_channel',
    'D-day Reminder',
    channelDescription: 'TickDay event reminder notifications.',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  static const NotificationDetails _details = NotificationDetails(android: _androidDetails);

  // ⚠️ 풀스크린 알림 테스트용 (1차 안전버전, 아직 실제 스케줄에 연결 안 함)
  static const AndroidNotificationDetails _androidDetailsFullScreen = AndroidNotificationDetails(
    'dday_alarm_fullscreen_channel',
    'D-day Full-Screen Reminder',
    channelDescription: 'TickDay full-screen event reminder notifications (test only).',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
    enableVibration: true,
    fullScreenIntent: true,  // 핵심: 풀스크린 모드 활성화
  );

  static const NotificationDetails _detailsFullScreen = NotificationDetails(android: _androidDetailsFullScreen);

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty || payload == '__test__') return;
        onNotificationClick?.call(payload);
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty &&
        launchPayload != '__test__') {
      _launchPayload = launchPayload;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  static Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canScheduleExactAlarms() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      return await androidPlugin?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestNotificationPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<bool> requestExactAlarmPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.requestExactAlarmsPermission() ?? false;
  }

  static Future<bool> requestFullScreenIntentPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      return await androidPlugin?.requestFullScreenIntentPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static int idFromString(String id) {
    final parsed = int.tryParse(id);
    if (parsed != null) return parsed.remainder(2147483647);
    return id.hashCode & 0x7fffffff;
  }

  static Future<void> showNow({
    int id = 999001,
    String title = 'Test notification',
    String body = 'If you see this, notifications are working.',
    String? payload,
  }) async {
    await _plugin.show(id, title, body, _details, payload: payload);
  }

  static Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
    bool fullScreen = false,
  }) async {
    final now = DateTime.now();
    print('[TickDayAlarm][${now.toIso8601String()}][NotificationService] schedule start id=$id payload=$payload fullScreen=$fullScreen scheduledAt=$scheduledAt');
    if (!scheduledAt.isAfter(now)) {
      print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NotificationService] schedule rejected id=$id scheduledAt=$scheduledAt');
      return false;
    }
    print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NotificationService] schedule accepted id=$id');

    // 같은 ID로 이미 예약된 알림이 남아 있으면 기기/OS에 따라 새 예약이
    // 씹히는 경우가 있어 먼저 취소 후 다시 예약합니다.
    await _plugin.cancel(id);

    final scheduled = tz.TZDateTime.from(scheduledAt, tz.local);
    final details = fullScreen ? _detailsFullScreen : _details;

    print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NotificationService] zonedSchedule start id=$id scheduledAt=$scheduled');

    // If this is a full-screen (strong) alarm, skip Flutter's zonedSchedule
    // and let the native alarm scheduler handle the full-screen behavior.
    if (fullScreen) {
      print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NotificationService] fullScreen=true skip flutter zonedSchedule id=$id');
      // User-requested plain log for easier filtering in debug logs
      print('[NotificationService] fullScreen=true skip flutter zonedSchedule');
      return true;
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NotificationService] zonedSchedule exact success id=$id');
      return true;
    } on PlatformException catch (ex) {
      print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NotificationService] zonedSchedule exact failed id=$id exception=${ex.message}');
      // 정확한 알람 권한이 잠깐 꺼졌거나 Android가 exact alarm을 거부하는 경우
      // 앱이 완전히 실패하지 않도록 일반 예약 알림으로 한 번 더 시도합니다.
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NotificationService] zonedSchedule inexact success id=$id');
        return true;
      } catch (ex) {
        print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NotificationService] zonedSchedule inexact failed id=$id exception=${ex}');
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel(int id) async => _plugin.cancel(id);


  // ⚠️ 테스트용 풀스크린 알림 (1차 안전버전)
  // 기존 schedule(), showNow() 등은 변경 없음
  static Future<void> showFullScreenNow({
    int id = 999888,
    String title = 'Full-Screen Test',
    String body = 'This is a full-screen notification test.',
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id,
        title,
        body,
        _detailsFullScreen,
        payload: payload ?? '__fullscreen_test__',
      );
    } catch (_) {
      // 실패해도 기존 앱 기능에 영향 없음
    }
  }
}

class NativeAlarmService {
  NativeAlarmService._();
  static const MethodChannel _channel = MethodChannel('com.tickday/alarm');

  static Future<void> scheduleAlarm({
    required int alarmId,
    required DateTime scheduledAt,
    String? title,
    String? body,
    String? itemId,
    String? memo,
  }) async {
    print('[NativeAlarmService] ENTER scheduleAlarm alarmId=$alarmId');
    print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NativeAlarmService] scheduleAlarm alarmId=$alarmId itemId=$itemId memo=${memo != null ? memo.replaceAll("\n", " ") : "null"} scheduledAt=$scheduledAt');
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'alarmId': alarmId,
        'triggerAtMillis': scheduledAt.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'itemId': itemId,
        'memo': memo,
      });
      print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NativeAlarmService] scheduleAlarm method channel invoked alarmId=$alarmId');
      // Additional concise logs for requested trace
      print('[NativeAlarmService] scheduleAlarm called');
      print('[NativeAlarmService] alarm scheduled requestCode=$alarmId');
    } catch (ex) {
      print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NativeAlarmService] scheduleAlarm failed alarmId=$alarmId exception=${ex}');
      print('[NativeAlarmService] FAILED scheduleAlarm alarmId=$alarmId exception=${ex}');
    }
  }

  static Future<void> cancelAlarm(int alarmId) async {
    print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NativeAlarmService] cancelAlarm alarmId=$alarmId');
    try {
      await _channel.invokeMethod('cancelAlarm', {'alarmId': alarmId});
      print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NativeAlarmService] cancelAlarm ok alarmId=$alarmId');
    } catch (ex) {
      print('[TickDayAlarm][${DateTime.now().toIso8601String()}][NativeAlarmService] cancelAlarm failed alarmId=$alarmId exception=$ex');
    }
  }
}


// ⚠️ 풀스크린 알림용 OverlayEntry 기반 UI (1차 안전버전, 테스트 전용)
// 실제 스케줄 알림과는 아직 연결 안 함
class FullScreenNotificationOverlay {
  static OverlayEntry? _currentEntry;

  static Future<void> show({
    required String title,
    required String body,
    Duration dismissDuration = const Duration(seconds: 5),
    VoidCallback? onConfirm,
    VoidCallback? onClose,
  }) async {
    _currentEntry?.remove();
    _currentEntry = null;

    // locale 확정: notifier가 null이면 SharedPreferences에서 직접 읽음
    // (앱 시작 직후 async 초기화 전에 show()가 호출되는 경우 대비)
    Locale locale = appLocaleNotifier.value ?? const Locale('ko', 'KR');
    if (appLocaleNotifier.value == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final code = prefs.getString(_localePrefsKey);
        if (code != null) {
          locale = _localeFromCode(code) ?? locale;
        }
      } catch (_) {}
    }
    final l = L(locale);
    final badge = l.pick(ko: 'D-Day 알림', en: 'D-Day Reminder', ja: 'D-Day通知', vi: 'Nhắc D-day');
    final confirmLabel = l.pick(ko: '확인하기', en: 'Confirm', ja: '확인', vi: 'Xác nhận');
    final closeLabel = l.pick(ko: '닫기', en: 'Close', ja: '閉じる', vi: 'Đóng');

    _currentEntry = OverlayEntry(
      builder: (context) => _FullScreenNotificationWidget(
        title: title,
        body: body,
        badge: badge,
        confirmLabel: confirmLabel,
        closeLabel: closeLabel,
        onConfirm: onConfirm ?? dismiss,
        onClose: onClose ?? dismiss,
      ),
    );

    // 상위 context의 Overlay에 추가
    try {
      Overlay.of(_getGlobalContext()).insert(_currentEntry!);
      Future.delayed(dismissDuration, dismiss);
    } catch (_) {
      _currentEntry = null;
    }
  }

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void dismissWithoutPendingOpen() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static BuildContext? _lastContext;

  static void setContext(BuildContext context) {
    _lastContext = context;
  }

  static BuildContext _getGlobalContext() {
    if (_lastContext != null) return _lastContext!;
    final navContext = _navigatorKey.currentContext;
    if (navContext != null) return navContext;
    throw Exception('FullScreenNotificationOverlay context not set');
  }
}

class _FullScreenNotificationWidget extends StatefulWidget {
  final String title;
  final String body;
  final String badge;
  final String confirmLabel;
  final String closeLabel;
  final VoidCallback onConfirm;
  final VoidCallback onClose;

  const _FullScreenNotificationWidget({
    required this.title,
    required this.body,
    required this.badge,
    required this.confirmLabel,
    required this.closeLabel,
    required this.onConfirm,
    required this.onClose,
  });

  @override
  State<_FullScreenNotificationWidget> createState() => _FullScreenNotificationWidgetState();
}

class _FullScreenNotificationWidgetState extends State<_FullScreenNotificationWidget>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _bgController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    _entryController.forward();

    _bgController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _bgController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: AnimatedBuilder(
          animation: _bgController,
          builder: (context, child) {
            final t = _bgController.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Aurora gradient background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + t * 0.5, -1.0),
                      end: Alignment(1.0, 1.0 - t * 0.4),
                      colors: [
                        Color.lerp(const Color(0xFF080D1C), const Color(0xFF130820), t)!,
                        Color.lerp(const Color(0xFF0D1230), const Color(0xFF0A1530), t)!,
                        Color.lerp(const Color(0xFF060A18), const Color(0xFF0A0E1F), t)!,
                      ],
                    ),
                  ),
                ),
                // Top-left purple glow
                Positioned(
                  top: -60 + t * 25,
                  left: -60 + t * 15,
                  child: _buildGlow(220,
                    Color.lerp(const Color(0xFF7C3AED), const Color(0xFF4F46E5), t)!
                        .withOpacity(0.38 + t * 0.08)),
                ),
                // Bottom-right blue glow
                Positioned(
                  bottom: -50 + t * 18,
                  right: -50 - t * 18,
                  child: _buildGlow(200,
                    Color.lerp(const Color(0xFF0EA5E9), const Color(0xFF06B6D4), t)!
                        .withOpacity(0.30 + t * 0.10)),
                ),
                // Bottom-left teal accent
                Positioned(
                  bottom: 80 - t * 18,
                  left: 10 + t * 12,
                  child: _buildGlow(130,
                    Color.lerp(const Color(0xFF10B981), const Color(0xFF0D9488), t)!
                        .withOpacity(0.20 + t * 0.08)),
                ),
                child!,
              ],
            );
          },
          child: SafeArea(
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1C2140).withOpacity(0.90),
                                const Color(0xFF0F1525).withOpacity(0.90),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Pulsing bell icon
                              AnimatedBuilder(
                                animation: _bgController,
                                builder: (context, _) => Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      Color.lerp(const Color(0xFF7C3AED), const Color(0xFF4F46E5),
                                          _bgController.value)!.withOpacity(0.28),
                                      Colors.transparent,
                                    ]),
                                    border: Border.all(
                                      color: Color.lerp(const Color(0xFF818CF8), const Color(0xFF60A5FA),
                                          _bgController.value)!.withOpacity(0.55),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color.lerp(const Color(0xFF7C3AED), const Color(0xFF4F46E5),
                                            _bgController.value)!.withOpacity(0.35),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: Color.lerp(const Color(0xFF60A5FA), const Color(0xFFA78BFA),
                                        _bgController.value),
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Badge chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED).withOpacity(0.40),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.badge,
                                  style: const TextStyle(
                                    decoration: TextDecoration.none,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Title
                              if (widget.title.isNotEmpty) ...[
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    decoration: TextDecoration.none,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              // Body (shown only when non-empty)
                              if (widget.body.isNotEmpty)
                                Text(
                                  widget.body,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    decoration: TextDecoration.none,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withOpacity(0.68),
                                    height: 1.55,
                                  ),
                                ),
                              const SizedBox(height: 28),
                              // Buttons
                              Row(
                                children: [
                                  Expanded(child: _buildConfirmButton(context)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildCloseButton(context)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return GestureDetector(
      onTap: widget.onConfirm,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(
              decoration: TextDecoration.none,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
          color: Colors.white.withOpacity(0.07),
        ),
        child: Center(
          child: Text(
            widget.closeLabel,
            style: const TextStyle(
              decoration: TextDecoration.none,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}


String _overlayText(BuildContext context, String key) {
  final locale = appLocaleNotifier.value ?? Localizations.localeOf(context);
  final l = L(locale);
  switch (key) {
    case 'badge': return l.pick(ko:'D-Day 알림', en:'D-Day Reminder', ja:'D-Day通知', vi:'Nhắc D-day');
    case 'title': return l.pick(ko:'알림 미리보기', en:'Notification Preview', ja:'通知プレビュー', vi:'Xem trước thông báo');
    case 'body': return l.pick(ko:'오늘의 중요한 일정을 놓치지 마세요', en:"Don't miss today's important schedule", ja:'今日の大切な予定を見逃さないでください', vi:'Đừng bỏ lỡ lịch trình quan trọng hôm nay');
    case 'confirm': return l.pick(ko:'확인하기', en:'Confirm', ja:'確認', vi:'Xác nhận');
    case 'close': return l.pick(ko:'닫기', en:'Close', ja:'閉じる', vi:'Đóng');
    default: return '';
  }
}

class WidgetDeepLinkService {
  WidgetDeepLinkService._();

  static const MethodChannel _channel = MethodChannel('tickday/widget_deeplink');
  static void Function(String itemId)? _onItemId;

  static void init(void Function(String itemId) onItemId) {
    _onItemId = onItemId;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openWidgetItem') return;
      final itemId = call.arguments?.toString() ?? '';
      if (itemId.isEmpty) return;
      _onItemId?.call(itemId);
    });
  }

  static Future<String?> takeInitialItemId() async {
    try {
      final itemId = await _channel.invokeMethod<String>('takeInitialWidgetItemId');
      if (itemId == null || itemId.isEmpty) return null;
      return itemId;
    } catch (_) {
      return null;
    }
  }

  static Future<bool?> requestPinHomeWidget(String providerName) async {
    try {
      return await _channel.invokeMethod<bool>('requestPinHomeWidget', {'provider': providerName});
    } catch (_) {
      return false;
    }
  }

  static void dispose() {
    _onItemId = null;
    _channel.setMethodCallHandler(null);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  unawaited(MobileAds.instance.initialize());
  runApp(const DdayApp());
}

class DdayApp extends StatefulWidget {
  const DdayApp({super.key});

  @override
  State<DdayApp> createState() => _DdayAppState();
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class _DdayAppState extends State<DdayApp> {
  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    appLocaleNotifier.value = _localeFromCode(prefs.getString(_localePrefsKey));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: appLocaleNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TickDay',
          navigatorKey: _navigatorKey,
          locale: locale,
          supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US'), Locale('ja', 'JP'), Locale('vi', 'VN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Roboto',
            scaffoldBackgroundColor: const Color(0xFFF4F6FA),
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF111827)),
            textTheme: ThemeData.light().textTheme.apply(
                  bodyColor: const Color(0xFF111827),
                  displayColor: const Color(0xFF111827),
                ),
          ),
          home: const SplashGate(),
        );
      },
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool? _showSplash;
  bool _isFirstLaunch = false;

  @override
  void initState() {
    super.initState();
    _checkSplash();
  }

  Future<void> _checkSplash() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenSplash = prefs.getBool(_splashSeenPrefsKey) ?? false;

    if (!hasSeenSplash) {
      await prefs.setBool(_splashSeenPrefsKey, true);
    }

    if (!mounted) return;
    setState(() {
      _isFirstLaunch = !hasSeenSplash;
      _showSplash = true;
    });
  }

  Future<void> _finishSplash() async {
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash == null) {
      return const Scaffold(backgroundColor: Color(0xFFF4F6FA));
    }
    if (_showSplash == true) {
      return TickDaySplashScreen(
        isFirstLaunch: _isFirstLaunch,
        onDone: _finishSplash,
      );
    }
    return const HomePage();
  }
}

class TickDaySplashScreen extends StatefulWidget {
  final bool isFirstLaunch;
  final Future<void> Function() onDone;

  const TickDaySplashScreen({
    super.key,
    required this.isFirstLaunch,
    required this.onDone,
  });

  @override
  State<TickDaySplashScreen> createState() => _TickDaySplashScreenState();
}

class _TickDaySplashScreenState extends State<TickDaySplashScreen> with SingleTickerProviderStateMixin {
  int _index = 0;
  Timer? _timer;
  late final AnimationController _iconController;

  List<String> _messages(BuildContext context) {
    final l = L.of(context);

    if (!widget.isFirstLaunch) {
      return [
        l.pick(
          ko: '오늘의 일정을 불러오는 중이에요',
          en: 'Loading your days',
          ja: '今日の予定を読み込んでいます',
          vi: 'Đang tải lịch của bạn',
        ),
      ];
    }

    return [
      l.pick(
        ko: '멋진 기기를 사용 중이시네요 😊',
        en: 'Nice device you’ve got 😊',
        ja: '素敵な端末をお使いですね 😊',
        vi: 'Bạn đang dùng một thiết bị thật đẹp 😊',
      ),
      l.pick(
        ko: 'TickDay 환경을 준비하고 있어요',
        en: 'Setting up your TickDay experience',
        ja: 'TickDay の環境を準備しています',
        vi: 'Đang chuẩn bị trải nghiệm TickDay',
      ),
      l.pick(
        ko: '위젯과 알림을 설정 중이에요',
        en: 'Preparing widgets and reminders',
        ja: 'ウィジェットと通知を設定しています',
        vi: 'Đang chuẩn bị widget và lời nhắc',
      ),
      l.pick(
        ko: '거의 다 되었어요 ✨',
        en: 'Almost ready ✨',
        ja: 'もうすぐ完了です ✨',
        vi: 'Sắp xong rồi ✨',
      ),
    ];
  }

  IconData _splashIcon(int index) {
    if (!widget.isFirstLaunch) return Icons.event_available_rounded;

    switch (index) {
      case 0:
        return Icons.lightbulb_outline_rounded;
      case 1:
        return Icons.auto_awesome_rounded;
      case 2:
        return Icons.notifications_active_outlined;
      case 3:
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.event_available_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isFirstLaunch ? 1100 : 450),
    )..repeat(reverse: true);

    final messagesCount = widget.isFirstLaunch ? 4 : 1;
    if (messagesCount <= 1) {
      _timer = Timer(Duration(milliseconds: widget.isFirstLaunch ? 1200 : 650), () {
        if (!mounted) return;
        widget.onDone();
      });
      return;
    }

    _timer = Timer.periodic(Duration(milliseconds: widget.isFirstLaunch ? 900 : 350), (timer) {
      if (!mounted) return;
      if (_index < messagesCount - 1) {
        setState(() => _index++);
      } else {
        timer.cancel();
        Future<void>.delayed(Duration(milliseconds: widget.isFirstLaunch ? 700 : 150), widget.onDone);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages(context);
    final iconSize = widget.isFirstLaunch ? 58.0 : 42.0;
    final boxSize = widget.isFirstLaunch ? 118.0 : 88.0;
    final titleSize = widget.isFirstLaunch ? 34.0 : 30.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3F4F6), Color(0xFFF4F6FA), Color(0xFFE5E7EB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: boxSize,
                    height: boxSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(widget.isFirstLaunch ? 34 : 28),
                      boxShadow: [BoxShadow(color: const Color(0xFF111827).withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 14))],
                    ),
                    child: AnimatedBuilder(
                      animation: _iconController,
                      builder: (context, child) {
                        final value = _iconController.value;
                        final scale = 0.94 + (value * 0.10);
                        final angle = widget.isFirstLaunch ? (value - 0.5) * 0.10 : 0.0;
                        return Transform.rotate(
                          angle: angle,
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: Icon(_splashIcon(_index), key: ValueKey<int>(_index), size: iconSize, color: const Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('TickDay', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800, color: const Color(0xFF111827), letterSpacing: -0.8)),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero).animate(animation), child: child),
                    ),
                    child: Text(
                      messages[_index.clamp(0, messages.length - 1)],
                      key: ValueKey<int>(_index),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: widget.isFirstLaunch ? 28 : 22,
                    height: widget.isFirstLaunch ? 28 : 22,
                    child: CircularProgressIndicator(strokeWidth: widget.isFirstLaunch ? 3 : 2.6, color: const Color(0xFF111827)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WidgetPreviewData {
  final String dday;
  final String title;
  final String remain;
  final String emotion;
  final double progress;
  final int colorValue;

  const WidgetPreviewData({
    required this.dday,
    required this.title,
    required this.remain,
    required this.emotion,
    required this.progress,
    required this.colorValue,
  });
}

class WidgetPreviewPage extends StatefulWidget {
  final List<WidgetPreviewData> items;
  final VoidCallback onAddSmall;
  final VoidCallback onAddWide;

  const WidgetPreviewPage({
    super.key,
    required this.items,
    required this.onAddSmall,
    required this.onAddWide,
  });

  @override
  State<WidgetPreviewPage> createState() => _WidgetPreviewPageState();
}

class _WidgetPreviewPageState extends State<WidgetPreviewPage> {
  final PageController _controller = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = _page == 0 ? 1 : 0;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _pageDot(int index) {
    final selected = _page == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: selected ? 18 : 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF111827) : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final items = widget.items.isEmpty
        ? [
            WidgetPreviewData(
              dday: 'D-7',
              title: l.pick(ko: '소중한 일정', en: 'Important day', ja: '大切な予定', vi: 'Ngày quan trọng'),
              remain: l.pick(ko: '7일 남음', en: '7 days left', ja: 'あと7日', vi: 'Còn 7 ngày'),
              emotion: l.pick(ko: '조금씩 가까워지고 있어요 🙂', en: 'Getting closer every day 🙂', ja: '少しずつ近づいています 🙂', vi: 'Mỗi ngày lại gần hơn 🙂'),
              progress: 0.62,
              colorValue: const Color(0xFF111827).value,
            ),
            WidgetPreviewData(
              dday: 'D-28',
              title: l.pick(ko: '여행 준비', en: 'Trip plan', ja: '旅行の準備', vi: 'Kế hoạch du lịch'),
              remain: l.pick(ko: '28일 남음', en: '28 days left', ja: 'あと28日', vi: 'Còn 28 ngày'),
              emotion: l.pick(ko: '천천히 준비해요 🌿', en: 'Prepare at your own pace 🌿', ja: 'ゆっくり準備しましょう 🌿', vi: 'Cứ từ từ chuẩn bị 🌿'),
              progress: 0.35,
              colorValue: const Color(0xFF111827).value,
            ),
          ]
        : widget.items;

    Widget infoBox({double horizontalMargin = 18}) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.info_outline_rounded, color: Color(0xFF111827), size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.pick(
                  ko: '추가 버튼을 누르면 Android 시스템 위젯 추가 화면이 열립니다. 이 화면의 언어는 휴대폰 시스템 언어를 따를 수 있어요.',
                  en: 'Tapping Add opens the Android system widget screen. That screen may follow your phone language.',
                  ja: '追加を押すとAndroidのウィジェット追加画面が開きます。この画面は端末の言語に従う場合があります。',
                  vi: 'Nhấn Thêm sẽ mở màn hình thêm widget của Android. Màn hình đó có thể dùng ngôn ngữ hệ thống của điện thoại.',
                ),
                softWrap: true,
                style: const TextStyle(fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
              ),
            ),
          ],
        ),
      );
    }

    Widget actionButtons({double horizontalPadding = 18}) {
      return Padding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onAddSmall();
                },
                icon: const Icon(Icons.crop_square_rounded),
                label: Text(l.pick(ko: '작은 위젯 추가', en: 'Add small widget', ja: '小さいウィジェットを追加', vi: 'Thêm widget nhỏ'), style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onAddWide();
                },
                icon: const Icon(Icons.view_agenda_outlined),
                label: Text(l.pick(ko: '넓은 위젯 추가', en: 'Add wide widget', ja: '横長ウィジェットを追加', vi: 'Thêm widget rộng'), style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget header({bool compact = false}) {
      return Padding(
        padding: EdgeInsets.fromLTRB(18, compact ? 6 : 12, 18, compact ? 4 : 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(backgroundColor: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.pick(ko: '홈 화면에서 바로 확인하세요', en: 'Check it from your home screen', ja: 'ホーム画面ですぐ確認', vi: 'Xem ngay trên màn hình chính'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 18 : 21, fontWeight: FontWeight.w900, color: const Color(0xFF111827), letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.pick(ko: '가장 가까운 D-day를 위젯으로 보여드려요', en: 'Your nearest D-day appears as a widget', ja: '一番近いD-dayをウィジェットで表示', vi: 'D-day gần nhất sẽ hiển thị bằng widget'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget previewPager({bool compact = false}) {
      return PageView(
        controller: _controller,
        onPageChanged: (value) => setState(() => _page = value),
        children: [
          _PreviewStage(
            compact: compact,
            title: l.smallWidget,
            subtitle: l.pick(ko: '가장 가까운 일정 1개를 크게 표시', en: 'Shows one nearest event clearly', ja: '一番近い予定を大きく表示', vi: 'Hiển thị rõ 1 sự kiện gần nhất'),
            child: _SmallWidgetPreview(item: items.first, compact: compact),
          ),
          _PreviewStage(
            compact: compact,
            title: l.wideWidget,
            subtitle: l.pick(ko: '가까운 일정 2개를 한 번에 표시', en: 'Shows two upcoming events at once', ja: '近い予定を2件まとめて表示', vi: 'Hiển thị 2 sự kiện sắp tới'),
            child: _WideWidgetPreview(items: items.length >= 2 ? items.take(2).toList() : [items.first, items.first], compact: compact),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactLandscape = constraints.maxWidth > constraints.maxHeight && constraints.maxHeight < 520;

            if (isCompactLandscape) {
              return Column(
                children: [
                  header(compact: true),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              Expanded(child: previewPager(compact: true)),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [_pageDot(0), _pageDot(1)]),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: math.min(360, constraints.maxWidth * 0.48),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(right: 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                infoBox(horizontalMargin: 0),
                                const SizedBox(height: 12),
                                actionButtons(horizontalPadding: 0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final previewHeight = constraints.maxHeight < 720 ? 405.0 : 445.0;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                header(),
                SizedBox(height: previewHeight, child: previewPager()),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [_pageDot(0), _pageDot(1)]),
                const SizedBox(height: 14),
                infoBox(),
                const SizedBox(height: 14),
                actionButtons(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreviewStage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool compact;

  const _PreviewStage({required this.title, required this.subtitle, required this.child, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(compact ? 12 : 22, compact ? 4 : 12, compact ? 12 : 22, compact ? 4 : 8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!compact) ...[
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.6)),
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
              const SizedBox(height: 18),
            ],
            Container(
              padding: EdgeInsets.all(compact ? 10 : 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE9EDF5),
                borderRadius: BorderRadius.circular(compact ? 24 : 34),
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallWidgetPreview extends StatelessWidget {
  final WidgetPreviewData item;
  final bool compact;
  const _SmallWidgetPreview({required this.item, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = Color(item.colorValue);
    return Container(
      width: compact ? 160 : 210,
      height: compact ? 160 : 210,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 26, offset: const Offset(0, 14))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.dday, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 27 : 34, fontWeight: FontWeight.w900, color: color, letterSpacing: -1.0)),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: item.progress, minHeight: 5, backgroundColor: const Color(0xFFE5E7EB), color: color),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(item.remain, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
          const SizedBox(height: 5),
          Text(item.emotion, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}

class _WideWidgetPreview extends StatelessWidget {
  final List<WidgetPreviewData> items;
  final bool compact;
  const _WideWidgetPreview({required this.items, this.compact = false});

  Widget _row(WidgetPreviewData item) {
    final color = Color(item.colorValue);
    return SizedBox(
      height: compact ? 66 : 78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(item.dday, style: TextStyle(fontSize: compact ? 16 : 20, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.6)),
              const SizedBox(width: 8),
              Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 11.5 : 13.5, fontWeight: FontWeight.w900, color: const Color(0xFF111827)))),
            ],
          ),
          SizedBox(height: compact ? 2 : 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: item.progress, minHeight: compact ? 3 : 4, backgroundColor: const Color(0xFFE5E7EB), color: color),
          ),
          SizedBox(height: compact ? 1 : 3),
          Text(item.remain, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 10 : 10.8, fontWeight: FontWeight.w800, color: const Color(0xFF6B7280))),
          SizedBox(height: compact ? 0 : 2),
          Text(item.emotion, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 9.4 : 10.2, fontWeight: FontWeight.w800, color: const Color(0xFF374151))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 300 : 320,
      height: compact ? 200 : 230,
      padding: EdgeInsets.fromLTRB(compact ? 14 : 18, compact ? 12 : 18, compact ? 14 : 18, compact ? 12 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 26, offset: const Offset(0, 14))],
      ),
      child: Column(
        children: [
          _row(items[0]),
          Container(height: 1, margin: EdgeInsets.symmetric(vertical: compact ? 5 : 8), color: const Color(0xFFE5E7EB)),
          _row(items[1]),
        ],
      ),
    );
  }
}


class _LegalPage extends StatelessWidget {
  final String type;
  const _LegalPage({required this.type});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final isPrivacy = type == 'privacy';
    final title = isPrivacy
        ? l.pick(ko: '개인정보 처리방침', en: 'Privacy policy', ja: 'プライバシーポリシー', vi: 'Chính sách bảo mật')
        : l.pick(ko: '이용약관', en: 'Terms of use', ja: '利用規約', vi: 'Điều khoản sử dụng');
    final body = isPrivacy
        ? l.pick(
            ko: 'TickDay는 사용자의 일정을 기기 안에 저장합니다.\n\n수집하는 정보\n- 사용자가 직접 입력한 일정 제목, 날짜, 시간, 메모, 알림 설정\n\n사용 목적\n- D-day 표시, 알림 예약, 홈 화면 위젯 표시\n\n외부 전송\n- TickDay는 일정 데이터를 외부 서버로 전송하지 않습니다.\n\n광고 및 분석\n- 현재 버전은 광고 및 외부 분석 도구를 사용하지 않습니다.',
            en: 'TickDay stores your events on your device.\n\nInformation stored\n- Event title, date, time, memo, and reminder settings entered by you\n\nPurpose\n- D-day display, reminder scheduling, and home screen widgets\n\nExternal transfer\n- TickDay does not send your event data to an external server.\n\nAds and analytics\n- This version does not use ads or external analytics tools.',
            ja: 'TickDayは予定情報を端末内に保存します。\n\n保存される情報\n- ユーザーが入力した予定名、日付、時刻、メモ、通知設定\n\n利用目的\n- D-day表示、通知予約、ホーム画面ウィジェット表示\n\n外部送信\n- TickDayは予定データを外部サーバーへ送信しません。\n\n広告と分析\n- 現在のバージョンでは広告および外部分析ツールを使用していません。',
            vi: 'TickDay lưu sự kiện của bạn trên thiết bị.\n\nThông tin được lưu\n- Tiêu đề, ngày, giờ, ghi chú và cài đặt nhắc nhở do bạn nhập\n\nMục đích\n- Hiển thị D-day, đặt nhắc nhở và widget màn hình chính\n\nGửi dữ liệu ra ngoài\n- TickDay không gửi dữ liệu sự kiện đến máy chủ bên ngoài.\n\nQuảng cáo và phân tích\n- Phiên bản hiện tại không dùng quảng cáo hoặc công cụ phân tích bên ngoài.',
          )
        : l.pick(
            ko: 'TickDay는 중요한 날을 기억하기 위한 D-day 및 알림 앱입니다.\n\n사용자는 본인의 책임 하에 일정을 등록하고 관리합니다.\n알림은 기기 상태, 권한 설정, 배터리 절약 정책에 따라 지연되거나 표시되지 않을 수 있습니다.\n앱은 지속적인 개선을 위해 업데이트될 수 있습니다.',
            en: 'TickDay is a D-day countdown and reminder app for important days.\n\nUsers register and manage events at their own responsibility.\nNotifications may be delayed or not displayed depending on device status, permissions, and battery-saving policies.\nThe app may be updated for continuous improvement.',
            ja: 'TickDayは大切な日を記憶するためのD-dayカウントダウン通知アプリです。\n\nユーザーは自己責任で予定を登録・管理します。\n通知は端末の状態、権限設定、バッテリー節約設定により遅延または表示されない場合があります。\nアプリは継続的な改善のため更新されることがあります。',
            vi: 'TickDay là ứng dụng đếm ngược D-day và nhắc nhở cho những ngày quan trọng.\n\nNgười dùng tự chịu trách nhiệm khi đăng ký và quản lý sự kiện.\nThông báo có thể bị trễ hoặc không hiển thị tùy theo trạng thái thiết bị, quyền và chế độ tiết kiệm pin.\nỨng dụng có thể được cập nhật để cải thiện liên tục.',
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Text(body, style: const TextStyle(fontSize: 15, height: 1.55, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          ),
        ),
      ),
    );
  }
}

class DdayItem {
  final String id;
  final String title;
  final DateTime targetDate;
  final TimeOfDay targetTime;
  final String repeatType; // none, yearly
  final String icon;
  final int colorValue;
  final DateTime createdAt;
  final String memo;
  final int alarmMinutesBefore; // -1=none, -2=today 9AM, 0=at time, minutes before target

  const DdayItem({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.targetTime,
    required this.repeatType,
    required this.icon,
    required this.colorValue,
    required this.createdAt,
    required this.memo,
    required this.alarmMinutesBefore,
  });

  DateTime get targetDateTime => DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        targetTime.hour,
        targetTime.minute,
      );

  DdayItem copyWith({
    String? id,
    String? title,
    DateTime? targetDate,
    TimeOfDay? targetTime,
    String? repeatType,
    String? icon,
    int? colorValue,
    DateTime? createdAt,
    String? memo,
    int? alarmMinutesBefore,
  }) {
    return DdayItem(
      id: id ?? this.id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      targetTime: targetTime ?? this.targetTime,
      repeatType: repeatType ?? this.repeatType,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      memo: memo ?? this.memo,
      alarmMinutesBefore: alarmMinutesBefore ?? this.alarmMinutesBefore,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetDate': targetDate.toIso8601String(),
        'targetHour': targetTime.hour,
        'targetMinute': targetTime.minute,
        'repeatType': repeatType,
        'icon': icon,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'memo': memo,
        'alarmMinutesBefore': alarmMinutesBefore,
      };

  factory DdayItem.fromJson(Map<String, dynamic> json) {
    return DdayItem(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled',
      targetDate: DateTime.tryParse(json['targetDate'] as String? ?? '') ?? DateTime.now(),
      targetTime: TimeOfDay(
        hour: json['targetHour'] as int? ?? 0,
        minute: json['targetMinute'] as int? ?? 0,
      ),
      repeatType: json['repeatType'] as String? ?? 'none',
      icon: json['icon'] as String? ?? 'star',
      colorValue: json['colorValue'] as int? ?? const Color(0xFF111827).value,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      memo: json['memo'] as String? ?? '',
      alarmMinutesBefore: json['alarmMinutesBefore'] as int? ?? 1440,
    );
  }
}

class _NotificationPlan {
  final DateTime target;
  final DateTime alarmAt;
  final bool fallbackToTargetTime;

  const _NotificationPlan({
    required this.target,
    required this.alarmAt,
    required this.fallbackToTargetTime,
  });
}


class _QuickEventPreset {
  final String type;
  final String icon;
  final String emoji;
  final Color color;
  final String title;
  final String subtitle;
  final String repeatType;
  final int alarmMinutesBefore;

  const _QuickEventPreset({
    required this.type,
    required this.icon,
    required this.emoji,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.repeatType,
    required this.alarmMinutesBefore,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _itemsKey = 'dday_items';
  static const _hideIntroKey = 'hide_intro_notice';
  static const _hideWidgetKey = 'hide_widget_notice';
  static const _trashItemsKey = 'dday_trash_items';
  static const _appOpenCountKey = 'tickday_app_open_count';
  static const _reviewPromptShownKey = 'tickday_review_prompt_shown';
  static const _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.forgeapps.tickday';

  final List<DdayItem> _items = [];
  final List<DdayItem> _trashItems = [];
  bool _isCardView = true;
  String _sortType = 'timeLeft'; // timeLeft, createdAt, title, icon, repeat
  bool _hideIntroNotice = false;
  bool _hideWidgetNotice = false;
  bool _notificationPermissionOk = false;
  bool _exactAlarmPermissionOk = false;
  bool _permissionCardExpanded = false;
  bool _globalReminderEnabled = true;
  bool _strongAlarmMode = false;
  bool _todaySummaryEnabled = false;
  int _todaySummaryHour = 9;
  int _todaySummaryMinute = 0;
  int _defaultAlarmMinutesBefore = 1440;
  String? _widgetPinnedItemId;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _clockTimer;
  String? _pendingNotificationItemId;
  bool _reviewPromptCheckedThisSession = false;
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onNotificationClick = _handleNotificationPayload;
    WidgetDeepLinkService.init(_handleWidgetItemId);
    final launchPayload = NotificationService.takeLaunchPayload();
    final _strippedLaunch = (launchPayload?.startsWith('__alarm__:') == true) ? launchPayload!.substring('__alarm__:'.length) : launchPayload;
    _pendingNotificationItemId = (_strippedLaunch == '__today_summary__' || _strippedLaunch == '__test__') ? null : _strippedLaunch;
    unawaited(_loadInitialWidgetItemId());
    _loadAll(rescheduleNotifications: true);
    _refreshPermissionStatus();
    _startClockTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showFirstGuideIfNeeded());
    });
    _loadBannerAd();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    if (NotificationService.onNotificationClick == _handleNotificationPayload) {
      NotificationService.onNotificationClick = null;
    }
    WidgetDeepLinkService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNow();
      _refreshPermissionStatus();
      unawaited(_rescheduleAllNotifications());
      unawaited(_scheduleTodaySummaryNotification());
      _startClockTimer();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
  }

  void _loadBannerAd() {
    final banner = BannerAd(
      adUnitId: _testBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isBannerAdReady = false;
          });
        },
      ),
    );
    banner.load();
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _refreshNow();
    });
  }

  Future<void> _showFirstGuideIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(_firstGuideSeenPrefsKey) ?? false;
    if (alreadySeen || !mounted) return;
    await prefs.setBool(_firstGuideSeenPrefsKey, true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    _showFirstGuideDialog();
  }

  void _showFirstGuideDialog() {
    final l = L.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'first-guide',
      barrierColor: Colors.black.withOpacity(0.38),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Widget guideItem(IconData icon, String title, String subtitle) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 21, color: const Color(0xFF111827)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          );
        }

        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: math.min(MediaQuery.of(dialogContext).size.width - 36, 360),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 30, offset: const Offset(0, 16))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.pick(ko: 'TickDay 빠른 안내', en: 'Quick TickDay guide', ja: 'TickDay クイックガイド', vi: 'Hướng dẫn nhanh TickDay'),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    guideItem(
                      Icons.add_rounded,
                      l.pick(ko: '+ 버튼', en: '+ button', ja: '＋ボタン', vi: 'Nút +'),
                      l.pick(ko: '새 일정을 직접 등록해요.', en: 'Add a new event manually.', ja: '新しい予定を直接追加できます。', vi: 'Thêm sự kiện mới thủ công.'),
                    ),
                    const SizedBox(height: 14),
                    guideItem(
                      Icons.bolt_rounded,
                      l.pick(ko: '번개 버튼', en: 'Lightning button', ja: '稲妻ボタン', vi: 'Nút tia chớp'),
                      l.pick(ko: '빠른 추가, 알림 확인, 위젯 추가를 한 번에 열어요.', en: 'Open quick add, notification check, and widgets.', ja: 'クイック追加、通知確認、ウィジェット追加を開けます。', vi: 'Mở thêm nhanh, kiểm tra thông báo và widget.'),
                    ),
                    const SizedBox(height: 14),
                    guideItem(
                      Icons.widgets_outlined,
                      l.pick(ko: '홈 위젯', en: 'Home widget', ja: 'ホームウィジェット', vi: 'Widget màn hình chính'),
                      l.pick(ko: '중요한 D-day를 홈 화면에서 바로 확인해요.', en: 'Check important D-days from your home screen.', ja: '大切なD-dayをホーム画面で確認できます。', vi: 'Xem D-day quan trọng ngay trên màn hình chính.'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text(l.pick(ko: '시작하기', en: 'Got it', ja: '始める', vi: 'Đã hiểu'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(l.pick(ko: '건너뛰기', en: 'Skip', ja: 'スキップ', vi: 'Bỏ qua'), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _maybeShowReviewPrompt() async {
    if (_reviewPromptCheckedThisSession || !mounted) return;
    _reviewPromptCheckedThisSession = true;

    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_reviewPromptShownKey) ?? false;
    final openCount = (prefs.getInt(_appOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_appOpenCountKey, openCount);

    if (alreadyShown) return;
    if (openCount < 3 && _items.length < 2) return;

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    await prefs.setBool(_reviewPromptShownKey, true);
    _showReviewPromptDialog();
  }

  Future<void> _openPlayStoreReviewPage() async {
    final uri = Uri.parse(_playStoreUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // 리뷰 페이지 이동 실패 시 앱 기능에는 영향을 주지 않습니다.
    }
  }

  void _showReviewPromptDialog() {
    final l = L.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'review-prompt',
      barrierColor: Colors.black.withOpacity(0.38),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: math.min(MediaQuery.of(dialogContext).size.width - 36, 360),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 30, offset: const Offset(0, 16))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.pick(
                        ko: 'TickDay가 도움이 되었나요?',
                        en: 'Is TickDay helpful?',
                        ja: 'TickDayは役に立っていますか？',
                        vi: 'TickDay có hữu ích không?',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 21, height: 1.25, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l.pick(
                        ko: '소중한 리뷰는 더 좋은 앱을 만드는 데 큰 힘이 됩니다.',
                        en: 'Your review helps us make the app better.',
                        ja: 'レビューはより良いアプリ作りの大きな力になります。',
                        vi: 'Đánh giá của bạn giúp chúng tôi cải thiện ứng dụng.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14.5, height: 1.45, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3),
                          child: Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 34),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await _openPlayStoreReviewPage();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text(
                          l.pick(ko: '리뷰 남기기', en: 'Leave a review', ja: 'レビューを書く', vi: 'Đánh giá ứng dụng'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        l.pick(ko: '나중에', en: 'Later', ja: '後で', vi: 'Để sau'),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _refreshNow() {
    if (!mounted) return;
    setState(() {
      if (_sortType == 'timeLeft') {
        _sortItems();
      }
    });
    unawaited(_updateHomeWidget());
  }

  void _handleNotificationPayload(String payload) {
    if (payload.isEmpty || payload == '__test__') return;
    // ⚠️ 풀스크린 알림 플래그 감지 (1차 안전버전, 테스트용)
    if (payload == '__fullscreen_test__' || payload == '__fullscreen_auto__') {
      FullScreenNotificationOverlay.setContext(context);
      final _l = L(appLocaleNotifier.value ?? const Locale('ko', 'KR'));
      unawaited(FullScreenNotificationOverlay.show(
        title: _l.pick(ko: '알림 미리보기', en: 'Notification Preview', ja: '通知プレビュー', vi: 'Xem trước thông báo'),
        body: '',
        dismissDuration: const Duration(seconds: 5),
        onClose: () {
          _pendingNotificationItemId = null;
          FullScreenNotificationOverlay.dismissWithoutPendingOpen();
        },
      ));
      return;
    }
    if (payload.startsWith('__alarm__:')) {
      // 실제 예약 알림 클릭 경로: 테스트용 Overlay는 절대 표시하지 않습니다.
      final itemId = payload.substring('__alarm__:'.length);
      _pendingNotificationItemId = itemId;
      _openPendingNotificationItem();
      return;
    }
    if (payload == '__today_summary__') {
      // 오늘 일정 요약 알림은 특정 카드가 아니라 앱 홈 화면으로 들어오게만 합니다.
      _pendingNotificationItemId = null;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    _pendingNotificationItemId = payload;
    _openPendingNotificationItem();
  }

  Future<void> _loadInitialWidgetItemId() async {
    final itemId = await WidgetDeepLinkService.takeInitialItemId();
    if (itemId == null || itemId.isEmpty) return;
    _handleWidgetItemId(itemId);
  }

  void _handleWidgetItemId(String itemId) {
    if (itemId.isEmpty) return;
    _pendingNotificationItemId = itemId;
    _openPendingNotificationItem();
  }

  void _openPendingNotificationItem() {
    // If the overlay close button was tapped, clear any pending notification item
    // and do not process it. This avoids navigation, snackbars, or deleted-item alerts.
    if (_pendingNotificationItemId == null) {
      return;
    }

    final id = _pendingNotificationItemId;
    if (id == null || id.isEmpty || !mounted) return;

    DdayItem? targetItem;
    for (final item in _items) {
      if (item.id == id) {
        targetItem = item;
        break;
      }
    }

    if (targetItem == null) {
      _pendingNotificationItemId = null;
      // 이미 휴지통에서 완전 삭제된 일정의 위젯/알림 딥링크가 남아 있어도
      // 휴지통 복구나 Undo가 다시 살아나지 않도록 여기서 종료합니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        _showInfoSnack(L.of(context).pick(
          ko: '이미 삭제된 일정이에요.',
          en: 'This event has already been deleted.',
          ja: 'この予定はすでに削除されています。',
          vi: 'Sự kiện này đã bị xóa.',
        ));
      });
      return;
    }

    _pendingNotificationItemId = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showDetail(targetItem!);
    });
  }

  void _toggleViewMode() {
    setState(() => _isCardView = !_isCardView);

    // 카드/목록 전환 시 현재 스크롤 위치 때문에
    // 상단 알림 설정 상태 카드가 사라진 것처럼 보이지 않도록
    // 화면을 항상 맨 위로 되돌립니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _refreshPermissionStatus() async {
    final notificationOk = await NotificationService.areNotificationsEnabled();
    final exactOk = await NotificationService.canScheduleExactAlarms();
    if (!mounted) return;
    setState(() {
      _notificationPermissionOk = notificationOk;
      _exactAlarmPermissionOk = exactOk;
    });
  }

  void _sortItems() {
    switch (_sortType) {
      case 'createdAt':
        _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'title':
        _items.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'icon':
        _items.sort((a, b) => a.icon.compareTo(b.icon));
        break;
      case 'repeat':
        _items.sort((a, b) => b.repeatType.compareTo(a.repeatType));
        break;
      case 'timeLeft':
      default:
        _items.sort((a, b) => _effectiveTarget(a).compareTo(_effectiveTarget(b)));
        break;
    }
  }

  String _sortText(String type) {
    switch (type) {
      case 'createdAt':
        return L.of(context).sortCreated;
      case 'title':
        return L.of(context).sortTitle;
      case 'icon':
        return L.of(context).sortIcon;
      case 'repeat':
        return L.of(context).sortRepeat;
      case 'timeLeft':
      default:
        return L.of(context).sortTimeLeft;
    }
  }

  void _showSortPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sortTile('timeLeft', Icons.schedule_rounded, L.of(context).sortTimeLeft),
              _sortTile('createdAt', Icons.history_rounded, L.of(context).sortCreated),
              _sortTile('title', Icons.sort_by_alpha_rounded, L.of(context).sortTitle),
              _sortTile('icon', Icons.category_rounded, L.of(context).sortIcon),
              _sortTile('repeat', Icons.repeat_rounded, L.of(context).sortRepeat),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(String value, IconData icon, String label) {
    final selected = _sortType == value;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF111827) : const Color(0xFF6B7280)),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? const Color(0xFF111827) : const Color(0xFF111827))),
      trailing: selected ? const Icon(Icons.check_rounded, color: Color(0xFF111827)) : null,
      onTap: () {
        setState(() {
          _sortType = value;
          _sortItems();
        });
        Navigator.pop(context);
      },
    );
  }

  Future<void> _loadAll({bool rescheduleNotifications = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_itemsKey) ?? [];
    final rawTrashItems = prefs.getStringList(_trashItemsKey) ?? [];
    final loaded = rawItems
        .map((e) {
          try {
            return DdayItem.fromJson(jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<DdayItem>()
        .toList();
    final loadedTrash = rawTrashItems
        .map((e) {
          try {
            return DdayItem.fromJson(jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<DdayItem>()
        .toList();

    setState(() {
      _items
        ..clear()
        ..addAll(loaded);
      _trashItems
        ..clear()
        ..addAll(loadedTrash);
      _sortItems();
      _hideIntroNotice = prefs.getBool(_hideIntroKey) ?? false;
      _hideWidgetNotice = prefs.getBool(_hideWidgetKey) ?? false;
      _globalReminderEnabled = prefs.getBool(_globalReminderEnabledKey) ?? true;
      _todaySummaryEnabled = prefs.getBool(_todaySummaryEnabledKey) ?? false;
      _todaySummaryHour = prefs.getInt(_todaySummaryHourKey) ?? 9;
      _todaySummaryMinute = prefs.getInt(_todaySummaryMinuteKey) ?? 0;
      _defaultAlarmMinutesBefore = prefs.getInt(_defaultAlarmMinutesKey) ?? 1440;
      _strongAlarmMode = prefs.getBool(_strongAlarmModeKey) ?? false;
      _widgetPinnedItemId = prefs.getString(_widgetPinnedItemIdKey);
    });

    _openPendingNotificationItem();
    await _updateHomeWidget();

    if (rescheduleNotifications) {
      await _rescheduleAllNotifications();
      await _scheduleTodaySummaryNotification();
    }

    unawaited(_maybeShowReviewPrompt());
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_itemsKey, _items.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> _saveTrashItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_trashItemsKey, _trashItems.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> _markWidgetItemsPermanentlyDeleted(Iterable<String> itemIds) async {
    final idsToAdd = itemIds.where((id) => id.trim().isNotEmpty).toSet();
    if (idsToAdd.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_permanentlyDeletedWidgetIdsKey) ?? <String>[];
    final merged = <String>{...existing, ...idsToAdd}.toList();

    await prefs.setStringList(_permanentlyDeletedWidgetIdsKey, merged);

    // Android 홈 위젯 Provider가 삭제된 일정 ID를 알 수 있도록 HomeWidget 저장소에도 기록합니다.
    // 기존 위젯 박스는 Android 정책상 앱이 강제로 제거할 수 없으므로,
    // 해당 위젯은 "일정을 선택하세요" 상태로 안전하게 초기화됩니다.
    await HomeWidget.saveWidgetData<String>('widget_deleted_item_ids', jsonEncode(merged));
    await HomeWidget.updateWidget(androidName: 'DdayWidgetProvider');
  }


  DdayItem? _nearestWidgetItem() {
    final items = _nearestWidgetItems(1);
    return items.isEmpty ? null : items.first;
  }

  List<DdayItem> _nearestWidgetItems(int count) {
    if (_items.isEmpty) return <DdayItem>[];

    final upcoming = List<DdayItem>.from(_items)
      ..sort((a, b) => _effectiveTarget(a).compareTo(_effectiveTarget(b)));

    return upcoming.take(count).toList();
  }

  DdayItem? _pinnedWidgetItem() {
    final pinnedId = _widgetPinnedItemId;
    if (pinnedId == null || pinnedId.isEmpty) return null;
    for (final item in _items) {
      if (item.id == pinnedId) return item;
    }
    return null;
  }

  DdayItem? _smallWidgetItem() {
    // Small widget default is always the nearest upcoming event.
    // Card-specific widget additions are stored as a per-widget pending snapshot
    // so multiple 1x1 widgets can each keep different events.
    return _nearestWidgetItem();
  }

  String _widgetRemainText(DdayItem item) {
    final l = L.of(context);
    final d = _timeLeft(item);
    if (d.isNegative) return l.pick(ko: '오늘입니다', en: 'Today', ja: '今日です', vi: 'Hôm nay');
    final days = d.inDays;
    final hours = d.inHours % 24;
    if (days <= 0) return l.pick(ko: '오늘 · ${hours}시간 남음', en: 'Today · ${hours}h left', ja: '今日 · あと${hours}時間', vi: 'Hôm nay · còn ${hours} giờ');
    if (days == 1) return l.pick(ko: '내일 · ${hours}시간 남음', en: 'Tomorrow · ${hours}h left', ja: '明日 · あと${hours}時間', vi: 'Ngày mai · còn ${hours} giờ');
    return l.pick(ko: '${days}일 남음', en: '${days}d left', ja: 'あと${days}日', vi: 'Còn ${days} ngày');
  }

  Future<void> _saveWidgetItemsSnapshot() async {
    final snapshot = _items.map((item) {
      final target = _effectiveTarget(item);
      return {
        'id': item.id,
        'title': item.title,
        'dday': _dDayText(item),
        'remain': _widgetRemainText(item),
        'color': item.colorValue,
        'targetMillis': target.millisecondsSinceEpoch,
        'repeatType': item.repeatType,
        'month': item.targetDate.month,
        'day': item.targetDate.day,
        'hour': item.targetTime.hour,
        'minute': item.targetTime.minute,
        'createdMillis': item.createdAt.millisecondsSinceEpoch,
      };
    }).toList();

    await HomeWidget.saveWidgetData<String>('widget_items_snapshot', jsonEncode(snapshot));
  }

  Future<void> _updateHomeWidget() async {
    try {
      final widgetItems = _nearestWidgetItems(2);
      final item = _smallWidgetItem();

      await _saveWidgetItemsSnapshot();

      if (item == null) {
        await HomeWidget.saveWidgetData<String>('widget_item_id', '');
        await HomeWidget.saveWidgetData<String>('widget_dday', 'D-Day');
        await HomeWidget.saveWidgetData<String>('widget_title', L.of(context).pick(ko: '일정을 등록하세요', en: 'Add an event', ja: '予定を追加してください', vi: 'Thêm sự kiện')); 
        await HomeWidget.saveWidgetData<String>('widget_remain', 'TickDay');
        await HomeWidget.saveWidgetData<int>('widget_color', const Color(0xFF111827).value);
        await HomeWidget.saveWidgetData<int>('widget_target_millis', 0);
        await HomeWidget.saveWidgetData<String>('widget_repeat_type', 'none');
        await HomeWidget.saveWidgetData<int>('widget_month', 0);
        await HomeWidget.saveWidgetData<int>('widget_day', 0);
        await HomeWidget.saveWidgetData<int>('widget_hour', 0);
        await HomeWidget.saveWidgetData<int>('widget_minute', 0);
        await HomeWidget.saveWidgetData<int>('widget_created_millis', 0);
        await HomeWidget.saveWidgetData<String>('widget_lang', Localizations.localeOf(context).languageCode);
      } else {
        final target = _effectiveTarget(item);
        await HomeWidget.saveWidgetData<String>('widget_item_id', item.id);
        await HomeWidget.saveWidgetData<String>('widget_dday', _dDayText(item));
        await HomeWidget.saveWidgetData<String>('widget_title', item.title);
        await HomeWidget.saveWidgetData<String>('widget_remain', _widgetRemainText(item));
        await HomeWidget.saveWidgetData<int>('widget_color', item.colorValue);
        await HomeWidget.saveWidgetData<int>('widget_target_millis', target.millisecondsSinceEpoch);
        await HomeWidget.saveWidgetData<String>('widget_repeat_type', item.repeatType);
        await HomeWidget.saveWidgetData<int>('widget_month', item.targetDate.month);
        await HomeWidget.saveWidgetData<int>('widget_day', item.targetDate.day);
        await HomeWidget.saveWidgetData<int>('widget_hour', item.targetTime.hour);
        await HomeWidget.saveWidgetData<int>('widget_minute', item.targetTime.minute);
        await HomeWidget.saveWidgetData<int>('widget_created_millis', item.createdAt.millisecondsSinceEpoch);
        await HomeWidget.saveWidgetData<String>('widget_lang', Localizations.localeOf(context).languageCode);
      }

      await _saveWideWidgetItem(1, widgetItems.isNotEmpty ? widgetItems[0] : null);
      await _saveWideWidgetItem(2, widgetItems.length > 1 ? widgetItems[1] : null);

      await HomeWidget.updateWidget(androidName: 'DdayWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'DdayWidgetProviderWide');
    } catch (_) {
      // 홈 위젯이 아직 추가되지 않았거나 네이티브 위젯 초기화 전이어도 앱 기능은 그대로 유지합니다.
    }
  }

  Future<void> _saveWideWidgetItem(int index, DdayItem? item) async {
    final prefix = 'widget_wide_${index}_';
    if (item == null) {
      await HomeWidget.saveWidgetData<String>('${prefix}item_id', '');
      await HomeWidget.saveWidgetData<String>('${prefix}dday', '');
      await HomeWidget.saveWidgetData<String>('${prefix}title', index == 1 ? L.of(context).pick(ko: '일정을 등록하세요', en: 'Add an event', ja: '予定を追加してください', vi: 'Thêm sự kiện') : '');
      await HomeWidget.saveWidgetData<String>('${prefix}remain', index == 1 ? 'TickDay' : '');
      await HomeWidget.saveWidgetData<int>('${prefix}color', const Color(0xFF111827).value);
      await HomeWidget.saveWidgetData<int>('${prefix}target_millis', 0);
      await HomeWidget.saveWidgetData<String>('${prefix}repeat_type', 'none');
      await HomeWidget.saveWidgetData<int>('${prefix}month', 0);
      await HomeWidget.saveWidgetData<int>('${prefix}day', 0);
      await HomeWidget.saveWidgetData<int>('${prefix}hour', 0);
      await HomeWidget.saveWidgetData<int>('${prefix}minute', 0);
      await HomeWidget.saveWidgetData<int>('${prefix}created_millis', 0);
      await HomeWidget.saveWidgetData<String>('${prefix}lang', Localizations.localeOf(context).languageCode);
      return;
    }

    final target = _effectiveTarget(item);
    await HomeWidget.saveWidgetData<String>('${prefix}item_id', item.id);
    await HomeWidget.saveWidgetData<String>('${prefix}dday', _dDayText(item));
    await HomeWidget.saveWidgetData<String>('${prefix}title', item.title);
    await HomeWidget.saveWidgetData<String>('${prefix}remain', _widgetRemainText(item));
    await HomeWidget.saveWidgetData<int>('${prefix}color', item.colorValue);
    await HomeWidget.saveWidgetData<int>('${prefix}target_millis', target.millisecondsSinceEpoch);
    await HomeWidget.saveWidgetData<String>('${prefix}repeat_type', item.repeatType);
    await HomeWidget.saveWidgetData<int>('${prefix}month', item.targetDate.month);
    await HomeWidget.saveWidgetData<int>('${prefix}day', item.targetDate.day);
    await HomeWidget.saveWidgetData<int>('${prefix}hour', item.targetTime.hour);
    await HomeWidget.saveWidgetData<int>('${prefix}minute', item.targetTime.minute);
    await HomeWidget.saveWidgetData<int>('${prefix}created_millis', item.createdAt.millisecondsSinceEpoch);
    await HomeWidget.saveWidgetData<String>('${prefix}lang', Localizations.localeOf(context).languageCode);
  }

  Future<void> _savePendingSmallWidgetItem(DdayItem? item) async {
    if (item == null) {
      await HomeWidget.saveWidgetData<String>('widget_pending_item_id', '');
      await HomeWidget.saveWidgetData<String>('widget_pending_dday', 'D-Day');
      await HomeWidget.saveWidgetData<String>('widget_pending_title', L.of(context).pick(ko: '일정을 등록하세요', en: 'Add an event', ja: '予定を追加してください', vi: 'Thêm sự kiện'));
      await HomeWidget.saveWidgetData<String>('widget_pending_remain', 'TickDay');
      await HomeWidget.saveWidgetData<int>('widget_pending_color', const Color(0xFF111827).value);
      await HomeWidget.saveWidgetData<int>('widget_pending_target_millis', 0);
      await HomeWidget.saveWidgetData<String>('widget_pending_repeat_type', 'none');
      await HomeWidget.saveWidgetData<int>('widget_pending_month', 0);
      await HomeWidget.saveWidgetData<int>('widget_pending_day', 0);
      await HomeWidget.saveWidgetData<int>('widget_pending_hour', 0);
      await HomeWidget.saveWidgetData<int>('widget_pending_minute', 0);
      await HomeWidget.saveWidgetData<int>('widget_pending_created_millis', 0);
      await HomeWidget.saveWidgetData<String>('widget_pending_lang', Localizations.localeOf(context).languageCode);
      return;
    }

    final target = _effectiveTarget(item);
    await HomeWidget.saveWidgetData<String>('widget_pending_item_id', item.id);
    await HomeWidget.saveWidgetData<String>('widget_pending_dday', _dDayText(item));
    await HomeWidget.saveWidgetData<String>('widget_pending_title', item.title);
    await HomeWidget.saveWidgetData<String>('widget_pending_remain', _widgetRemainText(item));
    await HomeWidget.saveWidgetData<int>('widget_pending_color', item.colorValue);
    await HomeWidget.saveWidgetData<int>('widget_pending_target_millis', target.millisecondsSinceEpoch);
    await HomeWidget.saveWidgetData<String>('widget_pending_repeat_type', item.repeatType);
    await HomeWidget.saveWidgetData<int>('widget_pending_month', item.targetDate.month);
    await HomeWidget.saveWidgetData<int>('widget_pending_day', item.targetDate.day);
    await HomeWidget.saveWidgetData<int>('widget_pending_hour', item.targetTime.hour);
    await HomeWidget.saveWidgetData<int>('widget_pending_minute', item.targetTime.minute);
    await HomeWidget.saveWidgetData<int>('widget_pending_created_millis', item.createdAt.millisecondsSinceEpoch);
    await HomeWidget.saveWidgetData<String>('widget_pending_lang', Localizations.localeOf(context).languageCode);
  }

  Future<void> _setNoticeHidden(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == _hideIntroKey) _hideIntroNotice = value;
      if (key == _hideWidgetKey) _hideWidgetNotice = value;
    });
  }

  Future<void> _upsertItem(DdayItem item) async {
    final index = _items.indexWhere((e) => e.id == item.id);
    setState(() {
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.add(item);
      }
      _sortItems();
    });

    await _saveItems();
    await _updateHomeWidget();

    // 중요: 실제 일정 저장 직후에는 알림 예약을 반드시 완료한 뒤 다음 단계로 넘어갑니다.
    // 이전처럼 unawaited()로 백그라운드 분리하면 일부 기기/상황에서 사용자가 홈으로 나가거나
    // 앱 생명주기가 바뀌는 순간 예약이 누락될 수 있습니다.
    final scheduledOk = await _scheduleNotifications(item);
    unawaited(_scheduleTodaySummaryNotification());
    unawaited(_maybeShowReviewPrompt());

    if (mounted && item.alarmMinutesBefore != -1 && !scheduledOk) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L.of(context).pick(
              ko: '알림 시간이 이미 지났거나 권한 문제로 예약하지 못했어요.',
              en: 'The reminder time has passed or permission is blocking scheduling.',
              ja: '通知時刻が過ぎたか、権限の問題で予約できませんでした。',
              vi: 'Giờ nhắc đã qua hoặc quyền đang chặn việc đặt nhắc nhở.',
            ),
          ),
        ),
      );
    }
  }

  DateTime _alarmTimeForTarget(DdayItem item, DateTime target) {
    if (item.alarmMinutesBefore == -2) {
      return DateTime(target.year, target.month, target.day, 9, 0);
    }
    return target.subtract(Duration(minutes: item.alarmMinutesBefore));
  }

  _NotificationPlan? _nextNotificationPlan(DdayItem item) {
    if (item.alarmMinutesBefore == -1) return null;

    final now = DateTime.now();

    if (item.repeatType == 'yearly') {
      for (var i = 0; i < 8; i++) {
        final year = now.year + i;
        final target = DateTime(
          year,
          item.targetDate.month,
          item.targetDate.day,
          item.targetTime.hour,
          item.targetTime.minute,
        );
        final alarmAt = _alarmTimeForTarget(item, target);

        if (alarmAt.isAfter(now)) {
          return _NotificationPlan(
            target: target,
            alarmAt: alarmAt,
            fallbackToTargetTime: false,
          );
        }

        // 알림 시점은 이미 지났지만 실제 D-day 시간이 아직 남아 있으면
        // 조용히 버리지 않고 D-day 정각 알림으로 보정합니다.
        if (target.isAfter(now.add(const Duration(seconds: 5)))) {
          return _NotificationPlan(
            target: target,
            alarmAt: target,
            fallbackToTargetTime: true,
          );
        }
      }
      return null;
    }

    final target = item.targetDateTime;
    if (!target.isAfter(now)) return null;

    final alarmAt = _alarmTimeForTarget(item, target);
    if (alarmAt.isAfter(now)) {
      return _NotificationPlan(
        target: target,
        alarmAt: alarmAt,
        fallbackToTargetTime: false,
      );
    }

    // 예: 오늘 10분 뒤 일정인데 기본값이 '하루 전'이면 원래 알림 시점은 과거입니다.
    // 이 경우 예약 자체를 버리지 않고 D-day 정각에라도 울리게 합니다.
    if (target.isAfter(now.add(const Duration(seconds: 5)))) {
      return _NotificationPlan(
        target: target,
        alarmAt: target,
        fallbackToTargetTime: true,
      );
    }

    return null;
  }

  Future<void> _rescheduleAllNotifications() async {
    if (!_globalReminderEnabled) {
      for (final item in List<DdayItem>.from(_items)) {
        await NotificationService.cancel(NotificationService.idFromString(item.id));
      }
      for (var i = 0; i < _todaySummaryScheduleDays; i++) {
        await NotificationService.cancel(_todaySummaryNotificationId + i);
      }
      return;
    }
    for (final item in List<DdayItem>.from(_items)) {
      await _scheduleNotifications(item);
    }
  }

  Future<void> _scheduleTodaySummaryNotification() async {
    for (var i = 0; i < _todaySummaryScheduleDays; i++) {
      await NotificationService.cancel(_todaySummaryNotificationId + i);
    }
    if (!_globalReminderEnabled || !_todaySummaryEnabled) return;

    final now = DateTime.now();
    var firstScheduledAt = DateTime(now.year, now.month, now.day, _todaySummaryHour, _todaySummaryMinute);
    if (!firstScheduledAt.isAfter(now.add(const Duration(seconds: 5)))) {
      firstScheduledAt = firstScheduledAt.add(const Duration(days: 1));
    }

    for (var i = 0; i < _todaySummaryScheduleDays; i++) {
      final scheduledAt = firstScheduledAt.add(Duration(days: i));
      final targetDay = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
      final todayItems = _items.where((item) {
        final target = _effectiveTargetForDay(item, targetDay);
        return target.year == targetDay.year && target.month == targetDay.month && target.day == targetDay.day;
      }).toList()
        ..sort((a, b) => _effectiveTargetForDay(a, targetDay).compareTo(_effectiveTargetForDay(b, targetDay)));

      final title = L.of(context).pick(ko: '오늘 일정 확인', en: 'Today\'s events', ja: '今日の予定', vi: 'Sự kiện hôm nay');
      final body = todayItems.isEmpty
          ? L.of(context).pick(ko: '오늘도 소중한 하루를 준비해요.', en: 'Plan your day with TickDay.', ja: '今日も大切な一日を準備しましょう。', vi: 'Hãy chuẩn bị một ngày thật ý nghĩa.')
          : _todaySummaryBody(todayItems, targetDay);

      await NotificationService.schedule(
        id: _todaySummaryNotificationId + i,
        title: title,
        body: body,
        scheduledAt: scheduledAt,
        payload: '__today_summary__',
      );
    }
  }

  DateTime _effectiveTargetForDay(DdayItem item, DateTime day) {
    if (item.repeatType == 'yearly') {
      return DateTime(day.year, item.targetDate.month, item.targetDate.day, item.targetTime.hour, item.targetTime.minute);
    }
    return item.targetDateTime;
  }

  String _todaySummaryBody(List<DdayItem> items, DateTime day) {
    final names = items.take(3).map((item) => item.title.trim().isEmpty ? L.of(context).titleNone : item.title.trim()).join(', ');
    if (items.length <= 3) {
      return L.of(context).pick(
        ko: '오늘 일정 ${items.length}개: $names',
        en: '${items.length} event(s) today: $names',
        ja: '今日は${items.length}件: $names',
        vi: 'Hôm nay có ${items.length} sự kiện: $names',
      );
    }
    final more = items.length - 3;
    return L.of(context).pick(
      ko: '오늘 일정 ${items.length}개: $names 외 $more개',
      en: '${items.length} events today: $names and $more more',
      ja: '今日は${items.length}件: $names 他$more件',
      vi: 'Hôm nay có ${items.length} sự kiện: $names và $more mục nữa',
    );
  }

  Future<bool> _scheduleNotifications(DdayItem item) async {
    final notificationId = NotificationService.idFromString(item.id);
    if (!_globalReminderEnabled) {
      await NotificationService.cancel(notificationId);
      return false;
    }
    await NotificationService.cancel(notificationId);

    final plan = _nextNotificationPlan(item);
    if (plan == null) return false;

    final bodyPrefix = plan.fallbackToTargetTime ? L.of(context).pick(ko: '알림 시간이 지나 D-day 정각으로 보정됨', en: 'Reminder time passed, adjusted to event time', ja: '通知時刻が過ぎたため予定時刻に調整しました', vi: 'Giờ nhắc đã qua, chuyển sang giờ sự kiện') : _alarmText(item.alarmMinutesBefore);

    final nTitle = L.of(context).pick(ko: 'D-day 알림: ${item.title}', en: 'D-day reminder: ${item.title}', ja: 'D-day通知: ${item.title}', vi: 'Nhắc D-day: ${item.title}');
    final nBody = '$bodyPrefix · ${_fullDate(plan.target)} ${_timeText(TimeOfDay.fromDateTime(plan.target))}';
    final scheduled = await NotificationService.schedule(
      id: notificationId,
      title: nTitle,
      body: nBody,
      scheduledAt: plan.alarmAt,
      payload: '__alarm__:${item.id}',
      fullScreen: false,
    );
    if (scheduled) {
      // FOR TESTING: temporarily await native scheduling so logs are visible
      await NativeAlarmService.scheduleAlarm(
        alarmId: notificationId,
        scheduledAt: plan.alarmAt,
        title: nTitle,
        body: nBody,
        itemId: item.id,
        memo: item.memo,
      );
    }
    return scheduled;
  }

  Future<void> _deleteItem(DdayItem item) async {
    // Release 빌드에서 알림 취소가 먼저 실행되면 기기/권한 상태에 따라 삭제 UI가
    // 늦거나 멈춘 것처럼 보일 수 있습니다. 먼저 화면과 저장소에서 제거하고,
    // 알림 취소는 뒤에서 시도합니다.
    setState(() {
      _items.removeWhere((e) => e.id == item.id);
      _trashItems.removeWhere((e) => e.id == item.id);
      _trashItems.insert(0, item);
      if (_widgetPinnedItemId == item.id) {
        _widgetPinnedItemId = _items.isEmpty ? null : _items.first.id;
      }
      _sortItems();
    });

    final prefs = await SharedPreferences.getInstance();
    if (_widgetPinnedItemId == null || _widgetPinnedItemId!.isEmpty) {
      await prefs.remove(_widgetPinnedItemIdKey);
    } else {
      await prefs.setString(_widgetPinnedItemIdKey, _widgetPinnedItemId!);
    }

    await _saveItems();
    await _saveTrashItems();
    await _updateHomeWidget();

    unawaited(NotificationService.cancel(NotificationService.idFromString(item.id)));
    unawaited(NativeAlarmService.cancelAlarm(NotificationService.idFromString(item.id)));
    unawaited(_scheduleTodaySummaryNotification());

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L.of(context).pick(ko: '휴지통으로 이동했어요.', en: 'Moved to trash.', ja: 'ゴミ箱に移動しました。', vi: 'Đã chuyển vào thùng rác.')),
        action: SnackBarAction(
          label: L.of(context).pick(ko: '되돌리기', en: 'Undo', ja: '元に戻す', vi: 'Hoàn tác'),
          onPressed: () => unawaited(_restoreTrashItem(item)),
        ),
      ),
    );
  }

  Future<void> _restoreTrashItem(DdayItem item) async {
    final canRestore = _trashItems.any((e) => e.id == item.id);
    if (!canRestore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _showInfoSnack(L.of(context).pick(
        ko: '이미 완전히 삭제된 일정이에요.',
        en: 'This event was permanently deleted.',
        ja: 'この予定は完全に削除されています。',
        vi: 'Sự kiện này đã bị xóa vĩnh viễn.',
      ));
      return;
    }

    setState(() {
      _trashItems.removeWhere((e) => e.id == item.id);
      if (!_items.any((e) => e.id == item.id)) {
        _items.add(item);
      }
      _sortItems();
    });

    await _saveItems();
    await _saveTrashItems();
    await _scheduleNotifications(item);
    await _scheduleTodaySummaryNotification();
    await _updateHomeWidget();

    if (!mounted) return;
    _showInfoSnack(L.of(context).pick(ko: '일정을 복구했어요.', en: 'Event restored.', ja: '予定を復元しました。', vi: 'Đã khôi phục sự kiện.'));
  }

  Future<void> _permanentlyDeleteTrashItem(DdayItem item) async {
    setState(() {
      _trashItems.removeWhere((e) => e.id == item.id);
    });
    await _saveTrashItems();
    await _markWidgetItemsPermanentlyDeleted([item.id]);
    unawaited(NotificationService.cancel(NotificationService.idFromString(item.id)));
    unawaited(_scheduleTodaySummaryNotification());
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    _showInfoSnack(L.of(context).pick(ko: '완전히 삭제했어요.', en: 'Permanently deleted.', ja: '完全に削除しました。', vi: 'Đã xóa vĩnh viễn.'));
  }

  Future<void> _emptyTrash() async {
    if (_trashItems.isEmpty) return;
    final deletedItems = List<DdayItem>.from(_trashItems);
    setState(() => _trashItems.clear());
    await _saveTrashItems();
    await _markWidgetItemsPermanentlyDeleted(deletedItems.map((e) => e.id));
    for (final item in deletedItems) {
      unawaited(NotificationService.cancel(NotificationService.idFromString(item.id)));
    }
    unawaited(_scheduleTodaySummaryNotification());
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    _showInfoSnack(L.of(context).pick(ko: '휴지통을 비웠어요.', en: 'Trash emptied.', ja: 'ゴミ箱を空にしました。', vi: 'Đã dọn thùng rác.'));
  }

  Future<void> _openTrashPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrashPage(
          items: List<DdayItem>.from(_trashItems),
          onRestore: _restoreTrashItem,
          onDeleteForever: _permanentlyDeleteTrashItem,
          onEmpty: _emptyTrash,
        ),
      ),
    );
  }

  DateTime _effectiveTarget(DdayItem item) {
    final now = DateTime.now();
    var target = item.targetDateTime;
    if (item.repeatType == 'yearly') {
      target = DateTime(now.year, item.targetDate.month, item.targetDate.day, item.targetTime.hour, item.targetTime.minute);
      if (!target.isAfter(now)) {
        target = DateTime(now.year + 1, item.targetDate.month, item.targetDate.day, item.targetTime.hour, item.targetTime.minute);
      }
    }
    return target;
  }

  int _daysLeft(DdayItem item) {
    final now = DateTime.now();
    final target = _effectiveTarget(item);
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    return targetDay.difference(today).inDays;
  }

  Duration _timeLeft(DdayItem item) => _effectiveTarget(item).difference(DateTime.now());

  double _progress(DdayItem item) {
    // 실제 진행률입니다.
    // 등록일시(createdAt)부터 목표일시까지의 전체 시간 중,
    // 현재 얼마나 지났는지를 정확한 퍼센트로 표시합니다.
    final now = DateTime.now();
    final target = _effectiveTarget(item);
    final total = target.difference(item.createdAt).inSeconds;
    final elapsed = now.difference(item.createdAt).inSeconds;

    if (total <= 0) return 1.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }


  Color _urgencyColor(DdayItem item) {
    final days = _daysLeft(item);
    if (days <= 0) return const Color(0xFF111827);
    if (days <= 3) return const Color(0xFFEF4444);
    if (days <= 7) return const Color(0xFFF97316);
    return Color(item.colorValue);
  }

  String _shortDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.month)}.${two(date.day)}';
  }

  String _fullDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)}';
  }

  String _timeText(TimeOfDay time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }

  String _remainText(DdayItem item) {
    final l = L.of(context);
    final d = _timeLeft(item);
    if (d.isNegative) return l.pick(ko: '오늘입니다', en: 'Today', ja: '今日です', vi: 'Hôm nay');
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    return l.pick(ko: '${days}일 ${hours}시간 ${minutes}분 남음', en: '${days}d ${hours}h ${minutes}m left', ja: 'あと${days}日${hours}時間${minutes}分', vi: 'Còn ${days} ngày ${hours} giờ ${minutes} phút');
  }

  String _eventMoodLabel(DdayItem item) {
    final title = item.title.toLowerCase();
    switch (item.icon) {
      case 'cake':
        return L.of(context).pick(ko: '생일까지', en: 'Birthday in', ja: '誕生日まで', vi: 'Đến sinh nhật');
      case 'heart':
        return L.of(context).pick(ko: '기념일까지', en: 'Anniversary in', ja: '記念日まで', vi: 'Đến kỷ niệm');
      case 'flight':
        return L.of(context).pick(ko: '여행까지', en: 'Trip in', ja: '旅行まで', vi: 'Đến chuyến đi');
      case 'school':
        return L.of(context).pick(ko: '중요한 날까지', en: 'School day in', ja: '大切な日まで', vi: 'Đến ngày quan trọng');
      case 'work':
        return L.of(context).pick(ko: '업무 일정까지', en: 'Work event in', ja: '仕事の予定まで', vi: 'Đến lịch công việc');
      case 'gift':
        return L.of(context).pick(ko: '선물할 날까지', en: 'Gift day in', ja: '贈り物の日まで', vi: 'Đến ngày tặng quà');
      default:
        if (title.contains('생일') || title.contains('birthday')) {
          return L.of(context).pick(ko: '생일까지', en: 'Birthday in', ja: '誕生日まで', vi: 'Đến sinh nhật');
        }
        if (title.contains('기념') || title.contains('anniversary')) {
          return L.of(context).pick(ko: '기념일까지', en: 'Anniversary in', ja: '記念日まで', vi: 'Đến kỷ niệm');
        }
        if (title.contains('여행') || title.contains('trip') || title.contains('travel')) {
          return L.of(context).pick(ko: '여행까지', en: 'Trip in', ja: '旅行まで', vi: 'Đến chuyến đi');
        }
        return L.of(context).pick(ko: '기다리는 날까지', en: 'Counting down', ja: 'カウントダウン', vi: 'Đang đếm ngược');
    }
  }

  String _dDayText(DdayItem item) {
    final days = _daysLeft(item);
    if (days == 0) return 'D-Day';
    return 'D-${days.abs()}';
  }

  String _cardEmotionLine(DdayItem item) {
    final l = L.of(context);
    final d = _timeLeft(item);
    final days = d.inDays;
    final title = item.title.toLowerCase();

    if (d.isNegative || days == 0) {
      return l.pick(ko: '오늘이 바로 그날이에요 💜', en: 'Today is the day 💜', ja: '今日はその日です 💜', vi: 'Hôm nay là ngày đó 💜');
    }
    if (days <= 2) {
      return l.pick(ko: '곧 만날 순간이에요 💜', en: 'The moment is almost here 💜', ja: 'もうすぐその瞬間です 💜', vi: 'Khoảnh khắc ấy sắp đến rồi 💜');
    }
    if (days <= 7) {
      return l.pick(ko: '조금씩 가까워지고 있어요 🙂', en: 'It is getting closer 🙂', ja: '少しずつ近づいています 🙂', vi: 'Đang đến gần hơn rồi 🙂');
    }
    if (item.icon == 'cake' || title.contains('생일') || title.contains('birthday')) {
      return l.pick(ko: '축하할 날을 기다리고 있어요 🎂', en: 'A celebration is on the way 🎂', ja: 'お祝いの日を待っています 🎂', vi: 'Ngày chúc mừng đang đến 🎂');
    }
    if (item.icon == 'flight' || title.contains('여행') || title.contains('trip') || title.contains('travel')) {
      return l.pick(ko: '떠날 날이 천천히 다가와요 ✈️', en: 'Your trip is getting closer ✈️', ja: '旅の日が近づいています ✈️', vi: 'Chuyến đi đang đến gần ✈️');
    }
    if (item.icon == 'heart' || title.contains('기념') || title.contains('anniversary')) {
      return l.pick(ko: '소중한 날을 기억하고 있어요 💕', en: 'Remembering a precious day 💕', ja: '大切な日を覚えています 💕', vi: 'Đang ghi nhớ ngày quý giá 💕');
    }
    return l.pick(ko: '천천히 준비해요 🌿', en: 'Take your time preparing 🌿', ja: 'ゆっくり準備しましょう 🌿', vi: 'Cứ từ từ chuẩn bị 🌿');
  }

  IconData _iconData(String key) {
    switch (key) {
      case 'heart':
        return Icons.favorite;
      case 'cake':
        return Icons.cake;
      case 'flight':
        return Icons.flight_takeoff;
      case 'school':
        return Icons.school;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'pets':
        return Icons.pets;
      case 'music':
        return Icons.music_note;
      case 'gift':
        return Icons.card_giftcard;
      case 'camera':
        return Icons.photo_camera;
      case 'car':
        return Icons.directions_car;
      case 'cart':
        return Icons.shopping_cart;
      case 'coffee':
        return Icons.local_cafe;
      case 'fitness':
        return Icons.fitness_center;
      default:
        return Icons.star;
    }
  }

  String _repeatText(String type) => type == 'yearly' ? L.of(context).yearlyRepeat : L.of(context).noRepeat;

  String _alarmText(int minutes) {
    final l = L.of(context);
    switch (minutes) {
      case -1:
        return l.pick(ko: '알림 안 함', en: 'No reminder', ja: '通知なし', vi: 'Không nhắc');
      case -2:
        return l.pick(ko: '당일 오전 9시', en: 'Same day 9 AM', ja: '当日午前9時', vi: '9 giờ sáng cùng ngày');
      case 0:
        return l.pick(ko: '정각 알림', en: 'At event time', ja: '予定時刻', vi: 'Đúng giờ sự kiện');
      case 60:
        return l.pick(ko: '1시간 전', en: '1 hour before', ja: '1時間前', vi: 'Trước 1 giờ');
      case 180:
        return l.pick(ko: '3시간 전', en: '3 hours before', ja: '3時間前', vi: 'Trước 3 giờ');
      case 360:
        return l.pick(ko: '6시간 전', en: '6 hours before', ja: '6時間前', vi: 'Trước 6 giờ');
      case 720:
        return l.pick(ko: '12시간 전', en: '12 hours before', ja: '12時間前', vi: 'Trước 12 giờ');
      case 1440:
        return l.pick(ko: '하루 전', en: '1 day before', ja: '1日前', vi: 'Trước 1 ngày');
      case 2880:
        return l.pick(ko: '2일 전', en: '2 days before', ja: '2日前', vi: 'Trước 2 ngày');
      case 10080:
        return l.pick(ko: '일주일 전', en: '1 week before', ja: '1週間前', vi: 'Trước 1 tuần');
      default:
        if (minutes > 0 && minutes % 1440 == 0) return l.pick(ko: '${minutes ~/ 1440}일 전', en: '${minutes ~/ 1440} days before', ja: '${minutes ~/ 1440}日前', vi: 'Trước ${minutes ~/ 1440} ngày');
        if (minutes > 0 && minutes % 60 == 0) return l.pick(ko: '${minutes ~/ 60}시간 전', en: '${minutes ~/ 60} hours before', ja: '${minutes ~/ 60}時間前', vi: 'Trước ${minutes ~/ 60} giờ');
        return l.pick(ko: '알림 설정', en: 'Reminder setting', ja: '通知設定', vi: 'Cài đặt nhắc nhở');
    }
  }

  Future<void> _openEditor({DdayItem? item}) async {
    await _refreshPermissionStatus();
    if (!_notificationPermissionOk || !_exactAlarmPermissionOk) {
      await _showPermissionGuide(
        title: L.of(context).pick(ko: '알림 설정이 필요해요', en: 'Reminder setup needed', ja: '通知設定が必要です', vi: 'Cần cài đặt nhắc nhở'),
        message: L.of(context).pick(ko: '일정 알림을 정확한 시간에 받으려면 알림 권한과 알람 및 리마인더 권한이 필요합니다.', en: 'Notification and exact alarm permissions are needed to receive reminders at the right time.', ja: '予定通知を正確な時刻に受け取るには通知権限とアラーム権限が必要です。', vi: 'Cần quyền thông báo và báo thức chính xác để nhận nhắc nhở đúng giờ.'),
        actionLabel: L.of(context).pick(ko: '설정 확인', en: 'Check settings', ja: '設定を確認', vi: 'Kiểm tra cài đặt'),
        onAction: () async {
          await NotificationService.requestNotificationPermission();
          await NotificationService.requestExactAlarmPermission();
          await AppSettings.openAppSettings();
        },
      );
    }
    final shouldCelebrateFirstCard = item == null && _items.isEmpty;
    final result = await Navigator.of(context).push<DdayItem>(
      MaterialPageRoute(builder: (_) => EditPage(item: item)),
    );
    if (result != null) {
      await _upsertItem(result);
      if (shouldCelebrateFirstCard && mounted) {
        _showFirstCardCelebration();
      }
    }
  }

  void _showFirstCardCelebration() {
    if (!mounted) return;

    final l = L.of(context);
    final messages = [
      l.pick(
        ko: '첫 소중한 날이 등록됐어요 🎉',
        en: 'Your first precious day is saved 🎉',
        ja: '最初の大切な日を登録しました 🎉',
        vi: 'Ngày quan trọng đầu tiên đã được lưu 🎉',
      ),
      l.pick(
        ko: '기억할 순간이 하나 생겼어요 ✨',
        en: 'A new moment worth remembering ✨',
        ja: '覚えておきたい瞬間ができました ✨',
        vi: 'Một khoảnh khắc đáng nhớ đã bắt đầu ✨',
      ),
      l.pick(
        ko: '새로운 기다림이 시작됐어요 💜',
        en: 'A new countdown begins 💜',
        ja: '新しい楽しみが始まりました 💜',
        vi: 'Một hành trình chờ đợi mới đã bắt đầu 💜',
      ),
    ];
    final message = messages[math.Random().nextInt(messages.length)];

    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final overlay = Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
      if (overlay == null) return;

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _FirstCardCelebrationOverlay(
          message: message,
          onDone: () {
            if (entry.mounted) entry.remove();
          },
        ),
      );

      try {
        overlay.insert(entry);
      } catch (_) {
        // 스낵바는 이미 표시했으므로 추가 처리 없음
      }
    });
  }

  void _confirmDeleteAfterClosingSheet(DdayItem item) {
    // 휴지통 + 되돌리기가 있으므로 release 안정성을 위해 확인창을 거치지 않고 바로 이동합니다.
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      unawaited(_deleteItem(item));
    });
  }

  void _showDetail(DdayItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final color = Color(item.colorValue);
        return SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 14))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
                          child: Icon(_iconData(item.icon), color: color, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                              const SizedBox(height: 4),
                              Text(_repeatText(item.repeatType), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: const Color(0xFFF6F7FB), borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        children: [
                          Text(L.of(context).pick(ko: '${_daysLeft(item)}일', en: 'D-${_daysLeft(item)}', ja: 'あと${_daysLeft(item)}日', vi: 'Còn ${_daysLeft(item)} ngày'), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                          const SizedBox(height: 4),
                          Text(_remainText(item), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _detailRow(Icons.calendar_month, L.of(context).date, _fullDate(_effectiveTarget(item))),
                    _detailRow(Icons.schedule, L.of(context).time, _timeText(item.targetTime)),
                    _detailRow(Icons.repeat, L.of(context).repeat, _repeatText(item.repeatType)),
                    _detailRow(Icons.notifications_none_rounded, L.of(context).reminder, _alarmText(item.alarmMinutesBefore)),
                    const SizedBox(height: 16),
                    Text(L.of(context).memo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF6F7FB), borderRadius: BorderRadius.circular(18)),
                      child: Text(
                        item.memo.trim().isEmpty ? L.of(context).noMemo : item.memo.trim(),
                        style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _openEditor(item: item);
                            },
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: Text(L.of(context).edit, style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDeleteAfterClosingSheet(item);
                            },
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111827), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: Text(L.of(context).delete, style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(DdayItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(L.of(context).pick(ko: '삭제할까요?', en: 'Delete this event?', ja: '削除しますか？', vi: 'Xóa sự kiện này?')),
        content: Text(L.of(context).pick(ko: '「${item.title}」 일정을 삭제합니다.', en: 'Delete “${item.title}”?', ja: '「${item.title}」を削除します。', vi: 'Xóa “${item.title}”?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L.of(context).cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(L.of(context).delete)),
        ],
      ),
    );
    if (ok == true) await _deleteItem(item);
  }

  Future<void> _copyItem(DdayItem item) async {
    final copy = item.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: L.of(context).pick(ko: '${item.title} 복사본', en: '${item.title} copy', ja: '${item.title} コピー', vi: 'Bản sao ${item.title}'),
      createdAt: DateTime.now(),
    );
    await _upsertItem(copy);
  }

  Future<void> _shareItem(DdayItem item) async {
    final target = _effectiveTarget(item);
    final repeat = item.repeatType == 'yearly' ? L.of(context).pick(ko: ' (매년)', en: ' (yearly)', ja: ' (毎年)', vi: ' (hằng năm)') : '';
    final text = '${item.title}\n${_fullDate(target)}$repeat\n\nD-${_daysLeft(item)}\n${_remainText(item)}';
    await Share.share(text);
  }

  void _showItemMenu(DdayItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuTile(Icons.ios_share, L.of(context).share, () {
                Navigator.pop(context);
                _shareItem(item);
              }),
              _menuTile(Icons.edit, L.of(context).edit, () {
                Navigator.pop(context);
                _openEditor(item: item);
              }),
              _menuTile(Icons.copy, L.of(context).copy, () {
                Navigator.pop(context);
                _copyItem(item);
              }),
              _menuTile(
                Icons.widgets_outlined,
                L.of(context).pick(ko: '홈 위젯에 추가', en: 'Add to home widget', ja: 'ホームウィジェットに追加', vi: 'Thêm vào widget'),
                () {
                  Navigator.pop(context);
                  _requestPinHomeWidget(wide: false, pinnedItem: item);
                },
              ),
              _menuTile(Icons.delete_outline, L.of(context).delete, () {
                Navigator.pop(context);
                _confirmDeleteAfterClosingSheet(item);
              }, danger: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String text, VoidCallback onTap, {bool danger = false}) {
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.redAccent : const Color(0xFF111827)),
      title: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: danger ? Colors.redAccent : const Color(0xFF111827))),
      onTap: onTap,
    );
  }

  Future<void> _requestPinHomeWidget({required bool wide, DdayItem? pinnedItem, bool useNearestForSmall = false}) async {
    final providerName = wide ? 'DdayWidgetProviderWide' : 'DdayWidgetProvider';
    final widgetLabel = wide ? L.of(context).pick(ko: '넓은 위젯(2개 표시)', en: 'Wide widget (2 events)', ja: '横長ウィジェット（2件）', vi: 'Widget rộng (2 sự kiện)') : L.of(context).pick(ko: '작은 위젯(1개 표시)', en: 'Small widget (1 event)', ja: '小さいウィジェット（1件）', vi: 'Widget nhỏ (1 sự kiện)');

    if (wide) {
      await _updateHomeWidget();
    } else {
      final itemToPin = pinnedItem ?? _nearestWidgetItem();
      await _savePendingSmallWidgetItem(itemToPin);
    }
    if (!mounted) return;

    bool requested = false;

    // Release-safe path: call our native Android requestPinAppWidget directly first.
    // The previous HomeWidget plugin path could fall back to the manual guide on release builds
    // because the qualified provider name was still the old com.example.dday_app path.
    try {
      requested = await WidgetDeepLinkService.requestPinHomeWidget(providerName) ?? false;
    } catch (_) {
      requested = false;
    }

    // Fallback to the plugin with the real application package name.
    if (!requested) {
      try {
        requested = await HomeWidget.isRequestPinWidgetSupported() ?? false;
        if (requested) {
          await HomeWidget.requestPinWidget(
            name: providerName,
            androidName: providerName,
            qualifiedAndroidName: 'com.forgeapps.tickday.$providerName',
          );
        }
      } catch (_) {
        requested = false;
      }
    }

    if (!mounted) return;

    if (requested) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).pick(ko: '$widgetLabel 추가 창을 열었습니다.', en: '$widgetLabel add screen opened.', ja: '$widgetLabel の追加画面を開きました。', vi: 'Đã mở màn hình thêm $widgetLabel.'))),
      );
      return;
    }

    await _showManualWidgetGuide(widgetLabel);
  }

  Future<void> _showManualWidgetGuide(String widgetLabel) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.touch_app_rounded, color: Color(0xFF111827)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(L.of(context).pick(ko: '$widgetLabel 추가 방법', en: 'How to add $widgetLabel', ja: '$widgetLabel の追加方法', vi: 'Cách thêm $widgetLabel'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                L.of(context).pick(ko: '이 휴대폰 런처에서는 앱에서 바로 위젯을 추가할 수 없어요. 아래 순서로 직접 추가해주세요.', en: 'This launcher does not support adding widgets directly from the app. Please add it manually.', ja: 'このランチャーではアプリから直接ウィジェットを追加できません。以下の手順で追加してください。', vi: 'Launcher này không hỗ trợ thêm widget trực tiếp từ ứng dụng. Hãy thêm thủ công theo các bước sau.'),
                style: TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 14),
              _widgetPlanRow('1', L.of(context).pick(ko: '홈 화면 빈 공간 길게 누르기', en: 'Long-press empty home screen space', ja: 'ホーム画面の空きスペースを長押し', vi: 'Nhấn giữ khoảng trống màn hình chính'), L.of(context).pick(ko: '아이콘이 없는 빈 공간을 꾹 눌러주세요.', en: 'Press and hold a blank area without icons.', ja: 'アイコンのない空きスペースを長押ししてください。', vi: 'Nhấn giữ khu vực trống không có biểu tượng.')), 
              _widgetPlanRow('2', L.of(context).pick(ko: '위젯 메뉴 선택', en: 'Choose widgets', ja: 'ウィジェットメニューを選択', vi: 'Chọn menu widget'), L.of(context).pick(ko: '위젯 목록에서 TickDay를 찾습니다.', en: 'Find TickDay in the widget list.', ja: 'ウィジェット一覧からTickDayを探します。', vi: 'Tìm TickDay trong danh sách widget.')), 
              _widgetPlanRow('3', L.of(context).pick(ko: '원하는 크기 선택', en: 'Choose a size', ja: 'サイズを選択', vi: 'Chọn kích thước'), L.of(context).pick(ko: '작은 위젯은 1개, 넓은 위젯은 2개 일정을 보여줍니다.', en: 'Small shows 1 event; wide shows 2 events.', ja: '小さいウィジェットは1件、横長は2件表示します。', vi: 'Widget nhỏ hiển thị 1 sự kiện; widget rộng hiển thị 2 sự kiện.')), 
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(L.of(context).confirm, style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  WidgetPreviewData _toWidgetPreviewData(DdayItem item) {
    return WidgetPreviewData(
      dday: _dDayText(item),
      title: item.title,
      remain: _widgetRemainText(item),
      emotion: _cardEmotionLine(item),
      progress: _progress(item),
      colorValue: item.colorValue,
    );
  }

  void _showWidgetPlanSheet() {
    final previewItems = _nearestWidgetItems(2).map(_toWidgetPreviewData).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WidgetPreviewPage(
          items: previewItems,
          onAddSmall: () => _requestPinHomeWidget(wide: false, useNearestForSmall: true),
          onAddWide: () => _requestPinHomeWidget(wide: true),
        ),
      ),
    );
  }

  Widget _widgetPlanRow(String step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(step, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAppDrawer() {
    final l = L.of(context);
    final currentCode = Localizations.localeOf(context).languageCode;
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.event_available_rounded, color: Color(0xFF111827), size: 32),
                  ),
                  const SizedBox(height: 14),
                  const Text('TickDay', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(l.subtitle, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _drawerTile(Icons.home_rounded, l.pick(ko: '전체 일정', en: 'All events', ja: 'すべての予定', vi: 'Tất cả sự kiện'), () => Navigator.pop(context), selected: true),
                  _drawerTile(Icons.widgets_rounded, l.pick(ko: '홈 위젯 추가', en: 'Add home widget', ja: 'ホームウィジェット追加', vi: 'Thêm widget'), () { Navigator.pop(context); _showWidgetPlanSheet(); }),
                  _drawerTile(Icons.notifications_active_rounded, l.pick(ko: '알림 설정', en: 'Reminder settings', ja: '通知設定', vi: 'Cài đặt nhắc nhở'), () { Navigator.pop(context); _showGlobalReminderSettingsSheet(); }),
                  _drawerTile(Icons.language_rounded, l.pick(ko: '언어 설정', en: 'Language', ja: '言語設定', vi: 'Ngôn ngữ'), () { Navigator.pop(context); _showLanguageSheet(); }, trailingText: _languageName(currentCode)),
                  _drawerTile(
                    Icons.palette_rounded,
                    l.pick(ko: '테마 설정', en: 'Theme', ja: 'テーマ', vi: 'Giao diện'),
                    null,
                    disabled: true,
                    trailingText: l.pick(ko: '준비중', en: 'Soon', ja: '準備中', vi: 'Sắp có'),
                  ),
                  _drawerTile(Icons.delete_outline_rounded, l.pick(ko: '휴지통', en: 'Trash', ja: 'ゴミ箱', vi: 'Thùng rác'), () { Navigator.pop(context); _openTrashPage(); }, trailingText: _trashItems.isEmpty ? null : '${_trashItems.length}'),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8), child: Divider(height: 1)),
                  _drawerTile(Icons.privacy_tip_outlined, l.pick(ko: '개인정보 처리방침', en: 'Privacy policy', ja: 'プライバシーポリシー', vi: 'Chính sách bảo mật'), () { Navigator.pop(context); _openExternalUrl(_privacyPolicyUrl, fallbackType: 'privacy'); }),
                  _drawerTile(Icons.description_outlined, l.pick(ko: '이용약관', en: 'Terms of use', ja: '利用規約', vi: 'Điều khoản sử dụng'), () { Navigator.pop(context); _openExternalUrl(_termsOfUseUrl, fallbackType: 'terms'); }),
                  _drawerTile(Icons.info_outline_rounded, l.pick(ko: '앱 정보', en: 'App info', ja: 'アプリ情報', vi: 'Thông tin ứng dụng'), () { Navigator.pop(context); _showAppInfoSheet(); }),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Version 1.0.0', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, VoidCallback? onTap, {bool selected = false, bool disabled = false, String? trailingText}) {
    final color = disabled ? const Color(0xFF9CA3AF) : const Color(0xFF111827);
    final trailingColor = disabled ? const Color(0xFFB0B7C3) : const Color(0xFF6B7280);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? const Color(0xFFF3F4F6) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: color))),
                if (trailingText != null) Text(trailingText, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: trailingColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Future<void> _saveGlobalReminderSettings({
    bool? reminderEnabled,
    bool? todaySummaryEnabled,
    int? todaySummaryHour,
    int? todaySummaryMinute,
    int? defaultAlarmMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nextReminderEnabled = reminderEnabled ?? _globalReminderEnabled;
    final nextTodaySummaryEnabled = todaySummaryEnabled ?? _todaySummaryEnabled;
    final nextTodaySummaryHour = todaySummaryHour ?? _todaySummaryHour;
    final nextTodaySummaryMinute = todaySummaryMinute ?? _todaySummaryMinute;
    final nextDefaultAlarmMinutes = defaultAlarmMinutes ?? _defaultAlarmMinutesBefore;

    await prefs.setBool(_globalReminderEnabledKey, nextReminderEnabled);
    await prefs.setBool(_todaySummaryEnabledKey, nextTodaySummaryEnabled);
    await prefs.setInt(_todaySummaryHourKey, nextTodaySummaryHour);
    await prefs.setInt(_todaySummaryMinuteKey, nextTodaySummaryMinute);
    await prefs.setInt(_defaultAlarmMinutesKey, nextDefaultAlarmMinutes);

    if (!mounted) return;
    setState(() {
      _globalReminderEnabled = nextReminderEnabled;
      _todaySummaryEnabled = nextTodaySummaryEnabled;
      _todaySummaryHour = nextTodaySummaryHour;
      _todaySummaryMinute = nextTodaySummaryMinute;
      _defaultAlarmMinutesBefore = nextDefaultAlarmMinutes;
    });

    if (nextReminderEnabled) {
      await _rescheduleAllNotifications();
      await _scheduleTodaySummaryNotification();
    } else {
      await _rescheduleAllNotifications();
    }
  }

  String _defaultAlarmShortText(int minutes) => _alarmText(minutes);

  String _todaySummaryTimeText(BuildContext context) {
    final time = TimeOfDay(hour: _todaySummaryHour, minute: _todaySummaryMinute);
    return MaterialLocalizations.of(context).formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }

  String _todaySummaryDescription(BuildContext context) {
    final l = L.of(context);
    return l.pick(
      ko: '매일 ${_todaySummaryTimeText(context)}에 오늘의 일정을 알려줍니다.',
      en: 'Every day at ${_todaySummaryTimeText(context)}, TickDay reminds you of today’s events.',
      ja: '毎日${_todaySummaryTimeText(context)}に今日の予定をお知らせします。',
      vi: 'Mỗi ngày lúc ${_todaySummaryTimeText(context)}, TickDay nhắc các sự kiện hôm nay.',
    );
  }

  Widget _globalReminderChoiceTile({
    required int value,
    required String title,
    required String subtitle,
    required StateSetter sheetSetState,
  }) {
    final selected = _defaultAlarmMinutesBefore == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            sheetSetState(() => _defaultAlarmMinutesBefore = value);
            await _saveGlobalReminderSettings(defaultAlarmMinutes: value);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showGlobalReminderSettingsSheet() async {
    final l = L.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, sheetSetState) {
          Future<void> updateSheet({bool? reminderEnabled, bool? todaySummaryEnabled, int? todaySummaryHour, int? todaySummaryMinute, int? defaultAlarmMinutes}) async {
            sheetSetState(() {
              if (reminderEnabled != null) _globalReminderEnabled = reminderEnabled;
              if (todaySummaryEnabled != null) _todaySummaryEnabled = todaySummaryEnabled;
              if (todaySummaryHour != null) _todaySummaryHour = todaySummaryHour;
              if (todaySummaryMinute != null) _todaySummaryMinute = todaySummaryMinute;
              if (defaultAlarmMinutes != null) _defaultAlarmMinutesBefore = defaultAlarmMinutes;
            });
            await _saveGlobalReminderSettings(
              reminderEnabled: reminderEnabled,
              todaySummaryEnabled: todaySummaryEnabled,
              todaySummaryHour: todaySummaryHour,
              todaySummaryMinute: todaySummaryMinute,
              defaultAlarmMinutes: defaultAlarmMinutes,
            );
          }

          Future<void> pickTodaySummaryTime() async {
            final picked = await showTimePicker(
              context: sheetContext,
              initialTime: TimeOfDay(hour: _todaySummaryHour, minute: _todaySummaryMinute),
            );
            if (picked == null) return;
            await updateSheet(todaySummaryHour: picked.hour, todaySummaryMinute: picked.minute);
          }

          Future<void> sendTodaySummaryTest() async {
            final now = DateTime.now();
            final todayItems = _items.where((item) {
              final target = _effectiveTargetForDay(item, now);
              return target.year == now.year && target.month == now.month && target.day == now.day;
            }).toList()
              ..sort((a, b) => _effectiveTargetForDay(a, now).compareTo(_effectiveTargetForDay(b, now)));
            final title = l.pick(ko: '오늘 일정 확인', en: 'Today\'s events', ja: '今日の予定', vi: 'Sự kiện hôm nay');
            final body = todayItems.isEmpty
                ? l.pick(ko: '오늘도 소중한 하루를 준비해요.', en: 'Plan your day with TickDay.', ja: '今日も大切な一日を準備しましょう。', vi: 'Hãy chuẩn bị một ngày thật ý nghĩa.')
                : _todaySummaryBody(todayItems, now);

            await NotificationService.showNow(
              id: _todaySummaryNotificationId + 99,
              title: title,
              body: body,
              payload: '__today_summary__',
            );

            final scheduledOk = await NotificationService.schedule(
              id: _todaySummaryNotificationId + 98,
              title: l.pick(ko: '예약 검증 · 오늘 일정 요약', en: 'Scheduled check · Today summary', ja: '予約確認 · 今日の予定まとめ', vi: 'Kiểm tra đặt lịch · Tóm tắt hôm nay'),
              body: body,
              scheduledAt: now.add(const Duration(seconds: 10)),
              payload: '__today_summary__',
            );

            await _scheduleTodaySummaryNotification();

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  scheduledOk
                      ? l.pick(ko: '즉시 알림 + 10초 뒤 예약 알림까지 검증합니다.', en: 'Checking both instant and 10-second scheduled notifications.', ja: '即時通知と10秒後の予約通知を確認します。', vi: 'Đang kiểm tra cả thông báo ngay và thông báo đặt sau 10 giây.')
                      : l.pick(ko: '즉시 알림은 보냈지만 예약 검증은 실패했습니다. 정확한 알람 권한을 확인해주세요.', en: 'Instant notification sent, but scheduled check failed. Check exact alarm permission.', ja: '即時通知は送信しましたが、予約確認に失敗しました。正確なアラーム権限を確認してください。', vi: 'Đã gửi thông báo ngay, nhưng kiểm tra đặt lịch thất bại. Hãy kiểm tra quyền báo thức chính xác.'),
                ),
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Container(
                margin: const EdgeInsets.all(16),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.88),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l.pick(ko: '알림 설정', en: 'Reminder settings', ja: '通知設定', vi: 'Cài đặt nhắc nhở'), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -0.5))),
                        IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(l.pick(ko: '필요한 알림만 간단하게 켜고, 요약 시간은 원하는 때로 바꿀 수 있어요.', en: 'Keep reminders simple and choose when your daily summary arrives.', ja: '必要な通知だけを簡単に設定し、まとめの時刻も変更できます。', vi: 'Giữ nhắc nhở thật đơn giản và chọn giờ nhận tóm tắt hằng ngày.'), style: const TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notifications_active_rounded, color: Color(0xFF111827)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.pick(ko: '전체 알림 사용', en: 'Use reminders', ja: '通知を使用', vi: 'Dùng nhắc nhở'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                                    const SizedBox(height: 2),
                                    Text(l.pick(ko: '끄면 일정 알림과 요약 알림이 모두 멈춥니다.', en: 'Turning this off stops event and summary reminders.', ja: 'オフにすると予定通知と要約通知が停止します。', vi: 'Tắt mục này sẽ dừng mọi nhắc nhở.'), style: const TextStyle(fontSize: 12.3, height: 1.25, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                                  ],
                                ),
                              ),
                              Switch(value: _globalReminderEnabled, activeColor: const Color(0xFF2563EB), onChanged: (value) => updateSheet(reminderEnabled: value)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(height: 1, color: const Color(0xFFE5E7EB)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.wb_sunny_outlined, color: _globalReminderEnabled ? const Color(0xFF111827) : const Color(0xFF9CA3AF)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.pick(ko: '오늘 일정 요약', en: 'Today summary', ja: '今日の予定まとめ', vi: 'Tóm tắt hôm nay'), style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _globalReminderEnabled ? const Color(0xFF111827) : const Color(0xFF9CA3AF))),
                                    const SizedBox(height: 2),
                                    Text(_todaySummaryDescription(sheetContext), style: const TextStyle(fontSize: 12.3, height: 1.25, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                                  ],
                                ),
                              ),
                              Switch(value: _todaySummaryEnabled, activeColor: const Color(0xFF2563EB), onChanged: _globalReminderEnabled ? (value) => updateSheet(todaySummaryEnabled: value) : null),
                            ],
                          ),
                          if (_globalReminderEnabled && _todaySummaryEnabled) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: pickTodaySummaryTime,
                                    icon: const Icon(Icons.schedule_rounded, size: 18),
                                    label: Text(l.pick(ko: '요약 시간 ${_todaySummaryTimeText(sheetContext)}', en: 'Summary time ${_todaySummaryTimeText(sheetContext)}', ja: 'まとめ時刻 ${_todaySummaryTimeText(sheetContext)}', vi: 'Giờ tóm tắt ${_todaySummaryTimeText(sheetContext)}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: sendTodaySummaryTest,
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                  child: Text(l.pick(ko: '검증', en: 'Verify', ja: '確認', vi: 'Kiểm tra'), style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.alarm_rounded, color: _strongAlarmMode ? const Color(0xFF111827) : const Color(0xFF9CA3AF)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.pick(ko: '강한 알람 모드', en: 'Strong alarm mode', ja: '強いアラームモード', vi: 'Chế độ báo thức mạnh'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                                const SizedBox(height: 2),
                                Text(l.pick(ko: '알람 발생 시 반복 멜로디를 재생합니다.', en: 'Plays a repeating melody when an alarm fires.', ja: 'アラーム発生時にメロディーをループ再生します。', vi: 'Phát âm thanh lặp lại khi báo thức.'), style: const TextStyle(fontSize: 12.3, height: 1.25, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                          Switch(
                            value: _strongAlarmMode,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (v) async {
                              sheetSetState(() => _strongAlarmMode = v);
                              setState(() => _strongAlarmMode = v);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool(_strongAlarmModeKey, v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(l.pick(ko: '새 일정 기본 알림', en: 'Default reminder for new events', ja: '新しい予定の初期通知', vi: 'Nhắc mặc định cho sự kiện mới'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    const SizedBox(height: 10),
                    _globalReminderChoiceTile(value: -2, title: l.pick(ko: '당일 오전 9시', en: 'Same day 9 AM', ja: '当日午前9時', vi: '9 giờ sáng cùng ngày'), subtitle: l.pick(ko: '일정 당일 아침에 미리 알림', en: 'Reminder on the morning of the event', ja: '予定当日の朝に通知', vi: 'Nhắc vào buổi sáng cùng ngày'), sheetSetState: sheetSetState),
                    _globalReminderChoiceTile(value: 0, title: l.pick(ko: '정각 알림', en: 'At event time', ja: '予定時刻', vi: 'Đúng giờ sự kiện'), subtitle: l.pick(ko: '일정 시간이 되었을 때 알림', en: 'Notify exactly at the event time', ja: '予定時刻に通知', vi: 'Nhắc đúng giờ sự kiện'), sheetSetState: sheetSetState),
                    _globalReminderChoiceTile(value: 60, title: l.pick(ko: '1시간 전', en: '1 hour before', ja: '1時間前', vi: 'Trước 1 giờ'), subtitle: l.pick(ko: '중요한 약속 직전 알림', en: 'Best for important appointments', ja: '重要な予定の直前通知', vi: 'Phù hợp cho lịch hẹn quan trọng'), sheetSetState: sheetSetState),
                    _globalReminderChoiceTile(value: 1440, title: l.pick(ko: '하루 전', en: '1 day before', ja: '1日前', vi: 'Trước 1 ngày'), subtitle: l.pick(ko: '기념일 전날 미리 알림', en: 'Good for anniversaries and plans', ja: '記念日の前日に通知', vi: 'Tốt cho kỷ niệm và kế hoạch'), sheetSetState: sheetSetState),
                    _globalReminderChoiceTile(value: 10080, title: l.pick(ko: '일주일 전', en: '1 week before', ja: '1週間前', vi: 'Trước 1 tuần'), subtitle: l.pick(ko: '여행, 시험, 큰 일정 준비용', en: 'For trips, exams, and big plans', ja: '旅行・試験・大きな予定の準備用', vi: 'Cho chuyến đi, kỳ thi, kế hoạch lớn'), sheetSetState: sheetSetState),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await NotificationService.requestNotificationPermission();
                        await NotificationService.requestExactAlarmPermission();
                        await AppSettings.openAppSettings();
                        await _refreshPermissionStatus();
                      },
                      icon: const Icon(Icons.settings_outlined),
                      label: Text(l.pick(ko: '휴대폰 알림 권한 확인', en: 'Open phone notification settings', ja: '端末の通知設定を確認', vi: 'Mở cài đặt thông báo điện thoại'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Text(l.done, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showLanguageSheet() async {
    final l = L.of(context);
    final currentCode = Localizations.localeOf(context).languageCode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.pick(ko: '언어 설정', en: 'Language', ja: '言語設定', vi: 'Ngôn ngữ'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              Text(l.pick(ko: '사용할 언어를 선택하세요.', en: 'Choose your language.', ja: '使用する言語を選択してください。', vi: 'Chọn ngôn ngữ bạn muốn dùng.'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
              const SizedBox(height: 14),
              _languageTile('ko', '🇰🇷', '한국어', currentCode),
              _languageTile('en', '🇺🇸', 'English', currentCode),
              _languageTile('ja', '🇯🇵', '日本語', currentCode),
              _languageTile('vi', '🇻🇳', 'Tiếng Việt', currentCode),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
                child: Text(l.pick(ko: '언어는 언제든지 변경할 수 있어요. 위젯 문구도 함께 바뀝니다.', en: 'You can change the language anytime. Widget messages update too.', ja: '言語はいつでも変更できます。ウィジェットの文言も変わります。', vi: 'Bạn có thể đổi ngôn ngữ bất cứ lúc nào. Nội dung widget cũng sẽ đổi theo.'), style: const TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w700, color: Color(0xFF6D3E91))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageTile(String code, String flag, String label, String currentCode) {
    final selected = currentCode == code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFF9F5FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _setLanguage(code),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB))),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)))),
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? const Color(0xFF111827) : const Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefsKey, code);
    appLocaleNotifier.value = _localeFromCode(code);
    if (!mounted) return;
    Navigator.pop(context);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    _refreshNow();
  }

  Future<void> _openExternalUrl(String url, {required String fallbackType}) async {
    final uri = Uri.parse(url);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LegalPage(type: fallbackType)));
  }

  void _showThemeComingSoon() {
    _showInfoSnack(L.of(context).pick(ko: '테마 설정은 다음 업데이트에서 제공됩니다.', en: 'Theme settings are coming in the next update.', ja: 'テーマ設定は次回アップデートで提供予定です。', vi: 'Cài đặt giao diện sẽ có trong bản cập nhật tới.'));
  }

  void _showPremiumComingSoon() {
    _showInfoSnack(L.of(context).pick(ko: '프리미엄 기능은 출시 후 추가 예정입니다.', en: 'Premium features will be added after launch.', ja: 'プレミアム機能は公開後に追加予定です。', vi: 'Tính năng Premium sẽ được thêm sau khi phát hành.'));
  }

  void _showInfoSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showAppInfoSheet() {
    showAboutDialog(
      context: context,
      applicationName: 'TickDay',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.event_available_rounded, color: Color(0xFF111827)),
      ),
      children: [Text(L.of(context).pick(ko: '소중한 날을 놓치지 않도록 도와주는 D-day 알림 앱입니다.', en: 'A countdown and reminder app for your important days.', ja: '大切な日を忘れないためのカウントダウン通知アプリです。', vi: 'Ứng dụng đếm ngược và nhắc nhở cho những ngày quan trọng.'))],
    );
  }


  Future<void> _sendQuickNotificationTest() async {
    await NotificationService.showNow(
      title: L.of(context).pick(ko: '알림 확인', en: 'Notification check', ja: '通知チェック', vi: 'Kiểm tra thông báo'),
      body: L.of(context).pick(
        ko: '이 알림이 보이면 기본 알림은 정상입니다.',
        en: 'If you see this, basic notifications are working.',
        ja: 'この通知が見えれば基本通知は正常です。',
        vi: 'Nếu bạn thấy thông báo này, thông báo cơ bản hoạt động.',
      ),
      payload: '__today_summary__',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.of(context).pick(ko: '알림을 보냈습니다.', en: 'Notification sent.', ja: '通知を送信しました。', vi: 'Đã gửi thông báo.'))),
    );
  }

  // ⚠️ 풀스크린 알림 테스트 (1차 안전버전)
  Future<void> _sendFullScreenNotificationTest() async {
    final scheduledAt = DateTime.now().add(const Duration(seconds: 10));
    final scheduledOk = await NotificationService.schedule(
      id: 999889,
      title: L.of(context).pick(
        ko: '풀스크린 알림 테스트',
        en: 'Full-Screen Test',
        ja: 'フルスクリーン通知テスト',
        vi: 'Kiểm tra toàn màn hình',
      ),
      body: L.of(context).pick(
        ko: 'TickDay 풀스크린 알림이 작동하는지 확인합니다.',
        en: 'Checking if full-screen notifications work.',
        ja: 'フルスクリーン通知の動作確認中です。',
        vi: 'Đang kiểm tra thông báo toàn màn hình.',
      ),
      scheduledAt: scheduledAt,
      payload: '__fullscreen_auto__',
      fullScreen: true,
    );

    // For testing strong (full-screen) alarms, also schedule the native alarm
    // so we can observe native FullScreen behavior without Flutter's zonedSchedule.
    if (scheduledOk) {
      unawaited(NativeAlarmService.scheduleAlarm(
        alarmId: 999889,
        scheduledAt: scheduledAt,
        title: L.of(context).pick(
          ko: '풀스크린 알림 테스트',
          en: 'Full-Screen Test',
          ja: 'フルスクリーン通知テスト',
          vi: 'Kiểm tra toàn màn hình',
        ),
        body: L.of(context).pick(
          ko: 'TickDay 풀스크린 알림이 작동하는지 확인합니다.',
          en: 'Checking if full-screen notifications work.',
          ja: 'フルスクリーン通知の動作確認中です。',
          vi: 'Đang kiểm tra thông báo toàn màn hình.',
        ),
        itemId: '__fullscreen_test__',
        memo: null,
      ));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.of(context).pick(
        ko: scheduledOk
          ? '알림 예약 완료\n10초 후 전체 화면 알림이 표시됩니다'
          : '풀스크린 알림 예약에 실패했습니다.',
        en: scheduledOk
            ? 'Full-screen notification scheduled. Overlay will show in 10 seconds.'
            : 'Failed to schedule full-screen notification.',
        ja: scheduledOk
            ? 'フルスクリーン通知を予約しました。10秒後にOverlayが表示されます。'
            : 'フルスクリーン通知の予約に失敗しました。',
        vi: scheduledOk
            ? 'Đã lên lịch thông báo toàn màn hình. Overlay sẽ hiển thị sau 10 giây.'
            : 'Lên lịch thông báo toàn màn hình không thành công.',
      ))),
    );
  }

  void _showAppMenu() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'quick-menu',
      barrierColor: Colors.black.withOpacity(0.12),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: 76,
                right: 24,
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 310, minWidth: 250),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 26, offset: const Offset(0, 14)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _quickMenuTile(
                            icon: Icons.auto_awesome_rounded,
                            title: L.of(context).pick(ko: '빠른 일정 추가', en: 'Quick add event', ja: '予定をクイック追加', vi: 'Thêm nhanh sự kiện'),
                            subtitle: L.of(context).pick(ko: '테마와 날짜만 선택해요', en: 'Pick a theme and date', ja: 'テーマと日付だけ選択', vi: 'Chọn chủ đề và ngày'),
                            isPrimary: true,
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              _showQuickAddThemeSheet();
                            },
                          ),
                          const SizedBox(height: 6),
                          _quickMenuTile(
                            icon: Icons.notifications_active_rounded,
                            title: L.of(context).pick(ko: '알림 확인하기', en: 'Check notifications', ja: '通知を確認', vi: 'Kiểm tra thông báo'),
                            subtitle: L.of(context).pick(ko: '즉시 테스트 알림 보내기', en: 'Send a test notification', ja: 'テスト通知を送信', vi: 'Gửi thông báo thử'),
                            onTap: () async {
                              Navigator.of(dialogContext).pop();
                              await _sendQuickNotificationTest();
                            },
                          ),
                          const SizedBox(height: 6),
                          // ⚠️ 풀스크린 알림 테스트 메뉴 (1차 안전버전)
                          _quickMenuTile(
                            icon: Icons.fullscreen_rounded,
                            title: L.of(context).pick(ko: '알림 미리보기', en: 'Full-Screen Test', ja: 'フルスクリーンテスト', vi: 'Kiểm tra toàn màn hình'),
                            subtitle: L.of(context).pick(ko: '전체 화면 알림 미리 체험', en: 'Test full-screen overlay', ja: 'Overlay表示テスト', vi: 'Kiểm tra Overlay'),
                            onTap: () async {
                              Navigator.of(dialogContext).pop();
                              await _sendFullScreenNotificationTest();
                            },
                          ),
                          const SizedBox(height: 6),
                          _quickMenuTile(
                            icon: Icons.schedule_rounded,
                            title: L.of(context).pick(ko: '오늘 요약 설정', en: 'Today summary settings', ja: '今日のまとめ設定', vi: 'Cài đặt tóm tắt hôm nay'),
                            subtitle: L.of(context).pick(ko: '시간과 요약 알림 관리', en: 'Manage time and summary', ja: '時刻と通知を管理', vi: 'Quản lý giờ và tóm tắt'),
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              _showGlobalReminderSettingsSheet();
                            },
                          ),
                          _quickMenuTile(
                            icon: Icons.widgets_outlined,
                            title: L.of(context).pick(ko: '홈 위젯 추가', en: 'Add home widget', ja: 'ホームウィジェット追加', vi: 'Thêm widget màn hình chính'),
                            subtitle: L.of(context).pick(ko: 'D-day를 홈 화면에서 보기', en: 'See D-days on home screen', ja: 'ホーム画面でD-dayを見る', vi: 'Xem D-day trên màn hình chính'),
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              _showWidgetPlanSheet();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.08, -0.06), end: Offset.zero).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
              alignment: Alignment.topRight,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _quickMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final color = isPrimary ? const Color(0xFF059669) : const Color(0xFF111827);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isPrimary ? const Color(0xFFA7F3D0) : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                  const SizedBox(height: 3),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: isPrimary ? const Color(0xFF059669) : const Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickAddThemeSheet() async {
    final l = L.of(context);
    final presets = <_QuickEventPreset>[
      _QuickEventPreset(
        type: 'birthday',
        icon: 'cake',
        emoji: '🎂',
        color: const Color(0xFFEC4899),
        title: l.pick(ko: '생일', en: 'Birthday', ja: '誕生日', vi: 'Sinh nhật'),
        subtitle: l.pick(ko: '매년 반복되는 소중한 날', en: 'A special day every year', ja: '毎年の大切な日', vi: 'Ngày đặc biệt hằng năm'),
        repeatType: 'yearly',
        alarmMinutesBefore: 1440,
      ),
      _QuickEventPreset(
        type: 'anniversary',
        icon: 'heart',
        emoji: '💍',
        color: const Color(0xFF8B5CF6),
        title: l.pick(ko: '기념일', en: 'Anniversary', ja: '記念日', vi: 'Kỷ niệm'),
        subtitle: l.pick(ko: '잊지 말아야 할 특별한 날', en: 'A day worth remembering', ja: '忘れたくない特別な日', vi: 'Một ngày đáng nhớ'),
        repeatType: 'yearly',
        alarmMinutesBefore: 1440,
      ),
      _QuickEventPreset(
        type: 'trip',
        icon: 'flight',
        emoji: '✈️',
        color: const Color(0xFF3B82F6),
        title: l.pick(ko: '여행', en: 'Trip', ja: '旅行', vi: 'Du lịch'),
        subtitle: l.pick(ko: '떠나는 날을 설레게 기다려요', en: 'Count down to departure', ja: '出発日を楽しみに待つ', vi: 'Đếm ngược đến ngày đi'),
        repeatType: 'none',
        alarmMinutesBefore: -2,
      ),
      _QuickEventPreset(
        type: 'appointment',
        icon: 'star',
        emoji: '📅',
        color: const Color(0xFF22C55E),
        title: l.pick(ko: '약속', en: 'Appointment', ja: '予定', vi: 'Cuộc hẹn'),
        subtitle: l.pick(ko: '친구, 가족, 중요한 약속', en: 'Friends, family, or plans', ja: '友達・家族・大切な予定', vi: 'Bạn bè, gia đình, kế hoạch'),
        repeatType: 'none',
        alarmMinutesBefore: 60,
      ),
      _QuickEventPreset(
        type: 'dday',
        icon: 'event',
        emoji: '⭐',
        color: const Color(0xFF111827),
        title: l.pick(ko: 'D-day', en: 'D-day', ja: 'D-day', vi: 'D-day'),
        subtitle: l.pick(ko: '직접 이름 붙일 중요한 날', en: 'A custom important day', ja: '自由に名前を付ける大切な日', vi: 'Ngày quan trọng tùy chỉnh'),
        repeatType: 'none',
        alarmMinutesBefore: 1440,
      ),
      _QuickEventPreset(
        type: 'exam',
        icon: 'school',
        emoji: '🎓',
        color: const Color(0xFFF59E0B),
        title: l.pick(ko: '시험', en: 'Exam', ja: '試験', vi: 'Kỳ thi'),
        subtitle: l.pick(ko: '준비가 필요한 중요한 날', en: 'A day to prepare for', ja: '準備が必要な大切な日', vi: 'Ngày quan trọng cần chuẩn bị'),
        repeatType: 'none',
        alarmMinutesBefore: 1440,
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 16))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.pick(ko: '어떤 일정을 추가할까요?', en: 'What do you want to add?', ja: 'どんな予定を追加しますか？', vi: 'Bạn muốn thêm sự kiện nào?'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.4))),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded), style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l.pick(ko: '테마를 고르면 제목, 반복, 알림이 자동으로 설정돼요.', en: 'Pick a theme and TickDay fills in title, repeat, and reminder.', ja: 'テーマを選ぶとタイトル・繰り返し・通知を自動設定します。', vi: 'Chọn chủ đề, TickDay sẽ tự đặt tiêu đề, lặp lại và nhắc nhở.'), style: const TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: presets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.42),
                  itemBuilder: (_, index) {
                    final preset = presets[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickQuickEventDateTime(preset);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: preset.color.withOpacity(0.09), borderRadius: BorderRadius.circular(22), border: Border.all(color: preset.color.withOpacity(0.18))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(preset.emoji, style: const TextStyle(fontSize: 25)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    preset.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              preset.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.2, height: 1.20, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickQuickEventDateTime(_QuickEventPreset preset) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
      helpText: L.of(context).pick(ko: '날짜 선택', en: 'Select date', ja: '日付を選択', vi: 'Chọn ngày'),
      cancelText: L.of(context).cancel,
      confirmText: L.of(context).confirm,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: L.of(context).pick(ko: '시간 선택', en: 'Select time', ja: '時刻を選択', vi: 'Chọn giờ'),
      cancelText: L.of(context).cancel,
      confirmText: L.of(context).confirm,
    );
    if (time == null || !mounted) return;

    final shouldCelebrateFirstCard = _items.isEmpty;
    final item = DdayItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: preset.title,
      targetDate: DateTime(date.year, date.month, date.day),
      targetTime: time,
      repeatType: preset.repeatType,
      icon: preset.icon,
      colorValue: preset.color.value,
      createdAt: DateTime.now(),
      memo: '',
      alarmMinutesBefore: preset.alarmMinutesBefore,
    );

    await _upsertItem(item);
    if (!mounted) return;
    if (shouldCelebrateFirstCard) {
      _showFirstCardCelebration();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).pick(ko: '일정이 추가되었어요.', en: 'Event added.', ja: '予定を追加しました。', vi: 'Đã thêm sự kiện.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: Builder(
          builder: (context) {
            final size = MediaQuery.of(context).size;
            final isLandscape = size.width > size.height;
            final drawerWidth = isLandscape ? size.width * 0.50 : size.width * 0.84;
            return SizedBox(
              width: drawerWidth.clamp(280.0, 420.0),
              child: _buildAppDrawer(),
            );
          },
        ),
        floatingActionButton: SizedBox(
          width: 58,
          height: 58,
          child: FloatingActionButton(
            onPressed: () => _openEditor(),
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.add, size: 25),
          ),
        ),
        bottomNavigationBar: (_isBannerAdReady && _bannerAd != null)
            ? SafeArea(
                top: false,
                child: Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: _bannerAd!.size.height.toDouble(),
                  color: Colors.white,
                  child: AdWidget(ad: _bannerAd!),
                ),
              )
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await _refreshPermissionStatus();
              await _loadAll();
              _refreshNow();
            },
            displacement: 36,
            edgeOffset: 6,
            color: const Color(0xFF111827),
            backgroundColor: Colors.white,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
              SliverPersistentHeader(
                pinned: false,
                floating: true,
                delegate: FixedHeaderDelegate(
                  height: 106,
                  child: _header(),
                ),
              ),
              SliverToBoxAdapter(child: _permissionStatusCard()),
              SliverToBoxAdapter(child: _notices()),
              SliverToBoxAdapter(child: _sectionTitle()),
              if (_items.isEmpty) SliverFillRemaining(hasScrollBody: false, child: _empty()) else _isCardView ? _cardGrid() : _listView(),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA).withOpacity(0.96),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
        child: Row(
          children: [
            _roundButton(Icons.menu, () => _scaffoldKey.currentState?.openDrawer()),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.of(context).appTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF111827), letterSpacing: -0.8)),
                  SizedBox(height: 2),
                  Text(L.of(context).subtitle, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            _roundButton(Icons.bolt_rounded, _showAppMenu),
          ],
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Icon(icon, size: 25, color: const Color(0xFF111827))),
      ),
    );
  }

  Widget _permissionStatusCard() {
    final l = L.of(context);
    final hasCriticalIssue = !_notificationPermissionOk;
    final hasWarning = !hasCriticalIssue && !_exactAlarmPermissionOk;
    final bgColor = hasCriticalIssue
        ? const Color(0xFFFFE7E7)
        : hasWarning
            ? const Color(0xFFFFF4DE)
            : const Color(0xFFEAF8EF);
    final borderColor = hasCriticalIssue
        ? const Color(0xFFFCA5A5)
        : hasWarning
            ? const Color(0xFFFCD34D)
            : const Color(0xFFBBF7D0);
    final accentColor = hasCriticalIssue
        ? const Color(0xFFEF4444)
        : hasWarning
            ? const Color(0xFFF59E0B)
            : const Color(0xFF16A34A);
    final title = hasCriticalIssue
        ? l.pick(ko: '알림 설정이 필요해요', en: 'Reminder setup needed', ja: '通知設定が必要です', vi: 'Cần cài đặt nhắc nhở')
        : hasWarning
            ? l.pick(ko: '정확한 알람을 확인해주세요', en: 'Check exact alarms', ja: '正確なアラームを確認', vi: 'Kiểm tra báo thức chính xác')
            : l.pick(ko: '알림이 정상 작동 중이에요', en: 'Reminders are working', ja: '通知は正常に動作中', vi: 'Nhắc nhở đang hoạt động');
    final statusText = hasCriticalIssue
        ? l.pick(ko: '확인 필요', en: 'Check', ja: '確認', vi: 'Kiểm tra')
        : hasWarning
            ? l.pick(ko: '주의', en: 'Check', ja: '注意', vi: 'Chú ý')
            : l.pick(ko: '정상', en: 'OK', ja: '正常', vi: 'Ổn');
    final subtitle = hasCriticalIssue
        ? l.pick(ko: '일정 알림을 받으려면 기본 알림 권한이 필요해요.', en: 'Notification permission is needed for reminders.', ja: '予定通知には通知権限が必要です。', vi: 'Cần quyền thông báo để nhận nhắc nhở.')
        : hasWarning
            ? l.pick(ko: '예약 알림을 정확히 울리려면 알람 권한을 확인해주세요.', en: 'Exact alarm permission helps reminders ring on time.', ja: '正確な通知にはアラーム権限を確認してください。', vi: 'Quyền báo thức giúp nhắc đúng giờ.')
            : l.pick(ko: '일정 알림과 오늘 요약이 준비되어 있어요.', en: 'Event reminders and today summary are ready.', ja: '予定通知と今日のまとめが準備できています。', vi: 'Nhắc lịch và tóm tắt hôm nay đã sẵn sàng.');

    Future<void> sendQuickTest() async {
      await NotificationService.showNow(
        id: 999777,
        title: l.pick(ko: 'TickDay 알림 테스트', en: 'TickDay test notification', ja: 'TickDay 通知テスト', vi: 'Thông báo thử TickDay'),
        body: l.pick(ko: '알림이 정상적으로 도착했어요.', en: 'Your notification arrived successfully.', ja: '通知が正常に届きました。', vi: 'Thông báo đã đến thành công.'),
        payload: '__today_summary__',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(16, 14, 16, _permissionCardExpanded ? 16 : 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.78), borderRadius: BorderRadius.circular(13)),
                  child: Icon(hasCriticalIssue ? Icons.notifications_off_rounded : Icons.verified_rounded, color: accentColor, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, height: 1.15, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.2)),
                      const SizedBox(height: 7),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.75), borderRadius: BorderRadius.circular(999)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 7, height: 7, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                                const SizedBox(width: 5),
                                Text(statusText, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: accentColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _permissionCardExpanded = !_permissionCardExpanded),
                    icon: Icon(_permissionCardExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18),
                    label: Text(_permissionCardExpanded ? l.pick(ko: '접기', en: 'Hide', ja: '閉じる', vi: 'Ẩn') : l.pick(ko: '상세 보기', en: 'Details', ja: '詳細', vi: 'Chi tiết'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.45), foregroundColor: const Color(0xFF374151), side: BorderSide(color: Colors.black.withOpacity(0.08)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: sendQuickTest,
                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    label: Text(l.pick(ko: '알림 테스트', en: 'Test', ja: 'テスト', vi: 'Thử'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ],
            ),
            if (_permissionCardExpanded) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: Colors.black.withOpacity(0.06)),
              const SizedBox(height: 8),
              _permissionRow(
                icon: Icons.notifications_none_rounded,
                title: l.pick(ko: '기본 알림', en: 'Basic notifications', ja: '基本通知', vi: 'Thông báo cơ bản'),
                ok: _notificationPermissionOk,
                okText: l.normal,
                badText: l.settingsNeeded,
                onTap: () => _showPermissionGuide(
                  title: l.pick(ko: '기본 알림 권한', en: 'Notification permission', ja: '通知権限', vi: 'Quyền thông báo'),
                  message: l.pick(ko: '일정 알림과 오늘 요약을 받으려면 앱 알림 권한이 필요합니다. 소리와 진동은 휴대폰 알림 설정에 따라 달라질 수 있어요.', en: 'Notification permission is required for event reminders and today summary. Sound and vibration depend on your phone notification settings.', ja: '予定通知と今日のまとめには通知権限が必要です。音と振動は端末の通知設定によって異なります。', vi: 'Cần quyền thông báo cho nhắc lịch và tóm tắt hôm nay. Âm thanh và rung phụ thuộc vào cài đặt điện thoại.'),
                  actionLabel: l.pick(ko: '알림 권한 확인', en: 'Check permission', ja: '権限を確認', vi: 'Kiểm tra quyền'),
                  onAction: () async {
                    await NotificationService.requestNotificationPermission();
                    await AppSettings.openAppSettings();
                  },
                ),
              ),
              _permissionRow(
                icon: Icons.alarm_rounded,
                title: l.pick(ko: '정확한 알람', en: 'Exact alarms', ja: '正確なアラーム', vi: 'Báo thức chính xác'),
                ok: _exactAlarmPermissionOk,
                okText: l.normal,
                badText: l.settingsNeeded,
                onTap: () => _showPermissionGuide(
                  title: l.pick(ko: '알람 및 리마인더 권한', en: 'Alarm & reminder permission', ja: 'アラームとリマインダー権限', vi: 'Quyền báo thức & nhắc nhở'),
                  message: l.pick(ko: '정확한 시간에 예약 알림을 울리려면 알람 및 리마인더 권한이 필요합니다.', en: 'Exact alarm permission helps reminders ring at the right time.', ja: '正確な時刻に通知するにはアラーム権限が必要です。', vi: 'Quyền báo thức giúp nhắc đúng giờ.'),
                  actionLabel: l.pick(ko: '설정 열기', en: 'Open settings', ja: '設定を開く', vi: 'Mở cài đặt'),
                  onAction: () async {
                    await NotificationService.requestExactAlarmPermission();
                    await AppSettings.openAppSettings();
                  },
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _refreshPermissionStatus,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l.pick(ko: '상태 새로고침', en: 'Refresh status', ja: '状態を更新', vi: 'Làm mới trạng thái'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _permissionRow({
    required IconData icon,
    required String title,
    required bool ok,
    required String okText,
    required String badText,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    final statusColor = muted ? const Color(0xFFF59E0B) : (ok ? const Color(0xFF16A34A) : const Color(0xFFEF4444));
    final statusText = muted ? badText : (ok ? okText : badText);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF6B7280)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Future<void> _showPermissionGuide({
    required String title,
    required String message,
    required String actionLabel,
    required Future<void> Function() onAction,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.info_outline_rounded, color: Color(0xFF111827)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
                ],
              ),
              const SizedBox(height: 14),
              Text(message, style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(L.of(context).later, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await onAction();
                        await Future<void>.delayed(const Duration(milliseconds: 300));
                        await _refreshPermissionStatus();
                      },
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111827), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notices() {
    if (_items.isNotEmpty) return const SizedBox.shrink();

    final notices = <Widget>[];

    if (!_hideIntroNotice) {
      notices.add(_noticeCard(
        L.of(context).pick(ko: '첫 소중한 날을 기록해보세요', en: 'Save your first special day', ja: '最初の大切な日を記録しましょう', vi: 'Lưu ngày quan trọng đầu tiên'),
        L.of(context).pick(ko: '생일, 기념일, 여행까지 한눈에 관리하세요.', en: 'Track birthdays, anniversaries, trips and more.', ja: '誕生日や記念日、旅行まで一目で管理。', vi: 'Theo dõi sinh nhật, kỷ niệm, chuyến đi và hơn thế nữa.'),
        Icons.event_available,
        () => _setNoticeHidden(_hideIntroKey, true),
        backgroundColor: const Color(0xFFFFF7D6),
        iconBackgroundColor: const Color(0xFFFFF1B8),
        iconColor: const Color(0xFFF59E0B),
      ));
    }
    if (!_hideWidgetNotice) {
      notices.add(_noticeCard(
        L.of(context).pick(ko: '홈 화면에서 바로 확인하세요', en: 'Check it on your home screen', ja: 'ホーム画面ですぐ確認', vi: 'Xem ngay trên màn hình chính'),
        L.of(context).pick(ko: '가까운 D-day를 위젯으로 한눈에 볼 수 있어요.', en: 'See upcoming D-days at a glance with widgets.', ja: '近いD-dayをウィジェットで一目で確認できます。', vi: 'Xem nhanh các D-day sắp tới bằng widget.'),
        Icons.widgets,
        () => _setNoticeHidden(_hideWidgetKey, true),
        backgroundColor: const Color(0xFFEAF7F0),
        iconBackgroundColor: const Color(0xFFDDF3E8),
        iconColor: const Color(0xFF22C55E),
      ));
    }

    if (notices.isEmpty) return const SizedBox.shrink();

    if (notices.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
        child: SizedBox(height: 124, child: notices.first),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SizedBox(height: 124, child: notices[0])),
          const SizedBox(width: 12),
          Expanded(child: SizedBox(height: 124, child: notices[1])),
        ],
      ),
    );
  }

  Widget _noticeCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onClose, {
    Color backgroundColor = Colors.white,
    Color iconBackgroundColor = const Color(0xFFF3F4F6),
    Color iconColor = const Color(0xFF111827),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.018), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: iconBackgroundColor, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 16),
            ),
          ),
          Positioned(
            top: -5,
            right: -6,
            child: SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 18),
              ),
            ),
          ),
          Positioned.fill(
            top: 33,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: const TextStyle(fontSize: 12.1, height: 1.15, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: const TextStyle(fontSize: 9.8, height: 1.18, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.of(context).myEvents,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: Color(0xFF111827), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showSortPicker,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.tune_rounded, color: Color(0xFF111827), size: 18),
                  label: Text(
                    _sortText(_sortType),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleViewMode,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(_isCardView ? Icons.view_list_rounded : Icons.grid_view_rounded, color: const Color(0xFF111827), size: 19),
                  label: Text(
                    _isCardView ? L.of(context).list : L.of(context).card,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 86, height: 86, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)), child: const Icon(Icons.add_task, size: 42, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 18),
            Text(L.of(context).emptyTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(L.of(context).emptySubtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _cardGrid() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 36 : 24),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) => _ddayCard(_items[index]), childCount: _items.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 18,
          mainAxisSpacing: isLandscape ? 14 : 14,
          mainAxisExtent: isLandscape ? 132 : null,
          childAspectRatio: isLandscape ? 2.35 : 0.82,
        ),
      ),
    );
  }

  Widget _ddayCard(DdayItem item) {
    final color = Color(item.colorValue);
    final days = _daysLeft(item);
    final progress = _progress(item);
    final left = _timeLeft(item);
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final radius = isLandscape ? 14.0 : 18.0;
    final cardPadding = isLandscape
        ? const EdgeInsets.fromLTRB(12, 8, 10, 8)
        : const EdgeInsets.fromLTRB(14, 11, 12, 8);
    final ddaySize = isLandscape ? 27.0 : 30.0;
    final titleSize = isLandscape ? 12.8 : 13.2;
    final subtitleSize = isLandscape ? 10.3 : 11.2;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          onTap: () => _showDetail(item),
          child: Stack(
            children: [
              Padding(
                padding: cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: isLandscape ? 26 : 30,
                          height: isLandscape ? 26 : 30,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.11),
                            borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),
                          ),
                          child: Icon(_iconData(item.icon), size: isLandscape ? 15 : 17, color: color),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: isLandscape ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    height: 1.12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                    letterSpacing: -0.35,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _fullDate(_effectiveTarget(item)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: subtitleSize,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF7C8493),
                                        ),
                                      ),
                                    ),
                                    if (item.repeatType == 'yearly') ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: isLandscape ? 4 : 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          L.of(context).repeatYearly,
                                          style: TextStyle(fontSize: isLandscape ? 8.2 : 9.0, fontWeight: FontWeight.w700, color: color),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isLandscape ? 7 : 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _dDayText(item),
                        style: TextStyle(
                          fontSize: ddaySize,
                          height: 0.95,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: -1.1,
                        ),
                      ),
                    ),
                    SizedBox(height: isLandscape ? 2 : 4),
                    Text(
                      _cardEmotionLine(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isLandscape ? 10.4 : 12.2,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4B5563),
                        letterSpacing: -0.25,
                      ),
                    ),
                    SizedBox(height: isLandscape ? 5 : 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: isLandscape ? 4 : 6,
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFEFF3F9),
                        valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.88)),
                      ),
                    ),
                    if (!isLandscape) ...[
                      const SizedBox(height: 5),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.065),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 13, color: color.withOpacity(0.76)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _cardEmotionLine(item),
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 10.6,
                                  fontWeight: FontWeight.w700,
                                  color: color.withOpacity(0.86),
                                  letterSpacing: -0.25,
                                ),
                              ),
                            ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 5,
                right: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showItemMenu(item),
                  child: const SizedBox(
                    width: 26,
                    height: 30,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.more_vert, color: Color(0xFF9CA3AF), size: 19),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final color = Color(item.colorValue);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showDetail(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(_iconData(item.icon), color: color, size: 24)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)), const SizedBox(height: 4), Text('${_fullDate(_effectiveTarget(item))} · ${_remainText(item)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))])),
                      Text(L.of(context).pick(ko: '${_daysLeft(item)}일', en: 'D-${_daysLeft(item)}', ja: 'あと${_daysLeft(item)}日', vi: 'Còn ${_daysLeft(item)} ngày'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                      IconButton(onPressed: () => _showItemMenu(item), icon: const Icon(Icons.more_vert, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const FixedHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant FixedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final safeProgress = progress.clamp(0.0, 1.0);

    final bg = Paint()
      ..color = const Color(0xFFEFF3F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = color.withOpacity(0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final endFade = Paint()
      ..color = Colors.white.withOpacity(0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bg);

    // 실제 진행률은 그대로 사용하되, 등록 직후처럼 아주 작은 진행률도
    // 사용자가 알아볼 수 있도록 최소한의 색 점은 항상 보여줍니다.
    if (safeProgress >= 0.0) {
      final sweep = math.pi * 2 * safeProgress;
      if (sweep > 0.02) {
        canvas.drawArc(rect, -math.pi / 2, sweep, false, fg);
      }

      if (sweep > 0.35) {
        canvas.drawArc(rect, -math.pi / 2 + sweep - 0.16, 0.14, false, endFade);
      }

      final angle = -math.pi / 2 + sweep;
      final dot = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawCircle(dot, 6.0, Paint()..color = Colors.white);
      canvas.drawCircle(dot, 4.4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}

class _FirstCardCelebrationOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onDone;

  const _FirstCardCelebrationOverlay({required this.message, required this.onDone});

  @override
  State<_FirstCardCelebrationOverlay> createState() => _FirstCardCelebrationOverlayState();
}

class _FirstCardCelebrationOverlayState extends State<_FirstCardCelebrationOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List<_ConfettiParticle>.generate(34, (index) => _ConfettiParticle(index));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDone();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final fade = t < 0.72 ? 1.0 : (1.0 - ((t - 0.72) / 0.28)).clamp(0.0, 1.0).toDouble();
            final scale = 0.86 + (0.14 * Curves.elasticOut.transform(t.clamp(0.0, 1.0).toDouble()));

            return Stack(
              fit: StackFit.expand,
              children: [
                ..._particles.map((p) => p.build(context, t, fade)),
                Align(
                  alignment: const Alignment(0, -0.08),
                  child: Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.16),
                              blurRadius: 34,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.celebration_rounded, color: Color(0xFF9333EA), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                widget.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.28,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  final int index;
  late final double _xSeed;
  late final double _ySeed;
  late final double _angleSeed;
  late final double _size;
  late final IconData _icon;
  late final Color _color;

  _ConfettiParticle(this.index) {
    final random = math.Random(index * 9973 + 17);
    _xSeed = random.nextDouble();
    _ySeed = random.nextDouble();
    _angleSeed = random.nextDouble();
    _size = 11 + random.nextDouble() * 13;
    _icon = const [
      Icons.star_rounded,
      Icons.favorite_rounded,
      Icons.circle,
      Icons.auto_awesome_rounded,
      Icons.celebration_rounded,
    ][index % 5];
    _color = const [
      Color(0xFF9333EA),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
      Color(0xFF22C55E),
      Color(0xFF3B82F6),
    ][index % 5];
  }

  Widget build(BuildContext context, double t, double fade) {
    final size = MediaQuery.of(context).size;
    final normalized = t.clamp(0.0, 1.0).toDouble();
    final curved = Curves.easeOutCubic.transform(normalized);
    final leftStart = size.width * 0.5;
    final topStart = size.height * 0.38;
    final direction = _xSeed < 0.5 ? -1.0 : 1.0;
    final spreadX = (40 + (_xSeed * size.width * 0.72)) * direction;
    final fallY = 42 + (_ySeed * size.height * 0.34);
    final riseY = 82 + (_ySeed * 90);

    final left = leftStart + (spreadX * curved);
    final wave = math.sin(normalized * math.pi).clamp(0.0, 1.0).toDouble();
    final top = topStart - (riseY * wave) + (fallY * normalized);
    final rotation = (_angleSeed * 8.0) + (normalized * 8.0 * direction);

    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: fade,
        child: Transform.rotate(
          angle: rotation,
          child: Icon(_icon, size: _size, color: _color),
        ),
      ),
    );
  }
}


class TrashPage extends StatefulWidget {
  final List<DdayItem> items;
  final Future<void> Function(DdayItem item) onRestore;
  final Future<void> Function(DdayItem item) onDeleteForever;
  final Future<void> Function() onEmpty;

  const TrashPage({
    super.key,
    required this.items,
    required this.onRestore,
    required this.onDeleteForever,
    required this.onEmpty,
  });

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  late final List<DdayItem> _items = List<DdayItem>.from(widget.items);

  IconData _trashIconData(String key) {
    switch (key) {
      case 'heart':
        return Icons.favorite_rounded;
      case 'cake':
        return Icons.cake_rounded;
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'camera':
        return Icons.camera_alt_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'cart':
        return Icons.shopping_cart_rounded;
      case 'coffee':
        return Icons.local_cafe_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'star':
      default:
        return Icons.star_rounded;
    }
  }

  String _dateText(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  Future<void> _confirmDeleteForever(DdayItem item) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l.pick(ko: '완전히 삭제할까요?', en: 'Delete forever?', ja: '完全に削除しますか？', vi: 'Xóa vĩnh viễn?')),
        content: Text(l.pick(
          ko: '「${item.title}」 일정은 복구할 수 없어요.',
          en: '“${item.title}” cannot be restored.',
          ja: '「${item.title}」は復元できません。',
          vi: 'Không thể khôi phục “${item.title}”.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await widget.onDeleteForever(item);
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e.id == item.id));
  }

  Future<void> _confirmEmptyTrash() async {
    if (_items.isEmpty) return;
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l.pick(ko: '휴지통을 비울까요?', en: 'Empty trash?', ja: 'ゴミ箱を空にしますか？', vi: 'Dọn thùng rác?')),
        content: Text(
	  l.pick(
	    ko: '휴지통에 있는 모든 일정이 영구 삭제됩니다.',
	    en: 'All events in the trash will be permanently deleted.',
	    ja: 'ゴミ箱内のすべての予定が完全に削除されます。',
	    vi: 'Tất cả sự kiện trong thùng rác sẽ bị xóa vĩnh viễn.',
	  ),
	),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.pick(ko: '비우기', en: 'Empty', ja: '空にする', vi: 'Dọn'))),
        ],
      ),
    );
    if (ok != true) return;
    await widget.onEmpty();
    if (!mounted) return;
    setState(() => _items.clear());
  }

  Future<void> _restore(DdayItem item) async {
    await widget.onRestore(item);
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e.id == item.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        title: Text(l.pick(ko: '휴지통', en: 'Trash', ja: 'ゴミ箱', vi: 'Thùng rác'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _confirmEmptyTrash,
              child: Text(l.pick(ko: '비우기', en: 'Empty', ja: '空にする', vi: 'Dọn'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: SafeArea(
        child: _items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                        child: const Icon(Icons.delete_outline_rounded, size: 38, color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 18),
                      Text(l.pick(ko: '휴지통이 비어 있어요', en: 'Trash is empty', ja: 'ゴミ箱は空です', vi: 'Thùng rác trống'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                      const SizedBox(height: 8),
                      Text(l.pick(ko: '삭제한 일정은 이곳에서 복구할 수 있어요.', en: 'Deleted events can be restored here.', ja: '削除した予定はここで復元できます。', vi: 'Sự kiện đã xóa có thể khôi phục tại đây.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final color = Color(item.colorValue);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                          child: Icon(_trashIconData(item.icon), color: color, size: 23),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title.trim().isEmpty ? l.titleNone : item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                              const SizedBox(height: 4),
                              Text(_dateText(item.targetDate), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l.pick(ko: '복구', en: 'Restore', ja: '復元', vi: 'Khôi phục'),
                          onPressed: () => _restore(item),
                          icon: const Icon(Icons.restore_rounded, color: Color(0xFF059669)),
                        ),
                        IconButton(
                          tooltip: l.delete,
                          onPressed: () => _confirmDeleteForever(item),
                          icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class EditPage extends StatefulWidget {
  final DdayItem? item;
  const EditPage({super.key, this.item});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _softIcon = Color(0xFF9CA3AF);
  static const _line = Color(0xFFE5E7EB);
  static const _saveBlue = Color(0xFF2563EB);

  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late DateTime _date;
  late TimeOfDay _time;
  late String _repeatType;
  late String _icon;
  late Color _color;
  late int _alarmMinutesBefore;
  late bool _alarmEnabled;

  final _icons = const [
    'star', 'heart', 'cake', 'flight', 'school',
    'work', 'home', 'pets', 'music', 'gift',
    'camera', 'car', 'cart', 'coffee', 'fitness',
  ];

  final _colors = const [
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFF59E0B), // amber
    Color(0xFF22C55E), // green
    Color(0xFF06B6D4), // cyan
    Color(0xFF3B82F6), // blue
    Color(0xFF6366F1), // indigo
    Color(0xFF8B5CF6), // violet
    Color(0xFFA855F7), // purple
    Color(0xFFEC4899), // pink
    Color(0xFFF43F5E), // rose
    Color(0xFF14B8A6), // teal
    Color(0xFF84CC16), // lime
    Color(0xFF64748B), // slate
    Color(0xFF111827), // black
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _memoController = TextEditingController(text: item?.memo ?? '');
    _date = item?.targetDate ?? DateTime.now().add(const Duration(days: 1));
    _time = item?.targetTime ?? const TimeOfDay(hour: 9, minute: 0);
    _repeatType = item?.repeatType ?? 'none';
    _icon = item?.icon ?? 'star';
    _color = Color(item?.colorValue ?? const Color(0xFF111827).value);
    _alarmMinutesBefore = item?.alarmMinutesBefore ?? 1440;
    if (item == null) {
      unawaited(_loadDefaultAlarmSetting());
    }
    _alarmEnabled = _alarmMinutesBefore != -1;
    if (_alarmMinutesBefore == -1) {
      _alarmMinutesBefore = 1440;
    }
  }

  Future<void> _loadDefaultAlarmSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultMinutes = prefs.getInt(_defaultAlarmMinutesKey) ?? 1440;
    if (!mounted) return;
    setState(() {
      _alarmMinutesBefore = defaultMinutes;
      _alarmEnabled = defaultMinutes != -1;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  IconData _iconData(String key) {
    switch (key) {
      case 'heart':
        return Icons.favorite;
      case 'cake':
        return Icons.cake;
      case 'flight':
        return Icons.flight_takeoff;
      case 'school':
        return Icons.school;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'pets':
        return Icons.pets;
      case 'music':
        return Icons.music_note;
      case 'gift':
        return Icons.card_giftcard;
      case 'camera':
        return Icons.photo_camera;
      case 'car':
        return Icons.directions_car;
      case 'cart':
        return Icons.shopping_cart;
      case 'coffee':
        return Icons.local_cafe;
      case 'fitness':
        return Icons.fitness_center;
      default:
        return Icons.star;
    }
  }

  String _fullDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)}';
  }

  String _timeText(TimeOfDay time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }

  String _repeatText(String type) => type == 'yearly' ? L.of(context).yearlyRepeat : L.of(context).noRepeat;

  String _alarmText(int minutes) {
    final l = L.of(context);
    switch (minutes) {
      case -1:
        return l.pick(ko: '알림 안 함', en: 'No reminder', ja: '通知なし', vi: 'Không nhắc');
      case -2:
        return l.pick(ko: '당일 오전 9시', en: 'Same day 9 AM', ja: '当日午前9時', vi: '9 giờ sáng cùng ngày');
      case 0:
        return l.pick(ko: '정각 알림', en: 'At event time', ja: '予定時刻', vi: 'Đúng giờ sự kiện');
      case 60:
        return l.pick(ko: '1시간 전', en: '1 hour before', ja: '1時間前', vi: 'Trước 1 giờ');
      case 180:
        return l.pick(ko: '3시간 전', en: '3 hours before', ja: '3時間前', vi: 'Trước 3 giờ');
      case 360:
        return l.pick(ko: '6시간 전', en: '6 hours before', ja: '6時間前', vi: 'Trước 6 giờ');
      case 720:
        return l.pick(ko: '12시간 전', en: '12 hours before', ja: '12時間前', vi: 'Trước 12 giờ');
      case 1440:
        return l.pick(ko: '하루 전', en: '1 day before', ja: '1日前', vi: 'Trước 1 ngày');
      case 2880:
        return l.pick(ko: '2일 전', en: '2 days before', ja: '2日前', vi: 'Trước 2 ngày');
      case 10080:
        return l.pick(ko: '일주일 전', en: '1 week before', ja: '1週間前', vi: 'Trước 1 tuần');
      default:
        if (minutes > 0 && minutes % 1440 == 0) return l.pick(ko: '${minutes ~/ 1440}일 전', en: '${minutes ~/ 1440} days before', ja: '${minutes ~/ 1440}日前', vi: 'Trước ${minutes ~/ 1440} ngày');
        if (minutes > 0 && minutes % 60 == 0) return l.pick(ko: '${minutes ~/ 60}시간 전', en: '${minutes ~/ 60} hours before', ja: '${minutes ~/ 60}時間前', vi: 'Trước ${minutes ~/ 60} giờ');
        return l.pick(ko: '알림 설정', en: 'Reminder setting', ja: '通知設定', vi: 'Cài đặt nhắc nhở');
    }
  }

  int _daysUntil() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(_date.year, _date.month, _date.day);
    return target.difference(today).inDays;
  }

  String _editDdayText() {
    final days = _daysUntil();
    if (days == 0) return 'D-Day';
    return 'D-${days.abs()}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _showRepeatPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.of(context).pick(ko: '반복 설정', en: 'Repeat settings', ja: '繰り返し設定', vi: 'Cài đặt lặp lại'), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 10),
                  _repeatOption('none', L.of(context).noRepeat, L.of(context).pick(ko: '한 번만 카운트다운', en: 'Countdown only once', ja: '一度だけカウントダウン', vi: 'Chỉ đếm ngược một lần')),
                  _repeatOption('yearly', L.of(context).yearlyRepeat, L.of(context).pick(ko: '생일, 결혼기념일처럼 매년 반복', en: 'For birthdays and anniversaries', ja: '誕生日や記念日のように毎年繰り返し', vi: 'Dành cho sinh nhật, kỷ niệm')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _repeatOption(String value, String label, String desc) {
    final selected = _repeatType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() => _repeatType = value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? _ink : _line, width: selected ? 7 : 2),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 3),
                  Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlarmPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            void updateAlarmState(VoidCallback change) {
              setState(change);
              modalSetState(() {});
            }

            Widget alarmOption(int value, String label, String desc) {
              final selected = _alarmEnabled && _alarmMinutesBefore == value;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  updateAlarmState(() {
                    _alarmEnabled = true;
                    _alarmMinutesBefore = value;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? _saveBlue : _line, width: selected ? 7 : 2),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                            const SizedBox(height: 3),
                            Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 32, offset: const Offset(0, 14))],
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.78,
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(L.of(context).pick(ko: '알림 설정', en: 'Reminder settings', ja: '通知設定', vi: 'Cài đặt nhắc nhở'), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _ink))),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, color: _softIcon, size: 26),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _alarmSwitchTile(
                            onChanged: (v) {
                              updateAlarmState(() {
                                _alarmEnabled = v;
                                if (v && _alarmMinutesBefore == -1) {
                                  _alarmMinutesBefore = 1440;
                                }
                                if (!v) {
                                  _alarmMinutesBefore = -1;
                                }
                              });
                            },
                          ),
                          if (_alarmEnabled) ...[
                            const Divider(height: 20, color: _line),
                            alarmOption(-2, _alarmText(-2), L.of(context).pick(ko: '일정 당일 아침에 미리 알림', en: 'Remind me on the morning of the event', ja: '予定当日の朝に通知', vi: 'Nhắc vào sáng ngày sự kiện')),
                            alarmOption(0, _alarmText(0), L.of(context).pick(ko: '일정 시간이 되었을 때', en: 'When the event time arrives', ja: '予定時刻になったとき', vi: 'Khi đến giờ sự kiện')),
                            alarmOption(60, _alarmText(60), L.of(context).pick(ko: '중요한 약속 직전 알림', en: 'A quick reminder before an important event', ja: '大切な予定の直前に通知', vi: 'Nhắc ngay trước sự kiện quan trọng')),
                            alarmOption(1440, _alarmText(1440), L.of(context).pick(ko: '기념일 전날 미리 알림', en: 'A day-before reminder', ja: '記念日の前日に通知', vi: 'Nhắc trước một ngày')),
                            alarmOption(2880, _alarmText(2880), L.of(context).pick(ko: '준비가 필요한 일정', en: 'For events that need preparation', ja: '準備が必要な予定', vi: 'Cho sự kiện cần chuẩn bị')),
                            alarmOption(10080, _alarmText(10080), L.of(context).pick(ko: '여행, 시험, 큰 일정', en: 'For trips, exams, and big events', ja: '旅行、試験、大きな予定に', vi: 'Cho chuyến đi, kỳ thi, sự kiện lớn')),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: _saveBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              child: Text(L.of(context).done, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _alarmSwitchTile({required ValueChanged<bool> onChanged}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(!_alarmEnabled),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.of(context).pick(ko: '알림 사용', en: 'Use reminders', ja: '通知を使用', vi: 'Dùng nhắc nhở'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 3),
                  Text(_alarmEnabled ? _alarmText(_alarmMinutesBefore) : L.of(context).pick(ko: '알림을 보내지 않음', en: 'No reminder will be sent', ja: '通知を送信しません', vi: 'Không gửi nhắc nhở'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
                ],
              ),
            ),
            Switch(
              value: _alarmEnabled,
              activeColor: _saveBlue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _alarmOption(int value, String label, String desc) {
    final selected = _alarmMinutesBefore == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() => _alarmMinutesBefore = value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? _saveBlue : _line, width: selected ? 7 : 2),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 3),
                  Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.of(context).pick(ko: '제목을 입력해주세요.', en: 'Please enter a title.', ja: 'タイトルを入力してください。', vi: 'Vui lòng nhập tiêu đề.'))));
      return;
    }
    final old = widget.item;
    final item = DdayItem(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      targetDate: _date,
      targetTime: _time,
      repeatType: _repeatType,
      icon: _icon,
      colorValue: _color.value,
      createdAt: old?.createdAt ?? DateTime.now(),
      memo: _memoController.text.trim(),
      alarmMinutesBefore: _alarmEnabled ? _alarmMinutesBefore : -1,
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(isEdit),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _previewCard(),
                    const SizedBox(height: 16),
                    _titleBox(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _selectCard(Icons.calendar_month, L.of(context).date, _fullDate(_date), _pickDate)),
                        const SizedBox(width: 12),
                        Expanded(child: _selectCard(Icons.schedule, L.of(context).time, _timeText(_time), _pickTime)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _wideSelectCard(Icons.repeat, L.of(context).repeat, _repeatText(_repeatType), _showRepeatPicker),
                    const SizedBox(height: 12),
                    _wideSelectCard(Icons.notifications_none_rounded, L.of(context).reminder, _alarmEnabled ? _alarmText(_alarmMinutesBefore) : L.of(context).pick(ko: '알림 안 함', en: 'No reminder', ja: '通知なし', vi: 'Không nhắc'), _showAlarmPicker),
                    const SizedBox(height: 12),
                    _memoBox(),
                    const SizedBox(height: 22),
                    _sectionLabel(L.of(context).decorate),
                    const SizedBox(height: 12),
                    _decorBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(L.of(context).icon, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _muted)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: _icons.map((e) => _iconChip(e)).toList()),
                          const SizedBox(height: 18),
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: Text(L.of(context).color, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _muted))),
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [BoxShadow(color: _color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(spacing: 12, runSpacing: 12, children: _colors.map((e) => _colorChip(e)).toList()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(bool isEdit) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 20, 10),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 29, color: Color(0xFF4B5563))),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              isEdit ? L.of(context).editEvent : L.of(context).newEvent,
              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.8),
            ),
          ),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: _saveBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(L.of(context).save, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final title = _titleController.text.trim().isEmpty ? L.of(context).titleFallback : _titleController.text.trim();
    final days = _daysUntil();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return AnimatedBuilder(
      animation: _titleController,
      builder: (context, _) {
        final isTitleEmpty = _titleController.text.trim().isEmpty;
        final liveTitle = isTitleEmpty ? L.of(context).titleFallback : _titleController.text.trim();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(19)),
                child: Icon(_iconData(_icon), color: const Color(0xFF4B5563), size: 30),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_editDdayText(), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _color, letterSpacing: -0.5)),
                    SizedBox(height: isLandscape ? 2 : 4),
                    Text(liveTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isTitleEmpty ? const Color(0xFFB7BDC8) : _ink, letterSpacing: -0.5)),
                    const SizedBox(height: 5),
                    Text('${_fullDate(_date)} · ${_timeText(_time)} · ${_repeatText(_repeatType)} · ${_alarmEnabled ? _alarmText(_alarmMinutesBefore) : L.of(context).pick(ko: '알림 안 함', en: 'No reminder', ja: '通知なし', vi: 'Không nhắc')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _muted)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _titleBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
      child: Row(
        children: [
          Icon(_iconData(_icon), color: _softIcon, size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
              decoration: InputDecoration(hintText: L.of(context).titleFallback, hintStyle: TextStyle(color: Color(0xFFB7BDC8), fontWeight: FontWeight.w700), border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectCard(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
        child: Row(
          children: [
            Icon(icon, color: _softIcon, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _muted)),
                  const SizedBox(height: 4),
                  Text(value, maxLines: 1, overflow: TextOverflow.visible, softWrap: false, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideSelectCard(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
        child: Row(
          children: [
            Icon(icon, color: _softIcon, size: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _muted)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _softIcon),
          ],
        ),
      ),
    );
  }

  Widget _memoBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 18), child: Icon(Icons.notes, color: _softIcon, size: 23)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _memoController,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
              decoration: InputDecoration(hintText: L.of(context).memo, hintStyle: TextStyle(color: Color(0xFFB7BDC8), fontWeight: FontWeight.w700), border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.3)),
    );
  }

  Widget _decorBox({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line)),
      child: child,
    );
  }

  Widget _iconChip(String key) {
    final selected = _icon == key;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _icon = key),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _ink : _line, width: selected ? 1.7 : 1),
        ),
        child: Icon(_iconData(key), color: selected ? _ink : const Color(0xFF4B5563), size: 22),
      ),
    );
  }

  Widget _colorChip(Color color) {
    final selected = _color.value == color.value;
    return AnimatedScale(
      scale: selected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _color = color),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? color : _line, width: selected ? 2 : 1),
            boxShadow: selected
                ? [BoxShadow(color: color.withOpacity(0.28), blurRadius: 12, offset: const Offset(0, 6))]
                : null,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : null,
          ),
        ),
      ),
    );
  }
}