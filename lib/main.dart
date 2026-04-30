import 'dart:async';
import 'dart:convert';

import 'services/notification_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const DdayApp());
}

class DdayApp extends StatelessWidget {
  const DdayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'D-day App',
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3182F6)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class DdayItem {
  final String title;
  final DateTime targetDate;
  final int iconCodePoint;
  final int colorValue;
  final DateTime createdAt;
  final String repeatType;

  DdayItem({
    required this.title,
    required this.targetDate,
    required this.iconCodePoint,
    required this.colorValue,
    DateTime? createdAt,
    this.repeatType = 'none',
  }) : createdAt = createdAt ?? DateTime.now();

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Color get color => Color(colorValue);

  bool get isYearly => repeatType == 'yearly';

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'targetDate': targetDate.toIso8601String(),
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'repeatType': repeatType,
    };
  }

  factory DdayItem.fromJson(Map<String, dynamic> json) {
    return DdayItem(
      title: json['title'] as String,
      targetDate: DateTime.parse(json['targetDate'] as String),
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['createdAt'] as String),
      repeatType: (json['repeatType'] as String?) ?? 'none',
    );
  }

  DdayItem copyWith({
    String? title,
    DateTime? targetDate,
    int? iconCodePoint,
    int? colorValue,
    DateTime? createdAt,
    String? repeatType,
  }) {
    return DdayItem(
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      repeatType: repeatType ?? this.repeatType,
    );
  }
}

