import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_settings/app_settings.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;


const String _localePrefsKey = 'tickday_locale';
const String _splashSeenPrefsKey = 'tickday_splash_seen';
const String _globalReminderEnabledKey = 'tickday_global_reminder_enabled';
const String _defaultAlarmMinutesKey = 'tickday_default_alarm_minutes';
const String _todaySummaryEnabledKey = 'tickday_today_summary_enabled';
const String _widgetPinnedItemIdKey = 'tickday_widget_pinned_item_id';
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

  static Future<void> requestExactAlarmPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestExactAlarmsPermission();
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
  }) async {
    if (!scheduledAt.isAfter(DateTime.now())) return false;

    // 같은 ID로 이미 예약된 알림이 남아 있으면 기기/OS에 따라 새 예약이
    // 씹히는 경우가 있어 먼저 취소 후 다시 예약합니다.
    await _plugin.cancel(id);

    final scheduled = tz.TZDateTime.from(scheduledAt, tz.local);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } on PlatformException {
      // 정확한 알람 권한이 잠깐 꺼졌거나 Android가 exact alarm을 거부하는 경우
      // 앱이 완전히 실패하지 않도록 일반 예약 알림으로 한 번 더 시도합니다.
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          _details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        return true;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel(int id) async => _plugin.cancel(id);
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

  static void dispose() {
    _onItemId = null;
    _channel.setMethodCallHandler(null);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const DdayApp());
}

class DdayApp extends StatefulWidget {
  const DdayApp({super.key});

  @override
  State<DdayApp> createState() => _DdayAppState();
}

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

  @override
  void initState() {
    super.initState();
    _checkSplash();
  }

  Future<void> _checkSplash() async {
    // TickDay는 실행 시 짧은 준비 화면을 보여주는 구조가 더 자연스러워서
    // 이전 실행 여부와 관계없이 매번 스플래시를 표시합니다.
    if (!mounted) return;
    setState(() => _showSplash = true);
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
      return TickDaySplashScreen(onDone: _finishSplash);
    }
    return const HomePage();
  }
}

class TickDaySplashScreen extends StatefulWidget {
  final Future<void> Function() onDone;
  const TickDaySplashScreen({super.key, required this.onDone});

  @override
  State<TickDaySplashScreen> createState() => _TickDaySplashScreenState();
}

class _TickDaySplashScreenState extends State<TickDaySplashScreen> with SingleTickerProviderStateMixin {
  int _index = 0;
  Timer? _timer;
  late final AnimationController _iconController;

  List<String> _messages(BuildContext context) {
    final l = L.of(context);
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
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) return;
      final count = _messages(context).length;
      if (_index < count - 1) {
        setState(() => _index++);
      } else {
        timer.cancel();
        Future<void>.delayed(const Duration(milliseconds: 700), widget.onDone);
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
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [BoxShadow(color: const Color(0xFF111827).withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 14))],
                    ),
                    child: AnimatedBuilder(
                      animation: _iconController,
                      builder: (context, child) {
                        final value = _iconController.value;
                        final scale = 0.94 + (value * 0.10);
                        final angle = (value - 0.5) * 0.10;
                        return Transform.rotate(
                          angle: angle,
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: Icon(_splashIcon(_index), key: ValueKey<int>(_index), size: 58, color: const Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text('TickDay', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -0.8)),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero).animate(animation), child: child),
                    ),
                    child: Text(
                      messages[_index],
                      key: ValueKey<int>(_index),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF111827))),
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _itemsKey = 'dday_items';
  static const _hideIntroKey = 'hide_intro_notice';
  static const _hideWidgetKey = 'hide_widget_notice';

  final List<DdayItem> _items = [];
  bool _isCardView = true;
  String _sortType = 'timeLeft'; // timeLeft, createdAt, title, icon, repeat
  bool _hideIntroNotice = false;
  bool _hideWidgetNotice = false;
  bool _notificationPermissionOk = false;
  bool _exactAlarmPermissionOk = false;
  bool _permissionCardExpanded = false;
  bool _globalReminderEnabled = true;
  bool _todaySummaryEnabled = false;
  int _defaultAlarmMinutesBefore = 1440;
  String? _widgetPinnedItemId;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _clockTimer;
  String? _pendingNotificationItemId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onNotificationClick = _handleNotificationPayload;
    WidgetDeepLinkService.init(_handleWidgetItemId);
    _pendingNotificationItemId = NotificationService.takeLaunchPayload();
    unawaited(_loadInitialWidgetItemId());
    _loadAll(rescheduleNotifications: true);
    _refreshPermissionStatus();
    _startClockTimer();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    if (NotificationService.onNotificationClick == _handleNotificationPayload) {
      NotificationService.onNotificationClick = null;
    }
    WidgetDeepLinkService.dispose();
    WidgetsBinding.instance.removeObserver(this);
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

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _refreshNow();
    });
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
    if (payload.isEmpty || payload == '__test__' || payload == '__today_summary__') return;
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
    final id = _pendingNotificationItemId;
    if (id == null || id.isEmpty || !mounted) return;

    DdayItem? targetItem;
    for (final item in _items) {
      if (item.id == id) {
        targetItem = item;
        break;
      }
    }

    if (targetItem == null) return;
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

    setState(() {
      _items
        ..clear()
        ..addAll(loaded);
      _sortItems();
      _hideIntroNotice = prefs.getBool(_hideIntroKey) ?? false;
      _hideWidgetNotice = prefs.getBool(_hideWidgetKey) ?? false;
      _globalReminderEnabled = prefs.getBool(_globalReminderEnabledKey) ?? true;
      _todaySummaryEnabled = prefs.getBool(_todaySummaryEnabledKey) ?? false;
      _defaultAlarmMinutesBefore = prefs.getInt(_defaultAlarmMinutesKey) ?? 1440;
      _widgetPinnedItemId = prefs.getString(_widgetPinnedItemIdKey);
    });

    _openPendingNotificationItem();
    await _updateHomeWidget();

    if (rescheduleNotifications) {
      await _rescheduleAllNotifications();
      await _scheduleTodaySummaryNotification();
    }
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_itemsKey, _items.map((e) => jsonEncode(e.toJson())).toList());
  }


  DdayItem? _nearestWidgetItem() {
    final items = _nearestWidgetItems(1);
    return items.isEmpty ? null : items.first;
  }

  List<DdayItem> _nearestWidgetItems(int count) {
    if (_items.isEmpty) return <DdayItem>[];

    final upcoming = List<DdayItem>.from(_items)
      ..sort((a, b) => _effectiveTarget(a).compareTo(_effectiveTarget(b)));

    // 위젯은 사용자가 마지막으로 저장/수정한 일정을 우선 표시합니다.
    // 이전에는 가장 가까운 일정만 자동 선택해서, 예전 일정(예: 결혼기념일)이 계속 보이는 것처럼 느껴질 수 있었습니다.
    final pinnedId = _widgetPinnedItemId;
    if (pinnedId != null && pinnedId.isNotEmpty) {
      final pinnedIndex = upcoming.indexWhere((item) => item.id == pinnedId);
      if (pinnedIndex >= 0) {
        final pinned = upcoming.removeAt(pinnedIndex);
        upcoming.insert(0, pinned);
      }
    }

    return upcoming.take(count).toList();
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

  Future<void> _updateHomeWidget() async {
    try {
      final widgetItems = _nearestWidgetItems(2);
      final item = widgetItems.isEmpty ? null : widgetItems.first;

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
      _widgetPinnedItemId = item.id;
      _sortItems();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_widgetPinnedItemIdKey, item.id);

    await _saveItems();
    await _updateHomeWidget();
    await _scheduleNotifications(item);
    await _scheduleTodaySummaryNotification();
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
    var firstScheduledAt = DateTime(now.year, now.month, now.day, 9, 0);
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

  Future<void> _scheduleNotifications(DdayItem item) async {
    final notificationId = NotificationService.idFromString(item.id);
    if (!_globalReminderEnabled) {
      await NotificationService.cancel(notificationId);
      return;
    }
    await NotificationService.cancel(notificationId);

    final plan = _nextNotificationPlan(item);
    if (plan == null) return;

    final bodyPrefix = plan.fallbackToTargetTime ? L.of(context).pick(ko: '알림 시간이 지나 D-day 정각으로 보정됨', en: 'Reminder time passed, adjusted to event time', ja: '通知時刻が過ぎたため予定時刻に調整しました', vi: 'Giờ nhắc đã qua, chuyển sang giờ sự kiện') : _alarmText(item.alarmMinutesBefore);

    await NotificationService.schedule(
      id: notificationId,
      title: L.of(context).pick(ko: 'D-day 알림: ${item.title}', en: 'D-day reminder: ${item.title}', ja: 'D-day通知: ${item.title}', vi: 'Nhắc D-day: ${item.title}'),
      body: '$bodyPrefix · ${_fullDate(plan.target)} ${_timeText(TimeOfDay.fromDateTime(plan.target))}',
      scheduledAt: plan.alarmAt,
      payload: item.id,
    );
  }

  Future<void> _deleteItem(DdayItem item) async {
    await NotificationService.cancel(NotificationService.idFromString(item.id));
    setState(() {
      _items.removeWhere((e) => e.id == item.id);
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
    await _updateHomeWidget();
    await _scheduleTodaySummaryNotification();
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
    final result = await Navigator.of(context).push<DdayItem>(
      MaterialPageRoute(builder: (_) => EditPage(item: item)),
    );
    if (result != null) await _upsertItem(result);
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
                              _confirmDelete(item);
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
              _menuTile(Icons.delete_outline, L.of(context).delete, () {
                Navigator.pop(context);
                _confirmDelete(item);
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

  Future<void> _requestPinHomeWidget({required bool wide}) async {
    final providerName = wide ? 'DdayWidgetProviderWide' : 'DdayWidgetProvider';
    final widgetLabel = wide ? L.of(context).pick(ko: '넓은 위젯(2개 표시)', en: 'Wide widget (2 events)', ja: '横長ウィジェット（2件）', vi: 'Widget rộng (2 sự kiện)') : L.of(context).pick(ko: '작은 위젯(1개 표시)', en: 'Small widget (1 event)', ja: '小さいウィジェット（1件）', vi: 'Widget nhỏ (1 sự kiện)');

    await _updateHomeWidget();

    bool supported = false;
    try {
      supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      supported = false;
    }

    if (!mounted) return;

    if (!supported) {
      await _showManualWidgetGuide(widgetLabel);
      return;
    }

    try {
      await HomeWidget.requestPinWidget(
        name: providerName,
        androidName: providerName,
        qualifiedAndroidName: 'com.example.dday_app.$providerName',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).pick(ko: '$widgetLabel 추가 요청을 보냈습니다. 홈 화면에서 확인해보세요.', en: '$widgetLabel add request sent. Check your home screen.', ja: '$widgetLabel の追加リクエストを送信しました。ホーム画面を確認してください。', vi: 'Đã gửi yêu cầu thêm $widgetLabel. Hãy kiểm tra màn hình chính.'))),
      );
    } catch (_) {
      if (!mounted) return;
      await _showManualWidgetGuide(widgetLabel);
    }
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
          onAddSmall: () => _requestPinHomeWidget(wide: false),
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
                  _drawerTile(Icons.palette_rounded, l.pick(ko: '테마 설정', en: 'Theme', ja: 'テーマ', vi: 'Giao diện'), () { Navigator.pop(context); _showThemeComingSoon(); }),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8), child: Divider(height: 1)),
                  _drawerTile(Icons.privacy_tip_outlined, l.pick(ko: '개인정보 처리방침', en: 'Privacy policy', ja: 'プライバシーポリシー', vi: 'Chính sách bảo mật'), () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _LegalPage(type: 'privacy'))); }),
                  _drawerTile(Icons.description_outlined, l.pick(ko: '이용약관', en: 'Terms of use', ja: '利用規約', vi: 'Điều khoản sử dụng'), () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _LegalPage(type: 'terms'))); }),
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

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap, {bool selected = false, String? trailingText}) {
    final color = selected ? const Color(0xFF111827) : const Color(0xFF111827);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? const Color(0xFFF3F4F6) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: color))),
                if (trailingText != null) Text(trailingText, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
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
    int? defaultAlarmMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nextReminderEnabled = reminderEnabled ?? _globalReminderEnabled;
    final nextTodaySummaryEnabled = todaySummaryEnabled ?? _todaySummaryEnabled;
    final nextDefaultAlarmMinutes = defaultAlarmMinutes ?? _defaultAlarmMinutesBefore;

    await prefs.setBool(_globalReminderEnabledKey, nextReminderEnabled);
    await prefs.setBool(_todaySummaryEnabledKey, nextTodaySummaryEnabled);
    await prefs.setInt(_defaultAlarmMinutesKey, nextDefaultAlarmMinutes);

    if (!mounted) return;
    setState(() {
      _globalReminderEnabled = nextReminderEnabled;
      _todaySummaryEnabled = nextTodaySummaryEnabled;
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
          Future<void> updateSheet({bool? reminderEnabled, bool? todaySummaryEnabled, int? defaultAlarmMinutes}) async {
            sheetSetState(() {
              if (reminderEnabled != null) _globalReminderEnabled = reminderEnabled;
              if (todaySummaryEnabled != null) _todaySummaryEnabled = todaySummaryEnabled;
              if (defaultAlarmMinutes != null) _defaultAlarmMinutesBefore = defaultAlarmMinutes;
            });
            await _saveGlobalReminderSettings(
              reminderEnabled: reminderEnabled,
              todaySummaryEnabled: todaySummaryEnabled,
              defaultAlarmMinutes: defaultAlarmMinutes,
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
                    Text(l.pick(ko: '전체 알림 정책과 새 일정의 기본 알림값을 정합니다.', en: 'Set app-wide reminders and the default for new events.', ja: '全体の通知設定と新しい予定の初期値を設定します。', vi: 'Đặt nhắc nhở toàn ứng dụng và mặc định cho sự kiện mới.'), style: const TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_rounded, color: Color(0xFF111827)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.pick(ko: '전체 알림 사용', en: 'Use reminders', ja: '通知を使用', vi: 'Dùng nhắc nhở'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                                const SizedBox(height: 3),
                                Text(l.pick(ko: '끄면 모든 일정 알림과 요약 알림이 멈춥니다.', en: 'Turning this off stops event and summary reminders.', ja: 'オフにすると予定通知と要約通知が停止します。', vi: 'Tắt mục này sẽ dừng mọi nhắc nhở.'), style: const TextStyle(fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                          Switch(value: _globalReminderEnabled, activeColor: const Color(0xFF2563EB), onChanged: (value) => updateSheet(reminderEnabled: value)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Row(
                        children: [
                          const Icon(Icons.wb_sunny_outlined, color: Color(0xFF111827)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.pick(ko: '오늘 일정 요약', en: 'Today summary', ja: '今日の予定まとめ', vi: 'Tóm tắt hôm nay'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                                const SizedBox(height: 3),
                                Text(l.pick(ko: '매일 오전 9시에 오늘의 일정을 한 번 알려줍니다.', en: 'Once a day at 9 AM, TickDay reminds you of today’s events.', ja: '毎朝9時に今日の予定を一度お知らせします。', vi: 'Mỗi ngày lúc 9 giờ sáng, TickDay nhắc các sự kiện hôm nay.'), style: const TextStyle(fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                          Switch(value: _todaySummaryEnabled, activeColor: const Color(0xFF2563EB), onChanged: _globalReminderEnabled ? (value) => updateSheet(todaySummaryEnabled: value) : null),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
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


  void _showAppMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.45),
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final isLandscape = media.orientation == Orientation.landscape;
        final maxHeight = media.size.height * (isLandscape ? 0.58 : 0.82);

        Widget compactTile(IconData icon, String text, VoidCallback onTap) {
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 14 : 18,
                vertical: isLandscape ? 8 : 13,
              ),
              child: Row(
                children: [
                  Icon(icon, size: isLandscape ? 20 : 24, color: const Color(0xFF111827)),
                  SizedBox(width: isLandscape ? 12 : 16),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isLandscape ? 14 : 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
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
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(16, 0, 16, isLandscape ? 8 : 16),
                padding: EdgeInsets.symmetric(vertical: isLandscape ? 8 : 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isLandscape ? 18 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      compactTile(Icons.notifications_active_rounded, L.of(context).pick(ko: '즉시 테스트 알림', en: 'Send test notification', ja: 'テスト通知を送信', vi: 'Gửi thông báo thử'), () async {
                        Navigator.pop(sheetContext);
                        await NotificationService.showNow(title: L.of(context).pick(ko: '테스트 알림', en: 'Test notification', ja: 'テスト通知', vi: 'Thông báo thử'), body: L.of(context).pick(ko: '이 알림이 보이면 기본 알림은 성공입니다.', en: 'If you see this, basic notifications are working.', ja: 'この通知が見えれば基本通知は正常です。', vi: 'Nếu bạn thấy thông báo này, thông báo cơ bản hoạt động.')); 
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.of(context).pick(ko: '즉시 테스트 알림을 보냈습니다.', en: 'Test notification sent.', ja: 'テスト通知を送信しました。', vi: 'Đã gửi thông báo thử.'))));
                      }),
                      compactTile(Icons.timer_rounded, L.of(context).pick(ko: '5초 뒤 예약 테스트', en: 'Schedule test in 5 sec', ja: '5秒後の予約テスト', vi: 'Thử đặt sau 5 giây'), () async {
                        Navigator.pop(sheetContext);
                        final ok = await NotificationService.schedule(
                          id: 999002,
                          title: L.of(context).pick(ko: '예약 테스트 알림', en: 'Scheduled test notification', ja: '予約テスト通知', vi: 'Thông báo thử đã đặt'),
                          body: L.of(context).pick(ko: '5초 뒤 예약 알림이 정상 작동했습니다.', en: 'The 5-second scheduled notification worked.', ja: '5秒後の予約通知が正常に動作しました。', vi: 'Thông báo đặt sau 5 giây đã hoạt động.'),
                          scheduledAt: DateTime.now().add(const Duration(seconds: 5)),
                          payload: '__test__',
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? L.of(context).pick(ko: '5초 뒤 예약 테스트를 걸었습니다.', en: 'Scheduled a test notification in 5 seconds.', ja: '5秒後の予約テストを設定しました。', vi: 'Đã đặt thông báo thử sau 5 giây.') : L.of(context).pick(ko: '예약 테스트 등록에 실패했습니다. 알림/정확한 알람 권한을 확인해주세요.', en: 'Failed to schedule test. Check notification/exact alarm permissions.', ja: '予約テストに失敗しました。通知／正確なアラーム権限を確認してください。', vi: 'Không thể đặt thử. Hãy kiểm tra quyền thông báo/báo thức chính xác.'))),
                        );
                      }),
                      compactTile(Icons.widgets_outlined, L.of(context).addHomeWidget, () {
                        Navigator.pop(sheetContext);
                        _showWidgetPlanSheet();
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
    final isAllGood = !hasCriticalIssue && !hasWarning;

    final bgColor = hasCriticalIssue
        ? const Color(0xFFFFF1F2)
        : hasWarning
            ? const Color(0xFFFFF7E6)
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
    final statusText = hasCriticalIssue
        ? l.pick(ko: '설정 필요', en: 'Needs setup', ja: '設定が必要', vi: 'Cần cài đặt')
        : hasWarning
            ? l.pick(ko: '확인 필요', en: 'Check', ja: '確認', vi: 'Kiểm tra')
            : l.pick(ko: '정상 작동', en: 'Working', ja: '正常動作', vi: 'Đang hoạt động');
    final title = isAllGood
        ? l.pick(ko: '알림이 정상 작동 중이에요', en: 'Reminders are working', ja: '通知は正常に動作中です', vi: 'Nhắc nhở đang hoạt động')
        : l.permissionTitle;
    final subtitle = hasCriticalIssue
        ? l.pick(ko: '알림 권한을 켜야 일정 알림을 받을 수 있어요.', en: 'Turn on notifications to receive reminders.', ja: '通知を受け取るには権限をオンにしてください。', vi: 'Bật thông báo để nhận nhắc nhở.')
        : hasWarning
            ? l.pick(ko: '정확한 시간 알림을 위해 알람 권한을 확인해주세요.', en: 'Check exact alarm permission for on-time reminders.', ja: '正確な時刻の通知にはアラーム権限を確認してください。', vi: 'Kiểm tra quyền báo thức để nhắc đúng giờ.')
            : l.pick(ko: '일정 알림과 오늘 요약이 준비되어 있어요.', en: 'Event reminders and today summary are ready.', ja: '予定通知と今日のまとめが準備できています。', vi: 'Nhắc lịch và tóm tắt hôm nay đã sẵn sàng.');

    Future<void> sendQuickTest() async {
      await NotificationService.showNow(
        id: 999778,
        title: l.pick(ko: 'TickDay 알림 확인', en: 'TickDay reminder check', ja: 'TickDay通知チェック', vi: 'Kiểm tra nhắc nhở TickDay'),
        body: l.pick(ko: '알림이 정상적으로 표시됩니다.', en: 'Notifications are showing correctly.', ja: '通知は正常に表示されています。', vi: 'Thông báo hiển thị bình thường.'),
        payload: 'today_summary',
      );
      await _refreshPermissionStatus();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.78), borderRadius: BorderRadius.circular(14)),
                  child: Icon(isAllGood ? Icons.verified_rounded : Icons.notifications_active_rounded, color: accentColor, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                        softWrap: true,
                        style: const TextStyle(fontSize: 17, height: 1.18, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -0.2),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.8, height: 1.35, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.78), borderRadius: BorderRadius.circular(999)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 6, height: 6, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                                const SizedBox(width: 5),
                                Text(statusText, style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w800, color: accentColor)),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _permissionCardExpanded = !_permissionCardExpanded),
                    icon: Icon(_permissionCardExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18),
                    label: Text(_permissionCardExpanded ? l.pick(ko: '접기', en: 'Hide', ja: '閉じる', vi: 'Ẩn') : l.pick(ko: '상세 보기', en: 'Details', ja: '詳細', vi: 'Chi tiết'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.70), side: BorderSide(color: accentColor.withOpacity(0.20)), foregroundColor: const Color(0xFF374151), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: sendQuickTest,
                    icon: const Icon(Icons.notifications_active_outlined, size: 17),
                    label: Text(l.pick(ko: '알림 테스트', en: 'Test', ja: 'テスト', vi: 'Thử'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
                  message: l.pick(ko: '일정 알림과 오늘 요약을 받으려면 앱 알림 권한이 필요합니다.', en: 'Notification permission is required for event reminders and today summary.', ja: '予定通知と今日のまとめには通知権限が必要です。', vi: 'Cần quyền thông báo cho nhắc lịch và tóm tắt hôm nay.'),
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
                  title: l.pick(ko: '정확한 알람 권한', en: 'Exact alarm permission', ja: '正確なアラーム権限', vi: 'Quyền báo thức chính xác'),
                  message: l.pick(ko: '정확한 시간에 알림을 울리려면 알람 및 리마인더 권한이 필요합니다.', en: 'Exact alarm permission helps reminders ring at the right time.', ja: '正確な時刻に通知するにはアラーム権限が必要です。', vi: 'Quyền báo thức giúp nhắc đúng giờ.'),
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
                  label: Text(l.pick(ko: '상태 새로고침', en: 'Refresh', ja: '更新', vi: 'Làm mới'), style: const TextStyle(fontWeight: FontWeight.w800)),
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
    // 개인 일정 카드가 하나라도 있으면 온보딩 공지 카드는 숨깁니다.
    if (_items.isNotEmpty) return const SizedBox.shrink();

    final notices = <Widget>[];

    if (!_hideIntroNotice) {
      notices.add(_noticeCard(
        L.of(context).pick(ko: '첫 소중한 날을 기록해보세요', en: 'Save your first special day', ja: '最初の大切な日を記録しましょう', vi: 'Lưu ngày đặc biệt đầu tiên'),
        L.of(context).pick(ko: '생일, 기념일, 여행까지 한눈에 관리하세요.', en: 'Track birthdays, anniversaries, trips and more.', ja: '誕生日、記念日、旅行まで一目で管理。', vi: 'Theo dõi sinh nhật, kỷ niệm và chuyến đi.'),
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
        L.of(context).pick(ko: '가까운 D-day를 위젯으로 한눈에 볼 수 있어요.', en: 'See your upcoming D-days as widgets.', ja: '近いD-dayをウィジェットで確認できます。', vi: 'Xem D-day sắp tới bằng widget.'),
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
    Color(0xFF8B5CF6), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF111827), // black
    Color(0xFF6B7280), // gray
    Color(0xFF64748B), // slate
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
    if (picked != null) {
      setState(() {
        final yearChanged = picked.year != _date.year;
        _date = picked;

        // 매년 반복 일정은 원래 '년도'를 무시하고 월/일만 계산합니다.
        // 그래서 사용자가 편집 화면에서 년도를 직접 바꿨을 때는
        // 실제 변경 의도가 반영되도록 자동으로 '반복 안 함'으로 전환합니다.
        if (yearChanged && _repeatType == 'yearly') {
          _repeatType = 'none';
        }
      });
    }
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