enum ViewMode { card, list }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String storageKey = 'dday_items';

  List<DdayItem> items = [];
  ViewMode viewMode = ViewMode.card;
  Timer? timer;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    loadItems();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(storageKey);

    if (saved == null || saved.isEmpty) {
      items = [];
      await saveItems();
    } else {
      final decoded = jsonDecode(saved) as List<dynamic>;
      items = decoded
          .map((e) => DdayItem.fromJson(e as Map<String, dynamic>))
          .toList();
      sortItems();
      await saveItems();
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }

  void sortItems() {
    items.sort(
      (a, b) => getNextOccurrence(a).compareTo(getNextOccurrence(b)),
    );
  }

  DateTime getNextOccurrence(DdayItem item) {
    final targetDate = item.targetDate;

    if (item.repeatType == 'yearly') {
      final today = DateTime(now.year, now.month, now.day);
      DateTime next = DateTime(now.year, targetDate.month, targetDate.day);

      if (next.isBefore(today)) {
        next = DateTime(now.year + 1, targetDate.month, targetDate.day);
      }

      return next;
    }

    return DateTime(targetDate.year, targetDate.month, targetDate.day);
  }

  int getDday(DdayItem item) {
    final today = DateTime(now.year, now.month, now.day);
    final target = getNextOccurrence(item);
    return target.difference(today).inDays;
  }

  String getDdayText(DdayItem item) {
    final dday = getDday(item);

    if (dday == 0) return 'D-Day';
    if (dday > 0) return 'D-$dday';
    return 'D+${dday.abs()}';
  }

  String getRemainTimeText(DdayItem item) {
    final targetDate = getNextOccurrence(item);
    final target = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      0,
      0,
      0,
    );

    final difference = target.difference(now);

    if (difference.isNegative) {
      final passed = now.difference(target);
      final days = passed.inDays;
      final hours = passed.inHours % 24;
      final minutes = passed.inMinutes % 60;
      return '$days일 $hours시간 $minutes분 지남';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    return '$days일 $hours시간 $minutes분 남음';
  }

  String getSmallTimeText(DdayItem item) {
    final targetDate = getNextOccurrence(item);
    final target = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      0,
      0,
      0,
    );

    final difference = target.difference(now);

    if (difference.isNegative) {
      return '지남';
    }

    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    return '$hours시간 $minutes분';
  }

  double getProgressValue(DdayItem item) {
    final targetDate = getNextOccurrence(item);
    final target = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      0,
      0,
      0,
    );

    final start = item.createdAt;

    if (now.isAfter(target) || now.isAtSameMomentAs(target)) {
      return 1.0;
    }

    if (now.isBefore(start) || now.isAtSameMomentAs(start)) {
      return 0.0;
    }

    final total = target.difference(start).inSeconds;
    final passed = now.difference(start).inSeconds;

    if (total <= 0) return 1.0;

    return (passed / total).clamp(0.0, 1.0);
  }

  Future<void> openAddScreen() async {
    final newItem = await Navigator.push<DdayItem>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddDdayScreen(),
      ),
    );

    if (newItem == null) return;

    setState(() {
      items.add(newItem);
      sortItems();
    });

    // 🔥 알림 추가
    await NotificationService.scheduleDdayNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: newItem.title,
      targetDate: newItem.targetDate,
    );

    await saveItems();
  }

  Future<void> openEditScreen(DdayItem item) async {
    final editedItem = await Navigator.push<DdayItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDdayScreen(
          item: item,
        ),
      ),
    );

    if (editedItem == null) return;

    final index = items.indexOf(item);
    if (index == -1) return;

    setState(() {
      items[index] = editedItem;
      sortItems();
    });

    await saveItems();
  }

  Future<void> deleteItem(DdayItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('일정 삭제'),
          content: Text('"${item.title}" 일정을 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Color(0xFFFF5A5F),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      items.remove(item);
    });

    await saveItems();
  }

  Future<void> duplicateItem(DdayItem item) async {
    final copied = item.copyWith(
      title: '${item.title} 복사본',
      createdAt: DateTime.now(),
    );

    setState(() {
      items.add(copied);
      sortItems();
    });

    await saveItems();
  }

  void showComingSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Future<void> handleItemMenu(String value, DdayItem item) async {
    if (value == 'share') {
      showComingSoon('공유 기능은 다음 단계에서 연결합니다.');
    } else if (value == 'edit') {
      await openEditScreen(item);
    } else if (value == 'duplicate') {
      await duplicateItem(item);
    } else if (value == 'delete') {
      await deleteItem(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
                children: [
                  _buildNoticeArea(),
                  const SizedBox(height: 18),
                  _buildSectionTitle(),
                  const SizedBox(height: 12),
                  if (items.isEmpty) _buildEmptyState() else _buildCardArea(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddScreen,
        backgroundColor: const Color(0xFF3182F6),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.add_rounded, size: 34),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FB),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.menu_rounded,
              color: Color(0xFF111827),
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '카운트다운',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '소중한 날을 놓치지 마세요',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFF111827),
                size: 29,
              ),
            ),
            onSelected: (value) {
              showComingSoon('이 메뉴는 다음 단계에서 연결합니다.');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'settings',
                child: Text('설정'),
              ),
              PopupMenuItem(
                value: 'help',
                child: Text('도움말'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeArea() {
    return Row(
      children: [
        Expanded(
          child: _buildNoticeCard(
            title: '첫 일정을 등록해보세요',
            body: '생일, 시험, 여행처럼 중요한 날을 한눈에 관리할 수 있어요.',
            icon: Icons.add_circle_outline_rounded,
            backgroundColor: const Color(0xFF3182F6),
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildNoticeCard(
            title: '위젯 준비 중',
            body: '홈 화면에서 바로 볼 수 있는 위젯 기능을 곧 추가할 예정이에요.',
            icon: Icons.widgets_rounded,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeCard({
    required String title,
    required String body,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    final isWhite = backgroundColor == Colors.white;

    return Container(
      height: 154,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: isWhite
            ? Border.all(
                color: const Color(0xFFE5EAF2),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isWhite ? 0.035 : 0.09),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            top: -4,
            child: Icon(
              icon,
              color: foregroundColor.withOpacity(isWhite ? 0.14 : 0.22),
              size: 58,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor.withOpacity(isWhite ? 0.62 : 0.88),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '내 일정',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              viewMode = viewMode == ViewMode.card ? ViewMode.list : ViewMode.card;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFFE5EAF2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  viewMode == ViewMode.card
                      ? Icons.grid_view_rounded
                      : Icons.list_rounded,
                  size: 17,
                  color: const Color(0xFF3182F6),
                ),
                const SizedBox(width: 6),
                Text(
                  viewMode == ViewMode.card ? '카드' : '목록',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardArea() {
    if (viewMode == ViewMode.list) {
      return Column(
        children: items.map(_buildListCard).toList(),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (context, index) {
        return _buildDdayCard(items[index]);
      },
    );
  }

  Widget _buildDdayCard(DdayItem item) {
    final dday = getDday(item);
    final isToday = dday == 0;
    final progress = getProgressValue(item).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE9EEF6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.targetDate.year}.${item.targetDate.month.toString().padLeft(2, '0')}.${item.targetDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7B8494),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (item.isYearly)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '매년',
                        style: TextStyle(
                          fontSize: 10,
                          color: item.color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 116,
                  height: 116,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 116,
                        height: 116,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFFE9EEF6),
                          valueColor: AlwaysStoppedAnimation<Color>(item.color),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isToday
                                    ? 'D-Day'
                                    : dday > 0
                                        ? '${dday}일'
                                        : '+${dday.abs()}일',
                                style: const TextStyle(
                                  fontSize: 25,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isToday ? '오늘' : getSmallTimeText(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isToday ? '오늘입니다' : getRemainTimeText(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Positioned(
            top: -8,
            right: -12,
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF9AA4B2),
                size: 24,
              ),
              onSelected: (value) => handleItemMenu(value, item),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'share',
                  child: Text('공유'),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text('편집'),
                ),
                PopupMenuItem(
                  value: 'duplicate',
                  child: Text('복사본 만들기'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('삭제'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(DdayItem item) {
    final dday = getDday(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE9EEF6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: getProgressValue(item),
              strokeWidth: 5,
              backgroundColor: const Color(0xFFE9EEF6),
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
              strokeCap: StrokeCap.round,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  getRemainTimeText(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            dday == 0
                ? '오늘'
                : dday > 0
                    ? 'D-$dday'
                    : 'D+${dday.abs()}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: item.color,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFF9AA4B2),
            ),
            onSelected: (value) => handleItemMenu(value, item),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'share',
                child: Text('공유'),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Text('편집'),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Text('복사본 만들기'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 46, 22, 46),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE9EEF6),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 58,
            color: Color(0xFF3182F6),
          ),
          SizedBox(height: 18),
          Text(
            '아직 등록된 일정이 없어요',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '+ 버튼을 눌러 첫 일정을 추가해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class AddDdayScreen extends StatefulWidget {
  final DdayItem? item;

  const AddDdayScreen({
    super.key,
    this.item,
  });

  @override
  State<AddDdayScreen> createState() => _AddDdayScreenState();
}

class _AddDdayScreenState extends State<AddDdayScreen> {
  final TextEditingController titleController = TextEditingController();

  DateTime? selectedDate;
  int selectedIconCodePoint = Icons.star_rounded.codePoint;
  int selectedColorValue = const Color(0xFF3182F6).value;
  String repeatType = 'none';

  bool get isEditMode => widget.item != null;

  final List<IconData> iconOptions = const [
    Icons.star_rounded,
    Icons.favorite_rounded,
    Icons.cake_rounded,
    Icons.flight_takeoff_rounded,
    Icons.school_rounded,
    Icons.work_rounded,
    Icons.home_rounded,
    Icons.pets_rounded,
  ];

  final List<Color> colorOptions = const [
    Color(0xFF3182F6),
    Color(0xFFFF6B81),
    Color(0xFFFFA726),
    Color(0xFF00B894),
    Color(0xFF8E44AD),
    Color(0xFF2D3436),
  ];

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    if (item != null) {
      titleController.text = item.title;
      selectedDate = item.targetDate;
      selectedIconCodePoint = item.iconCodePoint;
      selectedColorValue = item.colorValue;
      repeatType = item.repeatType;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 50),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3182F6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });
  }

  void save() {
    final title = titleController.text.trim();

    if (title.isEmpty) {
      showSnackBar('제목을 입력해 주세요.');
      return;
    }

    if (selectedDate == null) {
      showSnackBar('날짜를 선택해 주세요.');
      return;
    }

    final original = widget.item;

    final item = DdayItem(
      title: title,
      targetDate: selectedDate!,
      iconCodePoint: selectedIconCodePoint,
      colorValue: selectedColorValue,
      createdAt: original?.createdAt ?? DateTime.now(),
      repeatType: repeatType,
    );

    Navigator.pop(context, item);
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  String getDateText() {
    if (selectedDate == null) return '날짜를 선택하세요';

    final date = selectedDate!;
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String getRepeatText() {
    if (repeatType == 'yearly') return '매년 반복';
    return '반복 없음';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Text(
          isEditMode ? '일정 편집' : '일정 추가',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 120),
          children: [
            Text(
              isEditMode ? '일정을 수정해보세요' : '어떤 날을 기다리고 있나요?',
              style: const TextStyle(
                fontSize: 25,
                height: 1.18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '제목과 날짜를 입력하면 자동으로 남은 시간이 계산됩니다.',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '제목',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: '예: 생일, 여행, 시험',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9AA4B2),
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FB),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              child: InkWell(
                onTap: pickDate,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: Color(selectedColorValue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          getDateText(),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: selectedDate == null
                                ? const Color(0xFF9AA4B2)
                                : const Color(0xFF111827),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9AA4B2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '반복',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRepeatButton(
                          label: '반복 없음',
                          value: 'none',
                          icon: Icons.event_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildRepeatButton(
                          label: '매년 반복',
                          value: 'yearly',
                          icon: Icons.repeat_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '아이콘',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: iconOptions.map((icon) {
                      final selected = selectedIconCodePoint == icon.codePoint;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedIconCodePoint = icon.codePoint;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected
                                ? Color(selectedColorValue).withOpacity(0.13)
                                : const Color(0xFFF5F7FB),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: selected
                                  ? Color(selectedColorValue)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: selected
                                ? Color(selectedColorValue)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '색상',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: colorOptions.map((color) {
                      final selected = selectedColorValue == color.value;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedColorValue = color.value;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF111827)
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.22),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 24,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: const Color(0xFFF5F7FB),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3182F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                isEditMode ? '수정 완료' : '저장하기',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatButton({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final selected = repeatType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          repeatType = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        decoration: BoxDecoration(
          color: selected
              ? Color(selectedColorValue).withOpacity(0.12)
              : const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? Color(selectedColorValue) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? Color(selectedColorValue) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: selected ? const Color(0xFF111827) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
